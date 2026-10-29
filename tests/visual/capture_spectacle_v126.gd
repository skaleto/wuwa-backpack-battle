extends SceneTree
const G=preload('res://tests/fixtures/travel_fixture_v64.gd')
const V=preload('res://scripts/ui/battle/combat_vfx.gd')
var viewport:SubViewport
var g
var output='res://build/qa/feedback-v126/native/'
class Gallery extends Node2D:
 var clock=0.0
 var font:Font
 var vfx=preload('res://scripts/ui/battle/combat_vfx.gd').new()
 const KINDS=['sword','broadblade','gauntlet','pistol','rectifier','echo']
 const NAMES=['迅刀','长刃','臂铠','配枪','音感仪','声骸']
 const COLORS=['66d5ff','ffae55','ffc86d','ffb58b','b3a0ff','6ce8ca']
 func _draw():
  draw_rect(Rect2(0,0,1440,960),Color('332a57'))
  var v=preload('res://scripts/ui/battle/combat_vfx.gd')
  for n in 6:
   var at=Vector2(28+(n%3)*470,60+(n/3)*450)
   var style=StyleBoxFlat.new();style.bg_color=Color('504578');style.set_corner_radius_all(20)
   draw_style_box(style,Rect2(at,Vector2(440,415)))
   draw_string(font,at+Vector2(24,43),NAMES[n],HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color('fff2dd'))
   var from=at+Vector2(50,250);var to=at+Vector2(256,206)
   var age=fmod(clock,1.4)
   if age<v.TRAVEL:
    v.projectile(self,{'life':v.TRAVEL-age,'weapon':KINDS[n],'color':Color(COLORS[n]),'strong':true,'side':0},from,to)
   elif age<v.TRAVEL+.8:
    v.paper_impact(self,{'position':to,'side':0,'weapon':KINDS[n],'color':Color(COLORS[n]),'strong':true,'age':age-v.TRAVEL,'duration':.7})
func _initialize():
 root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true);call_deferred('capture')
func shot(name):
 g.queue_redraw();await process_frame;RenderingServer.force_draw(true);await process_frame
 assert(viewport.get_texture().get_image().save_png(output+name+'.png')==OK)
func capture():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with('--tag='):output='res://build/qa/feedback-v126/native-'+arg.trim_prefix('--tag=')+'/'
 for folder in ['','gallery','battle']:DirAccess.make_dir_recursive_absolute(output+folder)
 viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 g=G.new();viewport.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
 g.screen='camp';g.saved={};g.camp_age=3;g.selection_age=3;g.mouse=Vector2(1410,950);g.motion.transition_left=0;g.transition_image=null
 await shot('opening')
 g.visible=false
 var gallery=Gallery.new();gallery.font=g.font;viewport.add_child(gallery)
 for n in 42:
  gallery.clock=n/30.0;gallery.queue_redraw();await shot('gallery/%03d'%n)
 gallery.queue_free();await process_frame;g.visible=true
 if '--gallery-only' in OS.get_cmdline_user_args():g.queue_free();await process_frame;quit();return
 var path='res://tests/fixtures/data/feedback-v120/input/hsin-round10.json'
 var data=JSON.parse_string(FileAccess.get_file_as_string(path))
 assert(g.storage.write_json(g.storage.root_path+'run.json',data))
 g.run=g.storage.resume();g.opponent=g.run.opponent.duplicate(true);g.combat=g.run.combat.duplicate(true);g.run.phase='battle'
 g.screen='game';g.combat_time=0;g.event_cursor=0;g.speed=1;g.paused=false;g.battle_entry_age=1;g._clear_feedback()
 var frozen_combat=g.combat.duplicate(true);var maximum=0
 for n in 180:
  g._process(1.0/30);await shot('battle/%03d'%n)
  if g.combat_vfx.impacts.size()>maximum:
   maximum=g.combat_vfx.impacts.size();await shot('impact')
 g.paused=true;var effects=g.combat_vfx.impacts.duplicate(true);var flights=g.projectiles.duplicate(true);g._process(.5)
 assert(effects==g.combat_vfx.impacts and flights==g.projectiles and frozen_combat==g.combat)
 FileAccess.open(output+'capture.txt',FileAccess.WRITE).store_string('Hidden/unfocusable native 1440x960. Independent QA Storage. 42 gallery + 180 dense recorded battle frames at 30 fps. Max impacts '+str(maximum)+'. Pause freezes impacts and flights. Combat record unchanged. No OS input or foreground activation.')
 g.queue_free();await process_frame;quit()
