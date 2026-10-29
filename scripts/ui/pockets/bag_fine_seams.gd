extends RefCounted
## Read-only cloth projection for option 01. Runtime draws each bag independently,
## exactly as in the approved standalone preview: full hem, corner and shadow.
const GRID=preload("res://scripts/ui/pockets/frequency_grid.gd")
const CONTACTS=preload("res://scripts/ui/pockets/bag_contacts.gd")
const SKIN=preload("res://scripts/ui/visual_skin.gd")
const TEXTURE="res://assets/ui/cloth/cloth-pocket.png"
const HEM_TEXTURE="res://assets/ui/seams/seam-reference.png"
const HEM_SOURCE_SIZE=Vector2(1536,1024)
# Untouched approved artwork, sampled at runtime. The reference's purple cloth
# normalizes to the same palette as the neutral body without repainting pixels.
const HEM_BASE=Color("b28be7")
const PALETTE={"satchel":Color("b78aeb"),"pouch":Color("f1c466"),"strip":Color("87cdb8"),"corner":Color("99bce6"),"travel":Color("dfa2c9")}
const SOURCE=Rect2(220,220,810,810)
const SOURCE_SIZE=1254.0
const RADIUS=.16
const NOTCH_RADIUS=.10
const CONTACT_SCALE=.62
const ARC_SIDES=[[3,0],[0,1],[1,2],[2,3]]
const CORNER_POINTS=[Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]
const CORNER_INWARD=[Vector2(1,1),Vector2(-1,1),Vector2(-1,-1),Vector2(1,-1)]
const ARC_STARTS=[PI,PI*1.5,0.0,PI*.5]
const LIMIT=32
const CLOTH_GAIN=Color(1.0/.837,1.0/.839,1.0/.855)
static var cache={}

static func _tone(kind:String)->Color:
	return PALETTE.get(kind,PALETTE.satchel)

static func _hem_source(kind:String)->Dictionary:
	# Each approved material supplies its own coloured thread and highlights;
	# tinting the purple highlight into gold would clip it into neon yellow.
	if kind=="pouch":return {"strip":Rect2(1170,297,95,15),"center":Vector2(1162,312),"radius":15.0,"contact":[Vector2(1149,350),Vector2(1162,350)],"gain":Color.WHITE}
	if kind=="strip":return {"strip":Rect2(865,563,75,16),"center":Vector2(860,579),"radius":16.0,"contact":[Vector2(844,620),Vector2(858,620)],"gain":Color.WHITE}
	var tone=_tone(kind)
	return {"strip":Rect2(870,199,95,14),"center":Vector2(863,213),"radius":14.0,"contact":[Vector2(1148,250),Vector2(1135,250)],"gain":Color(tone.r/HEM_BASE.r,tone.g/HEM_BASE.g,tone.b/HEM_BASE.b)}

static func cloth_uv(point:Vector2,pitch:float)->Vector2:
	# All nine bag kinds sample one unmodified authored cloth surface. A common
	# phase avoids a lighting jump at same-colour seams, in every rotation.
	var unit=point/(pitch*4.0)
	unit=Vector2(absf(fposmod(unit.x,2.0)-1.0),absf(fposmod(unit.y,2.0)-1.0))
	return (SOURCE.position+unit*SOURCE.size)/SOURCE_SIZE

static func layout(bags:Array,pitch:float)->Dictionary:
	var owner={};var kinds={};var cells=[]
	for bag in bags:
		kinds[bag.uid]=bag.kind
		for cell in bag.cells:owner[cell]=bag.uid;cells.append(cell)
	var faces=[];var borders=[]
	for bag in bags:
		for face in GRID._surface_geometry(bag.cells,pitch,pitch*RADIUS,10):
			face.uid=bag.uid;face.contacts=[];face.radii=[]
			for side in 4:
				var neighbor=owner.get(face.cell+GRID.DIRECTIONS[side],"")
				face.contacts.append(not neighbor.is_empty() and neighbor!=bag.uid)
			var polygon=PackedVector2Array()
			for corner in 4:
				var sides=ARC_SIDES[corner]
				var count=int(face.contacts[sides[0]])+int(face.contacts[sides[1]])
				var radius=pitch*([RADIUS,.10,.06][count])
				face.radii.append(radius)
				var point=(Vector2(face.cell)+CORNER_POINTS[corner])*pitch
				if not face.corners[corner]:polygon.append(point);continue
				var center=point+CORNER_INWARD[corner]*radius
				for n in 11:polygon.append(center+Vector2.from_angle(ARC_STARTS[corner]+PI*.5*n/10.0)*radius)
			face.polygon=polygon;faces.append(face)
		for edge in GRID._edge_records(bag.cells):
			if edge.count!=1:continue
			edge.uid=bag.uid;edge.contact=owner.has(edge.cell+GRID.DIRECTIONS[edge.side])
			borders.append(edge)
	var rims=[]
	for edge in GRID._edge_records(cells):
		if edge.count!=1:continue
		edge.uid=owner[edge.cell];rims.append(edge)
	var vertices={};var notches={}
	for cell in cells:
		for offset in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.ONE]:vertices[cell+offset]=true
	var quadrants=[Vector2i(-1,-1),Vector2i(0,-1),Vector2i.ZERO,Vector2i(-1,0)]
	for vertex in vertices:
		var neighbors=[];var empty=-1
		for n in 4:
			var uid=owner.get(vertex+quadrants[n],"")
			if uid.is_empty():empty=n
			else:neighbors.append(uid)
		# A tiny fabric fillet belongs only to an actual single-bag notch.
		# Never blend ownership or bridge differently coloured bags at a T-joint.
		if neighbors.size()==3 and neighbors.all(func(uid):return uid==neighbors[0]):
			notches[vertex]={"uid":neighbors[0],"direction":Vector2(quadrants[empty])*2+Vector2.ONE,"start":PI*.5*empty}
	return {"faces":faces,"rims":rims,"borders":borders,"seams":CONTACTS.segments(bags),"kinds":kinds,"notches":notches}

static func _polygon(data:Dictionary,points:PackedVector2Array,tone:Color,pitch:float,source:PackedVector2Array=PackedVector2Array())->void:
	var base=data.vertices.size()
	for n in points.size():
		var p=points[n]
		data.vertices.append(Vector3(p.x,p.y,0));data.uv.append(cloth_uv(p,pitch) if source.is_empty() else source[n]/SOURCE_SIZE)
		data.colors.append(tone)
	for i in Geometry2D.triangulate_polygon(points):data.indices.append(base+i)

static func _authored_quad(data:Dictionary,points:PackedVector2Array,uv:PackedVector2Array)->void:
	var base=data.vertices.size()
	for n in points.size():
		data.vertices.append(Vector3(points[n].x,points[n].y,0));data.uv.append(uv[n]/HEM_SOURCE_SIZE);data.colors.append(Color.WHITE)
	for i in Geometry2D.triangulate_polygon(points):data.indices.append(base+i)

static func _stitch(data:Dictionary,center:Vector2,direction:Vector2,length:float,width:float,pitch:float)->void:
	var normal=Vector2(-direction.y,direction.x)
	var points=PackedVector2Array()
	for side in [1,-1]:
		var end=center+direction*(length-width)*.5*side
		for n in 7:
			var angle=-PI*.5+PI*n/6.0
			points.append(end+(direction*cos(angle)*side+normal*sin(angle)*side)*width*.5)
	var uv=PackedVector2Array()
	for point in points:uv.append(Vector2(197,117))
	_polygon(data,points,Color("fff5e8",.80),pitch,uv)

const HEM_OFFSETS=[0.0,.012,.035,.075,.125]
static func _hem_colors(tone:Color,contact:bool=false)->Array:
	if contact:return [tone.darkened(.30),tone.darkened(.10),tone.lightened(.20),tone.lightened(.08),tone]
	return [tone.darkened(.48),tone.darkened(.22),tone.lightened(.28),tone.lightened(.12),tone]

static func _edge_scale(face:Dictionary,side:int,corner:int,pitch:float)->float:
	var scale_value=CONTACT_SCALE if face.contacts[side] else 1.0
	if face.corners[corner]:scale_value=minf(scale_value,face.radii[corner]/(pitch*HEM_OFFSETS[-1])*.90)
	return scale_value

static func _rim(data:Dictionary,a:Vector2,b:Vector2,inward:Vector2,pitch:float,start_scale:float=1,end_scale:float=1,contact:bool=false)->void:
	var source=data.source;var rect:Rect2=source.strip
	var uv=PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
	if contact:uv=PackedVector2Array([source.contact[0],source.contact[0],source.contact[1],source.contact[1]])
	_authored_quad(data,PackedVector2Array([a,b,b+inward*pitch*.125*end_scale,a+inward*pitch*.125*start_scale]),uv)

static func _arc(data:Dictionary,center:Vector2,radius:float,start:float,tone:Color,pitch:float,concave:bool=false,start_scale:float=1,end_scale:float=1,start_contact:bool=false,end_contact:bool=false)->void:
	if not concave:
		for n in 10:
			var t0=n/10.0;var t1=(n+1)/10.0
			var d0=Vector2.from_angle(start+PI*.5*t0);var d1=Vector2.from_angle(start+PI*.5*t1)
			var s0=lerpf(start_scale,end_scale,t0);var s1=lerpf(start_scale,end_scale,t1)
			var u0=Vector2.from_angle(PI+PI*.5*t0);var u1=Vector2.from_angle(PI+PI*.5*t1)
			var uv_center:Vector2=data.source.center;var uv_radius:float=data.source.radius
			_authored_quad(data,PackedVector2Array([center+d0*radius,center+d1*radius,center+d1*(radius-pitch*.125*s1),center+d0*(radius-pitch*.125*s0)]),PackedVector2Array([uv_center+u0*uv_radius,uv_center+u1*uv_radius,uv_center+u1,uv_center+u0]))
		return
	var first=_hem_colors(tone,start_contact);var last=_hem_colors(tone,end_contact)
	var side=1.0 if concave else -1.0
	for layer in HEM_OFFSETS.size()-1:
		var points=PackedVector2Array()
		for edge in [layer,layer+1]:
			for n in (range(11) if edge==layer else range(10,-1,-1)):
				var t=n/10.0
				points.append(center+Vector2.from_angle(start+PI*.5*t)*(radius+side*pitch*HEM_OFFSETS[edge]*lerpf(start_scale,end_scale,t)))
		var base=data.colors.size();_polygon(data,points,tone,pitch)
		for n in points.size():
			var edge=layer if n<11 else layer+1;var t=n/10.0 if n<11 else (21-n)/10.0
			data.colors[base+n]=first[edge].lerp(last[edge],t)
	if start_contact or end_contact:return
	var stitch_radius=radius+side*pitch*.057
	for step in [0.30,0.70]:
		var angle=start+PI*.5*step
		_stitch(data,center+Vector2.from_angle(angle)*stitch_radius,Vector2.from_angle(angle+PI*.5),pitch*.050,pitch*.014,pitch)

static func meshes(bags:Array,pitch:float)->Array:
	var key=str(pitch)+str(bags)
	if cache.has(key):return cache[key]
	var model=layout(bags,pitch);var data={};var hems={};var by_cell={}
	for uid in model.kinds:
		data[uid]={"vertices":PackedVector3Array(),"uv":PackedVector2Array(),"colors":PackedColorArray(),"indices":PackedInt32Array()}
		hems[uid]={"vertices":PackedVector3Array(),"uv":PackedVector2Array(),"colors":PackedColorArray(),"indices":PackedInt32Array(),"source":_hem_source(model.kinds[uid])}
	for face in model.faces:
		by_cell[face.cell]=face
		_polygon(data[face.uid],face.polygon,_tone(model.kinds[face.uid]),pitch)
	# Each owner retains its silhouette. Shared borders use compressed hems;
	# the continuous shade bends into the bag's own rounded end, even at a T-joint.
	var pairs=[[0,1],[1,2],[3,2],[0,3]]
	for edge in model.borders:
		var face=by_cell[edge.cell];var d=hems[edge.uid]
		var tone=_tone(model.kinds[edge.uid])
		var direction=(edge.b-edge.a).normalized()
		var head=pairs[edge.side][0];var tail=pairs[edge.side][1]
		var a=edge.a*pitch+direction*(face.radii[head] if face.corners[head] else pitch*NOTCH_RADIUS if model.notches.has(Vector2i(edge.a)) else 0.0)
		var b=edge.b*pitch-direction*(face.radii[tail] if face.corners[tail] else pitch*NOTCH_RADIUS if model.notches.has(Vector2i(edge.b)) else 0.0)
		_rim(d,a,b,edge.inward,pitch,_edge_scale(face,edge.side,head,pitch),_edge_scale(face,edge.side,tail,pitch),edge.contact)
	for face in model.faces:
		var tone=_tone(model.kinds[face.uid])
		for corner in 4:
			if not face.corners[corner]:continue
			var radius=face.radii[corner];var sides=ARC_SIDES[corner]
			var center=(Vector2(face.cell)+CORNER_POINTS[corner])*pitch+CORNER_INWARD[corner]*radius
			_arc(hems[face.uid],center,radius,ARC_STARTS[corner],tone,pitch,false,_edge_scale(face,sides[0],corner,pitch),_edge_scale(face,sides[1],corner,pitch),face.contacts[sides[0]],face.contacts[sides[1]])
	for vertex in model.notches:
		var notch=model.notches[vertex];var tone=_tone(model.kinds[notch.uid])
		var at=Vector2(vertex)*pitch;var r=pitch*NOTCH_RADIUS;var center=at+notch.direction*r
		var points=PackedVector2Array([at])
		for n in 11:points.append(center+Vector2.from_angle(notch.start+PI*.5*n/10.0)*r)
		_polygon(data[notch.uid],points,tone,pitch)
		_arc(data[notch.uid],center,r,notch.start,tone,pitch,true)
	var result=[]
	for uid in data:
		var entry={"uid":uid,"hem_gain":hems[uid].source.gain}
		for layer in ["mesh","hem"]:
			var d=data[uid] if layer=="mesh" else hems[uid];var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX]=d.vertices;arrays[Mesh.ARRAY_TEX_UV]=d.uv;arrays[Mesh.ARRAY_COLOR]=d.colors;arrays[Mesh.ARRAY_INDEX]=d.indices
			var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);entry[layer]=mesh
		result.append(entry)
	if cache.size()>=LIMIT:cache.erase(cache.keys()[0])
	cache[key]=result;return result

static func draw(c:CanvasItem,origin:Vector2,bags:Array,pitch:float,alpha:float,focus:String="",pulses:Dictionary={})->void:
	var texture=SKIN.texture(TEXTURE)
	var hem_texture=SKIN.texture(HEM_TEXTURE)
	if texture==null or hem_texture==null:return
	# No neighbor data enters a bag's rendering. Placing another bag beside it
	# must not resize its corners, compress its hem or replace its stitching.
	for bag in bags:
		for entry in meshes([bag],pitch):
			c.draw_mesh(entry.mesh,texture,Transform2D(0,origin+Vector2(0,pitch*.04)),Color(.20,.12,.34,.38*alpha))
			var tint=Color(1.04,1.04,1.04) if entry.uid==focus else Color.WHITE
			tint=tint.lerp(Color(1.08,1.05,.94),clampf(float(pulses.get(entry.uid,0)),0,1));tint.a=alpha
			# Apply material normalization after clamped mesh vertex colours.
			c.draw_mesh(entry.mesh,texture,Transform2D(0,origin),tint*CLOTH_GAIN)
			c.draw_mesh(entry.hem,hem_texture,Transform2D(0,origin),tint*entry.hem_gain)
