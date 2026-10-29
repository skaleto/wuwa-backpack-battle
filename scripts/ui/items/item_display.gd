extends RefCounted
## Size-aware presentation of existing art. Never changes its footprint or source.
const BLADE_TYPES=["sword","broadblade"]

static func stretch(definition: Dictionary,room: Vector2,angle: float,body: Rect2) -> Vector2:
	if str(definition.get("weapon_type","")) not in BLADE_TYPES or not bool(definition.get("combat_v15",false)):return Vector2.ONE
	# These selected sprites are authored horizontally. Scale their short axis
	# before rotation, so rotated items keep exactly the same treatment.
	var axis=Vector2.RIGHT.rotated(angle).abs()
	var available_length=room.dot(axis)
	# Compact inventory/shop art needs a stronger silhouette. Large inspection
	# previews approach the original proportions instead of inflating every view.
	var compact=1.0-smoothstep(250.0,440.0,available_length)
	var slender=clampf((body.size.x/maxf(body.size.y,1.0)-4.5)/4.5,0,1)
	return Vector2(1.0,1.0+compact*1.20*slender)

static func fit(definition: Dictionary,desc: Dictionary,room: Vector2,center: Vector2) -> Dictionary:
	if definition.is_empty():
		# Preserve the real rotated silhouette, rather than rotating its loose AABB.
		var bounds:Rect2=desc.bounds
		var factor=minf(room.x/maxf(1,bounds.size.x),room.y/maxf(1,bounds.size.y))
		var position=center-(bounds.get_center()+Vector2(desc.image_center).rotated(desc.angle))*factor
		return {"position":position,"scale":factor,"aspect":Vector2.ONE,"angle":desc.angle,"transform":Transform2D(desc.angle,Vector2.ONE*factor,0,position),"center":center,"bounds":Rect2(center-bounds.size*factor*.5,bounds.size*factor)}
	var body: Rect2=desc.get("body",Rect2(Vector2.ZERO,desc.get("image_size",Vector2.ONE)))
	var aspect=stretch(definition,room,float(desc.angle),body)
	var original_size: Vector2=desc.bounds.size
	var original_scale=minf(room.x/maxf(1,original_size.x),room.y/maxf(1,original_size.y))
	var cross_room=room.dot(Vector2.DOWN.rotated(float(desc.angle)).abs())
	# A wide guard already filling the row must not shorten the entire weapon.
	aspect.y=minf(aspect.y,maxf(1.0,cross_room/maxf(1,body.size.y*original_scale)))
	var local=Transform2D(float(desc.angle),aspect,0,Vector2.ZERO)
	var low=Vector2(INF,INF);var high=Vector2(-INF,-INF)
	for point in [body.position,Vector2(body.end.x,body.position.y),body.end,Vector2(body.position.x,body.end.y)]:
		var p=local*(point-Vector2(desc.image_center));low=low.min(p);high=high.max(p)
	var bounds=Rect2(low,high-low)
	var scale_value=minf(room.x/maxf(1,bounds.size.x),room.y/maxf(1,bounds.size.y))
	var position=center-(bounds.get_center()+local*Vector2(desc.image_center))*scale_value
	var transform=Transform2D(float(desc.angle),aspect*scale_value,0,position)
	return {"position":position,"scale":scale_value,"aspect":aspect,"angle":desc.angle,"transform":transform,"center":center,"bounds":Rect2(center-bounds.size*scale_value*.5,bounds.size*scale_value)}
