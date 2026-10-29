extends Node2D
## Native skeletal animation sampled exclusively by the owning presentation clock.
const D=preload("res://scripts/ui/portraits/portrait_rig_definition.gd")
@export var character_id="jiyan"
var idle_strength=1.0
var bones: Dictionary={}
var rest: Dictionary={}
var player: AnimationPlayer
var skeleton: Skeleton2D
var mesh: Polygon2D
var action=""
var action_start=-100.0
var clock=0.0
var revision=0
var applied_offsets: Dictionary={}
var blend_from: Dictionary={}

func _ready() -> void:
	skeleton=$Skeleton2D;mesh=$Artwork;player=$AnimationPlayer
	player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for n in range(skeleton.get_bone_count()):
		var bone=skeleton.get_bone(n)
		bones[str(bone.name)]=bone;rest[str(bone.name)]=bone.rest

func trigger(kind: String,at: float) -> bool:
	if not D.LENGTHS.has(kind) or kind=="idle":return false
	var active=not action.is_empty() and at<action_start+float(D.LENGTHS[action])
	if active and int(D.PRIORITY[kind])<int(D.PRIORITY[action]):return false
	if active and kind==action and at-action_start<.16:return false
	sample(at)
	blend_from=applied_offsets.duplicate(true)
	action=kind;action_start=at;revision+=1
	return true

func clear() -> void:
	action="";action_start=-100;revision+=1;blend_from.clear();applied_offsets.clear()

func sample(at: float) -> void:
	clock=at
	player.play("idle");player.seek(fposmod(at,3.6),true)
	for key in bones:
		var bone: Bone2D=bones[key]
		bone.position=Transform2D(rest[key]).origin+(bone.position-Transform2D(rest[key]).origin)*idle_strength
		bone.rotation*=idle_strength
	var local_time=at-action_start
	if action.is_empty() or local_time<0 or local_time>=float(D.LENGTHS[action]):
		applied_offsets.clear();return
	var base={}
	for key in bones:base[key]=bones[key].transform
	player.play(action);player.seek(local_time,true)
	# Action keys are offsets from rest. Layer them over the continuous idle pose.
	for key in bones:
		var bone: Bone2D=bones[key]
		var additive=bone.position-Transform2D(rest[key]).origin
		var angle=bone.rotation
		var mix=smoothstep(0,.075,local_time)
		var outgoing=blend_from.get(key,{"offset":Vector2.ZERO,"angle":0.0})
		additive=Vector2(outgoing.offset).lerp(additive,mix)
		angle=lerpf(float(outgoing.angle),angle,mix)
		applied_offsets[key]={"offset":additive,"angle":angle}
		bone.transform=base[key]
		bone.position+=additive;bone.rotation+=angle

func rest_pose() -> void:
	player.stop();clear()
	for key in bones:bones[key].apply_rest()

func deform_point(point: Vector2) -> Vector2:
	# Diagnostic counterpart of Polygon2D skinning; runtime uses native GPU skinning.
	var weights=D.weights_at(character_id,point);var result=Vector2.ZERO
	for key in weights:
		var bone: Bone2D=bones[key]
		var posed=skeleton.global_transform.affine_inverse()*bone.global_transform
		result+=(posed*bone.get_skeleton_rest().affine_inverse()*point)*float(weights[key])
	return result
