extends SceneTree
const G=preload('res://scripts/game.gd')
const S=preload('res://scripts/storage/storage.gd')
const P=preload('res://scripts/online/async_pvp.gd')
const CAMP=preload('res://scripts/ui/chibi_camp_view.gd')
const OUT='res://build/qa/lobby-v135/native/'
var vp
var g
var failures=0
var checks=0
func ck(value,label):
 checks+=1
 if not value:failures+=1;printerr('FAIL ',label)
func _initialize():
 root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true);call_deferred('test')
func frame(name=''):
 g.motion.transition_left=0;g.transition_image=null;g.queue_redraw()
 await process_frame;RenderingServer.force_draw(true);await process_frame
 if not name.is_empty():ck(vp.get_texture().get_image().save_png(OUT+name+'.png')==OK,'screenshot '+name)
func click(point):
 for down in [true,false]:
  var e=InputEventMouseButton.new();e.position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;g._input(e)
func action_click(action):
 var found=g.buttons.filter(func(b):return b.action==action)
 ck(found.size()==1,'one target for '+action)
 if found.size()==1:click(found[0].rect.get_center())
func test():
 if DisplayServer.get_name()=='headless':quit(2);return
 vp=SubViewport.new();vp.size=Vector2i(1440,960);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
 g=G.new();g.storage=S.new('user://qa-v135-native-'+P.random_id()+'/');vp.add_child(g)
 await process_frame;g.set_process(false);g.set_process_input(false);g.camp_age=2;g.selection_age=2;g.age=2
 await frame('01-lobby')
 ck(not g.buttons.any(func(b):return b.action=='online_settings' or b.action.begins_with('mode:')),'no technical configuration or mode toggle')
 for n in g.C.selectable_leaders().size():
  click(CAMP.tag_rect(n).get_center());g._process(.6)
  ck(g.selected_leader==g.C.selectable_leaders()[n],'real character selection '+str(n))
  await frame('leader-'+g.selected_leader)
  var targets=g.buttons
  for a in targets.size():
   ck(Rect2(0,0,1440,960).encloses(targets[a].rect),'target inside canvas')
   for b in range(a+1,targets.size()):ck(not targets[a].rect.intersects(targets[b].rect),'no overlapping click targets')
 var choice=g.selected_leader
 action_click('camp:practice:enter');ck(g.screen=='game' and g.run.leader==choice,'human entry starts directly')
 await frame('02-practice')
 var human=g.run.duplicate(true);g._action('home');g._process(1);await frame('03-human-save')
 action_click('camp:async:enter');ck(g.screen=='game' and g.run.get('mode')=='async','online entry starts directly')
 await frame('04-online');g._action('home');g._process(1);await frame('05-both-saves')
 action_click('camp:practice:resume');ck(g.run==human,'continue preserves human progress')
 g._action('home');g._process(1);await frame()
 action_click('camp:async:history');g._process(1);await frame('06-online-history')
 ck(g.overlay=='history' and g.game_mode=='async','mode history opens without starting or settings')
 g.overlay='';g.motion.modal_value=0;g.motion.modal_target=0;await frame()
 var snapshot=g.camp_saves.duplicate(true);await frame();ck(g.camp_saves==snapshot,'redrawing never mutates saved state')
 g.camp_age=0;await frame('07-entrance');click(CAMP.tag_rect(0).get_center());g._process(.15);await frame('08-switching')
 g._process(1);await frame('09-final')
 g.queue_free();await process_frame;await create_timer(.2).timeout
 print('NATIVE_LOBBY_V135 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
