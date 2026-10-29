extends SceneTree
const A=preload("res://scripts/ui/audio/event_audio.gd")
var checks=[]
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	checks.append({"ok":ok,"label":label})
	if not ok:printerr("FAIL ",label)
func run():
	var audio=A.new();root.add_child(audio);await process_frame
	check(not audio.muted,"normal audio default is unmuted")
	var native=DisplayServer.get_name()!="headless"
	var capture=AudioEffectCapture.new();capture.buffer_length=2
	AudioServer.add_bus_effect(AudioServer.get_bus_index(audio.bus_name),capture)
	var samples={}
	for key in A.KEYS:
		audio.stop_all();capture.clear_buffer()
		check(audio.play_event(key),"event dispatch "+key)
		if native:
			await create_timer(.24).timeout
			var data=capture.get_buffer(capture.get_frames_available());var peak=0.0;var sum=0.0
			for frame in data:peak=maxf(peak,maxf(absf(frame.x),absf(frame.y)));sum+=frame.length_squared()*.5
			samples[key]={"frames":data.size(),"peak":peak,"rms":sqrt(sum/maxi(1,data.size()))}
			check(data.size()>0 and peak>.001,"native PCM nonzero "+key)
			check(peak<1.0,"native PCM unclipped "+key)
		else:await create_timer(.01).timeout
	audio.stop_all();audio.last_played.clear();capture.clear_buffer()
	for key in ["attack","star","heal","click","drop","start"]:audio.play_event(key)
	var active=audio.diagnostics().active
	check(active.weapon==1 and active.combat==2 and active.ui==2 and active.placement==1,"weapon, effects and UI events overlap in separate voices")
	for n in 40:audio.play_event("attack")
	check(audio.diagnostics().active.weapon<=6 and int(audio.suppressed.get("attack",0))>=39,"repeated battle events are bounded and rate-limited")
	if native:
		await create_timer(.35).timeout
		var data=capture.get_buffer(capture.get_frames_available());var peak=0.0
		for frame in data:peak=maxf(peak,maxf(absf(frame.x),absf(frame.y)))
		samples["mixed"]={"frames":data.size(),"peak":peak};check(peak>.001 and peak<1,"mixed polyphony produces nonzero unclipped PCM")
	audio.set_muted(true);var played=audio.played.duplicate()
	check(not audio.play_event("pick") and audio.played==played,"mute suppresses new playback")
	check(audio.diagnostics().active.values().all(func(v):return v==0),"mute stops all active channels immediately")
	audio.set_muted(false);audio.last_played.clear();check(audio.play_event("pick"),"unmute restores event playback")
	var failures=checks.filter(func(v):return not v.ok).size()
	var file=FileAccess.open("res://build/qa/ui-v53/checks/audio-"+("native" if native else "headless")+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"native_capture":native,"samples":samples,"diagnostics":audio.diagnostics(),"note":"PCM capture proves engine output, not human listening."},"\t"));file.close()
	print("V53 AUDIO ",checks.size()," checks ",failures," failures");audio.queue_free();await process_frame;await create_timer(.12).timeout;quit(1 if failures else 0)
