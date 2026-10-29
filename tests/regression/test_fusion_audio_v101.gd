extends SceneTree
const F=preload("res://scripts/ui/crafting/fusion_view.gd")
const A=preload("res://scripts/ui/audio/event_audio.gd")
var checks=0
var failures=0
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:
	# Never send test audio to the user's speakers, even when launched manually.
	AudioServer.set_bus_mute(0,true)
	call_deferred("test")
func test()->void:
	if AudioServer.get_driver_name()!="Dummy":
		printerr("Run this test with --headless --audio-driver Dummy; no desktop audio is played.")
		quit(2);return
	var view=F.new();root.add_child(view)
	var audio=A.new();root.add_child(audio);await process_frame
	var supported=view.has_signal("sound_cue") and view.has_signal("stopped")
	ck(supported,"fusion exposes animation-owned sound and cancellation signals")
	ck(audio.has_method("stop_fusion"),"audio exposes a fusion-only cancellation entry")
	ck(audio.pools.has("fusion") and audio.pools.fusion.size()==2,"two fusion voices are isolated from UI and combat")
	if not supported or not audio.has_method("stop_fusion") or not audio.pools.has("fusion"):
		view.free();audio.free();quit(1);return
	var events:Array=[]
	view.connect("sound_cue",func(key):events.append(key);audio.play_event(key))
	view.connect("stopped",func():events.append("stop");audio.stop_fusion())

	# The component only receives committed render facts, with no run or inventory.
	view.start([],Vector2(40,20),"crafted")
	ck(events==["stop"],"V102 start clears any previous voice and leaves approach silent")
	ck(view.active() and view.output_alpha("crafted")==0.0,"committed presentation hides its new output")
	view.advance(.939)
	ck(events==["stop"],"approach remains silent before the visible output begins")
	view.advance(.002)
	ck(events==["stop","fusion_land"],"crossing output appearance requests one short land cue")
	view.advance(0.0);view.advance(.05)
	ck(events.count("fusion_land")==1,"subsequent animation frames do not repeat land")
	view.advance(.4)
	ck(not view.active() and events==["stop","fusion_land"],"natural completion releases visuals without restarting audio")
	ck(audio.diagnostics().active.fusion>0,"natural finish leaves the started land voice playing")
	ck(audio.streams.fusion_land.get_length()>=.20 and audio.streams.fusion_land.get_length()<=.30,"V102 land is a short 200–300 ms sample")
	view.advance(2.0)
	ck(events.count("fusion_land")==1,"completed animation never emits a delayed second cue")
	view.finish()
	ck(audio.diagnostics().active.fusion==0,"explicit finish also cancels a naturally finishing audio tail")

	events.clear();view.start([],Vector2.ZERO,"skip-before")
	view.advance(.5);view.finish();view.advance(5.0)
	ck(events==["stop","stop"],"skip before landing stays silent and never schedules land")
	ck(audio.diagnostics().active.fusion==0,"skip before land leaves no fusion voice")
	events.clear();view.start([],Vector2.ZERO,"skip-after")
	view.advance(.95);view.finish();view.advance(5.0)
	ck(events==["stop","fusion_land","stop"],"skip after landing cancels the land voice once")
	ck(audio.diagnostics().active.fusion==0,"skip after land leaves no fusion voice")

	events.clear();view.start([],Vector2.ZERO,"large-frame");view.advance(2.0)
	ck(events==["stop","fusion_land"] and not view.active(),"one large frame crosses landing exactly once before natural finish")
	events.clear();var gathers=int(audio.played.get("fusion",0))
	view.start([],Vector2.ZERO,"restart-a");view.start([],Vector2.ZERO,"restart-b")
	ck(events==["stop","stop"],"replacement cancels the previous sequence and remains silent")
	ck(int(audio.played.get("fusion",0))==gathers,"no gather voice is requested by replacement")
	view.advance(.95)
	ck(events.count("fusion_land")==1,"replacement has one land belonging to the current sequence")
	view.finish()

	audio.stop_all();audio.last_played.clear()
	ck(audio.play_event("click") and audio.play_event("start"),"UI can fill its own two voices")
	ck(audio.play_event("attack","sword") and audio.play_event("star"),"combat and weapon voices may also be active")
	events.clear();view.start([],Vector2.ZERO,"busy-ui");view.advance(.95)
	var active=audio.diagnostics().active
	ck(active.fusion==1 and active.ui==2 and active.weapon==1 and active.combat==1,"one short fusion cue plays while unrelated pools are occupied")
	var click_clock=audio.last_played.get("click")
	view.finish()
	active=audio.diagnostics().active
	ck(active.fusion==0 and active.ui==2 and active.weapon==1 and active.combat==1,"fusion cancellation leaves unrelated audio playing")
	ck(audio.last_played.get("click")==click_clock,"fusion restart does not reset unrelated rate limits")
	for player in audio.pools.fusion:
		ck(player.pitch_scale==1.0,"fusion samples retain their original pitch and speed")
	audio.set_muted(true);var before=audio.played.duplicate()
	view.start([],Vector2.ZERO,"muted");view.advance(.95)
	ck(audio.played==before and audio.diagnostics().active.fusion==0,"mute suppresses the short fusion cue")
	view.finish()
	# Controller integration: the committed animation owns the sole fusion cue.
	var G=load("res://tests/fixtures/playable_fixture_v50.gd");var game=G.new()
	root.add_child(game);await process_frame;game.set_process(false);game.set_process_input(false)
	game.audio.requested.clear()
	game.fusion_view.start([],Vector2.ZERO,"committed")
	ck(game.audio.requested.get("fusion",0)==0,"controller keeps approach silent")
	game._process(.95)
	ck(game.audio.requested.get("fusion_land",0)==1,"controller follows output reveal")
	game.fusion_view.finish();game.audio.requested.clear()
	game.fusion_view.start([],Vector2.ZERO,"cancel-before")
	game.fusion_view.advance(.93);game.overlay="menu";game._process(.1)
	ck(not game.fusion_view.active() and game.audio.requested.get("fusion_land",0)==0,"invalid context cancels before crossing land")
	game.overlay="";game.fusion_view.start([],Vector2.ZERO,"skip")
	var press=InputEventKey.new();press.pressed=true;press.keycode=KEY_ESCAPE
	game._input(press);game._process(2.0)
	ck(not game.fusion_view.active() and game.audio.requested.get("fusion_land",0)==0,"controller input skip never leaves a delayed land")
	game.queue_free();await process_frame
	print("FUSION_AUDIO_V101 ",checks," checks, ",failures," failures")
	view.free();audio.queue_free();await process_frame
	await create_timer(.15).timeout
	quit(1 if failures else 0)
