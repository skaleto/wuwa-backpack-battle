extends RefCounted
## Cosmetic slot shadows. Logical cells, ownership and hit areas stay rectangular.
const OUTLINE=[
	Vector2(.18,.10),Vector2(.46,.075),Vector2(.81,.13),
	Vector2(.925,.25),Vector2(.89,.47),Vector2(.92,.78),
	Vector2(.79,.90),Vector2(.53,.925),Vector2(.18,.88),
	Vector2(.075,.74),Vector2(.115,.47),Vector2(.08,.24)
]

static func polygon(rect:Rect2,variant:int=0)->PackedVector2Array:
	var points=PackedVector2Array()
	for value in OUTLINE:
		var p=value
		match posmod(variant,4):
			1:p=Vector2(1-p.y,p.x)
			2:p=Vector2.ONE-p
			3:p=Vector2(p.y,1-p.x)
		points.append(p)
	# A smooth irregular impression, rather than a bevelled square tile.
	for step in 2:
		var smooth=PackedVector2Array()
		for n in points.size():
			var a=points[n];var b=points[(n+1)%points.size()]
			smooth.append(a.lerp(b,.22));smooth.append(a.lerp(b,.78))
		points=smooth
	for n in points.size():points[n]=rect.position+points[n]*rect.size
	return points

static var meshes={}
static func slot_mesh(variant:int,feathered:bool)->ArrayMesh:
	var key=posmod(variant,4)+ (4 if feathered else 0)
	if meshes.has(key):return meshes[key]
	var vertices=PackedVector3Array();var colors=PackedColorArray();var indices=PackedInt32Array()
	for step in (4 if feathered else 1):
		var points=polygon(Rect2(0,0,1,1).grow(-float(step)*.006),variant)
		var base=vertices.size()
		for point in points:
			vertices.append(Vector3(point.x,point.y,0));colors.append(Color(1,1,1,.25 if feathered else 1))
		for index in Geometry2D.triangulate_polygon(points):indices.append(base+index)
	var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);meshes[key]=mesh;return mesh

static func draw(c:CanvasItem,rect:Rect2,base:Color,variant:int,alpha:float=1.0,unused:bool=false,tint:Color=Color.TRANSPARENT)->void:
	var feathered=not unused and tint.a>0
	var tone=Color(tint,tint.a*alpha) if feathered else Color(base.darkened(.30) if unused else Color("362643"),(.065 if unused else .28)*alpha)
	c.draw_mesh(slot_mesh(variant,feathered),null,Transform2D(0,rect.size,0,rect.position),tone)
