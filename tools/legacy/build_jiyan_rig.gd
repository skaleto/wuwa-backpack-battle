extends SceneTree
## Generates an editable native Godot scene. It never writes source artwork.
const D=preload("res://scripts/ui/portraits/jiyan_rig_definition.gd")
const R=preload("res://scripts/ui/portraits/portrait_rig.gd")
func _initialize() -> void:call_deferred("build")
func build() -> void:
	var rig=Node2D.new();rig.name="JiyanRig"
	var skeleton=Skeleton2D.new();skeleton.name="Skeleton2D";rig.add_child(skeleton);skeleton.owner=rig
	var bones={};var world={}
	for entry in D.BONES:
		var bone=Bone2D.new();bone.name=entry[0]
		bone.set_autocalculate_length_and_angle(false);bone.set_length(45)
		var parent=skeleton if str(entry[1]).is_empty() else bones[entry[1]]
		parent.add_child(bone);bone.owner=rig
		bone.position=Vector2(entry[2])-Vector2(world.get(entry[1],Vector2.ZERO))
		bone.rest=bone.transform;bones[entry[0]]=bone;world[entry[0]]=entry[2]
	var mesh=Polygon2D.new();mesh.name="Artwork";mesh.texture=load(D.SOURCE)
	mesh.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;rig.add_child(mesh);mesh.owner=rig
	mesh.skeleton=NodePath("../Skeleton2D")
	var vertices=PackedVector2Array();var triangles=[];var all_weights={}
	for entry in D.BONES:all_weights[entry[0]]=PackedFloat32Array()
	var cols=ceili(D.SIZE.x/D.STEP);var rows=ceili(D.SIZE.y/D.STEP)
	for y in range(rows+1):
		for x in range(cols+1):
			var point=Vector2(minf(x*D.STEP,D.SIZE.x),minf(y*D.STEP,D.SIZE.y))
			vertices.append(point)
			var weights=D.weights_at(point)
			for key in all_weights:all_weights[key].append(float(weights.get(key,0)))
	for y in range(rows):
		for x in range(cols):
			var a=y*(cols+1)+x;var b=a+1;var c=a+cols+1;var d=c+1
			triangles.append(PackedInt32Array([a,b,c]));triangles.append(PackedInt32Array([b,d,c]))
	mesh.polygon=vertices;mesh.uv=vertices;mesh.polygons=triangles
	for entry in D.BONES:mesh.add_bone(skeleton.get_path_to(bones[entry[0]]),all_weights[entry[0]])
	var player=AnimationPlayer.new();player.name="AnimationPlayer";rig.add_child(player);player.owner=rig
	player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var library=AnimationLibrary.new()
	for clip in D.LENGTHS:
		var anim=Animation.new();anim.length=float(D.LENGTHS[clip])
		anim.loop_mode=Animation.LOOP_LINEAR if clip=="idle" else Animation.LOOP_NONE
		var tracks={}
		for key in bones:
			var path=str(rig.get_path_to(bones[key]));var pos_track=anim.add_track(Animation.TYPE_VALUE);var rot_track=anim.add_track(Animation.TYPE_VALUE)
			anim.track_set_path(pos_track,NodePath(path+":position"));anim.track_set_path(rot_track,NodePath(path+":rotation"))
			tracks[key]=[pos_track,rot_track]
		var frames=ceili(anim.length*60)
		for frame in range(frames+1):
			var time=anim.length*float(frame)/frames;var pose=D.pose(clip,time)
			for key in bones:
				anim.track_insert_key(tracks[key][0],time,bones[key].position+Vector2(pose[key].offset))
				anim.track_insert_key(tracks[key][1],time,deg_to_rad(float(pose[key].angle)))
		library.add_animation(clip,anim)
	player.add_animation_library("",library)
	rig.set_script(R)
	var packed=PackedScene.new();var code=packed.pack(rig)
	if code==OK:code=ResourceSaver.save(packed,"res://assets/characters/rigs/jiyan/rig.tscn")
	print("JIYAN RIG BUILD: ",D.BONES.size()," bones; ",vertices.size()," vertices; ",triangles.size()," triangles; ",D.LENGTHS.size()," clips; status ",code)
	rig.free();quit(0 if code==OK else 1)
