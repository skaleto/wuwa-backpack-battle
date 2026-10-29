extends SceneTree
const G=preload('res://tests/fixtures/travel_fixture_v64.gd')
const CAP=preload('res://tests/fixtures/capacity_fixture_v111.gd')
const OUT='res://build/qa/feedback-v121/native/'
var g
var viewport
var checks=0
var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():
 root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true);call_deferred('test')
func frame(name):
 g.queue_redraw();await process_frame;RenderingServer.force_draw(true);await process_frame
 ck(viewport.get_texture().get_image().save_png(OUT+name+'.png')==OK,'save '+name)
func move(point):
 var ev=InputEventMouseMotion.new();ev.position=point;g._input(ev)
func press(down):
 var ev=InputEventMouseButton.new();ev.position=g.mouse;ev.button_index=MOUSE_BUTTON_LEFT;ev.pressed=down;g._input(ev)
func at(x,y):return g._board_to_screen(g.BOARD+Vector2(x,y)*g.CELL)
func test():
 if DisplayServer.get_name()=='headless':quit(1);return
 DirAccess.make_dir_recursive_absolute(OUT+'frames')
 viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 g=G.new();viewport.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
 g.run=g.inventory.new_run('aemeath',120);g.run.bags=CAP.full_bags(g.inventory);g.run.serial=60;g.run.gold=30;g.run.shop=[{},{},{},{},{},{}]
 g.run.items=[g.piece('crew_pulse_grip','i1',2,2),g.piece('w_sword','i2',3,2),g.piece('weapon_21020086','i4',1,5),g.piece('heron','i5',6,0)]
 g.run.stash=[g.piece('w_sword','i3',0,0)];g.run.primary='i2';g.opponent=g.storage.opponent(g.run)
 ck(g.inventory.validate_run(g.run),'native scenario legal')
 g.mouse=Vector2(980,920);await frame('01-idle')
 var before=g.run.duplicate(true)
 for n in 135:
  if n==3:move(at(2.5,2.5));press(true)
  if n==7:press(false)
  if n==40:g._close_item_details();g.motion.modal_value=0;g.motion.modal_target=0;g.hovered={};move(Vector2(980,920))
  if n==51:
   ck(g.run==before,'click and settle never changed build')
   move(g._stash_rect(0).get_center());press(true)
   ck(g.dragging.get('uid','')=='i3','real stash press grabs target')
  if n in range(52,68):
   # Exact target occupied center, independent of the original grip offset.
   var target=at(2,3)+g._occupied_center(g.dragging)*g._board_transform().get_scale().x
   move(g.mouse.lerp(target-g.drag_center_offset,1.0/(68-n)))
  if n==68:
   press(false)
   ck(g.run.items.any(func(p):return p.uid=='i3' and p.x==2 and p.y==3),'real drop commits expected cell')
   ck(g._placement_star_markers().any(func(m):return m.source_uid=='i1' and m.target_uid=='i3'),'incoming source lights after real drop')
   move(Vector2(980,920));g.hovered={}
  g._process(1.0/30)
  await frame('frames/%03d'%n)
  if n==6:await frame('02-independent-stars')
  if n==73:await frame('03-drop-activation')
  if n==113:
   ck(g._placement_star_markers().is_empty(),'drop feedback expires without hover')
   await frame('04-settled')
 var stable=g.run.duplicate(true)
 for n in 6:g._process(.07);await frame('glints-%d'%n)
 ck(g.run==stable,'rarity particles leave all state unchanged')
 print('NATIVE_FEEDBACK_V121 ',checks,' checks, ',failures,' failures');g.queue_free();await process_frame;quit(1 if failures else 0)
