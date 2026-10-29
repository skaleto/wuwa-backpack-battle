extends SceneTree
const D=preload("res://scripts/ui/portraits/portrait_rig_definition.gd")
var failures=0
var checks=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("review")
func review() -> void:
	for id in D.IDS:
		var rig=load("res://assets/characters/rigs/"+id+"/rig.tscn").instantiate();root.add_child(rig)
		check(rig.character_id==id and rig.skeleton.get_bone_count()==D.bones_for(id).size(),id+" editable native skeleton")
		check(rig.mesh.texture.resource_path==D.source(id),id+" uses its original unmodified portrait")
		var vertices=rig.mesh.polygon;var weights=[];var bones=[]
		for n in range(rig.mesh.get_bone_count()):
			weights.append(rig.mesh.get_bone_weights(n));bones.append(rig.skeleton.get_node(rig.mesh.get_bone_path(n)))
		for n in range(vertices.size()):
			var total=0.0;var count=0
			for w in weights:
				total+=w[n]
				if w[n]>0:count+=1
			check(absf(total-1)<.00001 and count<=4 and vertices[n]==rig.mesh.uv[n],id+" normalized weights and original UV")
		var face=Rect2(620,200,70,40) if id=="jiyan" else Rect2(D.PROFILES[id].face).grow(-20)
		var worst=1.0;var excursion=0.0;var worst_clip="";var worst_at=0.0;var worst_point=Vector2.ZERO
		for strength in [.8,1.35]:
			rig.idle_strength=strength
			for clip in D.LENGTHS:
				rig.clear()
				if clip!="idle":rig.trigger(clip,0)
				for step in range(13):
					var at=float(D.LENGTHS[clip])*step/12;rig.sample(at)
					check(absf(rig.deform_point(face.position).distance_to(rig.deform_point(face.end))-face.size.length())<.003,id+" rigid facial proportions "+clip)
					var transforms=[];var deformed=PackedVector2Array()
					for bone in bones:transforms.append(rig.skeleton.global_transform.affine_inverse()*bone.global_transform*bone.get_skeleton_rest().affine_inverse())
					for n in range(vertices.size()):
						var point=Vector2.ZERO
						for b in range(weights.size()):
							if weights[b][n]>0:point+=(transforms[b]*vertices[n])*weights[b][n]
						deformed.append(point);excursion=maxf(excursion,point.distance_to(vertices[n]))
					for tri in rig.mesh.polygons:
						var original=(vertices[tri[1]]-vertices[tri[0]]).cross(vertices[tri[2]]-vertices[tri[0]])
						var area=(deformed[tri[1]]-deformed[tri[0]]).cross(deformed[tri[2]]-deformed[tri[0]])
						if area/original<worst:worst=area/original;worst_clip=clip;worst_at=at;worst_point=vertices[tri[0]]
		check(worst>.2,id+" no folded or collapsed triangles")
		# Hit may translate the complete silhouette, but cannot alter its local shape.
		rig.clear();rig.sample(.14)
		var probes=[face.get_center(),Vector2(D.size_for(id).x*.5,500),Vector2(D.size_for(id).x*.4,950),Vector2(D.size_for(id).x*.6,1250)]
		var idle=probes.map(func(p):return rig.deform_point(p))
		rig.trigger("hit",0);rig.sample(.14)
		var offset=rig.deform_point(probes[0])-idle[0]
		for n in range(probes.size()):check((rig.deform_point(probes[n])-idle[n]).distance_to(offset)<.003,id+" hit only adds a rigid root translation")
		if id!="jiyan":
			var prop=Rect2(D.PROFILES[id].prop).grow(-20)
			check(absf(rig.deform_point(prop.position).distance_to(rig.deform_point(prop.end))-prop.size.length())<.003,id+" held prop remains rigid")
		print(id,": minimum triangle ratio ",worst," at ",worst_clip,"/",worst_at," ",worst_point,"; maximum displacement ",excursion)
		rig.queue_free();await process_frame
	print("NATIVE RIGS V24: ",checks," checks; ",failures," failures")
	quit(1 if failures else 0)
