extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const OUT="res://build/qa/battle-controls/"
var viewport:SubViewport
func _initialize()->void:
 root.mode=Window.MODE_MINIMIZED;root.unfocusable=true;AudioServer.set_bus_mute(0,true)
 DirAccess.make_dir_recursive_absolute(OUT);call_deferred("check")
func shot(g,name:String)->void:
 g.queue_redraw();await process_frame;RenderingServer.force_draw(true);await process_frame
 assert(viewport.get_texture().get_image().save_png(OUT+name+".png")==OK)
func click(g,point:Vector2)->void:
 var move=InputEventMouseMotion.new();move.position=point;g._input(move)
 for down in [true,false]:
  var event=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;g._input(event)
func target(g,action:String)->Rect2:
 for button in g.buttons:
  if button.action==action:return button.rect
 return Rect2()
func check()->void:
 viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var g=G.new();viewport.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
 g.screen="camp";g.camp_age=3;g.selection_age=3;g.motion.transition_left=0;g.transition_image=null
 await shot(g,"home")
 assert(target(g,"quit").size==Vector2.ZERO,"Home must not expose direct quit")
 click(g,Vector2(1377,58));assert(g.screen=="camp")
 if g.overlay=="settings":g._action("settings:back")
 g.screen="game";g.run.phase="shop";g._start_battle();g.battle_entry_age=1;g.motion.transition_left=0;g.transition_image=null
 await shot(g,"battle-playing")
 for action in ["pause","speed","skip"]:
  var r=target(g,action)
  assert(r.size.x>=80 and r.size.y>=48 and r.position.x>900 and r.end.y<100)
  for other in g.buttons:
   if other.action!=action:assert(not r.intersects(other.rect),"Battle controls must not overlap other targets")
 var gold_before=g.run.gold;var time_before=g.combat_time
 click(g,target(g,"pause").get_center());assert(g.paused)
 await shot(g,"battle-paused")
 click(g,target(g,"pause").get_center());assert(not g.paused)
 for expected in [2.0,4.0,1.0]:
  click(g,target(g,"speed").get_center());assert(g.speed==expected)
 assert(g.run.gold==gold_before and g.combat_time==time_before)
 click(g,Vector2(1377,860));assert(not g.paused and not g.skip_requested)
 click(g,target(g,"skip").get_center());assert(g.skip_requested and g.combat_time==g._replay_end())
 g.queue_free();await process_frame;print("PASS hidden native controls: home exit removed, pause/resume, 1/2/4x, skip, nonoverlap, old target inactive");quit()
