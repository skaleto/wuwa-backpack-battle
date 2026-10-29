extends RefCounted
## Layer 1: complete authored bags, including their own opaque lining.
## Continuous image coordinates preserve the single illustration at every join.
const SKIN=preload("res://scripts/ui/visual_skin.gd")
const ART=preload("res://scripts/ui/pockets/bag_art.gd")
const MARGIN=.24
static var masks={}
static var draw_geometry={}
const GEOMETRY_LIMIT=32
const PATCHWORK_MARGIN=.10

static func path(kind:String)->String:
	return ART.path(SKIN.bag_style,kind)

static func authored_turns(bag:Dictionary)->int:
	return posmod(int(bag.get("rotation",0))+ART.source_turns(SKIN.bag_style,bag.kind),4)

static func bounds(bag:Dictionary,pitch:float)->Rect2:
	var result=Rect2()
	for n in bag.cells.size():
		var rect=Rect2(Vector2(bag.cells[n])*pitch,Vector2.ONE*pitch)
		result=rect if n==0 else result.merge(rect)
	return result

static func _axis(t:float,start:float,end:float,padding:float)->float:
	# The full illustration stays continuous; only the empty lining stretches.
	if t<0:return lerpf(0,start,clampf((t+padding)/padding,0,1))
	if t>1:return lerpf(end,1,clampf((t-1)/padding,0,1))
	return lerpf(start,end,t)

static func _corner_axis(t:float,start:float,bend:float,end:float,at:float=.5)->float:
	if t<0 or t>1:return t
	var source=lerpf(start,bend,t/at) if t<=at else lerpf(bend,end,(t-at)/(1-at))
	return inverse_lerp(start,end,source)

static func uv_at(point:Vector2,body:Rect2,turns:int,kind:String,pitch:float)->Vector2:
	var unit=(point-body.position)/body.size
	var size=body.size/pitch
	match posmod(turns,4):
		1:unit=Vector2(unit.y,1-unit.x);size=Vector2(size.y,size.x)
		2:unit=Vector2.ONE-unit
		3:unit=Vector2(1-unit.y,unit.x);size=Vector2(size.y,size.x)
	var opening=ART.opening(SKIN.bag_style,kind)
	var joint_data=ART.joint(SKIN.bag_style,kind)
	if not joint_data.is_empty():
		unit.x=_corner_axis(unit.x,opening.position.x,joint_data.uv.x,opening.end.x,joint_data.grid.x)
		unit.y=_corner_axis(unit.y,opening.position.y,joint_data.uv.y,opening.end.y,joint_data.grid.y)
	elif kind=="corner" and ART.trial(SKIN.bag_style):
		var joint=ART.corner_joint(SKIN.bag_style)
		# Only bend the UV mapping at the actual L junction, never between slot vertices.
		unit.x=_corner_axis(unit.x,opening.position.x,joint.x,opening.end.x)
		unit.y=_corner_axis(unit.y,opening.position.y,joint.y,opening.end.y)
	var margin=PATCHWORK_MARGIN if ART.patchwork(ART.style_for(SKIN.bag_style,kind)) else MARGIN
	var uv=Vector2(_axis(unit.x,opening.position.x,opening.end.x,margin/size.x),_axis(unit.y,opening.position.y,opening.end.y,margin/size.y))
	var frame=ART.frame(SKIN.bag_style,kind)
	return frame.position+uv*frame.size

static func _joining_offset(point:Vector2,uid:String,owner:Dictionary,pitch:float,kind:String="")->Vector2:
	var style=ART.style_for(SKIN.bag_style,kind)
	if style=="flat":return Vector2.ZERO
	var grid=point/pitch
	if not grid.is_equal_approx(grid.round()):return Vector2.ZERO
	var v=Vector2i(grid.round());var shift=Vector2.ZERO
	# At a touching edge, extend the nearby lining to the join instead of
	# retaining two cream lips. All faces sharing this vertex use the same UV.
	for y in [-1,0]:
		var left=owner.get(v+Vector2i(-1,y),"")
		var right=owner.get(v+Vector2i(0,y),"")
		if left==uid and not right.is_empty() and right!=uid:shift.x-=.5
		elif right==uid and not left.is_empty() and left!=uid:shift.x+=.5
	for x in [-1,0]:
		var top=owner.get(v+Vector2i(x,-1),"")
		var bottom=owner.get(v+Vector2i(x,0),"")
		if top==uid and not bottom.is_empty() and bottom!=uid:shift.y-=.5
		elif bottom==uid and not top.is_empty() and top!=uid:shift.y+=.5
	# Only exposed endpoints keep part of their original rim. Fully surrounded
	# junctions still sample the lining, otherwise corner hardware leaks inside.
	if [Vector2i.ZERO,Vector2i.LEFT,Vector2i.UP,-Vector2i.ONE].all(func(offset):return owner.has(v+offset)):
		shift=Vector2(signf(shift.x),signf(shift.y))
	# Open fabric bags retain their folded perimeter on exposed edges, while
	# touching lips compress gently into the lining. No cross-bag colour blending.
	return shift*pitch*(.12 if style=="fold" else .04 if style=="storybook" else .30)

static func patches(bags:Array,pitch:float)->Array:
	if ART.patchwork(SKIN.bag_style):return _patchwork_patches(bags,pitch)
	var owner={}
	for bag in bags:
		for cell in bag.cells:owner[cell]=bag.uid
	var result=_patchwork_patches(bags,pitch)
	for bag in bags:
		if ART.patchwork(ART.style_for(SKIN.bag_style,bag.kind)):continue
		if bag.cells.is_empty():continue
		var body=bounds(bag,pitch)
		var xs=[body.position.x-MARGIN*pitch]
		var ys=[body.position.y-MARGIN*pitch]
		for n in int(round(body.size.x/pitch))+1:xs.append(body.position.x+n*pitch)
		for n in int(round(body.size.y/pitch))+1:ys.append(body.position.y+n*pitch)
		xs.append(body.end.x+MARGIN*pitch);ys.append(body.end.y+MARGIN*pitch)
		for y in ys.size()-1:
			for x in xs.size()-1:
				var rect=Rect2(xs[x],ys[y],xs[x+1]-xs[x],ys[y+1]-ys[y])
				var cell=Vector2i((rect.get_center()/pitch).floor())
				# A neighboring bag owns that area; hide only this bag's
				# outside decoration there. No copied rims or new caps.
				if owner.has(cell) and owner[cell]!=bag.uid:continue
				var points=PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
				var uv=PackedVector2Array()
				for point in points:uv.append(uv_at(point+_joining_offset(point,bag.uid,owner,pitch,bag.kind),body,authored_turns(bag),bag.kind,pitch))
				result.append({"points":points,"uv":uv,"kind":bag.kind,"uid":bag.uid,"rect":rect,"inside":cell in bag.cells})
	return result

static func _patchwork_patches(bags:Array,pitch:float)->Array:
	# One lining face per owned cell. Only exposed edges get a narrow hem;
	# unlike a bounding-box draw, a long L never paints into its empty notch.
	var owner={};var result=[];var m=pitch*PATCHWORK_MARGIN
	for bag in bags:
		for cell in bag.cells:owner[cell]=bag.uid
	for bag in bags:
		if not ART.patchwork(ART.style_for(SKIN.bag_style,bag.kind)):continue
		if bag.cells.is_empty():continue
		var body=bounds(bag,pitch);var areas=[]
		for cell in bag.cells:
			var p=Vector2(cell)*pitch
			areas.append([Rect2(p,Vector2.ONE*pitch),true])
			if not owner.has(cell+Vector2i.LEFT):areas.append([Rect2(p-Vector2(m,0),Vector2(m,pitch)),false])
			if not owner.has(cell+Vector2i.RIGHT):areas.append([Rect2(p+Vector2(pitch,0),Vector2(m,pitch)),false])
			if not owner.has(cell+Vector2i.UP):areas.append([Rect2(p-Vector2(0,m),Vector2(pitch,m)),false])
			if not owner.has(cell+Vector2i.DOWN):areas.append([Rect2(p+Vector2(0,pitch),Vector2(pitch,m)),false])
			for direction in [Vector2i(-1,-1),Vector2i(1,-1),Vector2i(1,1),Vector2i(-1,1)]:
				if owner.has(cell+direction) or owner.has(cell+Vector2i(direction.x,0)) or owner.has(cell+Vector2i(0,direction.y)):continue
				areas.append([Rect2(p+Vector2(-m if direction.x<0 else pitch,-m if direction.y<0 else pitch),Vector2.ONE*m),false])
		for area in areas:
			var rect:Rect2=area[0]
			var points=PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
			var uv=PackedVector2Array()
			for point in points:uv.append(uv_at(point+_joining_offset(point,bag.uid,owner,pitch,bag.kind),body,authored_turns(bag),bag.kind,pitch))
			result.append({"points":points,"uv":uv,"kind":bag.kind,"uid":bag.uid,"rect":rect,"inside":area[1]})
	return result

static func draw(c:CanvasItem,origin:Vector2,bags:Array,pitch:float,alpha:float,focus:String="",pulses:Dictionary={})->void:
	for p in cached_patches(bags,pitch):
		var texture=SKIN.texture(path(p.kind))
		if texture==null:continue
		var points=PackedVector2Array()
		for point in p.points:points.append(origin+point)
		var tint=Color.WHITE
		if p.uid==focus:tint=Color(1.04,1.04,1.04)
		tint=tint.lerp(Color(1.08,1.05,.94),clampf(float(pulses.get(p.uid,0)),0,1))
		tint.a=alpha
		c.draw_polygon(points,PackedColorArray([tint]),p.uv,texture)

static func hit(point:Vector2,bags:Array,pitch:float)->String:
	# The existing logical-cell/item hit path owns the interior. Only actual
	# opaque outside bag pixels extend the grab region.
	var cell=Vector2i((point/pitch).floor())
	for bag in bags:
		if cell in bag.cells:return ""
	var layers=patches(bags,pitch)
	layers.reverse()
	for p in layers:
		if not p.rect.has_point(point):continue
		var f=(point-p.rect.position)/p.rect.size
		var uv=p.uv[0].lerp(p.uv[1],f.x).lerp(p.uv[3].lerp(p.uv[2],f.x),f.y)
		var image_path=path(p.kind)
		if not masks.has(image_path):
			var pixels=Image.load_from_file(image_path)
			if pixels==null:continue
			var mask=BitMap.new();mask.create_from_image_alpha(pixels,.25)
			masks[image_path]=mask
		var mask=masks[image_path]
		var at=Vector2i(uv*Vector2(mask.get_size())).clamp(Vector2i.ZERO,mask.get_size()-Vector2i.ONE)
		if mask.get_bitv(at):return p.uid
	return ""

static func cached_patches(bags:Array,pitch:float)->Array:
	# Only drawing reads this cache. Hit testing keeps its own reversible array.
	var key=str(SKIN.bag_style)+str(pitch)+str(bags)
	if not draw_geometry.has(key):
		if draw_geometry.size()>=GEOMETRY_LIMIT:draw_geometry.erase(draw_geometry.keys()[0])
		draw_geometry[key]=patches(bags,pitch)
	return draw_geometry[key]
