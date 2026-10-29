extends "res://scripts/game.gd"
func _ready() -> void:
	storage=S.new("user://qa-demo-v49-native")
	muted=true
	super._ready()
	reset_review()

func piece(kind:String,uid:String,x:int,y:int,turns:int=0) -> Dictionary:
	var value=inventory.make_piece(kind,uid)
	value.x=x;value.y=y;value.rotation=turns
	return value

func reset_review() -> void:
	run=inventory.new_run("jiyan",1729)
	run.round=4;run.gold=18
	run.bags=[piece("satchel","base",1,1),piece("strip","fast",1,0,1),piece("corner","echo",4,0),piece("pouch","guard",4,2),piece("travel","power",1,3)]
	run.items=[piece("discord","cross",1,1),piece("w_sword","fast-w",1,0),piece("whiff","echo-e",4,0),piece("turtle","guard-e",4,2),piece("w_rectifier","power-w",1,3),piece("tea","tea",3,3),piece("aero_coin","relic",5,3)]
	run.primary="cross";run.stash=[]
	opponent=storage.opponent(run)
	run.shop=[{"kind":"w_broadblade","locked":false},{"kind":"whiff","locked":false},{"kind":"aero_coin","locked":false},{"kind":"w_broadblade","locked":false},{"kind":"tea","locked":false},{"kind":"strip","locked":false}]
	screen="game";age=8;phase_age=2;reroll_age=2;capacity_pan_left=0
	transition_image=null;motion.transition_left=0;toast_timer=0
	hovered={};dragging={};overlay="";bag_mode=false;relay_mode=false
	mouse=Vector2(1010,845)
	storage.save(run)
	queue_redraw()
