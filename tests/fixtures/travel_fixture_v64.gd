extends "res://scripts/game.gd"
## Display QA only: separate Storage, no changes to the player's run/preferences.
func _ready()->void:
	storage=S.new("user://qa-travel-v64/"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	muted=true
	super._ready()
	reset_slice()

func piece(kind:String,uid:String,x:int,y:int)->Dictionary:
	var p=inventory.make_piece(kind,uid);p.x=x;p.y=y;return p

func reset_slice()->void:
	run=inventory.new_run("aemeath",19)
	selected_leader="aemeath"
	opponent=storage.opponent(run);screen="game"
	age=8;selection_age=2;phase_age=2;reroll_age=2;capacity_pan_left=0
	battle_entry_age=1.0;transition_image=null;motion.transition_left=0;toast_timer=0
	hovered={};dragging={};overlay="";forge_base="";forge_output={};forge_cache_key=""
	queue_redraw()

func joined_slice()->void:
	reset_slice()
	run.round=2;run.gold=9
	run.bags=[piece("satchel","b1",0,0),piece("pouch","b2",3,0),piece("strip","b3",5,0),piece("corner","b4",0,2),piece("travel","b5",2,2)]
	var blade=piece("w_sword","cross2",0,1);blade.rotation=1
	run.items=[piece("w_rectifier","cross1",2,0),blade]
	run.stash=[piece("turtle","stored1",0,0),piece("daily_tea","stored2",0,0)]
	run.primary="cross1"
	queue_redraw()
