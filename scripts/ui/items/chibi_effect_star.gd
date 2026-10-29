extends RefCounted
## Visual-only slot feedback. Callers supply the real inventory match state.
## Empty, mismatched and duplicate cells are grey; only one representative is lit.
const CLICK_DURATION=.38
const WAVE_DURATION=.30
const CORE_DURATION=.28
const STAGGER=.015
static var _wave_mesh:ArrayMesh
static var _diffusion_mesh:ArrayMesh
const SKIN=preload("res://scripts/ui/visual_skin.gd")

static func diffusion(canvas:CanvasItem,center:Vector2,radius:float,tint:Color,strength:float)->void:
	if _diffusion_mesh==null:_diffusion_mesh=_radial_mesh(false)
	canvas.draw_mesh(_diffusion_mesh,null,Transform2D(0,Vector2.ONE*radius,0,center),Color(tint,strength))

static func silhouette(center:Vector2,radius:float)->PackedVector2Array:
	var corners:PackedVector2Array=[]
	for n in 10:corners.append(Vector2.from_angle(-PI*.5+n*PI/5)*radius*(1.0 if n%2==0 else .50))
	var points:PackedVector2Array=[]
	for n in corners.size():
		var corner=corners[n]
		var from=corner.lerp(corners[posmod(n-1,10)],.18)
		var to=corner.lerp(corners[(n+1)%10],.18)
		for step in 5:
			var t=step/4.0
			points.append(center+from.lerp(corner,t).lerp(corner.lerp(to,t),t))
	return points

static func click_wave(age:float)->Dictionary:
	if age<0 or age>=WAVE_DURATION:return {"scale":0.0,"alpha":0.0}
	var t=age/WAVE_DURATION
	return {"scale":lerpf(.55,3.2,1-pow(1-t,2)),"alpha":smoothstep(0,.035,age)*pow(1-t,1.6)}

static func wave(canvas:CanvasItem,center:Vector2,radius:float,tint:Color,age:float,alpha:float)->void:
	var motion=click_wave(age)
	if motion.alpha<=0:return
	if _wave_mesh==null:_wave_mesh=_radial_mesh(true)
	canvas.draw_mesh(_wave_mesh,null,Transform2D(0,Vector2.ONE*radius*motion.scale,0,center),Color(tint,alpha*motion.alpha*.8))

static func _radial_mesh(shell:bool)->ArrayMesh:
	var vertices=PackedVector3Array();var colors=PackedColorArray();var indices=PackedInt32Array()
	var edge=silhouette(Vector2.ZERO,1.0)
	var radii=[.55,.82,1.0] if shell else [0.0,1.0]
	for layer in radii.size():
		for p in edge:
			vertices.append(Vector3(p.x*radii[layer],p.y*radii[layer],0))
			colors.append(Color(1,1,1,1 if layer==(1 if shell else 0) else 0))
	for layer in radii.size()-1:
		for n in edge.size():
			var a=layer*edge.size()+n;var b=layer*edge.size()+(n+1)%edge.size();var c=a+edge.size();var d=b+edge.size()
			indices.append_array(PackedInt32Array([a,b,c,b,d,c]))
	var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh

static func core_motion(age:float,index:int=0)->Dictionary:
	var t=age-mini(index,4)*STAGGER
	if age<0 or t>=CORE_DURATION:return {"scale":Vector2.ONE,"offset":Vector2.ZERO,"angle":0.0,"shine":0.0}
	if t<0:return {"scale":Vector2.ONE,"offset":Vector2.ZERO,"angle":0.0,"shine":0.0}
	var settle=smoothstep(0.0,CORE_DURATION,t)
	var spring=sin(t/CORE_DURATION*PI*2.0)*pow(1-settle,1.4)
	return {"scale":Vector2(1.0+spring*.20,1.0-spring*.10),"offset":Vector2(0,-sin(t/CORE_DURATION*PI)*3.5),"angle":spring*.14*(1 if index%2==0 else -1),"shine":sin(t/CORE_DURATION*PI)*.14}

static func draw(canvas:CanvasItem,center:Vector2,radius:float,state:String,_age:float,alpha:float=1.0,click_age:float=-1.0,index:int=0)->void:
	if not SKIN.is_chibi() or radius<=0:return
	var entry=SKIN.ui_entry("effect_stars")
	var texture=SKIN.texture(SKIN.ui_path("effect_stars"))
	if texture==null:return
	var regions=entry.get("regions",[])
	if regions.size()<2:return
	var lit=state=="lit"
	var region=regions[-1 if lit else 0]
	var source=Rect2(region[0],region[1],region[2],region[3])
	var local_age=click_age-mini(index,4)*STAGGER if click_age>=0 else -1.0
	# The wave expands at the slot anchor; the core bounces independently above it.
	wave(canvas,center,radius,Color("ffe765" if lit else "e8e3ff"),local_age,alpha)
	var pose=core_motion(click_age,index)
	var size=source.size*(radius*2.0/maxf(source.size.x,source.size.y))*pose.scale
	var points=PackedVector2Array();var uvs=PackedVector2Array()
	for corner in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:
		points.append(center+pose.offset+(corner*size-size*.5).rotated(pose.angle))
		uvs.append((source.position+corner*source.size)/texture.get_size())
	var light=(1.0 if lit else 1.06)+pose.shine
	canvas.draw_polygon(points,PackedColorArray([Color(light,light,light,alpha)]),uvs,texture)

static func cell(canvas:CanvasItem,rect:Rect2,state:String,alpha:float=1.0)->void:
	if not SKIN.is_chibi():return
	var center=rect.get_center()
	diffusion(canvas,center,rect.size.x*.47,Color("ffe37a" if state=="lit" else "bfb9dc"),alpha*(.12 if state=="lit" else .05))
