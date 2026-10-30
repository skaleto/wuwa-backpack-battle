extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
var failures=0
var checks=0
func ck(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:call_deferred("test")
func test()->void:
 var g=G.new();root.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false);g.muted=false
 var before=g.run.duplicate(true)
 g._action("settings")
 ck(g.overlay=="settings","settings opens from existing action route")
 if g.overlay!="settings":g.queue_free();await process_frame;quit(1);return
 var prefs=g.get("sound_settings")
 ck(prefs!=null,"sound preferences have their own store")
 if prefs!=null:
  ck(prefs.music_volume==1.0 and prefs.effects_volume==1.0,"defaults preserve the approved mix")
  prefs.music_volume=.35;prefs.effects_volume=.6;prefs.effects_muted=true
  g.call("_apply_sound_settings")
  var mi=AudioServer.get_bus_index(g.music.bus_name);var si=AudioServer.get_bus_index(g.audio.bus_name)
  ck(is_equal_approx(AudioServer.get_bus_volume_db(mi),linear_to_db(.35)),"music slider controls music bus")
  ck(is_equal_approx(AudioServer.get_bus_volume_db(si),linear_to_db(.6)),"effects slider controls effects bus")
  ck(not g.music.muted and g.audio.muted,"effects can mute without muting music")
  ck(not g.audio.play_event("click"),"muted effects cannot start a voice")
  prefs.effects_muted=false;prefs.music_muted=true;g.call("_apply_sound_settings")
  ck(g.music.muted and not g.audio.muted,"music can mute without muting effects")
  g.audio.last_played.clear();ck(g.audio.play_event("pick"),"effects remain playable with music muted")
  prefs.effects_muted=true;g.call("_apply_sound_settings")
  ck(g.audio.diagnostics().active.values().all(func(value):return value==0),"mute stops voices already in flight")
  prefs.effects_muted=false;prefs.effects_volume=0;g.call("_apply_sound_settings")
  ck(g.audio.muted and AudioServer.is_bus_mute(AudioServer.get_bus_index(g.audio.bus_name)),"zero volume is truly silent")
  prefs.effects_volume=.6;prefs.effects_muted=true;prefs.music_muted=false;g.call("_apply_sound_settings")
  ck(prefs.save(),"settings saved")
  var loaded=prefs.get_script().new(g.practice_storage.root_path)
  ck(loaded.music_volume==.35 and loaded.effects_volume==.6 and loaded.effects_muted,"restart restores independent settings")
  g.call("_settings_action","settings:back")
  ck(g.overlay.is_empty() and g.run==before,"closing does not mutate the current run")
  g._start_battle();g.paused=true;g._action("menu");g._action("settings")
  var t=g.combat_time;g._process(.2)
  ck(g.combat_time==t,"settings blocks battle advancement")
  g.call("_settings_action","settings:back")
  ck(g.overlay=="menu" and g.paused,"return preserves manual pause and parent menu")
  g._action("close");g.paused=false;g._action("settings");t=g.combat_time;g._process(.2)
  ck(g.combat_time==t and not g.paused,"settings pauses without rewriting playback state")
  g.call("_settings_action","settings:reset")
  ck(prefs.music_volume==1 and prefs.effects_volume==1 and not prefs.effects_muted,"defaults restore both channels")
  var file=ConfigFile.new();file.set_value("audio","music_volume",-4);file.set_value("audio","effects_volume","bad");file.set_value("audio","music_muted","bad");file.save(g.practice_storage.root_path+"settings.cfg")
  loaded=prefs.get_script().new(g.practice_storage.root_path)
  ck(loaded.music_volume==0 and loaded.effects_volume==1 and not loaded.music_muted,"invalid persisted values clamp or fall back safely")
 g.queue_free();await process_frame
 print("SETTINGS ",checks," checks, ",failures," failures");quit(1 if failures else 0)
