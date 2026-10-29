extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v114.gd")
const R=preload("res://scripts/party/recruitment_v114.gd")
const P=preload("res://scripts/ui/party/recruitment_presenter.gd")
const FIX=preload("res://tests/fixtures/capacity_fixture_v111.gd")
const PANEL=preload("res://scripts/ui/items/item_panel.gd")
var g
var checks=0
var failures=0
func ck(value:bool,label:String)->void:
	checks+=1
	if not value:failures+=1;printerr("FAIL ",label)
func _initialize()->void:
	root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true)
	call_deferred("run_tests")
func click(point:Vector2)->void:
	for pressed in [true,false]:
		var e=InputEventMouseButton.new();e.position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;g._input(e)
func key(code:int)->void:
	var e=InputEventKey.new();e.keycode=code;e.pressed=true;g._input(e)
func draft(node:int,roles:Array)->void:
	g.recruitment_view.clear();g.crew_setup_view.close();g.run.round=node+1
	ck(R.open_draft(g.inventory,g.run,node),"open node "+str(node))
	g.run.recruitment.candidates=roles;g._sync_recruitment()
func run_tests()->void:
	g=G.new();root.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
	draft(3,["role_1302","role_1207","role_1504"])
	var before=g.run.duplicate(true)
	click(Vector2(720,400));key(KEY_2)
	ck(g.recruitment_view.selected==-1 and g.run==before,"opening curtain gates accidental selections without domain writes")
	g.recruitment_view.advance(.4)
	ck(g.recruitment_view.cards[0].sprite.position.y<g.recruitment_view.cards[1].sprite.position.y,"cards rise in staggered order")
	g.recruitment_view.advance(1);click(Vector2(720,400));g.recruitment_view.advance(.2)
	ck(g.recruitment_view.selected==1 and g.run==before,"selection never recruits or purchases")
	ck(is_equal_approx(g.recruitment_view.cards[1].sprite.position.y,166),"selected card lift is only four pixels")
	click(Vector2(140,880));ck(g.recruitment_view.peek and g.run==before,"backpack inspection is read-only")
	key(KEY_ESCAPE);ck(not g.recruitment_view.peek,"escape closes inspection only")
	g.recruitment_view.model.cards[1].name="display-only"
	ck(R.card_models(g.inventory,g.run)[1].name!="display-only","view models detached from gameplay")
	key(KEY_ENTER)
	ck(g.run.phase=="shop" and g.run.supports==["role_1207"] and g.run.gold==before.gold,"confirmation commits free recruitment before animation")
	ck(g.recruitment_view.join_time==0 and g.recruitment_view.active,"committed result starts dissolution")
	var committed=g.run.duplicate(true);var saved=FileAccess.get_file_as_bytes(g.storage.root_path+"run.json")
	for n in 8:key(KEY_ENTER);click(Vector2(720,895))
	ck(g.run==committed and FileAccess.get_file_as_bytes(g.storage.root_path+"run.json")==saved,"repeated confirmation during dissolve cannot rewrite save or award again")
	var resumed=g.storage.resume()
	ck(resumed==committed,"restart mid-animation restores already committed shop, not another draft")
	g.recruitment_view.advance(.38)
	ck(float(g.recruitment_view.cards[1].material.get_shader_parameter("dissolve"))>0,"selected real card texture dissolves")
	ck(g.recruitment_view.cards[0].sprite.modulate.a==0,"unselected cards fade away")
	g._process(1);g.set_process(false)
	ck(not g.recruitment_view.active and g.run==committed,"animation completion cannot execute gameplay twice")
	ck(not g.crew_setup_view.active,"no empty setup forced open for unpairable starter")
	await process_frame
	ck(g.recruitment_view.cards.is_empty() and g.recruitment_view.get_child_count()==1,"viewport card layers are freed after arrival")
	draft(6,["role_1302","role_1505","role_1504"])
	g.recruitment_view.advance(1.4);click(Vector2(1100,400))
	var choices=g.recruitment_view.model.cards[2].reward_choices
	ck(not choices.is_empty() and not g.recruitment_view.can_confirm(),"supply bond requires an explicit actual gift choice")
	before=g.run.duplicate(true);key(KEY_ENTER);ck(g.run==before,"empty gift choice cannot submit")
	var chosen_kind=str(choices[0].kind)
	click(g.recruitment_view.cards[2].sprite.position+Vector2(150,556))
	ck(g.recruitment_view.selected_reward==chosen_kind and g.recruitment_view.can_confirm(),"gift row hit area selects the displayed item")
	var stash_count=g.run.stash.size();key(KEY_ENTER)
	ck(g.run.supports.size()==2 and g.run.stash.size()==stash_count+1 and g.run.stash[-1].kind==chosen_kind,"second draft commits chosen gift and companion together")
	ck(g.run.stash[-1].paid_cost==0,"free gift cannot invent resale investment")
	g._process(2);g.set_process(false);g.crew_setup_view.close()
	# Valid remote setup exercises actual matching and its visual consumer.
	g.run=g.inventory.new_run("aemeath",114);g.run.round=7;g.run.roster=["role_1302"];g.run.supports=g.run.roster.duplicate();g.run.recruited_round=7
	g.run.bags=FIX.full_bags(g.inventory);g.run.items=[g.piece("electro_coin","i1",0,0),g.piece("w_sword","i2",1,0),g.piece("w_sword","i3",4,2)];g.run.serial=100;g.run.stash=[];g.run.primary="i2"
	before=g.run.duplicate(true);g._open_crew_setup("link")
	ck(g.crew_setup_view.rows().size()>1 and g.run==before,"setup projects real available combinations without writes")
	var row=g.crew_setup_view.rows().filter(func(v):return v.config.get("link",{}).get("source","")=="i1" and v.config.get("link",{}).get("target","")=="i3")[0]
	g._crew_setup_intent({"kind":"configure","config":row.config})
	ck(g.run.recruitment.config.link==row.config.link,"setup intent passes through application commit")
	var markers=g._effect_star_markers(g.run.items[0],g.run.items,g.run)
	var lit=markers.filter(func(m):return m.state=="lit")
	ck(lit.size()==1 and lit[0].target_uid=="i3" and lit[0].cell in g.inventory.occupied(g.run.items[2]),"remote star highlights one real beneficiary at the target")
	ck(markers.size()<=g.inventory.stars(g.run.items[0]).size(),"remote display does not add phantom star count")
	ck(markers.all(func(m):return m.target_uid!="i2"),"replaced local target is not falsely highlighted")
	before=g.run.duplicate(true);var model=P.setup(g.inventory,g.run);model.config.clear();model.options.clear()
	ck(g.run==before,"mutating workbench snapshot does not change live rules")
	g.run.roster=["role_1302","role_1505"];g.run.supports=g.run.roster.duplicate()
	g.run.items=[g.piece("medical","i1",0,0),g.piece("flower","i2",6,3)];g.run.primary=""
	g.run.recruitment.config={"guard":["i1","i2"],"link":{"mode":"guard","source":"i1","target":"i2"}}
	var guard=P.setup(g.inventory,g.run).link
	ck(guard.get("mode","")=="guard" and not guard.get("target_cells",[]).is_empty(),"remote guard workbench receives the actual connector without inventing a star")
	for kind in g.C.items:
		if not str(kind).begins_with("crew_"):continue
		var image=P.item(kind);ck(image.texture!=null and image.source.has_area(),"specialty has actual atlas artwork "+str(kind))
	g.run.shop[3]={"kind":"tube","bundle":["tube","tuner"],"bundle_price":5,"locked":false}
	g.detail_origin="shop";g.detail_offer_index=3;g.detail_item={"kind":"tube"}
	ck(PANEL.bundle_offer(g).bundle==["tube","tuner"],"detail exposes both purchased bundle items")
	g.detail_origin="stash";ck(PANEL.bundle_offer(g).is_empty(),"stashed item cannot inherit shop bundle identity")
	g.queue_free();await process_frame;await process_frame
	print("RECRUITMENT_UI_V114 ",checks," checks, ",failures," failures");quit(1 if failures else 0)
