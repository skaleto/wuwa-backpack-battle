extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const LINK=preload("res://scripts/ui/crafting/craft_link_view.gd")
var checks=0;var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():call_deferred("test")
func test():
 for b in [Vector2(800,0),Vector2(0,800),Vector2(500,300),Vector2(-350,200)]:
  var a=Vector2(40,60)
  for t in [0.0,.25,.5,.75,1.0]:ck(LINK.point(a,b,t).is_equal_approx(a.lerp(b,t)),"beam is straight through both centers")
  var spans=LINK.spans(a,b,false)
  ck(spans.size()==2 and spans[0].x==0 and spans[1].y==1 and spans[0].y<spans[1].x,"distant beam starts at centers, leaving empty middle")
  ck(LINK.spans(a,b,true)==[Vector2(0,1)],"joined beam is continuous")
 var game=G.new();root.add_child(game);await process_frame;game.set_process(false);game.set_process_input(false)
 game.reset_slice();var before=game.run.duplicate(true)
 for kind in ["w_sword","whiff","violet"]:
  for rotation in 4:
   var p=game.piece(kind,"test",1,1);p.rotation=rotation
   var fitted=game._projection_for(kind,rotation,game.CELL)
   var at=game._piece_position(p,game.BOARD,0)
   ck(game._craft_item_center({"piece":p,"origin":"board"}).is_equal_approx(game._board_to_screen(at+fitted.center)),"board anchor follows fitted rotated image")
   game.dragging=p;game.mouse=Vector2(500,400);game.drag_origin="board";game._start_held_pose()
   game.drag_target_angle=PI*.5;game.drag_turn_remaining=-.2
   ck(game._craft_item_center({"piece":p,"origin":"board"},true).is_equal_approx(game._held_pose()*fitted.center),"held beam follows animated icon center")
 game.dragging={};game._clear_held_pose()
 game.item_selection_age=.08;game.detail_origin="shop";game.detail_offer_index=0
 ck(game._craft_item_center({"origin":"shop","index":0}).is_equal_approx(game._selection_rect(game._shop_icon_rect(0)).get_center()),"shop selected anchor follows lift")
 game.detail_origin="stash";game.detail_item={"uid":"test"}
 ck(game._craft_item_center({"origin":"stash","index":0,"piece":{"uid":"test"}}).is_equal_approx(game._selection_rect(game._stash_rect(0).grow(-3)).get_center()),"storage selected anchor follows lift")
 ck(game.run==before,"presentation never changes inventory or battle state")
 print("LINKS_V84 ",checks," checks, ",failures," failures")
 game.queue_free();await process_frame;quit(1 if failures else 0)
