extends SceneTree
const G=preload('res://tests/fixtures/travel_fixture_v64.gd')
const CAMP=preload('res://scripts/ui/chibi_camp_view.gd')
const PORTRAIT=preload('res://scripts/ui/portraits/portrait_framing.gd')
const PRESENTER=preload('res://scripts/ui/party/recruitment_presenter.gd')
const OUT='res://build/qa/opening-v119/native/'
var checks=0
var failures=0
var viewport:SubViewport
var g
var capture=false
class Gallery extends Node2D:
 var font:Font
 var roles:Array=[]
 var portraits:Array=[]
 func _draw():
  draw_rect(Rect2(0,0,1440,960),Color('75679b'))
  var skin=preload('res://scripts/ui/visual_skin.gd')
  var framing=preload('res://scripts/ui/portraits/portrait_framing.gd')
  var presenter=preload('res://scripts/ui/party/recruitment_presenter.gd')
  var art=preload('res://scripts/ui/party/recruitment_art.gd')
  var catalog=preload('res://scripts/data/catalog.gd')
  for n in roles.size():
   var origin=Vector2(28+(n%5)*282,24+(n/5)*230)
   var m=portraits[n]
   framing.draw(self,m.portrait,Rect2(origin+Vector2(32,0),Vector2(205,183)),m.head_source)
   art.text(self,font,catalog.roster[roles[n]].name,Rect2(origin+Vector2(0,185),Vector2(264,29)),18,Color('fff5de'))
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():
 root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true);call_deferred('test')
func frame(name=''):
 g.motion.transition_left=0;g.transition_image=null;g.queue_redraw()
 await process_frame;RenderingServer.force_draw(true);await process_frame
 if capture and not name.is_empty():ck(viewport.get_texture().get_image().save_png(OUT+name+'.png')==OK,'capture '+name)
func click(point):
 for down in [true,false]:
  var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=point;g._input(event)
func test():
 capture='--capture' in OS.get_cmdline_user_args();DirAccess.make_dir_recursive_absolute(OUT)
 viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 g=G.new();viewport.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
 var leaders=g.C.selectable_leaders()
 for n in leaders.size():
  ck(Rect2(0,0,1440,960).encloses(CAMP.tag_rect(n)),'portrait target on canvas')
  if n:ck(not CAMP.tag_rect(n).intersects(CAMP.tag_rect(n-1)),'portrait targets separated')
 var all=g.C.roster.keys()
 for role in all:
  var m=PRESENTER.portrait(role)
  ck(m.head_source.position==m.portrait_source.position and m.head_source.size.x==m.portrait_source.size.x,'all portraits retain full width '+role)
  ck(m.portrait_source.encloses(m.head_source),'crop inside original '+role)
 if DisplayServer.get_name()!='headless':
  g.screen='camp';g.saved={};g.camp_age=.0;g.selection_age=2;g.mouse=Vector2.ZERO
  await frame('01-entry');var original=g.run.duplicate(true)
  # Selection and start remain live even while the independent entry animation runs.
  click(CAMP.tag_rect(3).get_center());ck(g.selected_leader==leaders[3] and g.run==original,'early selection is read-only and never gated')
  g._process(.35);await frame('02-rising')
  g._process(1)
  for n in leaders.size():
   click(CAMP.tag_rect(n).get_center());g._process(.5)
   ck(g.selected_leader==leaders[n],'actual portrait click '+str(leaders[n]))
   await frame('leader-'+str(leaders[n]))
  for n in [0,2,1,4]:click(CAMP.tag_rect(n).get_center());g._process(.025)
  ck(g.selected_leader==leaders[4] and g.run==original,'rapid switch final choice, no game mutation')
  g._process(1);g.saved=g.run.duplicate(true);await frame('03-with-save')
  var buttons=g.buttons.filter(func(b):return b.action in ['camp:practice:enter','camp:async:enter'])
  ck(buttons.size()==2 and not buttons[0].rect.intersects(buttons[1].rect),'human and online entries stay separate')
  g.camp_age=0;await frame()
  click(CAMP.entry_rect('practice').get_center());ck(g.screen=='game' and g.run.leader==leaders[4],'start uses final visible choice')
  g._process(1);g._open_crew_setup();await frame('04-team-empty');g.crew_setup_view.close()
  var recruit=preload('res://scripts/party/recruitment_v115.gd')
  g.run.round=4;ck(recruit.open_draft(g.inventory,g.run,3),'open draft')
  g.run.recruitment.candidates=['role_1207','role_1607','role_1505'];g._sync_recruitment();g.recruitment_view.advance(1.5)
  await frame('05-recruitment')
  click(Vector2(300,400));g.recruitment_view.advance(.2);click(Vector2(721,895));g._process(1.5)
  ck(g.run.supports==['role_1207'],'native recruitment still commits selected teammate')
  g._open_crew_setup();await frame('04-team');g.crew_setup_view.close()
  g.visible=false
  for page in ceili(all.size()/20.0):
   var gallery=Gallery.new();gallery.font=g.font;gallery.roles=all.slice(page*20,page*20+20)
   # The gallery keeps its texture refs while native draw commands are pending.
   gallery.portraits=gallery.roles.map(PRESENTER.portrait);viewport.add_child(gallery)
   await frame('06-all-portraits-'+str(page+1));gallery.queue_free();await process_frame
  g.visible=true
  var state=g.run.duplicate(true);await frame();await frame();ck(g.run==state,'presentation redraw never changes run')
  if capture:
   g.screen='camp';g.overlay='';g.saved={};g.selected_leader=leaders[0];g.camp_previous_leader='';g.camp_age=0;g.selection_age=2;g.mouse=Vector2.ZERO
   DirAccess.make_dir_recursive_absolute(OUT+'frames')
   for n in 120:
    if n==53:click(CAMP.tag_rect(3).get_center())
    if n==89:click(CAMP.tag_rect(1).get_center())
    g._process(1.0/30);await frame('frames/%03d'%n)
 g.queue_free();await process_frame;await create_timer(.3).timeout
 print('OPENING_V119 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
