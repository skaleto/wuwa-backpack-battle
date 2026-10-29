extends SceneTree
const G=preload('res://tests/fixtures/travel_fixture_v64.gd')
const B=preload('res://scripts/ui/chibi_action_button.gd')
const OUT='res://build/qa/buttons-v118/native/'
var checks=0
var failures=0
var g
var viewport
var capture=false
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():
 root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true);call_deferred('test')
func frame(name=''):
 g.paint_alpha=1;g.paint_offset=Vector2.ZERO;g.motion.transition_left=0;g.transition_image=null;g.queue_redraw()
 await process_frame;RenderingServer.force_draw(true);await process_frame
 var image=viewport.get_texture().get_image()
 if capture and not name.is_empty():assert(image.save_png(OUT+name+'.png')==OK)
 return image
func click(point):
 for pressed in [true,false]:
  var event=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;g._input(event)
func target(action):
 var found=g.buttons.filter(func(b):return b.action==action and (action!='crew' or b.rect==g.QL.RECRUIT))
 ck(found.size()==1,'one registered target for '+action)
 return found[0] if not found.is_empty() else {}
func test():
 capture='--capture' in OS.get_cmdline_user_args();DirAccess.make_dir_recursive_absolute(OUT)
 viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 g=G.new();viewport.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
 for data in [[B.START,'开始游戏','start'],[B.RESUME,'继续进度','secondary'],[g.QL.RECRUIT,'队伍','team'],[Rect2(0,0,166,43),'组合试玩','secondary'],[Rect2(0,0,176,43),'完整物品池','secondary'],[Rect2(0,0,318,34),'合成配方','secondary'],[Rect2(0,0,410,62),'返回选择','secondary'],[Rect2(0,0,124,34),'购买 99','secondary']]:
  var layout=B.geometry(data[0],data[2]);var size=B.font_size(g.font,data[1],layout.text,data[2])
  ck(size>=16,'readable button type '+data[1])
  ck(g.font.get_string_size(data[1],HORIZONTAL_ALIGNMENT_LEFT,-1,size).x<=layout.text.size.x,'label fits between authored caps '+data[1])
  ck(layout.left+layout.right<data[0].size.x,'caps leave a real text zone')
  ck(B.pose(data[0],data[2],0,0,true,0)!=B.pose(data[0],data[2],1,0,true,0),'hover has distinct pose '+data[1])
  ck(B.pose(data[0],data[2],1,0,false,0)==Transform2D.IDENTITY,'disabled does not invite interaction '+data[1])
 ck(B.START.size.y>=85 and B.START.size.x>B.RESUME.size.x,'start dominates secondary action')
 ck(not B.START.intersects(B.RESUME),'start and resume targets separated')
 ck(Rect2(0,0,1440,960).encloses(B.START),'primary stays within canvas')
 if DisplayServer.get_name()!='headless':
  g.screen='camp';g.saved={};g.mouse=Vector2(700,50)
  await frame('01-start-idle');var start=target('camp:practice:enter');var original=start.rect
  g.mouse=start.rect.get_center();await frame();g._process(.18);var over=await frame('02-start-hover')
  ck(g.motion.hover_values.get('camp:practice:enter@'+str(original.position),0)>0.5,'start hover actually advances')
  ck(target('camp:practice:enter').rect==original,'hover never moves start hit target')
  g.motion.press('camp:practice:enter');var press=await frame('03-start-pressed')
  ck(over.get_data()!=press.get_data(),'native press changes visible button')
  g.motion.presses.clear();g.saved=g.run.duplicate(true);g.mouse=Vector2(700,50)
  g.camp_saves.practice=g.saved.duplicate(true)
  await frame('04-start-with-save');target('camp:practice:new')
  click(original.get_center());ck(g.screen=='game' and g.run.phase=='shop','real primary click starts the run')
  g._process(1);g.mouse=Vector2(1000,900);await frame('05-team-idle');var crew=target('crew');var run=g.run.duplicate(true)
  g.mouse=crew.rect.get_center();await frame();g._process(.16);await frame('06-team-hover');ck(target('crew').rect==crew.rect,'team target stays fixed')
  click(crew.rect.get_center());ck(g.crew_setup_view.active and g.run==run,'team click opens read-only team view')
  g.crew_setup_view.advance(1);await frame('07-team-view');g.crew_setup_view.close();g.overlay=''
  g.overlay='menu';g.motion.modal_value=1;g.motion.modal_target=1;await frame('08-menu')
  g.overlay='';g.motion.modal_value=0;g.motion.modal_target=0;g._open_item_details(g.run.items[0],'board');g._process(1);await frame('09-item-details')
  var detail=target('detail_recipes');click(detail.rect.get_center());ck(g.overlay=='item_recipes','unified recipe action still opens recipes')
  g._process(1);await frame('10-recipes');g.overlay='';g.motion.modal_value=0;g.motion.modal_target=0
  g.run.items=[];await frame('11-disabled-battle');var battle=target('battle');ck(not battle.enabled,'empty backpack disables battle')
  click(battle.rect.get_center());ck(g.run.phase=='shop','disabled battle cannot transact')
  if capture:
   g.screen='camp';g.saved={};g.mouse=Vector2(700,50);g.motion.hover_values.clear();g.motion.hover_targets.clear()
   DirAccess.make_dir_recursive_absolute(OUT+'frames')
   for n in 60:
    g.mouse=B.START.get_center() if n in range(12,42) else Vector2(700,50)
    if n==30:g.motion.press('camp:practice:enter')
    g._process(1.0/30);await frame('frames/%03d'%n)
 g.queue_free();await process_frame;await create_timer(.3).timeout
 print('BUTTONS_V118 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
