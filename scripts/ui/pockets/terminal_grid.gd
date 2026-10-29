extends RefCounted
## Quiet ownership boundaries; fills remain continuous and always visible.
const SKIN=preload("res://scripts/ui/visual_skin.gd")
const GRID=preload("res://scripts/ui/pockets/frequency_grid.gd")
const UI=preload("res://scripts/ui/ui_theme.gd")
const MATERIAL=preload("res://scripts/ui/pockets/bag_material.gd")
const FORM=preload("res://scripts/ui/pockets/bag_form.gd")
const SLOTS=preload("res://scripts/ui/pockets/bag_slots.gd")
const CONTACTS=preload("res://scripts/ui/pockets/bag_contacts.gd")
const FINE=preload("res://scripts/ui/pockets/bag_fine_seams.gd")
static var inventory=preload("res://scripts/inventory/inventory.gd").new()
const FILLS={"satchel":Color("9bacb8"),"travel":Color("d5b16b"),"corner":Color("54bca2"),"strip":Color("659fd1"),"pouch":Color("aa8bcc")}
const PAPER_WASH={"satchel":Color("ceb991"),"travel":Color("df917d"),"corner":Color("86b391"),"strip":Color("7daeba"),"pouch":Color("d7b253")}
static var lining_meshes={}

static func _lining_mesh(size:Vector2,pitch:float)->ArrayMesh:
	var key=str(size)+str(pitch)
	if lining_meshes.has(key):return lining_meshes[key]
	var vertices=PackedVector3Array();var indices=PackedInt32Array()
	var bounds=PackedVector2Array([Vector2.ZERO,Vector2(size.x,0),size,Vector2(0,size.y)])
	var step=pitch*.90
	for row in range(-1,ceili(size.y/step)+1):
		for col in range(-1,ceili(size.x/(step*2))+1):
			var center=Vector2((col*2+posmod(row,2))*step,row*step)
			var diamond=PackedVector2Array([center+Vector2(0,-step),center+Vector2(step,0),center+Vector2(0,step),center+Vector2(-step,0)])
			# Alternate complete diamonds; clipping preserves the panel's fixed bounds.
			if posmod(row,2)==1:continue
			for polygon in Geometry2D.intersect_polygons(diamond,bounds):
				var base=vertices.size()
				for point in polygon:vertices.append(Vector3(point.x,point.y,0))
				for index in Geometry2D.triangulate_polygon(polygon):indices.append(base+index)
	var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	if lining_meshes.size()>=16:lining_meshes.erase(lining_meshes.keys()[0])
	lining_meshes[key]=mesh;return mesh

static func placement_grid(c:CanvasItem,origin:Vector2,dimensions:Vector2i,pitch:float,alpha:float=1.0,column_pitch:float=0,lining:String="board")->void:
	var width=column_pitch if column_pitch>0 else pitch
	var rect=Rect2(origin,Vector2(dimensions)*Vector2(width,pitch))
	var q=SKIN.is_chibi()
	if q:
		var fill=Color("b9cfd6") if lining=="stash" else Color("ded3ef")
		var points=PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
		c.draw_polygon(points,PackedColorArray([Color(fill.lightened(.035),alpha),Color(fill,alpha),Color(fill.darkened(.025),alpha),Color(fill,alpha)]))
		if lining=="board":c.draw_mesh(_lining_mesh(rect.size,pitch),null,Transform2D(0,origin),Color("fff9ee",.26*alpha))
		for y in dimensions.y:
			for x in dimensions.x:
				var slot=Rect2(origin+Vector2(x*width,y*pitch),Vector2(width,pitch))
				SLOTS.draw(c,slot,fill,x+3*y,alpha,true)
		return
	else:c.draw_rect(rect,Color(UI.SHADOW,.11*alpha))
	var ink=SKIN.BLUEBERRY if q else UI.PAPER
	for x in dimensions.x+1:
		var a=origin+Vector2(x*width,0);var b=origin+Vector2(x*width,rect.size.y)
		if q:_cloth_guide(c,a,b,pitch,Color(ink,.14*alpha))
		else:c.draw_line(a,b,Color(ink,.12*alpha),.65,true)
	for y in dimensions.y+1:
		var a=origin+Vector2(0,y*pitch);var b=origin+Vector2(rect.size.x,y*pitch)
		if q:_cloth_guide(c,a,b,pitch,Color(ink,.14*alpha))
		else:c.draw_line(a,b,Color(ink,.12*alpha),.65,true)

static func surface(c:CanvasItem,origin:Vector2,bags:Array,pitch:float,focus:String="",alpha:float=1.0,pulses:Dictionary={}) -> void:
	if SKIN.is_chibi():
		chibi_surface(c,origin,bags,pitch,focus,alpha,pulses);return
	var owner={};var kinds={};var cells=[];var u=pitch/56.0
	for bag in bags:
		for cell in inventory.occupied(bag):
			if owner.has(cell):continue
			owner[cell]=bag.uid;kinds[cell]=bag.kind;cells.append(cell)
	# Every fill reaches its logical cell edge; joining never opens a seam.
	for cell in cells:
		var rect=Rect2(origin+Vector2(cell)*pitch,Vector2.ONE*pitch)
		c.draw_rect(rect,Color("213846",.48*alpha))
		c.draw_rect(rect,Color(FILLS[kinds[cell]],(.43 if kinds[cell]!="satchel" else .31)*alpha))
		if owner[cell]==focus:c.draw_rect(rect,Color(UI.PAPER,.085*alpha))
		var pulse=clampf(float(pulses.get(owner[cell],0.0)),0.0,1.0)
		if pulse>0:c.draw_rect(rect,Color(FILLS[kinds[cell]],pulse*.16*alpha))
	var vertices={}
	for edge in GRID._edge_records(cells):
		var a=origin+edge.a*pitch;var b=origin+edge.b*pitch
		if edge.count==1:
			GRID._band(c,a,b,edge.inward,.65*u,Color(UI.PAPER,.23*alpha))
		else:
			var neighbor=edge.cell+GRID.DIRECTIONS[edge.side]
			var separates=owner[edge.cell]!=owner[neighbor]
			# A shared boundary is one line, even for two bags of the same type.
			if separates:c.draw_line(a,b,Color(UI.PAPER,.24*alpha),.65*u,true)
			else:c.draw_line(a,b,Color(UI.PAPER,.065*alpha),.55*u,true)
		vertices[edge.a]=true;vertices[edge.b]=true
	for point in vertices:
		# Boundary intersections need no extra cross: it protrudes beyond the region.
		var adjacent=[Vector2i(point),Vector2i(point)+Vector2i.LEFT,Vector2i(point)+Vector2i.UP,Vector2i(point)-Vector2i.ONE]
		if not adjacent.all(func(cell):return owner.has(cell)):continue
		var first_owner=owner[adjacent[0]]
		if not adjacent.all(func(cell):return owner[cell]==first_owner):continue
		var at=origin+point*pitch
		c.draw_line(at-Vector2(1.3,0)*u,at+Vector2(1.3,0)*u,Color(UI.PAPER,.15*alpha),.6*u,true)
		c.draw_line(at-Vector2(0,1.3)*u,at+Vector2(0,1.3)*u,Color(UI.PAPER,.15*alpha),.6*u,true)
	# Keep 05's short exposed corner accents, without decorating every module.
	var owned={}
	for cell in cells:owned[cell]=true
	var corners=[Vector2.ZERO,Vector2(pitch,0),Vector2.ONE*pitch,Vector2(0,pitch)]
	var dirs=[[Vector2.RIGHT,Vector2.DOWN],[Vector2.LEFT,Vector2.DOWN],[Vector2.LEFT,Vector2.UP],[Vector2.RIGHT,Vector2.UP]]
	for cell in cells:
		var flags=GRID._corner_flags(cell,owned)
		for k in 4:
			if not flags[k]:continue
			var p=origin+Vector2(cell)*pitch+corners[k]
			# Inset both arms so even the short accents stay inside the total footprint.
			p+=(dirs[k][0]+dirs[k][1])*.4*u
			for direction in dirs[k]:c.draw_line(p,p+direction*4.5*u,Color(UI.PAPER,.50*alpha),.7*u,true)
	if not focus.is_empty():
		var selection=cells.filter(func(v):return owner[v]==focus)
		for e in GRID._edge_records(selection):
			if e.count==1:GRID._band(c,origin+e.a*pitch,origin+e.b*pitch,e.inward,.95*u,Color(UI.PAPER,.66*alpha))

static func thumbnail(c:CanvasItem,rect:Rect2,kind:String,turns:int,alpha:float) -> void:
	var bag={"kind":kind,"rotation":turns,"x":0,"y":0,"uid":"icon"}
	var hi=Vector2.ONE
	for cell in inventory.cells(bag):hi=hi.max(Vector2(cell)+Vector2.ONE)
	var pitch=minf(rect.size.x/hi.x,rect.size.y/hi.y)
	surface(c,rect.get_center()-hi*pitch*.5,[bag],pitch,"",alpha)

const DANGO_FILLS={"satchel":Color("c3b6d5"),"pouch":Color("e5d3a4"),"strip":Color("b1cfbd"),"corner":Color("aec5d9"),"travel":Color("dcb6c1")}

static func _soft_star(c:CanvasItem,center:Vector2,radius:float,color:Color)->void:
	# Four-point material print, deliberately distinct from five-point effect stars.
	var points=PackedVector2Array()
	for n in 8:
		points.append(center+Vector2.from_angle(n*PI*.25-PI*.5)*radius*(1.0 if n%2==0 else .24))
	c.draw_colored_polygon(points,color)

static func _fabric_source(name:String="paper_cell")->Dictionary:
	var path=SKIN.ui_path(name);var texture=SKIN.texture(path)
	var source=SKIN.bounds(path) if texture else Rect2()
	var authored=SKIN.ui_entry(name).get("source_rect",[])
	if authored is Array and authored.size()==4:source=Rect2(authored[0],authored[1],authored[2],authored[3])
	return {"texture":texture,"source":source}

static func _fabric_uv(point:Vector2,pitch:float,source:Rect2,texture_size:Vector2)->Vector2:
	# One square of fabric spans the fixed board width. Both axes retain their
	# texture phase across cells and bags, without changing caller repeat state.
	return (source.position+point/(pitch*inventory.WIDTH)*source.size)/texture_size

static func _paper_geometry(cells:Array,pitch:float)->Array:
	return GRID._surface_geometry(cells,pitch,10.5*pitch/56.0,18)

static func _inner_corners(owner:Dictionary,pitch:float)->Array:
	var vertices={};var result=[]
	for cell in owner:
		for offset in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.ONE,Vector2i.DOWN]:vertices[cell+offset]=true
	var quadrants=[Vector2i(-1,-1),Vector2i(0,-1),Vector2i.ZERO,Vector2i(-1,0)]
	var signs=[Vector2(-1,-1),Vector2(1,-1),Vector2.ONE,Vector2(-1,1)]
	var radius=pitch*3.2/56.0
	for vertex in vertices:
		var missing=[]
		for n in 4:
			if not owner.has(vertex+quadrants[n]):missing.append(n)
		if missing.size()!=1:continue
		var n=missing[0];var point=Vector2(vertex)*pitch
		var center=point+signs[n]*radius;var arc=PackedVector2Array()
		for step in 19:arc.append(center+Vector2.from_angle(n*PI*.5+step/18.0*PI*.5)*radius)
		var polygon=PackedVector2Array([point]);polygon.append_array(arc)
		result.append({"point":point,"center":center,"radius":radius,"angle":n*PI*.5,"polygon":polygon,"cell":vertex+quadrants[(n+2)%4]})
	return result

static func _rim_cut(point:Vector2,owner:Dictionary,radius:float)->float:
	var count=0
	for offset in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.UP,-Vector2i.ONE]:
		if owner.has(Vector2i(point)+offset):count+=1
	return radius if count==1 else radius*3.2/10.5 if count==3 else 0.0

static func _cloth_guide(c:CanvasItem,a:Vector2,b:Vector2,pitch:float,color:Color)->void:
	# Fine, softly broken pressed lines, phased in grid units. Each shared edge
	# is still drawn once; the dash rhythm cannot drift between neighboring cells.
	var u=pitch/56.0;var length=a.distance_to(b)
	if length<=0 or u<=0:return
	var direction=(b-a)/length
	var step=pitch/8.0
	var at=step*.16
	while at<length:
		var start=a+direction*at;var end=a+direction*minf(at+step*.70,length-step*.14)
		if start.distance_squared_to(end)>.001:
			c.draw_line(start,end,Color(color,color.a*.17),2.3*u,true)
			c.draw_line(start,end,color,.85*u,true)
		at+=step

static func chibi_surface(c:CanvasItem,origin:Vector2,bags:Array,pitch:float,focus:String,alpha:float,pulses:Dictionary)->void:
	# Layer 1 is the complete illustration, including its painted lining.
	var display_bags=form_bags(bags)
	if FORM.ART.patchwork(SKIN.bag_style):FINE.draw(c,origin,display_bags,pitch,alpha,focus,pulses)
	else:FORM.draw(c,origin,display_bags,pitch,alpha,focus,pulses)
	if not FORM.ART.trial(SKIN.bag_style):CONTACTS.draw(c,origin,display_bags,pitch,alpha)
	# Layer 2 only adds quiet slot impressions over that lining.
	var seen={}
	for bag in bags:
		for cell in inventory.occupied(bag):
			if seen.has(cell):continue
			seen[cell]=true
			SLOTS.draw(c,Rect2(origin+Vector2(cell)*pitch,Vector2.ONE*pitch),DANGO_FILLS.get(bag.kind,SKIN.CREAM),cell.x+cell.y*3,alpha,false,FORM.ART.slot_tint(SKIN.bag_style,bag.kind))

static func form_bags(bags:Array)->Array:
	var result=[]
	for bag in bags:
		result.append({"kind":bag.kind,"uid":bag.uid,"rotation":int(bag.get("rotation",0)),"cells":inventory.occupied(bag)})
	return result

static func form_hit(point:Vector2,bags:Array,pitch:float)->String:
	# Fine cloth is entirely within its logical footprint, with no invisible
	# legacy trim outside the bag allowed to steal an item/empty-space click.
	if FORM.ART.patchwork(SKIN.bag_style):return ""
	return FORM.hit(point,form_bags(bags),pitch)

