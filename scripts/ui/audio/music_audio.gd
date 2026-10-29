extends Node
## Presentation only: phase/mute values in, two bounded music voices out.
## Both sources are the author's complete loop files, without pitch or time edits.
const TRACKS={
	"prepare":{"path":"res://assets/audio/music/positive_happy.ogg","gain_db":-17.34},
	"battle":{"path":"res://assets/audio/music/battle_fun.ogg","gain_db":-21.46},
}
const FADE_SECONDS=.65
var players:Dictionary={}
var levels={"prepare":0.0,"battle":0.0}
var current=""
var muted=false
var quiet=false
var duck=1.0
var bus_name=""

func _ready()->void:
	bus_name="Music"+str(get_instance_id())
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count-1,bus_name)
	for key in TRACKS:
		var stream=AudioStreamOggVorbis.load_from_file(TRACKS[key].path)
		stream.loop=true
		var player=AudioStreamPlayer.new()
		player.stream=stream;player.bus=bus_name;player.volume_db=-80.0
		add_child(player);players[key]=player

func set_context(phase:String,is_muted:bool,is_paused:bool=false)->void:
	var next="" if phase in ["result","ending"] else "battle" if phase=="battle" else "prepare"
	quiet=is_paused and phase=="battle"
	if muted!=is_muted:
		muted=is_muted
		AudioServer.set_bus_mute(AudioServer.get_bus_index(bus_name),muted)
	if current==next:return
	current=next
	if current.is_empty():
		stop_all()
		for key in levels:levels[key]=0.0
		return
	var player:AudioStreamPlayer=players[current]
	# Pause the silent voice after its fade, then resume the musical phrase later.
	if player.stream_paused:player.stream_paused=false
	elif not player.playing:player.play()

func _process(delta:float)->void:
	duck=move_toward(duck,.5 if quiet else 1.0,delta/.45)
	for key in players:
		levels[key]=move_toward(levels[key],1.0 if key==current else 0.0,delta/FADE_SECONDS)
		var player:AudioStreamPlayer=players[key]
		player.volume_db=float(TRACKS[key].gain_db)+linear_to_db(maxf(.0001,float(levels[key])*duck))
		if levels[key]==0.0 and player.playing:player.stream_paused=true

func diagnostics()->Dictionary:
	var active=[]
	for key in players:
		if players[key].playing and not players[key].stream_paused:active.append(key)
	return {"track":current,"active":active,"muted":muted,"quiet":quiet,"bus":bus_name}

func stop_all()->void:
	for player in players.values():
		player.stop();player.stream_paused=false

func _exit_tree()->void:
	stop_all()
	for player in players.values():player.stream=null
	var index=AudioServer.get_bus_index(bus_name)
	if index>0:AudioServer.remove_bus(index)
