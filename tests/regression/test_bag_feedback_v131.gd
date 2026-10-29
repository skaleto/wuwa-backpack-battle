extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const KINDS=["satchel","pouch","strip","corner","travel","pocket_single","pocket_double","pocket_long_l","pocket_long_j"]
var g
var checks=0
var failures=0
func ck(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:
 AudioServer.set_bus_mute(0,true);call_deferred("test")
func move(at:Vector2)->void:
 var e=InputEventMouseMotion.new();e.position=at;g._input(e)
func press(down:bool)->void:
 var e=InputEventMouseButton.new();e.position=g.mouse;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;g._input(e)
func test()->void:
 root.size=Vector2i(1440,960)
 g=G.new();root.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false);g.music.stop_all()
 for kind in KINDS:
  for origin in ["bag","stash","shop"]:
   if origin=="shop" and kind=="satchel":continue # Starting-only bag is never sold.
   g.reset_slice();g.buttons=[];g.run.items=[];g.run.stash=[];g.run.bags=[];g.run.gold=60;g.run.primary="";g.run.round=6
   g.run.shop=[{},{},{},{},{},{}];g.muted=false;g.audio.set_muted(false)
   g.audio.stop_all();g.audio.requested.clear();g.audio.played.clear();g.audio.last_played.clear()
   g.motion.modal_value=0;g.motion.modal_target=0;g.bag_mode=false;g.drag_pressed=false
   var piece=g.piece(kind,"target",0,0)
   var start=g._board_to_screen(g.BOARD+(Vector2(g.inventory.cells(piece)[0])+Vector2.ONE*.5)*g.CELL)
   if origin=="bag":g.run.bags=[piece]
   elif origin=="stash":g.run.stash=[piece];start=g._stash_rect(0).get_center()
   else:g.run.shop[5]={"kind":kind,"locked":false};start=g._offer_rect(5).get_center()
   move(start);press(true)
   ck(g.drag_origin==origin,"correct grab "+kind+" "+origin)
   ck(g.audio.played.get("bag_pick",0)==1,"actual grab voice plays "+kind+" "+origin)
   var voices=g.audio.pools.bag.filter(func(p):return p.playing)
   ck(voices.size()==1 and is_equal_approx(voices[0].volume_db,-1.0),"approved preview gain retained through limiter "+kind+" "+origin)
   move(g._stash_mat_rect().get_center());g.drag_distance=30
   press(false)
   ck(g.audio.played.get("bag_drop",0)==1,"actual drop voice plays "+kind+" "+origin)
   ck(g.audio.played.get("pick",0)==0 and g.audio.played.get("drop",0)==0,"no ordinary item cue layered onto bag")
 g.audio.stop_all();g.muted=true;g.audio.set_muted(true)
 ck(not g.audio.play_event("bag_pick"),"mute still honored")
 g.queue_free();await process_frame;await create_timer(.12).timeout
 print("BAG_FEEDBACK_V131 ",checks," checks, ",failures," failures");quit(1 if failures else 0)
