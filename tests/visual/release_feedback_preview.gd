extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
var g
var view
func _initialize():
 root.unfocusable=true;root.mode=Window.MODE_MINIMIZED;AudioServer.set_bus_mute(0,true);call_deferred("capture")
func frame(name:String):
 g.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(true)
 view.get_texture().get_image().save_png("res://build/qa/release-feedback/"+name+".png")
func capture():
 DirAccess.make_dir_recursive_absolute("res://build/qa/release-feedback")
 view=SubViewport.new();view.size=Vector2i(1440,960);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 g=G.new();view.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
 g.motion.modal_value=0;g.motion.modal_target=0;g.motion.transition_left=0;g.paint_alpha=1;g.transition_image=null
 g.run.wins=3;g.run.losses=1;g.run.round=5
 await frame("hud")
 g.overlay="menu";g.motion.modal_value=1;await frame("menu")
 g._request_end_run("practice","menu");await frame("end-confirm")
 g._cancel_end_run();g.overlay="";g.screen="camp";g.startup_update_prompted=false
 g.update_client.enabled=true;g.update_client.status="available";g.update_client.available={"version":"0.2.0-demo.3","notes":["更新提示、结束本局与胜负反馈。"]};g.update_client.artifact={"kind":"patch","bytes":300000}
 g.motion.modal_value=0;g._maybe_prompt_update();g.motion.modal_value=1;await frame("update-prompt")
 g.update_client.status="ready";g._refresh_camp_saves();g.camp_saves.practice=g.run.duplicate(true);await frame("update-end-option")
 g.overlay="";g.screen="game";g.motion.modal_value=0
 g.combat=g.engine.simulate(g.run,g.opponent,int(g.run.seed));g.run.phase="result";g.combat_time=g.combat.duration
 for winner in [1,-1]:
  g.combat.winner=winner
  for n in 6:
   g.phase_age=n*.25+.1;await frame(("win" if winner==1 else "loss")+str(n))
 g.queue_free();await process_frame;quit()
