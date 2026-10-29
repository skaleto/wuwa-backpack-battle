extends SceneTree
const G=preload('res://tests/fixtures/travel_fixture_v64.gd')
const OUT='res://build/qa/feedback-v117/native/'
var viewport
var g
func _initialize():
 root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true);call_deferred('capture')
func shot(name):
 g.paint_alpha=1;g.paint_offset=Vector2.ZERO;g.motion.transition_left=0;g.transition_image=null
 g.queue_redraw();await process_frame;RenderingServer.force_draw(true);await process_frame
 assert(viewport.get_texture().get_image().save_png(OUT+name+'.png')==OK)
func click(pressed,point):
 var event=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;g._input(event)
func capture():
 for folder in ['','star-frames','quality-frames']:DirAccess.make_dir_recursive_absolute(OUT+folder)
 viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 g=G.new();viewport.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
 g.reset_slice();g.run.round=7;g.run.gold=12;g.run.serial=30;g.run.shop=[{},{},{},{},{},{}];g.run.bags=[]
 for y in range(0,6,2):
  for x in range(0,8,2):g.run.bags.append(g.piece('pouch','bag%d%d'%[x,y],x,y))
 g.run.items=[g.piece('crew_pulse_grip','i1',1,1),g.piece('w_sword','i2',2,1),g.piece('weapon_21020086','i3',0,4),g.piece('heron','i4',5,3),g.piece('weapon_21050036','i5',5,0)]
 g.run.primary='i2';g.run.stash=[];g.mouse=Vector2(28,70);g._clear_feedback()
 assert(g.inventory.validate_run(g.run));var unchanged=g.run.duplicate(true)
 var point=g._board_transform(0)*(g.BOARD+Vector2(1.5,1.5)*g.CELL)
 for n in 120:
  if n%40==0:
   g._close_item_details();click(true,point)
  if n%40==(25 if n<80 else 2):click(false,point)
  g._process(1.0/30);await shot('star-frames/%03d'%n)
  if n in [0,4,9,18,30]:await shot('star-%02d'%n)
 assert(g.run==unchanged)
 g._close_item_details();g.motion.modal_target=0;g.motion.modal_value=0;g.mouse=Vector2(28,70)
 if '--stars-only' in OS.get_cmdline_user_args():
  g.queue_free();await process_frame;quit();return
 g.run.shop=[{'kind':'weapon_21020086','locked':false},{'kind':'heron','locked':false},{'kind':'weapon_21020076','locked':false},{},{},{}]
 for n in 150:
  g._process(1.0/30);await shot('quality-frames/%03d'%n)
  if n in [0,30,60,90]:await shot('quality-%03d'%n)
 FileAccess.open(OUT+'capture.txt',FileAccess.WRITE).store_string('Native hidden/unfocusable SubViewport; isolated Storage. Real input press/release, three one-shot waves. Surface light samples original artwork with board clipping. No cursor or foreground calls. Gameplay unchanged.')
 g.queue_free();await process_frame;quit()
