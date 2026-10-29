extends RefCounted
## Pure grid geometry. Definitions are injected; migration may supply overrides.
const WIDTH=9
const HEIGHT=7
var definitions:Dictionary
var overrides:Dictionary={}
func _init(items:Dictionary):definitions=items
func definition(kind:String)->Dictionary:return overrides.get(kind,definitions[kind])
func rotated(v:Vector2i,turns:int)->Vector2i:
	for n in range(posmod(turns,4)):v=Vector2i(-v.y,v.x)
	return v
func shape_low(kind:String,rotation:int)->Vector2i:
	var low=Vector2i(100,100)
	for p in definition(kind).shape:
		var v=rotated(Vector2i(int(p[0]),int(p[1])),rotation)
		low.x=mini(low.x,v.x);low.y=mini(low.y,v.y)
	return low
func cells(item:Dictionary)->Array:
	if not definitions.has(item.get("kind","")):return []
	var turns=int(item.get("rotation",0));var low=shape_low(item.kind,turns)
	return definition(item.kind).shape.map(func(p):return rotated(Vector2i(int(p[0]),int(p[1])),turns)-low)
func occupied(item:Dictionary)->Array:
	return cells(item).map(func(v):return v+Vector2i(int(item.get("x",0)),int(item.get("y",0))))
func stars(item:Dictionary)->Array:
	if not definitions.has(item.get("kind","")):return []
	var turns=int(item.get("rotation",0));var low=shape_low(item.kind,turns)
	var local=definition(item.kind).get("stars",[]).duplicate(true)
	if item.has("crew_star") and not local.is_empty():
		var direction=[Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP][posmod(int(item.crew_star),4)]
		var edge=Vector2i.ZERO
		for cell in definition(item.kind).shape:
			var v=Vector2i(int(cell[0]),int(cell[1]))
			if v.x*direction.x+v.y*direction.y>edge.x*direction.x+edge.y*direction.y:edge=v
		edge+=direction
		while [edge.x,edge.y] in local:edge+=direction
		local.append([edge.x,edge.y])
	return local.map(func(p):return rotated(Vector2i(int(p[0]),int(p[1])),turns)-low+Vector2i(int(item.get("x",0)),int(item.get("y",0))))
func coverage(bags:Array)->Array:
	var result:Array=[]
	for bag in bags:
		for v in occupied(bag):
			if v not in result:result.append(v)
	return result
func in_bounds(v:Vector2i)->bool:return v.x>=0 and v.x<WIDTH and v.y>=0 and v.y<HEIGHT
func can_place(item:Dictionary,items:Array,bags:Array)->bool:
	return fits_cells(occupied(item),placement_area(item,items,bags))
# One immutable search snapshot. Rebuild after any board change; never retain
# this across transactions. Every candidate shares the same placement predicate.
func placement_area(item:Dictionary,items:Array,bags:Array)->Dictionary:
	var area:Dictionary={}
	if not definitions.has(item.get("kind","")) or "bag" in definitions[item.kind].get("tags",[]):return area
	for cell in coverage(bags):
		if in_bounds(cell):area[cell]=true
	for other in items:
		if other.get("uid","")!=item.get("uid","?"):
			for cell in occupied(other):area.erase(cell)
	return area
func fits_cells(footprint:Array,area:Dictionary)->bool:
	return not footprint.is_empty() and footprint.all(func(v):return area.has(v))
func adjacent(a:Dictionary,b:Dictionary)->bool:
	return adjacent_cells(occupied(a),occupied(b))
func adjacent_cells(a:Array,b:Array)->bool:
	for v in a:
		for w in b:
			if absi(v.x-w.x)+absi(v.y-w.y)==1:return true
	return false
