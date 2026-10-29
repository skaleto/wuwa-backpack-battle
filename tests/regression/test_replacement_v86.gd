extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const F=preload("res://scripts/inventory/stash_transfer.gd")
var g;var checks=0;var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func click(at,down,button=MOUSE_BUTTON_LEFT):
 var e=InputEventMouseButton.new();e.position=at;e.button_index=button;e.pressed=down;g._input(e)
func move(at):
 var e=InputEventMouseMotion.new();e.position=at;g._input(e)
func cell(x,y):return g._board_to_screen(g.BOARD+Vector2(x,y)*g.CELL)
func escape():
 var e=InputEventKey.new();e.keycode=KEY_ESCAPE;e.pressed=true;g._input(e)
func setup():
 g.reset_slice();g._clear_held_pose();g.stash_transfer.clear();g.buttons=[];g.run.items=[g.piece("w_sword","old",0,0)];g.run.primary="old"
 g.run.bags=[g.piece("satchel","b1",0,0),g.piece("satchel","b2",3,0),g.piece("satchel","b3",0,2),g.piece("satchel","b4",3,2)]
 g.run.stash=[];g.run.shop=[{"kind":"whiff","locked":false},{},{},{},{},{}];g.run.gold=20
func _initialize():call_deferred("test")
func test():
 g=G.new();root.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
 setup();click(g._offer_rect(0).get_center(),true);move(cell(.5,.5));click(g.mouse,false)
 ck(g.carry_replacement and g.dragging.get("uid","")=="old","replacement immediately catches displaced item")
 ck(g.run.stash.any(func(p):return p.uid=="old") and g.stash_transfer.flights.is_empty(),"held displaced item safely owned without duplicate flight")
 var paid=g.run.gold;var before=g.run.duplicate(true);var pivot=g._held_center_screen()
 click(g.mouse,true,MOUSE_BUTTON_RIGHT);ck(g.dragging.rotation==1 and g.run==before and g._held_center_screen()==pivot,"caught item rotates around same center without committing")
 # Continue without a new pickup: a click/release places the carried old item.
 move(cell(4.5,1.5));click(g.mouse,true);click(g.mouse,false)
 ck(g.dragging.is_empty() and g.run.items.any(func(p):return p.uid=="old" and p.rotation==1),"carried replacement can be placed on next click")
 ck(g.run.gold==paid and g.inventory.validate_run(g.run),"no second purchase or invalid ownership")
 setup();click(g._offer_rect(0).get_center(),true);move(cell(.5,.5));click(g.mouse,false);before=g.run.duplicate(true);escape()
 ck(g.dragging.is_empty() and g.run==before and g.storage.resume().stash==g.run.stash,"cancel or restart preserves displaced item")
 setup();g.run.items=[g.piece("whiff","first",0,0),g.piece("whiff","second",1,0)];g.run.primary="";g.run.stash=[g.piece("w_sword","incoming",0,0)]
 click(g._stash_rect(0).get_center(),true);move(cell(.5,.5));click(g.mouse,false)
 ck(g.dragging.get("uid","")=="first" and g.stash_transfer.flights.size()==1 and g.stash_transfer.flights[0].piece.uid=="second","multi-displacement holds touched item, drops remainder")
 var flight=g.stash_transfer.flights[0].duplicate(true);var from=flight.from;var target=g._stash_rect(1).grow(-3)
 var start=F.pose(from,target,0);var middle=F.pose(from,target,.19);var end=F.pose(from,target,F.DURATION)
 ck(start.rect==from and end.rect==target,"ballistic animation has exact start and impact")
 ck(absf(middle.angle)>0,"flight rotates gently")
 ck(F.pose(from,target,F.DURATION+.1).rect.get_center().y<target.get_center().y,"impact bounces above slot")
 ck(F.pose(from,target,F.DURATION+F.SETTLE).rect==target,"bounce settles into exact slot")
 var y0=F.pose(from,target,.05).rect.get_center().y;var y1=F.pose(from,target,.10).rect.get_center().y;var y2=F.pose(from,target,.15).rect.get_center().y
 ck(y2-y1>y1-y0,"downward velocity accelerates")
 g.stash_transfer.flights[0].age=.19
 var flying_index=g.run.stash.find(g.inventory.find_piece(g.run,"second"))
 var expected_center=F.pose(from,g._stash_rect(flying_index).grow(-3),.19).rect.get_center()
 ck(g._craft_item_center({"origin":"stash","index":flying_index,"piece":g.inventory.find_piece(g.run,"second")}).is_equal_approx(expected_center),"craft beam follows falling item instead of empty slot")
 flight.age=.19
 var shifted=target;shifted.position.x+=100
 ck(F.pose(from,shifted,F.DURATION).rect==shifted and flight==g.stash_transfer.flights[0],"reflow updates destination without mutating flight or ownership")
 g.stash_transfer.update(0,g.run.stash.map(func(p):return p.uid),"second")
 ck(g.stash_transfer.flights.is_empty(),"regrabbing cancels only the object's flight")
 setup();var weapon=g.run.items[0];click(g._board_to_screen(g._item_rect(weapon,g.BOARD).get_center()),true);move(g._stash_rect(0).get_center());click(g.mouse,false)
 ck(g.stash_transfer.flights.size()==1 and g.stash_transfer.flights[0].from.get_center().distance_to(g.mouse)<g.CELL,"manual storage falls from cursor, not old board position")
 g.stash_transfer.update(1,g.run.stash.map(func(p):return p.uid),"");ck(g.stash_transfer.flights.is_empty(),"completed physics leaves no hidden items")
 print("REPLACEMENT_V86 ",checks," checks, ",failures," failures")
 g.queue_free();await process_frame;quit(1 if failures else 0)
