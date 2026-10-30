extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const OUT="res://build/qa/settings/native/"
var viewport:SubViewport
var checks=0
func _initialize()->void:
 root.mode=Window.MODE_MINIMIZED;root.unfocusable=true;AudioServer.set_bus_mute(0,true)
 DirAccess.make_dir_recursive_absolute(OUT);call_deferred("check")
func shot(g,name:String)->void:
 g.queue_redraw();await process_frame;RenderingServer.force_draw(true);await process_frame
 assert(viewport.get_texture().get_image().save_png(OUT+name+".png")==OK)
func move(g,at:Vector2)->void:
 var e=InputEventMouseMotion.new();e.position=at;g._input(e)
func press(g,at:Vector2,down:bool)->void:
 var e=InputEventMouseButton.new();e.position=at;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;g._input(e)
func click(g,at:Vector2)->void:move(g,at);press(g,at,true);press(g,at,false)
func key(g,code:int)->void:
 var e=InputEventKey.new();e.keycode=code;e.pressed=true;g._input(e)
func target(g,action:String)->Vector2:
 for button in g.buttons:
  if button.action==action:return button.rect.get_center()
 assert(false,"missing visible action: "+action);return Vector2.ZERO
func check()->void:
 viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var g=G.new();viewport.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
 g.screen="camp";g.camp_age=3;g.selection_age=3;g.transition_image=null;g.motion.transition_left=0
 await shot(g,"01-home-entry");click(g,target(g,"settings"));assert(g.overlay=="settings")
 g._process(.4);g.transition_image=null;g.motion.transition_left=0
 var before=g.run.duplicate(true)
 await shot(g,"02-defaults")
 var r=g.SETTINGS_VIEW.slider("music")
 press(g,r.position+Vector2(55,18),true);move(g,r.position+Vector2(220,18));press(g,r.position+Vector2(220,18),false)
 assert(is_equal_approx(g.sound_settings.music_volume,.4))
 var reloaded=g.SOUND_SETTINGS.new(g.practice_storage.root_path)
 assert(is_equal_approx(reloaded.music_volume,.4))
 click(g,target(g,"settings:toggle:effects"));assert(g.sound_settings.effects_muted)
 g._process(.2);await shot(g,"03-adjusted")
 # Modal clicks, space and arrow keys cannot purchase or launch a fight.
 click(g,Vector2(1100,870));assert(g.overlay=="settings" and g.run==before)
 key(g,KEY_TAB);key(g,KEY_HOME);assert(g.sound_settings.effects_volume==0)
 key(g,KEY_RIGHT);assert(is_equal_approx(g.sound_settings.effects_volume,.05))
 click(g,target(g,"settings:reset"));assert(g.sound_settings.music_volume==1 and not g.sound_settings.effects_muted)
 click(g,target(g,"settings:back"));assert(g.screen=="camp" and g.overlay.is_empty())
 g._process(.4);g.screen="game";g.run.phase="shop";await shot(g,"04-preparation")
 click(g,target(g,"menu"));g._process(.4);await shot(g,"05-menu-entry")
 click(g,target(g,"settings"));assert(g.overlay=="settings");g._process(.4);await shot(g,"06-preparation-settings")
 key(g,KEY_ESCAPE);assert(g.overlay=="menu");g._action("close")
 g._start_battle();g.battle_entry_age=1;g.paused=false;g._action("menu");g._action("settings");var t=g.combat_time
 g._process(.4);assert(g.combat_time==t and not g.paused)
 g.transition_image=null;g.motion.transition_left=0;await shot(g,"07-battle-settings")
 key(g,KEY_ESCAPE);assert(g.overlay=="menu" and not g.paused)
 g._action("close");g._process(.1);assert(g.combat_time>t)
 g.paused=true;g._action("settings");g._process(.2);key(g,KEY_ESCAPE);assert(g.paused)
 g.queue_free();await process_frame
 print("PASS SETTINGS NATIVE: home/shop/battle, sliders, persistence, mute, reset, keyboard, no click-through, resume state");quit()
