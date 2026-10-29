extends SceneTree
const OUT='res://build/qa/feedback-v122/native/'
var g
var viewport
func _initialize():
 root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true);call_deferred('test')
func test():
 if DisplayServer.get_name()=='headless':quit(2);return
 DirAccess.make_dir_recursive_absolute(OUT+'glints')
 viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 g=preload('res://tests/fixtures/travel_fixture_v64.gd').new();viewport.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
 var source=JSON.parse_string(FileAccess.get_file_as_string('res://tests/fixtures/data/feedback-v120/input/hsin-round10.json'))
 g.run=source.duplicate(true);g.run.phase='shop';g.run.erase('combat');g.run.erase('opponent')
 g.mouse=Vector2(1415,940);g.hovered={};g.overlay='';g.motion.modal_value=0;g.motion.modal_target=0
 var before=g.run.duplicate(true)
 for n in 72:
  g.age=8+n/24.0;g.queue_redraw();await process_frame;RenderingServer.force_draw(true);await process_frame
  viewport.get_texture().get_image().save_png(OUT+'glints/%03d.png'%n)
  if n==20:viewport.get_texture().get_image().save_png(OUT+'07-quality-particles.png')
 var ok=g.run==before
 print('NATIVE_GLINTS_V122 '+('PASS 72 frames, state unchanged' if ok else 'FAIL state mutation'))
 g.queue_free();await process_frame;quit(0 if ok else 1)
