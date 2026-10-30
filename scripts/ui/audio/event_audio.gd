extends Node
## Independent UI/placement/combat voices; bounded polyphony never replaces
## an unrelated event already playing. Clock limits are wall time, so 2× replay
## cannot double the maximum rate or cause a burst after pause.
const KEYS=["click","pick","bag_pick","turn","drop","bag_drop","purchase","sell","start","attack","heal","fusion","fusion_land","reject","star","win","lose"]
const COMBAT=["heal","star"]
const INTERVAL={"attack":90,"heal":160,"click":40,"pick":45,"turn":65,"drop":60,"purchase":80,"sell":80,"fusion":120,"fusion_land":120,"start":200,"reject":120,"star":260,"win":900,"lose":900}
const WEAPONS=["sword","broadblade","pistol","gauntlet","rectifier","echo"]
const VOICES={"ui":2,"placement":2,"bag":2,"combat":4,"weapon":6,"fusion":2}
var streams:Dictionary={}
var weapon_streams:Dictionary={}
var pools:Dictionary={}
var requested:Dictionary={}
var played:Dictionary={}
var suppressed:Dictionary={}
var last_played:Dictionary={}
var muted=false
var bus_name=""
func _ready()->void:
	bus_name="V53Events"+str(get_instance_id())
	AudioServer.add_bus();var index=AudioServer.bus_count-1
	AudioServer.set_bus_name(index,bus_name)
	var limiter=AudioEffectLimiter.new();limiter.ceiling_db=-1.0;limiter.threshold_db=-2.0
	AudioServer.add_bus_effect(index,limiter)
	for key in KEYS:
		var path="res://assets/audio/sfx/ui/"+key+".wav"
		if key in ["purchase","sell"]:path="res://assets/audio/sfx/coins/"+key+".wav"
		if key in ["bag_pick","bag_drop"]:path="res://assets/audio/sfx/cloth/"+key+".wav"
		if key in ["fusion","fusion_land"]:path="res://assets/audio/sfx/fusion/fusion_land.wav"
		if FileAccess.file_exists(path):streams[key]=AudioStreamWAV.load_from_file(path)
		else:
			var fallback="collect" if key in ["click","drop","purchase","sell","start","heal","fusion","reject"] else key
			streams[key]=load("res://assets/audio/sfx/fallback/"+fallback+".wav")
	for weapon in WEAPONS:
		weapon_streams[weapon]=AudioStreamWAV.load_from_file("res://assets/audio/sfx/weapons/"+weapon+".wav")
	for group in VOICES:
		pools[group]=[]
		for n in VOICES[group]:
			var player=AudioStreamPlayer.new();player.bus=bus_name;add_child(player);pools[group].append(player)
func set_volume(value:float)->void:
	var index=AudioServer.get_bus_index(bus_name)
	if index>=0:AudioServer.set_bus_volume_db(index,linear_to_db(clampf(value,0.0,1.0)) if value>0 else -80.0)
func set_muted(value:bool)->void:
	muted=value
	var index=AudioServer.get_bus_index(bus_name)
	if index>=0:AudioServer.set_bus_mute(index,muted)
	if muted:stop_all()
func stop_all()->void:
	for pool in pools.values():
		for player in pool:player.stop()
func stop_fusion()->void:
	for player in pools.get("fusion",[]):player.stop()
	# A new committed fusion can replace the old sequence immediately.
	for key in ["fusion","fusion_land"]:last_played.erase(key)
func play_event(key:String,weapon:String="")->bool:
	requested[key]=int(requested.get(key,0))+1
	if muted or not streams.has(key):return false
	var family=weapon if weapon_streams.has(weapon) else "sword"
	# Different weapon families may start on the same frame. Repeats of one
	# family still share a wall-clock limit; replay speed never bypasses it.
	var clock_key=key+":"+family if key=="attack" else key
	var now=Time.get_ticks_msec()
	if now-int(last_played.get(clock_key,-10000))<int(INTERVAL.get(key,80)):
		suppressed[key]=int(suppressed.get(key,0))+1;return false
	var group="fusion" if key in ["fusion","fusion_land"] else "weapon" if key=="attack" else "combat" if key in COMBAT else "bag" if key in ["bag_pick","bag_drop"] else "placement" if key in ["pick","turn","drop","reject"] else "ui"
	for player in pools[group]:
		if player.playing:continue
		# Reuse the licensed samples at their original pitch and speed.
		player.stream=weapon_streams[family] if key=="attack" else streams[key]
		player.volume_db=-9.0 if group=="weapon" else -10.0 if group=="combat" else -6.0 if key in ["start","win","lose"] else -7.0
		if key=="win":player.volume_db=-2.0
		if key=="start":player.volume_db=-7.0
		if key=="star":player.volume_db=-13.0
		# Approved bag WAVs already carry their final gentle level. The limiter
		# adds 1 dB below threshold; cancel that, not another UI attenuation.
		if group=="bag":player.volume_db=-1.0
		if key in ["purchase","sell"]:player.volume_db=-9.0
		player.play();last_played[clock_key]=now;played[key]=int(played.get(key,0))+1;return true
	suppressed[key]=int(suppressed.get(key,0))+1
	return false
func diagnostics()->Dictionary:
	var active={}
	for group in pools:active[group]=pools[group].filter(func(player):return player.playing).size()
	return {"requested":requested.duplicate(),"played":played.duplicate(),"suppressed":suppressed.duplicate(),"active":active,"muted":muted,"bus":bus_name,"streams":streams.keys()}
func _exit_tree()->void:
	stop_all()
	for pool in pools.values():
		for player in pool:player.stream=null
	streams.clear()
	weapon_streams.clear()
	var index=AudioServer.get_bus_index(bus_name)
	if index>0:AudioServer.remove_bus(index)
