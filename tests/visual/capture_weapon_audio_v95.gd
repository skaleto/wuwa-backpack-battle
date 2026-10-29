extends SceneTree
## Actual mixer preview. No window, desktop input, speaker output or player save.
const A=preload("res://scripts/ui/audio/event_audio.gd")
const M=preload("res://scripts/ui/audio/music_audio.gd")
var out_path="user://qa-weapon-mix.wav"
var report_path="res://build/qa/audio-v95/checks/pcm.json"
var checks=[]
func ck(ok:bool,label:String)->void:
	checks.append({"ok":ok,"label":label})
	if not ok:printerr("FAIL ",label)
func _initialize():
	# Optional paths preserve earlier auditions when comparing revised samples.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):out_path=arg.trim_prefix("--output=")
		elif arg.begins_with("--report="):report_path=arg.trim_prefix("--report=")
	AudioServer.set_bus_mute(0,true);call_deferred("capture_preview")
func capture_preview():
	ck(DisplayServer.get_name()=="headless" and AudioServer.get_driver_name()=="CoreAudio","headless display and real CoreAudio mixer")
	var capture=AudioEffectCapture.new();capture.buffer_length=12;AudioServer.add_bus_effect(0,capture)
	var music=M.new();root.add_child(music);music.set_context("battle",false)
	var effects=A.new();root.add_child(effects)
	var schedule=[
		[.6,"sword"],[1.0,"broadblade"],[1.4,"pistol"],[1.8,"gauntlet"],[2.2,"rectifier"],[2.6,"echo"],
		[3.4,"sword"],[3.4,"pistol"],[3.4,"rectifier"],[3.5,"gauntlet"],[3.6,"echo"],[3.7,"broadblade"],
		[4.2,"pistol"],[4.4,"sword"],[4.6,"rectifier"],[4.8,"gauntlet"],[5.0,"echo"],[5.2,"broadblade"],
		[5.8,"sword"],[5.8,"broadblade"],[5.8,"pistol"],[5.8,"gauntlet"],[5.8,"rectifier"],[5.8,"echo"],
		[6.7,"pistol"],[6.9,"rectifier"],[7.1,"sword"],[7.3,"gauntlet"],
	]
	var cursor=0;var accepted=0;var max_voices=0;var started=Time.get_ticks_msec()
	while float(Time.get_ticks_msec()-started)/1000.0<8.5:
		var t=float(Time.get_ticks_msec()-started)/1000.0
		while cursor<schedule.size() and t>=float(schedule[cursor][0]):
			if effects.play_event("attack",schedule[cursor][1]):accepted+=1
			cursor+=1
		max_voices=maxi(max_voices,int(effects.diagnostics().active.weapon))
		await create_timer(.02).timeout
	var frames=capture.get_buffer(capture.get_frames_available())
	var peak=0.0;var pcm=PackedByteArray();pcm.resize(frames.size()*4)
	for i in frames.size():
		peak=maxf(peak,maxf(absf(frames[i].x),absf(frames[i].y)))
		pcm.encode_s16(i*4,roundi(clampf(frames[i].x,-1,1)*32767))
		pcm.encode_s16(i*4+2,roundi(clampf(frames[i].y,-1,1)*32767))
	var wav=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.mix_rate=int(AudioServer.get_mix_rate());wav.stereo=true;wav.data=pcm
	ck(wav.save_to_wav(out_path)==OK,"audition WAV saved")
	ck(frames.size()>AudioServer.get_mix_rate()*8 and peak>.01 and peak<.99,"music and six weapon families yield nonzero unclipped PCM")
	ck(max_voices==6 and accepted==schedule.size(),"scheduled weapon chorus overlaps all six families without dropped cues")
	ck(not effects.requested.has("hit"),"mix contains no separate arrival or hurt sound")
	ck(AudioServer.is_bus_mute(0),"physical output stayed silent")
	var report=FileAccess.open(report_path,FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"peak":peak,"frames":frames.size(),"max_weapon_voices":max_voices,"accepted_attacks":accepted,"scheduled_attacks":schedule.size(),"note":"Synthetic event schedule through the actual game audio modules, not a live match recording. Original stock sounds only; physical Master muted."},"\t"));report.close()
	music.queue_free();effects.queue_free();await process_frame;await create_timer(.15).timeout
	AudioServer.remove_bus_effect(0,0)
	var failures=checks.filter(func(c):return not c.ok).size()
	print("WEAPON_PCM_V95 ",checks.size()," checks, ",failures," failures")
	quit(1 if failures else 0)
