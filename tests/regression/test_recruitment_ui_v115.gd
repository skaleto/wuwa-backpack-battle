extends SceneTree
const G=preload('res://tests/fixtures/travel_fixture_v64.gd')
const R=preload('res://scripts/party/recruitment_v115.gd')
const C=preload('res://scripts/data/catalog.gd')
const OUT='res://build/qa/recruitment-v115/native/'
var viewport:SubViewport
var g
var checks=0
var failures=0
var capture=false
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():
 root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true)
 capture='--capture' in OS.get_cmdline_user_args();DirAccess.make_dir_recursive_absolute(OUT)
 call_deferred('run_tests')
func click(point:Vector2):
 for down in [true,false]:
  var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=point;g._input(e)
func shot(name:String):
 g.queue_redraw();g.recruitment_view.queue_redraw();g.recruitment_view.foreground.queue_redraw();g.crew_setup_view.queue_redraw()
 for n in 3:await process_frame
 if capture:
  RenderingServer.force_draw(true);await process_frame
  ck(viewport.get_texture().get_image().save_png(OUT+name+'.png')==OK,'capture '+name)
func run_tests():
 viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 g=G.new();viewport.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
 g.screen='camp'
 for leader in C.selectable_leaders():
  g.selected_leader=leader;g.selection_age=2
  await shot('leader-'+leader)
 var before=g.selected_leader;var sixth=InputEventKey.new();sixth.keycode=KEY_6;sixth.pressed=true
 g._input(sixth);ck(g.selected_leader==before,'sixth shortcut safe with five choices')
 g.screen='game';g.run=g.inventory.new_run('aemeath',115);g.run.round=4
 ck(R.open_draft(g.inventory,g.run,3),'open first draft')
 g.run.recruitment.candidates=['role_1509','role_1207','role_1209'];g._sync_recruitment()
 var untouched=g.run.duplicate(true);click(Vector2(720,400))
 ck(g.recruitment_view.selected==-1 and g.run==untouched,'curtain input gated')
 g.recruitment_view.advance(.22);await shot('01-curtain')
 g.recruitment_view.advance(.36);await shot('02-rising')
 g.recruitment_view.advance(.85);click(Vector2(720,400));g.recruitment_view.advance(.2)
 ck(g.recruitment_view.selected==1 and g.run==untouched,'choice read-only')
 await shot('03-round3-choice')
 click(Vector2(721,895));ck(g.run.supports==['role_1207'] and g.run.gold==untouched.gold,'free confirmation')
 var committed=g.run.duplicate(true);g.recruitment_view.advance(.36);await shot('04-dissolve')
 click(Vector2(721,895));ck(g.run==committed,'animation repeated click harmless')
 g._process(1);g.set_process(false);ck(not g.crew_setup_view.active,'no auto configuration')
 ck(g.storage.resume()==committed,'restart preserves submitted choice')
 await shot('05-arrival')
 g.run.round=7;ck(R.open_draft(g.inventory,g.run,6),'open second draft')
 g.run.recruitment.candidates=['role_1505','role_1302','role_1504'];g._sync_recruitment();g.recruitment_view.advance(1.5)
 click(Vector2(1100,400));g.recruitment_view.advance(.2);await shot('06-round6-choice')
 var gold=g.run.gold;click(Vector2(721,895));ck(g.run.supports==['role_1207','role_1504'] and g.run.gold==gold+5,'full economy gift committed')
 g._process(2);g.set_process(false);ck(not g.crew_setup_view.active,'second choice no auto configuration')
 g._open_crew_setup();await shot('07-team')
 ck(g.crew_setup_view.model.automatic and g.crew_setup_view.rows().is_empty(),'team panel read-only')
 var current=g.run.duplicate(true);click(Vector2(1200,810));ck(g.run==current,'no hidden configuration hit')
 ck(g.crew_setup_view.hits.all(func(hit):return hit.kind=='close'),'no targeting or extra confirmation controls')
 g.queue_free();await process_frame
 print('RECRUITMENT_UI_V115 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
