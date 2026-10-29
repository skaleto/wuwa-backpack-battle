extends RefCounted
## Display-only contacts between different bags, below slots and items.
## Logical ownership remains rectangular; no texture or input geometry is added.
const FORM=preload("res://scripts/ui/pockets/bag_form.gd")
const SKIN=preload("res://scripts/ui/visual_skin.gd")

static func segments(bags:Array)->Array:
	var owner={}
	for bag in bags:
		for cell in bag.cells:owner[cell]=bag.uid
	var groups={}
	for cell in owner:
		for axis in 2:
			var neighbor=cell+(Vector2i.RIGHT if axis==0 else Vector2i.DOWN)
			if not owner.has(neighbor) or owner[cell]==owner[neighbor]:continue
			var pair=[owner[cell],owner[neighbor]];pair.sort()
			var line=cell.x+1 if axis==0 else cell.y+1
			var along=cell.y if axis==0 else cell.x
			var key=str(axis)+":"+str(line)+":"+JSON.stringify(pair)
			if not groups.has(key):groups[key]={"axis":axis,"line":line,"positions":[],"negative":owner[cell],"positive":owner[neighbor]}
			groups[key].positions.append(along)
	var keys=groups.keys();keys.sort()
	var result=[]
	for key in keys:
		var group=groups[key];var positions=group.positions;positions.sort()
		var start=positions[0];var last=start
		for n in range(1,positions.size()+1):
			if n<positions.size() and positions[n]==last+1:last=positions[n];continue
			var a=Vector2(group.line,start) if group.axis==0 else Vector2(start,group.line)
			var b=Vector2(group.line,last+1) if group.axis==0 else Vector2(last+1,group.line)
			result.append({"a":a,"b":b,"negative":group.negative,"positive":group.positive})
			if n<positions.size():start=positions[n];last=start
	return result

static func draw(c:CanvasItem,origin:Vector2,bags:Array,pitch:float,alpha:float)->void:
	var scale_value=pitch/56.0
	var by_uid={}
	for bag in bags:by_uid[bag.uid]=bag
	for edge in segments(bags):
		var a=origin+edge.a*pitch;var b=origin+edge.b*pitch
		var length=a.distance_to(b);var direction=(b-a)/length
		var normal=Vector2(-direction.y,direction.x)
		_blend(c,origin,edge,by_uid,pitch,alpha)
		var end_length=minf(pitch*.16,length*.25)
		var points=PackedVector2Array([a,a+direction*end_length,a+direction*(length-end_length),b])
		# Feathered contact, one drawing per shared side. Tips disappear softly
		# rather than producing heavy caps or a dark cross at four-bag junctions.
		for layer in [[3.6,.035],[1.8,.065],[.65,.095]]:
			var ink=Color("51405d");ink.a=float(layer[1])*alpha
			var clear=Color(ink,0)
			c.draw_polyline_colors(points,PackedColorArray([clear,ink,ink,clear]),float(layer[0])*scale_value,true)
		var light=Color("fff0dd",.065*alpha);var gleam=PackedVector2Array()
		for point in points:gleam.append(point+normal*.5*scale_value)
		c.draw_polyline_colors(gleam,PackedColorArray([Color(light,0),light,light,Color(light,0)]),.5*scale_value,true)

static func _blend(c:CanvasItem,origin:Vector2,edge:Dictionary,by_uid:Dictionary,pitch:float,alpha:float)->void:
	# A narrow crossfade of the actual two linings removes the ruler-straight
	# colour cut. It stays within the two owned cells and does not change hits.
	var a=edge.a*pitch;var b=edge.b*pitch
	var length=a.distance_to(b);var direction=(b-a)/length
	var normal=Vector2(-direction.y,direction.x)
	var width=pitch*.075;var steps=int(ceil(length/pitch*4))
	for side in [-1,1]:
		var inward=normal*side
		var uid=edge.negative if inward.x<0 or inward.y<0 else edge.positive
		var bag=by_uid[uid];var body=FORM.bounds(bag,pitch)
		var texture=SKIN.texture(FORM.path(bag.kind))
		if texture==null:continue
		for n in steps:
			var t0=length*n/steps;var t1=length*(n+1)/steps
			var p0=a+direction*t0;var p1=a+direction*t1
			var s0=a+direction*clampf(t0,pitch*.12,length-pitch*.12)+inward*pitch*.30
			var s1=a+direction*clampf(t1,pitch*.12,length-pitch*.12)+inward*pitch*.30
			var uv=PackedVector2Array()
			for sample in [s0,s1,s1+inward*width,s0+inward*width]:uv.append(FORM.uv_at(sample,body,FORM.authored_turns(bag),bag.kind,pitch))
			var fade0=smoothstep(0,pitch*.20,minf(t0,length-t0))
			var fade1=smoothstep(0,pitch*.20,minf(t1,length-t1))
			var colors=PackedColorArray([Color(1,1,1,.48*alpha*fade0),Color(1,1,1,.48*alpha*fade1),Color(1,1,1,0),Color(1,1,1,0)])
			c.draw_polygon(PackedVector2Array([origin+p0,origin+p1,origin+p1-inward*width,origin+p0-inward*width]),colors,uv,texture)
