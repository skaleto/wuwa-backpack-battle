extends SceneTree
const G=preload("res://scripts/game.gd")
const S=preload("res://scripts/storage/storage.gd")
const P=preload("res://scripts/online/async_pvp.gd")
const OUT="res://build/qa/pvp-v134/native/"
var vp
var g
func _initialize():
	root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true);call_deferred("capture")
func shot(name:String):
	g.queue_redraw();await process_frame;RenderingServer.force_draw(true);await process_frame
	if vp.get_texture().get_image().save_png(OUT+name+".png")!=OK:quit(1)
func capture():
	if DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(OUT)
	vp=SubViewport.new();vp.size=Vector2i(1440,960);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
	g=G.new();g.storage=S.new("user://qa-v134-capture-"+P.random_id()+"/");vp.add_child(g)
	await process_frame;g.set_process(false);g.set_process_input(false);g.camp_age=2.0;g.age=2.0
	await shot("01-practice")
	g._switch_mode("async");await shot("02-async")
	g._action("start");g.motion.transition_left=0;g.transition_image=null;await shot("03-preparation")
	g.matching=true;await shot("04-matching");g.matching=false
	await g._start_battle();g.battle_entry_age=1;g.combat_time=.2;await shot("05-bot-fallback")
	g._application().finish_replay(g.run);g._application().preserve_result(g.run);g._action("home");g._open_history();g.motion.transition_left=0;g.transition_image=null
	await shot("06-history")
	g.queue_free();await process_frame;print("Hidden nonfocusable capture: six screens, QA-only saves.");quit()
