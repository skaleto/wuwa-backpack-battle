extends SceneTree
## Headless display + CoreAudio mixer. Master is muted before any voice starts;
## capture is upstream of that mute, so no sound reaches the user's speakers.
const M=preload("res://scripts/ui/audio/music_audio.gd")
const A=preload("res://scripts/ui/audio/event_audio.gd")
var checks=[]
var samples={}
var capture=AudioEffectCapture.new()
var music
func ck(ok:bool,label:String)->void:
	checks.append({"ok":ok,"label":label})
	if not ok:printerr("FAIL ",label)
func _initialize():
	AudioServer.set_bus_mute(0,true)
	call_deferred("test")
func record(label:String,seconds:float)->Dictionary:
	capture.clear_buffer()
	await create_timer(seconds).timeout
	var data=capture.get_buffer(capture.get_frames_available())
	var peak=0.0;var energy=0.0;var zeros=0;var longest=0
	for frame in data:
		var level=maxf(absf(frame.x),absf(frame.y))
		peak=maxf(peak,level);energy+=frame.length_squared()*.5
		zeros=zeros+1 if level<.00001 else 0;longest=maxi(longest,zeros)
	var result={"frames":data.size(),"peak":peak,"rms":sqrt(energy/maxi(data.size(),1)),"silent_run_seconds":float(longest)/AudioServer.get_mix_rate()}
	samples[label]=result
	return result
func test():
	ck(AudioServer.get_driver_name()=="CoreAudio","real CoreAudio mixer is active")
	ck(DisplayServer.get_name()=="headless","no desktop window or focus")
	capture.buffer_length=3.0;AudioServer.add_bus_effect(0,capture)
	music=M.new();root.add_child(music)
	var effects=A.new();root.add_child(effects)
	for phase in ["shop","battle"]:
		music.set_context(phase,false)
		await create_timer(.9).timeout
		var row=await record(phase,.5)
		ck(row.frames>1000 and row.peak>.001 and row.peak<1.0,"nonzero unclipped music: "+phase)
		var player=music.players[music.current]
		player.seek(player.stream.get_length()-.18)
		row=await record(phase+"_loop",.55)
		ck(player.get_playback_position()<1.0,"author loop wraps: "+phase)
		ck(row.peak>.001 and row.silent_run_seconds<.06,"no silent gap at the loop seam: "+phase)
	music.set_context("shop",false)
	var row=await record("crossfade",.6)
	ck(row.peak>.001 and row.peak<1.0 and row.silent_run_seconds<.06,"crossfade produces continuous unclipped PCM")
	for key in ["pick","drop","star","attack"]:effects.play_event(key)
	row=await record("music_with_item_and_battle_effects",.4)
	ck(row.peak>.001 and row.peak<1.0,"music and independent effects mix without clipping")
	effects.stop_all();music.set_context("shop",true)
	await create_timer(.2).timeout
	row=await record("muted",.25)
	ck(row.frames>1000 and row.peak==0.0,"music mute yields actual silence at the output mix")
	music.set_context("shop",false)
	row=await record("restored",.3)
	ck(row.peak>.001,"unmute restores actual PCM")
	ck(AudioServer.is_bus_mute(0),"QA kept physical output muted throughout")
	music.queue_free();effects.queue_free();await process_frame
	var failures=checks.filter(func(c):return not c.ok).size()
	var report=FileAccess.open("res://build/qa/audio-v94/checks/pcm.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples,"note":"CoreAudio capture validates engine output, not subjective listening. Master stayed muted; no player Storage was created."},"\t"));report.close()
	AudioServer.remove_bus_effect(0,0)
	print("MUSIC_PCM_V94 ",checks.size()," checks, ",failures," failures")
	quit(1 if failures else 0)
