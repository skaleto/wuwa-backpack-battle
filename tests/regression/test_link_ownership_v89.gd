extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const F=preload("res://scripts/crafting/craft.gd")
const FIX=preload("res://tests/fixtures/craft_fixture_v75.gd")
var game
var checks=0
var failures=0
func ck(ok,label):
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func setup():
	game.reset_slice();game.run.serial=30;game.run.gold=100
	game.run.shop=[{},{},{},{},{},{}];game.run.items=[game.piece("w_sword","sword",0,0)]
	game.run.stash=[game.piece("mat_43020011","metal",0,0)];game.run.primary="sword"
	game.motion.modal_value=0;game.motion.modal_target=0;game.mouse=Vector2(30,930)
func links():return game.inline_craft.links(game._craft_view_model())
func _initialize():call_deferred("test")
func test():
	game=G.new();root.add_child(game);await process_frame;game.set_process(false);game.set_process_input(false)
	setup();var before=game.run.duplicate(true);var rows=links()
	ck(rows.size()==1 and rows[0].get("materials_complete",false) and not rows[0].ready,"board and stash complete materials are gold before placement")
	ck(game.run==before,"ownership hint never changes state")
	game.run.stash.append(game.run.items.pop_back());game.run.primary="";rows=links()
	ck(rows.size()==1 and rows[0].get("materials_complete",false) and not rows[0].adjacent,"both stash ingredients are gold with separated ends")
	setup();game.run.stash=[];game.run.bags.append(game.piece("satchel","extra-bag",3,2))
	game.run.items.append(game.piece("mat_43020011","metal",4,3));rows=links()
	ck(rows.size()==1 and rows[0].get("materials_complete",false) and not rows[0].adjacent,"distant board materials stay gold")
	setup();game.run.items.append(game.piece("mat_43020011","metal",0,1));game.run.stash=[]
	for n in 6:game.run.stash.append(game.piece("nutrition","full"+str(n),0,0))
	rows=links()
	ck(rows.size()==1 and rows[0].get("materials_complete",false) and rows[0].ready,"V103 occupied first page keeps materials gold and fallback ready")
	setup();game.run.shop[0]={"kind":"mat_43020011","locked":false};rows=links()
	ck(rows.size()==2 and rows.filter(func(v):return v.get("materials_complete",false)).size()==1,"owned pair gold but unbought duplicate offer blue")
	game.run.stash=[];rows=links()
	ck(rows.size()==1 and not rows[0].get("materials_complete",false),"missing owned ingredient has blue shop link")
	game._begin_shop_drag(0);game.drag_pressed=false
	game.mouse=game._board_to_screen(game.BOARD+Vector2(.5,1.5)*game.CELL);game._start_held_pose()
	before=game.run.duplicate(true);rows=links()
	ck(game._item_drop_preview().ok and rows.size()==1 and not rows[0].get("materials_complete",false),"unpaid legal drop remains blue")
	ck(game.run==before,"preview creates no ownership")
	var release=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.position=game.mouse;game._input(release)
	rows=links();ck(rows.size()==1 and rows[0].get("materials_complete",false) and rows[0].ready,"real purchase immediately changes link to gold")
	setup();game.run.items.append(game.piece("mat_43020011","metal2",0,1));rows=links()
	ck(rows.size()==2 and rows.all(func(v):return v.get("materials_complete",false)) and rows.filter(func(v):return v.ready).size()==1,"unused owned copy is complete without claiming transaction selection")
	# Every current exact two-input recipe: ownership is independent of geometry/capacity.
	for recipe in game.C.combinations:
		var r=FIX.make(game.inventory,recipe.target)
		var base=game.inventory.make_piece(recipe.base,"a");var material=game.inventory.make_piece(recipe.materials[0],"b")
		r.items=[base];r.stash=[material];r.shop=[{},{},{},{},{},{}]
		var facts=F.guidance(r,r,{},"",-1,game.inventory).relations.filter(func(v):return v.target==recipe.target)
		ck(facts.size()==1 and facts[0].get("materials_complete",false) and not facts[0].ready,"owned across containers "+recipe.id)
		r.stash=[];r.shop[0]={"kind":material.kind,"locked":false}
		facts=F.guidance(r,r,{},"",-1,game.inventory).relations.filter(func(v):return v.target==recipe.target)
		ck(facts.size()==1 and not facts[0].get("materials_complete",false),"shop input remains blue "+recipe.id)
	print("LINK_OWNERSHIP_V89 ",checks," checks, ",failures," failures")
	game.queue_free();await process_frame;quit(1 if failures else 0)
