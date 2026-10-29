extends SceneTree
const G=preload("res://tests/fixtures/playable_fixture_v50.gd")
var checks=0
var failures=0
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():call_deferred("test")
func test():
	# QA is silent even when invoked with a real audio driver.
	AudioServer.set_bus_mute(0,true)
	var bus_count=AudioServer.bus_count
	var game=G.new();root.add_child(game);await process_frame
	game.set_process(false);game.set_process_input(false)
	var music=game.get("music")
	ck(is_instance_valid(music),"game integrates the selected preparation and battle music")
	if not is_instance_valid(music):
		game.queue_free();await process_frame;quit(1);return
	music.set_process(false)
	ck(music.diagnostics().muted,"isolated QA mute applies before the first music frame")
	for key in ["prepare","battle"]:
		var stream=music.players[key].stream
		ck(stream is AudioStreamOggVorbis and stream.loop and stream.get_length()>60,"full author loop loads: "+key)
	music.set_context("shop",false);music._process(1.0)
	ck(music.diagnostics().active==["prepare"],"shop plays only preparation music")
	var playback=music.players.prepare.get_stream_playback()
	for n in 20:music.set_context("shop",false)
	ck(playback==music.players.prepare.get_stream_playback(),"repeated context does not restart the song")
	music.set_context("battle",false);music._process(.25)
	ck(music.diagnostics().active.size()==2,"battle transition overlaps two fading tracks")
	music.set_context("shop",false);music._process(.1)
	music.set_context("battle",false);music._process(1.0)
	ck(music.diagnostics().active==["battle"],"rapid transitions settle without extra playback voices")
	var battle_volume=music.players.battle.volume_db
	ck(is_equal_approx(battle_volume,-21.46),"battle BGM lowered by 3dB")
	for phase in ["result","ending"]:
		music.set_context(phase,false)
		ck(music.diagnostics().active.is_empty() and not music.players.battle.playing,"result/ending immediately stops battle music: "+phase)
		for n in 5:music.set_context(phase,false);music._process(.1)
		ck(music.diagnostics().active.is_empty(),"result stays silent: "+phase)
		music.set_context("battle",false);music._process(1.0)
		ck(music.diagnostics().active==["battle"],"next battle restarts its track")
	playback=music.players.battle.get_stream_playback()
	music.set_context("battle",false,true);music._process(1.0)
	ck(music.players.battle.volume_db<battle_volume-3,"paused battle lowers the music")
	music.set_context("battle",true)
	ck(AudioServer.is_bus_mute(AudioServer.get_bus_index(music.bus_name)),"mute silences both tracks immediately")
	music.set_context("battle",false);music._process(1.0)
	ck(not AudioServer.is_bus_mute(AudioServer.get_bus_index(music.bus_name)),"unmute restores music")
	ck(playback==music.players.battle.get_stream_playback(),"mute/unmute preserves playback position")
	# Exercise actual game frames, menus and the existing sound button.
	game.muted=false;game.screen="camp";game._process(.016);music._process(1.0)
	ck(music.diagnostics().active==["prepare"],"character selection uses preparation music")
	ck(is_equal_approx(music.players.prepare.volume_db,-17.34),"preparation BGM lowered by 3dB")
	game.screen="game";game.run.phase="shop";var before=game.run.duplicate(true)
	playback=music.players.prepare.get_stream_playback()
	for modal in ["","item_details","forge","menu"]:
		game.overlay=modal;game._process(.016);music._process(.016)
	ck(playback==music.players.prepare.get_stream_playback(),"details, recipes and menu do not restart preparation")
	ck(game.run==before,"music and overlays preserve the complete run state")
	game.run.phase="battle";game.paused=true;game.overlay="";game.speed=4
	game._process(.016);music._process(1.0)
	ck(music.diagnostics().active==["battle"],"real battle phase selects battle music")
	ck(music.players.values().all(func(p):return p.pitch_scale==1.0),"battle speed never changes music pitch or tempo")
	game._action("sound")
	ck(game.muted and game.audio.muted and music.diagnostics().muted,"existing sound toggle mutes music and effects together")
	game._action("sound")
	ck(not game.audio.muted and not music.diagnostics().muted,"existing sound toggle restores both")
	var bus_name=music.bus_name
	playback=null;music.stop_all();game.audio.stop_all();await create_timer(.25).timeout
	game.queue_free();await process_frame;await process_frame
	ck(AudioServer.get_bus_index(bus_name)==-1 and AudioServer.bus_count==bus_count,"scene teardown removes music and effect buses")
	print("MUSIC_V94 ",checks," checks, ",failures," failures")
	await create_timer(.15).timeout
	quit(1 if failures else 0)
