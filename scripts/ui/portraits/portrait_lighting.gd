extends RefCounted
## Runtime-only 2D lighting. Source art, alpha and UVs are never rewritten.
## The surface mesh is static: this is lighting, not a skeletal animation rig.
const SHADOW=Color("142737")
var surfaces: Dictionary={}
var spot: GradientTexture2D

func _init() -> void:
	var gradient=Gradient.new()
	gradient.offsets=PackedFloat32Array([0.0,.18,.52,1.0])
	gradient.colors=PackedColorArray([Color.WHITE,Color(1,1,1,.78),Color(1,1,1,.26),Color(1,1,1,0)])
	spot=GradientTexture2D.new();spot.width=128;spot.height=128
	spot.gradient=gradient;spot.fill=GradientTexture2D.FILL_RADIAL
	spot.fill_from=Vector2(.5,.5);spot.fill_to=Vector2(.5,0)

func prepare(key: String,texture: Texture2D,source: Rect2,has_feet: bool=true) -> void:
	if surfaces.has(key) or texture==null or source.size.x<=0 or source.size.y<=0:return
	var foot=Vector2(.5,1)
	if has_feet:
		var image=texture.get_image()
		if image.is_compressed():image.decompress()
		foot=foot_anchor(image,Rect2i(source))
	var entry={"source":source,"foot":foot,"mesh":[]}
	for flipped in [false,true]:entry.mesh.append(_surface(texture.get_size(),source,flipped))
	surfaces[key]=entry

static func foot_anchor(image: Image,source: Rect2i) -> Vector2:
	# Find solid footwear, ignoring faint effect pixels beneath the body.
	if image==null or image.is_empty() or source.size.x<=0 or source.size.y<=0:return Vector2(.5,1)
	source=source.intersection(Rect2i(Vector2i.ZERO,image.get_size()))
	if source.size.x<=0 or source.size.y<=0:return Vector2(.5,1)
	var bottom=source.end.y-1
	var found=false
	for y in range(bottom,source.position.y-1,-1):
		for x in range(source.position.x,source.end.x):
			if image.get_pixel(x,y).a>.72:bottom=y;found=true;break
		if found:break
	if not found:return Vector2(.5,1)
	var total=0.0;var moment=0.0
	var top=maxi(source.position.y,bottom-maxi(2,int(source.size.y*.022)))
	for y in range(top,bottom+1):
		for x in range(source.position.x,source.end.x):
			var alpha=image.get_pixel(x,y).a
			if alpha>.72:
				var weight=alpha*(.25+.75*float(y-top+1)/float(bottom-top+1))
				total+=weight;moment+=(x+.5)*weight
	var center=moment/total if total>0 else source.get_center().x
	return Vector2((center-source.position.x)/float(source.size.x),(bottom+1-source.position.y)/float(source.size.y))

static func _surface(texture_size: Vector2,source: Rect2,flipped: bool) -> ArrayMesh:
	var vertices=PackedVector2Array();var uvs=PackedVector2Array();var colors=PackedColorArray();var indices=PackedInt32Array()
	const X=4
	const Y=8
	for y in range(Y+1):
		for x in range(X+1):
			var p=Vector2(float(x)/X,float(y)/Y)
			vertices.append(p)
			uvs.append((source.position+p*source.size)/texture_size)
			var world_x=1-p.x if flipped else p.x
			# Keep the face close to the original exposure. Cool shadows build
			# gently toward the lower, far side; no face or material is repainted.
			var lower=smoothstep(.32,1.0,p.y)
			var far_side=smoothstep(.2,1.0,world_x)*.022
			var top_light=pow(1-p.y,2)*.028
			colors.append(Color(1.0+top_light-lower*.105-far_side,1.0+top_light*.8-lower*.078-far_side,1.0+top_light*.45-lower*.045-far_side,1))
	for y in range(Y):
		for x in range(X):
			var a=y*(X+1)+x;var b=a+1;var c=a+X+1;var d=c+1
			indices.append_array(PackedInt32Array([a,b,c,b,d,c]))
	var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs
	arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

func local_foot(key: String,target: Rect2) -> Vector2:
	return target.position+Vector2(surfaces[key].foot)*target.size

func contact(canvas: CanvasItem,center: Vector2,figure_size: Vector2,alpha: float) -> void:
	if alpha<=0:return
	var width=clampf(minf(figure_size.x*.45,figure_size.y*.24),38,172)
	var size=Vector2(width,width*.19)
	canvas.draw_texture_rect(spot,Rect2(center-size*.66+Vector2(2,1),size*1.32),false,Color(SHADOW,.19*alpha))
	var near=Vector2(width*.50,width*.071)
	canvas.draw_texture_rect(spot,Rect2(center-near*.5,near),false,Color(SHADOW,.30*alpha))

func silhouette(canvas: CanvasItem,texture: Texture2D,source: Rect2,target: Rect2,alpha: float,flipped: bool=false) -> void:
	if alpha<=0:return
	var radius=clampf(target.size.y*.017,3,13)
	var direction=-1.0 if flipped else 1.0
	var shift=Vector2(radius*.36*direction,radius*.55)
	canvas.draw_texture_rect_region(texture,Rect2(target.position+shift,target.size),source,Color(SHADOW,.03*alpha))
	# Two low-opacity rings make a feathered ambient shadow without a hard outline.
	for ring in range(2):
		for n in range(8):
			var angle=n*TAU/8+ring*PI/8
			var offset=Vector2.from_angle(angle)*radius*(.4 if ring==0 else 1.0)
			var opacity=.011 if ring==0 else .0055
			canvas.draw_texture_rect_region(texture,Rect2(target.position+shift+offset,target.size),source,Color(SHADOW,opacity*alpha))

func surface(canvas: CanvasItem,key: String,texture: Texture2D,target: Rect2,tint: Color,flipped: bool=false) -> void:
	if not surfaces.has(key):return
	canvas.draw_mesh(surfaces[key].mesh[1 if flipped else 0],texture,Transform2D(0,target.size,0,target.position),tint)
