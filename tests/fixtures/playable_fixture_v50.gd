extends "res://scripts/game.gd"
func _ready()->void:
	storage=S.new("user://qa-playable-v53/"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	muted=true
	super._ready()
	reset_slice()
func piece(kind:String,uid:String,x:int,y:int)->Dictionary:
	var p=inventory.make_piece(kind,uid);p.x=x;p.y=y;return p
func reset_slice()->void:
	run=inventory.new_run("encore",50);run.round=2;run.gold=9;run.serial=4
	run.bags=[piece("satchel","b1",0,0),piece("satchel","b2",3,0),piece("satchel","b3",0,2)]
	run.items=[piece("w_rectifier","i1",0,0),piece("whiff","i2",2,0),piece("mat_43020031","i3",2,1),piece("turtle","i4",4,0)]
	run.primary="i1";run.stash=[]
	opponent=storage.opponent(run);screen="game";age=8;phase_age=2;reroll_age=2;capacity_pan_left=0
	battle_entry_age=1.0;transition_image=null;motion.transition_left=0;toast_timer=0;hovered={};dragging={};overlay=""
	forge_base="i1";forge_cache_key="";forge_options=FORGE.options(run,forge_base,inventory)
	forge_index=forge_options.map(func(v):return v.target).find("weapon_21050044")
	storage.save(run);queue_redraw()
