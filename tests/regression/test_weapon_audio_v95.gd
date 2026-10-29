extends SceneTree
const A=preload("res://scripts/ui/audio/event_audio.gd")
var checks=0
var failures=0
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
	AudioServer.set_bus_mute(0,true)
	call_deferred("test")
func test():
	var audio=A.new();root.add_child(audio);await process_frame
	var weapons=["sword","broadblade","pistol","gauntlet","rectifier","echo"]
	for weapon in weapons:ck(audio.play_event("attack",weapon),"simultaneous weapon gets its own voice: "+weapon)
	var active=audio.diagnostics().active
	ck(int(active.get("weapon",0))==6,"six weapon types overlap without suppressing each other")
	var samples=[]
	for player in audio.pools.get("weapon",[]):
		ck(player.pitch_scale==1.0,"original sample pitch is preserved")
		if player.stream!=null and not samples.has(player.stream):samples.append(player.stream)
	ck(samples.size()==6,"weapon types use six distinct source samples")
	ck(audio.play_event("star") and audio.play_event("heal"),"weapon chorus leaves room for star and heal effects")
	ck(audio.play_event("click") and audio.play_event("drop"),"weapon chorus does not steal UI or placement voices")
	for n in 40:audio.play_event("attack","sword")
	ck(int(audio.suppressed.get("attack",0))>=40 and int(audio.diagnostics().active.get("weapon",0))<=6,"same-type burst remains bounded")
	audio.stop_all();audio.last_played.clear()
	ck(not audio.play_event("hit","sword"),"removed generic impact event cannot add a second sound")
	ck(audio.play_event("attack","unknown"),"missing weapon metadata has a safe attack fallback")
	audio.set_muted(true)
	ck(audio.diagnostics().active.values().all(func(v):return v==0),"mute stops every voice including the weapon pool")
	ck(not audio.play_event("attack","pistol"),"mute suppresses new weapon attacks")
	audio.set_muted(false);audio.last_played.clear()
	ck(audio.play_event("lose"),"selected failure cue dispatches")
	var selected=AudioStreamWAV.load_from_file("res://assets/audio/sfx/ui/lose.wav")
	ck(selected.get_length()>1.4 and selected.get_length()<1.7,"failure uses the selected complete short low tone")
	print("WEAPON_AUDIO_V95 ",checks," checks, ",failures," failures")
	audio.queue_free();await process_frame
	# Let the audio mixing thread release stopped playback resources before exit.
	await create_timer(.15).timeout
	quit(1 if failures else 0)
