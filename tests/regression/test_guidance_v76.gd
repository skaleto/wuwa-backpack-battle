extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const F=preload("res://scripts/crafting/craft.gd")
var game
var checks=0
var failures=0
func ck(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():call_deferred("run_tests")
func setup():
	game.fusion_view.finish();game.reset_slice();game.run.serial=20
	game.run.items=[game.piece("w_sword","i1",0,0),game.piece("mat_43020011","i2",0,1)]
	# V113's wider random shelf may add unrelated shop-to-shop recipe links.
	# Each shop scenario below supplies its own offers; board cases use none.
	game.run.shop=[{},{},{},{},{},{}]
	game.run.stash=[];game.run.primary="i1";game.mouse=Vector2(950,100)
	game.motion.modal_value=0;game.motion.modal_target=0
func run_tests():
	game=G.new();root.add_child(game);await process_frame
	game.set_process(false);game.set_process_input(false);setup()
	ck(game.inline_craft.links(game._craft_view_model()).size()==1,"adjacent exact pair keeps relation when output cannot fit")
	var before=game.run.duplicate(true);var relations=F.relationships(game.run,game.inventory)
	ck(relations.size()==1 and relations[0].ready and relations[0].get("destination","")=="stash" and relations[0].blocked.is_empty(),"V79 blocked board output falls back to storage without red cells")
	ck(game.run==before,"relationship query is read-only")
	var expanded=game.piece("strip","b2",3,0);expanded.rotation=1;game.run.bags.append(expanded)
	var links=game.inline_craft.links(game._craft_view_model())
	ck(links.size()==1 and links[0].ready,"extra capacity changes potential into ready")
	game.inline_craft.refresh(game._craft_view_model());ck(game.inline_craft.entries.size()==1,"ready button remains actionable")
	game.run.items.append(game.piece("nutrition","i3",3,0));links=game.inline_craft.links(game._craft_view_model())
	ck(links.size()==1 and links[0].ready and links[0].get("destination","")=="stash","V79 occupying board output keeps ready storage fallback")
	game.inline_craft.refresh(game._craft_view_model());ck(game.inline_craft.entries.size()==1,"V79 output can be crafted directly into storage")
	game.hovered={"origin":"board","item":game.run.items[-1]};ck(game.inline_craft.links(game._craft_view_model()).size()==1,"unrelated owned hover does not erase adjacent pair")
	game.hovered={}
	# Exact kind, distinct identities, and reverse direction.
	setup();var a=game.run.items[0];var b=game.run.items[1]
	ck(F.pair_recipes(game.run,a,b,game.inventory)==F.pair_recipes(game.run,b,a,game.inventory),"recipe query symmetric in its two inputs")
	ck(F.pair_recipes(game.run,a,a,game.inventory).is_empty(),"same UID cannot supply two inputs")
	ck(F.pair_recipes(game.run,a,game.piece("nutrition","other",0,1),game.inventory).is_empty(),"unrelated items never gain recipe hint")
	var gated=game.C.combinations.filter(func(v):return int(v.round_min)>1 and game.inventory.craft_unlocked(game.run,v.target))
	if not gated.is_empty():
		var recipe=gated[0];var ga={"kind":recipe.base,"uid":"ga"};var gb={"kind":recipe.materials[0],"uid":"gb"}
		game.run.round=int(recipe.round_min)-1;ck(not F.pair_recipes(game.run,ga,gb,game.inventory).is_empty(),"V80 early owned recipe stays visible")
		game.run.round=int(recipe.round_min);ck(not F.pair_recipes(game.run,ga,gb,game.inventory).is_empty(),"V80 recipe remains visible in later rounds")
	setup()
	# V113 supersedes the old owner/type-hidden recipe contract. At round one,
	# every exact pair is visible with no recruits, including foreign signatures.
	for recipe in game.C.combinations:
		ck(not F.pair_recipes(game.run,{"kind":recipe.base,"uid":"ga"},{"kind":recipe.materials[0],"uid":"gb"},game.inventory).is_empty(),"V113 unrecruited exact recipe remains visible "+recipe.id)
	setup();game.run.bags.append(expanded);game.run.items.append(game.piece("mat_43020011","i9",1,1))
	relations=F.relationships(game.run,game.inventory)
	var ready=relations.filter(func(v):return v.ready)
	ck(ready.size()==1 and ready[0].material_uid=="i2","only actual preview consumption marks duplicate material ready")
	# Shop hints persist and connect exact owned endpoints on either surface.
	setup();game.run.items.pop_back();game.run.shop=[{"kind":"mat_43020011","locked":false},{},{},{},{},{}]
	ck(game.inline_craft.matching_offers(game._craft_view_model())==[0],"shop offer highlights matching board item")
	game.mouse=game._offer_rect(0).get_center();links=game.inline_craft.links(game._craft_view_model())
	ck(links.size()==1 and not links[0].ready and links[0].to==game._shop_icon_rect(0).get_center(),"shop focus line reaches offered body")
	game._open_item_details(game.inventory.make_piece("mat_43020011","shop-preview"),"shop");game.detail_offer_index=0
	game.mouse=Vector2(950,100);links=game.inline_craft.links(game._craft_view_model())
	ck(links.size()==1,"selected detail card retains pre-craft relation")
	game.detail_parent_overlay="catalogue";ck(game.inline_craft.links(game._craft_view_model()).is_empty(),"detail opened from encyclopedia keeps real modal suppression")
	game.detail_parent_overlay=""
	game.overlay="catalogue";ck(game.inline_craft.links(game._craft_view_model()).is_empty(),"real modal suppresses guidance")
	game.overlay="";ck(game.inventory.stash(game.run,game.run.items[0]),"store base for shop guidance")
	game.mouse=game._offer_rect(0).get_center();links=game.inline_craft.links(game._craft_view_model())
	ck(links.size()==1 and links[0].from==game._stash_rect(0).get_center(),"stored base is a true line endpoint")
	game.run.shop[0]={"kind":"nutrition","locked":false};ck(game.inline_craft.matching_offers(game._craft_view_model()).is_empty(),"refresh invalidates obsolete recipe offer")
	game.run.shop[0]={"kind":"w_sword","locked":false};game.run.stash=[b.duplicate(true)]
	ck(game.inline_craft.matching_offers(game._craft_view_model())==[0],"reverse offer direction matches stored ingredient")
	# Held endpoints move continuously even while outside a legal board position.
	setup();game.run.items.pop_back();game.run.shop=[{"kind":"mat_43020011","locked":false},{},{},{},{},{}]
	game._begin_shop_drag(0);game.drag_pressed=false;game.mouse=game._stash_mat_rect().get_center();game._start_held_pose()
	before=game.run.duplicate(true);links=game.inline_craft.links(game._craft_view_model())
	ck(links.size()==1 and not links[0].ready,"held shop item outside board keeps potential only")
	game.mouse+=Vector2(7,3);var moved=game.inline_craft.links(game._craft_view_model())
	ck(moved.size()==1 and (moved[0].to-links[0].to).is_equal_approx(Vector2(7,3)) and moved[0].to.is_equal_approx(game._held_pose()*game._projection_for(game.drag_source.kind,int(game.drag_source.rotation),game.CELL).center),"held endpoint follows actual body within same cell")
	var cancel=InputEventKey.new();cancel.keycode=KEY_ESCAPE;cancel.pressed=true;game._input(cancel)
	ck(game.dragging.is_empty() and game.run==before,"cancel guidance leaves purchase and ownership unchanged")
	game.run.phase="battle";ck(game.inline_craft.links(game._craft_view_model()).is_empty(),"battle suppresses preparation guidance")
	# Every catalogue pair, including recruited signature owners, uses exact identity.
	var fixture=preload("res://tests/fixtures/craft_fixture_v75.gd")
	for recipe in game.C.combinations:
		var r=fixture.make(game.inventory,recipe.target)
		var base=game.inventory.make_piece(recipe.base,"qa-base")
		var material=game.inventory.make_piece(recipe.materials[0],"qa-material")
		r.items=[base];r.stash=[material];r.primary=base.uid if game.C.is_tag(base.kind,"weapon") else ""
		r.golden_acquired=game.C.is_tag(base.kind,"golden") or game.C.is_tag(material.kind,"golden")
		var potential=F.relationships(r,game.inventory).filter(func(v):return v.target==recipe.target)
		ck(potential.size()==1 and not potential[0].ready,"stored exact partner potential "+recipe.id)
		F.place_material(r,recipe.target,base.uid,material.kind,game.inventory)
		var exact=F.relationships(r,game.inventory).filter(func(v):return v.target==recipe.target and v.ready)
		ck(exact.size()==1,"placed exact pair ready "+recipe.id)
		var gated_run=r.duplicate(true);gated_run.round=maxi(1,int(recipe.round_min)-1)
		ck(not F.pair_recipes(gated_run,base,material,game.inventory).is_empty(),"V80 no round gate for exact pair "+recipe.id)
	# During displacement, the line follows the partner's proposed stash slot.
	setup();game.run.bags.append(expanded);game.run.stash=[game.piece("nutrition","s1",0,0)]
	game.run.shop=[{"kind":"mat_43020011","locked":false},{},{},{},{},{}]
	game.run.items.pop_back();game._begin_shop_drag(0);game.drag_pressed=false
	game.mouse=game._board_to_screen(game.BOARD+Vector2(.5,.5)*game.CELL);game._start_held_pose()
	links=game.inline_craft.links(game._craft_view_model())
	ck(links.size()==1 and not links[0].ready and links[0].from==game._stash_rect(1).get_center(),"displaced partner endpoint uses actual future stash slot")
	before=game.run.duplicate(true);var rot=InputEventKey.new();rot.keycode=KEY_R;rot.pressed=true;game._input(rot)
	ck(game.dragging.rotation==1 and game.run==before,"rotation updates held guidance without live mutation")
	game.dragging={};game._clear_held_pose()
	# Purchase simulation is placement guidance, never owned craft readiness.
	setup();game.run.bags.append(expanded);game.run.items.pop_back();game.run.gold=100
	game.run.shop=[{"kind":"mat_43020011","locked":false},{},{},{},{},{}]
	game._begin_shop_drag(0);game.drag_pressed=false
	game.mouse=game._board_to_screen(game.BOARD+Vector2(.5,1.5)*game.CELL);game._start_held_pose()
	before=game.run.duplicate(true);links=game.inline_craft.links(game._craft_view_model())
	ck(game._item_drop_preview().ok,"shop ingredient has a legal adjacent drop")
	ck(links.size()==1 and not links[0].ready and links[0].status=="potential","unpaid shop ingredient stays potential even at legal ready position")
	ck(game.run==before,"unpaid legal guidance spends no money and creates no ownership")
	var buy_release=InputEventMouseButton.new();buy_release.button_index=MOUSE_BUTTON_LEFT;buy_release.position=game.mouse;game._input(buy_release)
	links=game.inline_craft.links(game._craft_view_model())
	ck(links.size()==1 and links[0].ready and game.run.gold<before.gold and game.run.shop[0].is_empty(),"legal release purchases ingredient and immediately makes real pair ready")
	# No second shop offer may treat an unpaid dragged offer as owned inventory.
	for legal_board in [false,true]:
		setup();game.run.items=[];game.run.stash=[];game.run.primary="";game.run.gold=100
		game.run.shop=[{"kind":"w_sword","locked":false},{"kind":"mat_43020011","locked":false},{},{},{},{}]
		game._begin_shop_drag(1);game.drag_pressed=false
		game.mouse=game._board_to_screen(game.BOARD+Vector2(.5,.5)*game.CELL) if legal_board else game._stash_mat_rect().get_center()
		game._start_held_pose();before=game.run.duplicate(true)
		ck(game.inline_craft.matching_offers(game._craft_view_model())==[0],"V79 visible unpurchased partner highlights without ownership: "+str(legal_board))
		ck(game.inline_craft.links(game._craft_view_model()).size()==1 and not game.inline_craft.links(game._craft_view_model())[0].ready and game.run==before,"V79 two unpaid offers show potential only, without mutation: "+str(legal_board))
	# Geometric adjacency survives duplicate consumption selection.
	setup();game.run.bags.append(expanded);game.run.shop=[{},{},{},{},{},{}]
	game.run.items.append(game.piece("mat_43020011","i9",1,1))
	relations=F.relationships(game.run,game.inventory);links=game.inline_craft.links(game._craft_view_model())
	var duplicate=relations.filter(func(v):return v.material_uid=="i9")
	ck(duplicate.size()==1 and duplicate[0].adjacent and not duplicate[0].ready and duplicate[0].output.is_empty(),"unused duplicate keeps true adjacency without false consumption or output preview")
	ck(links.size()==2 and links.filter(func(v):return v.ready).size()==1,"idle board shows one chosen ready pair and one duplicate potential pair")
	print("GUIDANCE_V76 ",checks," checks, ",failures," failures")
	game.queue_free();await process_frame;quit(1 if failures else 0)
