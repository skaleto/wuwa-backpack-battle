extends SceneTree
const G=preload("res://scripts/game.gd")
var g
var checks=0
var failures=0
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func pointer(p:Vector2,down:bool,button:int=MOUSE_BUTTON_LEFT):
	var ev=InputEventMouseButton.new();ev.position=p;ev.pressed=down;ev.button_index=button;g._input(ev)
func reset():
	g.run=g.inventory.new_run("jiyan",49);g.screen="game";g.run.gold=30;g.overlay="";g.motion.modal_value=0;g.buttons=[];g.dragging={}
func _initialize():call_deferred("test")
func test():
	g=G.new();g.storage=G.S.new("user://qa-demo-v49/");g.muted=true;root.add_child(g);await process_frame
	reset();g.run.shop[0]={"kind":"w_broadblade","locked":false}
	var before=g.run.duplicate(true);var p=g._offer_rect(0).get_center()
	pointer(p,true);check(not g.dragging.is_empty(),"press lifts without purchase");pointer(p,false)
	check(g.overlay=="item_details","short click opens item details")
	check(g.run==before,"detail click never buys or modifies run")
	if g.has_method("_open_item_details"):
		g._action("detail_recipes");check(g.overlay=="item_recipes","details opens recipes")
	reset();var item=g.run.items[0];p=g._board_to_screen(G.BOARD+(Vector2(item.x,item.y)+Vector2(.5,.5))*G.CELL)
	pointer(p,true);pointer(p,false);check(g.overlay=="item_details","owned item click opens details")
	reset();g.run.shop[0]={"kind":"w_broadblade","locked":false};p=g._offer_rect(0).get_center();before=g.run.duplicate(true)
	pointer(p,true)
	if g.has_method("_drag_visual_origin"):
		var start=g._drag_visual_origin();g.mouse+=Vector2(3,7)
		check(g._drag_visual_origin().is_equal_approx(start+Vector2(3,7)),"held art follows sub-cell motion exactly")
	else:check(false,"continuous floating pose available")
	for n in range(4):pointer(g.mouse,true,MOUSE_BUTTON_RIGHT)
	check(g.dragging.rotation==0,"four rotations restore orientation")
	check(g.run==before,"rotate held offer never purchases")
	pointer(g._stash_mat_rect().get_center(),false)
	check(g.run.stash.size()==1 and g.run.gold==before.gold-G.C.items.w_broadblade.price,"release into stash purchases once")
	reset();var a=g.run.duplicate(true);var battle=g.engine.simulate(a,a,49)
	check(battle.frames.all(func(f):return f.sides.all(func(s):return s.concerto==0)),"disabled concerto stays zero throughout replay")
	check(battle.events.all(func(e):return e.kind not in ["relay","intro","outro","intro_attack"]),"demo emits no concerto transitions")
	g.engine.concerto_enabled=true
	var enabled=g.engine.simulate(a,a,49)
	check(enabled.events.any(func(e):return e.kind=="relay"),"explicit engine hook can still enable concerto")
	g.engine.concerto_enabled=false
	g.run.round=6
	for n in range(50):
		g.inventory.refresh(g.run)
		check(g.run.shop.all(func(v):return v.is_empty() or G.FEATURES.item_enabled(v.kind)),"no inactive concerto items in new offers")
	reset();g.inventory.finish(g.run,1)
	check((g.run.items+g.run.stash+g.run.pending_gifts).all(func(v):return v.kind!="strategy"),"disabled concerto keepsake is not gifted")
	for kind in G.C.items:
		var info=G.INFO.rows({"kind":kind})
		check(not info.is_empty() and info.all(func(row):return row.size()==2 and str(row[0]).length()<30 and str(row[1]).length()<55),"short structured attributes: "+kind)
	print("DEMO_INTERACTION: %d checks, %d failures"%[checks,failures]);g.queue_free();await process_frame;quit(1 if failures else 0)
