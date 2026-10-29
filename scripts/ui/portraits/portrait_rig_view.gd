extends SubViewport
## Transparent native rig render, composited at the existing UI drawing position.
const D=preload("res://scripts/ui/portraits/portrait_rig_definition.gd")
const MARGIN=64
var character_id="jiyan"
var rig
var last_clock=-INF
var last_revision=-1
var last_strength=-1.0

func _init() -> void:
	size=Vector2i(D.size_for(character_id))+Vector2i.ONE*MARGIN*2;transparent_bg=true;disable_3d=true
	render_target_update_mode=SubViewport.UPDATE_DISABLED
	gui_disable_input=true

func _ready() -> void:
	configure(character_id)

func configure(id: String) -> void:
	if rig!=null and character_id==id:return
	if rig!=null:remove_child(rig);rig.queue_free()
	character_id=id;size=Vector2i(D.size_for(id))+Vector2i.ONE*MARGIN*2
	rig=load("res://assets/characters/rigs/"+id+"/rig.tscn").instantiate();add_child(rig)
	rig.position=Vector2.ONE*MARGIN
	last_clock=-INF;last_revision=-1;last_strength=-1

func sample(at: float,strength: float=1.0) -> void:
	if at==last_clock and last_revision==rig.revision and strength==last_strength:return
	rig.idle_strength=strength;last_strength=strength
	rig.sample(at);last_clock=at;last_revision=rig.revision
	render_target_update_mode=SubViewport.UPDATE_ONCE

func reset() -> void:
	rig.clear();last_clock=-INF;last_revision=-1
