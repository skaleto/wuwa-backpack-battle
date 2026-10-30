extends SceneTree
const G=preload('res://tests/fixtures/travel_fixture_v64.gd')
const R=preload('res://scripts/party/recruitment_v115.gd')
var viewport:Window
var g
var out='res://build/qa/polish-140/'+('before/' if '--before' in OS.get_cmdline_user_args() else 'after/')
func _initialize():
 root.unfocusable=true;root.mode=Window.MODE_MINIMIZED;AudioServer.set_bus_mute(0,true)
 root.size=Vector2i(2560,1440);root.content_scale_size=Vector2i(1440,960)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_KEEP
 RenderingServer.viewport_set_update_mode(root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
 DirAccess.make_dir_recursive_absolute(out);call_deferred('capture')
func shot(name):
 g.queue_redraw();g.recruitment_view.queue_redraw();g.recruitment_view.foreground.queue_redraw()
 for n in 3:await process_frame
 RenderingServer.force_draw(true);await process_frame
 assert(viewport.get_texture().get_image().save_png(out+name+'.png')==OK)
 print('CAPTURE ',name)
func capture():
 root.mode=Window.MODE_MINIMIZED
 viewport=root
 g=G.new();viewport.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
 g.run.round=4;assert(R.open_draft(g.inventory,g.run,3));g.run.recruitment.candidates=['role_1509','role_1207','role_1505'];g._sync_recruitment();g.recruitment_view.advance(1.5);g.set_process(false)
 g.recruitment_view.select(0);g.recruitment_view.advance(.2);await shot('01-recruitment')
 var before=g.run.duplicate(true);print('QA can_confirm=',g.recruitment_view.can_confirm(),' selected=',g.recruitment_view.selected,' supply=',g.run.supply_version)
 var ev=InputEventKey.new();ev.keycode=KEY_ENTER;ev.pressed=true;g._input(ev)
 assert(g.run.supports==['role_1509'] and g.run.gold==before.gold,'free recruit committed once')
 g._process(2);g.set_process(false);g.capacity_pan_left=0
 g.run.shop=[{'kind':'pocket_single','locked':false},{'kind':'pocket_double','locked':false},{'kind':'pouch','locked':false},{'kind':'pocket_long_l','locked':false},{'kind':'w_sword','locked':false},{'kind':'daily_tea','locked':false}]
 g.reroll_age=2;g.transition_image=null;g.motion.transition_left=0
 await shot('02-shop')
 g.matching=true;g.age=8.25;await shot('03-matching');g.age=8.65;await shot('04-matching-motion');g.matching=false
 g.run.round=7;assert(R.open_draft(g.inventory,g.run,6));g.run.recruitment.candidates=['role_1207','role_1505','role_1504'];g._sync_recruitment();g.recruitment_view.advance(1.5);g.set_process(false)
 await shot('05-bond-cards')
 g.recruitment_view.clear();g.run.phase='shop';g.run.recruitment.candidates=[];g._open_crew_setup();await shot('06-team')
 g.queue_free();await process_frame;print('PASS native panels and free recruitment, independent QA profile');quit()
