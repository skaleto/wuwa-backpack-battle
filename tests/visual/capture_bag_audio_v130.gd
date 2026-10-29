extends SceneTree
## Real engine mixer, muted physical output; no window, input, or player save.
const A=preload("res://scripts/ui/audio/event_audio.gd")
const OUT="res://build/qa/pockets-v130/"
var checks=0
var failures=0
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:
	AudioServer.set_bus_mute(0,true);call_deferred("capture")
func capture()->void:
	ck(DisplayServer.get_name()=="headless" and AudioServer.get_driver_name()=="CoreAudio","no display, actual CoreAudio mixer")
	var capture=AudioEffectCapture.new();capture.buffer_length=5;AudioServer.add_bus_effect(0,capture)
	var effects=A.new();root.add_child(effects);await create_timer(.12).timeout
	var measures={};var combined=PackedVector2Array()
	for key in ["bag_pick","bag_drop"]:
		capture.clear_buffer();effects.last_played.clear()
		ck(effects.play_event(key),"dispatch "+key)
		await create_timer(.65).timeout
		var frames=capture.get_buffer(capture.get_frames_available());var peak=0.0;var sum=0.0
		for frame in frames:
			peak=maxf(peak,maxf(absf(frame.x),absf(frame.y)));sum+=frame.length_squared()*.5
		measures[key]={"peak":peak,"rms":sqrt(sum/maxi(1,frames.size())),"frames":frames.size()}
		ck(peak>.02 and peak<.99,"nonzero unclipped engine PCM "+key)
		combined.append_array(frames)
	# Rotation/currency voices must not choke the short bag landing cue.
	effects.stop_all();effects.last_played.clear()
	ck(effects.play_event("bag_pick"),"rapid grab accepted")
	ck(effects.play_event("turn"),"rotation accepted")
	ck(effects.play_event("bag_drop"),"rapid rotated drop remains audible")
	ck(effects.play_event("purchase"),"purchase confirmation may coexist")
	var pcm=PackedByteArray();pcm.resize(combined.size()*4)
	for n in combined.size():
		pcm.encode_s16(n*4,roundi(clampf(combined[n].x,-1,1)*32767));pcm.encode_s16(n*4+2,roundi(clampf(combined[n].y,-1,1)*32767))
	var wav=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.mix_rate=int(AudioServer.get_mix_rate());wav.stereo=true;wav.data=pcm
	ck(wav.save_to_wav(OUT+"bag-grab-drop-preview.wav")==OK,"audition saved")
	ck(AudioServer.is_bus_mute(0),"physical output remained muted")
	FileAccess.open(OUT+"audio-pcm.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":measures,"note":"Actual game audio mixer. Pickup, pause, landing. PCM validation is not human listening approval."},"\t"))
	effects.queue_free();await process_frame;await create_timer(.15).timeout
	AudioServer.remove_bus_effect(0,0)
	print("BAG_PCM_V130 ",checks," checks, ",failures," failures");quit(1 if failures else 0)
