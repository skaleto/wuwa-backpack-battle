extends SceneTree
## Run with --main-pack and an external output directory. Never uses player saves.
var game
var view
var output:String
func _initialize():
 root.unfocusable=true;root.mode=Window.MODE_MINIMIZED
 AudioServer.set_bus_mute(0,true)
 output=OS.get_cmdline_user_args()[0]
 call_deferred("verify")
func capture(name:String):
 game.queue_redraw();await process_frame;await process_frame
 RenderingServer.force_draw(true)
 view.get_texture().get_image().save_png(output.path_join(name+".png"))
func verify():
 view=SubViewport.new();view.size=Vector2i(1440,960)
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 game=load("res://scripts/game.gd").new()
 game.storage=load("res://scripts/storage/storage.gd").new("user://qa-local-v2-"+str(OS.get_process_id())+"/")
 game.muted=true;view.add_child(game);await process_frame
 if not game.get_meta("startup_complete",false):printerr("FAIL startup");quit(1);return
 game.set_process(false);game.set_process_input(false)
 game.motion.transition_left=0;game.transition_image=null;game.paint_alpha=1
 game.age=4;game.camp_age=4
 await capture("lobby")
 game.run=load("res://scripts/run/run_lifecycle.gd").start("aemeath",37,game.inventory).run
 game.opponent=game.storage.opponent(game.run);game.screen="game"
 game.phase_age=2;game.reroll_age=2;game.selection_age=2
 await capture("preparation")
 await game._start_battle()
 if game.combat.is_empty():printerr("FAIL battle");quit(1);return
 game.motion.transition_left=0;game.transition_image=null;game.paint_alpha=1
 game.battle_entry_age=1;game.combat_time=game.combat.duration;game.run.phase="result";game.phase_age=2
 await capture("result")
 print("LOCAL_V2_PACK: startup, preparation, full bot battle and result rendered")
 game.queue_free();await process_frame;quit()
