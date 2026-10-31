extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const O=preload("res://scripts/inventory/pocket_organizer.gd")
const SESSION=preload("res://scripts/run/run_session.gd")
var failures=0
func ck(ok:bool,label:String):
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():call_deferred("run_tests")
func run_tests():
	var g=G.new();root.add_child(g);await process_frame
	g.set_process(false);g.set_process_input(false)
	var original=g.run.duplicate(true)
	g._action("bag_mode")
	var bag=g.run.bags[0].duplicate(true);bag.x=5;bag.y=4
	g.dragging=bag;g.drag_origin="bag";g.drag_pressed=false
	g.drag_offset=Vector2i.ZERO;g.drag_fraction=Vector2.ONE*.5
	g.mouse=g._board_to_screen(g.BOARD+Vector2(5.5,4.5)*g.CELL)
	g._mouse_up()
	ck(g.run==original,"organizing does not move items or persist partial layout")
	g._action("bag_mode")
	ck(g.run.items.is_empty() and g.run.stash.size()==original.stash.size()+original.items.size(),"only finishing sends unsupported items to stash")
	ck(g.inventory.validate_run(g.run),"finished run valid")
	ck(g.stash_transfer.flights.size()==original.items.size(),"finished displaced items use falling animation")
	g.run=original.duplicate(true);g._begin_organization()
	var before=g.run.duplicate(true)
	var org=g.pocket_organizer
	bag=g.run.bags[0].duplicate(true);bag.x=5;bag.y=4;bag.rotation=1
	ck(org.move(g.run,bag,"board",g.inventory),"rotate and move pocket independently")
	ck(g.run==before,"draft rotation does not touch live items, money or RNG")
	var plan=org.finish(g.run,g.inventory)
	ck(not SESSION.commit(g.run,plan,g.inventory.validate_run,func(_r):return false).ok and g.run==before,"failed save retains live run")
	g._cancel_organization();ck(g.run==before and not g.bag_mode,"cancel discards draft")
	# Moving away then returning support before finishing retains every item.
	g._begin_organization();org=g.pocket_organizer
	ck(org.move(g.run,bag,"board",g.inventory),"temporary removal allowed")
	ck(org.move(g.run,original.bags[0],"board",g.inventory),"support may return before finish")
	ck(g._finish_organization() and g.run==original,"supported items remain exactly in place")
	# One item spans both pockets. Their union, not ownership by one bag, supports it.
	g.run.bags=[g.piece("satchel","b1",0,0),g.piece("pouch","b2",3,0)]
	g.run.items=[g.piece("w_sword","i1",2,0),g.piece("nutrition","i2",4,1)]
	g.run.primary="i1";g.run.stash=[];before=g.run.duplicate(true)
	ck(g.inventory.validate_run(g.run),"cross-pocket fixture valid")
	g._begin_organization();org=g.pocket_organizer
	bag=g.run.bags[0].duplicate(true);bag.x=3
	ck(not org.move(g.run,bag,"board",g.inventory),"overlap rejected without altering draft")
	bag.x=99;ck(not org.move(g.run,bag,"board",g.inventory),"off-board rejected")
	ck(org.move(g.run,g.run.bags[0],"stash",g.inventory),"pocket may be stored without removing items yet")
	ck(g.run==before,"stowing pocket still leaves real items fixed until finish")
	ck(g._finish_organization(),"finish cross-pocket layout")
	ck(g.run.items.size()==1 and g.run.items[0].uid=="i2" and g.run.stash.any(func(v):return v.uid=="i1"),"unsupported spanning item moves whole, other item stays")
	g._begin_organization();org=g.pocket_organizer
	ck(org.move(g.run,before.bags[0],"board",g.inventory),"stored pocket can be placed in draft")
	ck(g._finish_organization() and g.run.bags.size()==2,"stored pocket restoration commits")
	g._begin_organization();g.run.gold+=1
	ck(not g._finish_organization() and g.bag_mode,"stale draft cannot overwrite newer run")
	g._cancel_organization()
	g.run.pvp={"stage":"pending"};ck(not O.new().begin(g.run),"frozen online preparation cannot organize")
	g.run=original.duplicate(true);g._begin_organization()
	g.motion.modal_value=0;g.motion.modal_target=0;g.buttons=[]
	g.mouse=g._board_to_screen(g._item_rect(g.run.items[0],g.BOARD).get_center())
	g._mouse_down();ck(g.drag_origin=="bag" and g.inventory.C.is_tag(g.dragging.kind,"bag"),"gray item cannot intercept pocket click")
	g._cancel_organization()
	g.queue_free();await process_frame
	print("POCKET_ORGANIZER failures=",failures);quit(1 if failures else 0)
