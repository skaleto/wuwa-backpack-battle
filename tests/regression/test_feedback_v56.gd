extends SceneTree
const G=preload("res://tests/fixtures/playable_fixture_v50.gd")
var game
var checks=0
var failures=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():call_deferred("run_test")
func move(at:Vector2):
 var e=InputEventMouseMotion.new();e.position=at;game._input(e)
func button(down:bool,id:int=MOUSE_BUTTON_LEFT):
 var e=InputEventMouseButton.new();e.position=game.mouse;e.pressed=down;e.button_index=id;game._input(e)
func run_test():
 game=G.new();root.add_child(game);await process_frame;game.set_process(false);game.set_visual_skin("chibi",false)
 var before=game.run.duplicate(true)
 move(game.QL.offer(0).position+Vector2(64,65));button(true)
 if game.has_method("_shop_press_pending"):
  check(game._shop_press_pending(),"press without motion stays at shelf scale")
  game._process(.8);check(game._shop_press_pending(),"long hold does not cause preview enlargement")
  move(game.mouse+Vector2(9,0));check(not game._shop_press_pending(),"real dragging activates placement view")
 else:check(false,"shelf press must be distinct from dragged board-size preview")
 check(game.run==before,"press and motion do not purchase")
 button(true,MOUSE_BUTTON_RIGHT);check(game.drag_rotated and game.run==before,"right turn is still a non-purchasing preview")
 game.dragging={};game._clear_held_pose();game.drag_pressed=false
 move(game.QL.offer(0).position+Vector2(64,65));button(true);button(false)
 check(game.overlay=="item_details" and game.run==before,"short click shows details without changing ownership")
 game._close_item_details();game.reset_slice()
 game.dragging=game.run.bags[1].duplicate(true);game.drag_origin="bag"
 if game.has_method("_piece_elevation"):
  for item in game.run.items:check(is_zero_approx(game._piece_elevation(item,-1)),"bag-carried item retains paper-contact shadow "+item.kind)
  game.dragging=game.run.items[0].duplicate(true);game.drag_origin="board"
  check(game._piece_elevation(game.dragging,-1)>0,"individually held weapon retains grasp shadow")
 else:check(false,"shadow elevation must identify the actual held item")
 game.dragging={};game.queue_free();await process_frame
 print("V56 FEEDBACK ",checks," checks ",failures," failures");quit(1 if failures else 0)
