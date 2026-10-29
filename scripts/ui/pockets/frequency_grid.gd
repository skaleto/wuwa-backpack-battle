extends RefCounted
## Stateless native 2D drawing in the caller's current canvas transform.
## Cells accept Vector2i, integral Vector2, or [x,y]; invalid entries are ignored.
## draw() owns one merged flat array: modest exposed convex rounding, an inward
## trace and sparse perimeter marks. It adds no item-side textures or patterns.
## footprint() is a plain placement shadow; selected=true explicitly adds a trace.

const FILL := Color("25394ed9")
const GRID := Color("9eafbd42")
const BORDER := Color("c9d7da9c")
const MARK := Color("dfcfa7c7")
const DIRECTIONS := [Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)]

static func _cells(cells: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var used: Dictionary = {}
	for raw in cells:
		var cell: Vector2i
		if raw is Vector2i:
			cell = raw
		elif raw is Vector2:
			if not raw.is_finite() or raw.x != floor(raw.x) or raw.y != floor(raw.y):
				continue
			cell = Vector2i(raw)
		elif raw is Array and raw.size() == 2:
			if not (raw[0] is int or raw[0] is float) or not (raw[1] is int or raw[1] is float):
				continue
			var point := Vector2(float(raw[0]),float(raw[1]))
			if not point.is_finite() or point.x != floor(point.x) or point.y != floor(point.y):
				continue
			cell = Vector2i(point)
		else:
			continue
		if not used.has(cell):
			used[cell] = true
			result.append(cell)
	result.sort_custom(func(a: Vector2i,b: Vector2i): return a.y < b.y or (a.y == b.y and a.x < b.x))
	return result

static func _edge_records(cells: Array) -> Array:
	var records: Dictionary = {}
	for cell in _cells(cells):
		var keys := [Vector3i(cell.x,cell.y,0),Vector3i(cell.x+1,cell.y,1),Vector3i(cell.x,cell.y+1,0),Vector3i(cell.x,cell.y,1)]
		for side in range(4):
			var key: Vector3i = keys[side]
			if records.has(key):
				records[key].count += 1
			else:
				var a := Vector2(key.x,key.y)
				var b := a + (Vector2.RIGHT if key.z == 0 else Vector2.DOWN)
				records[key] = {"a":a,"b":b,"count":1,"inward":-Vector2(DIRECTIONS[side]),"cell":cell,"side":side}
	return records.values()

static func edges(cells: Array, exterior_only: bool = false) -> Array:
	var result: Array = []
	for edge in _edge_records(cells):
		if not exterior_only or edge.count == 1:
			result.append([edge.a,edge.b])
	return result

static func cell_rects(origin: Vector2, cells: Array, pitch: float, inset: float = 1.0) -> Array:
	var result: Array = []
	if not origin.is_finite() or not is_finite(pitch) or pitch <= 0.0 or not is_finite(inset):
		return result
	var margin := maxf(0.0,inset)
	if margin*2.0 >= pitch:
		return result
	for cell in _cells(cells):
		result.append(Rect2(origin+Vector2(cell)*pitch+Vector2.ONE*margin,Vector2.ONE*(pitch-margin*2.0)))
	return result

static func _band(canvas: CanvasItem, a: Vector2, b: Vector2, inward: Vector2, width: float, color: Color) -> void:
	# Filled bands start on the boundary and extend only inward. A centered stroke
	# would spill half its width into a neighboring item or an unowned cell.
	canvas.draw_colored_polygon(PackedVector2Array([a,b,b+inward*width,a+inward*width]),color)

static func _corner_flags(cell: Vector2i, owned: Dictionary) -> Array:
	return [
		not owned.has(cell+Vector2i.LEFT) and not owned.has(cell+Vector2i.UP) and not owned.has(cell+Vector2i(-1,-1)),
		not owned.has(cell+Vector2i.RIGHT) and not owned.has(cell+Vector2i.UP) and not owned.has(cell+Vector2i(1,-1)),
		not owned.has(cell+Vector2i.RIGHT) and not owned.has(cell+Vector2i.DOWN) and not owned.has(cell+Vector2i(1,1)),
		not owned.has(cell+Vector2i.LEFT) and not owned.has(cell+Vector2i.DOWN) and not owned.has(cell+Vector2i(-1,1))
	]

static func _surface_geometry(cells: Array, pitch: float, corner_radius:float=-1.0, arc_segments:int=6) -> Array:
	var result: Array = []
	if not is_finite(pitch) or pitch <= 0.0 or not (Vector2.ONE*pitch).is_finite(): return result
	var unique := _cells(cells)
	var owned: Dictionary = {}
	for cell in unique: owned[cell] = true
	var radius := minf(5.5,pitch*.095) if corner_radius<0 else clampf(corner_radius,0,pitch*.45)
	var segments := clampi(arc_segments,6,32)
	var starts := [PI,PI*1.5,0.0,PI*.5]
	var centers := [Vector2(radius,radius),Vector2(pitch-radius,radius),Vector2(pitch-radius,pitch-radius),Vector2(radius,pitch-radius)]
	var corners := [Vector2.ZERO,Vector2(pitch,0),Vector2.ONE*pitch,Vector2(0,pitch)]
	for cell in unique:
		var origin := Vector2(cell)*pitch
		if not origin.is_finite() or not (origin+Vector2.ONE*pitch).is_finite(): return []
		var exposed := _corner_flags(cell,owned)
		var polygon := PackedVector2Array()
		for corner in range(4):
			if exposed[corner]:
				for n in range(segments+1):
					var angle: float = starts[corner]+PI*.5*n/float(segments)
					polygon.append(origin+centers[corner]+Vector2(cos(angle),sin(angle))*radius)
			else:
				polygon.append(origin+corners[corner])
		result.append({"cell":cell,"polygon":polygon,"corners":exposed,"radius":radius})
	return result

static func _exterior_runs(records: Array) -> Array:
	var groups: Dictionary = {}
	for edge in records:
		if edge.count != 1: continue
		var horizontal: bool = edge.a.y == edge.b.y
		var key := Vector3i(0 if horizontal else 1,int(edge.a.y if horizontal else edge.a.x),int(edge.inward.y if horizontal else edge.inward.x))
		if not groups.has(key): groups[key] = []
		groups[key].append(edge)
	var runs: Array = []
	for key in groups:
		var group: Array = groups[key]
		group.sort_custom(func(a: Dictionary,b: Dictionary):return a.a.x < b.a.x if key.x == 0 else a.a.y < b.a.y)
		var run: Dictionary = {}
		for edge in group:
			if not run.is_empty() and run.b == edge.a:
				run.b = edge.b
				run.tail = edge
			else:
				if not run.is_empty(): runs.append(run)
				run = {"a":edge.a,"b":edge.b,"inward":edge.inward,"head":edge,"tail":edge}
		if not run.is_empty(): runs.append(run)
	runs.sort_custom(func(a: Dictionary,b: Dictionary):
		var length_a: float = a.a.distance_squared_to(a.b)
		var length_b: float = b.a.distance_squared_to(b.b)
		if not is_equal_approx(length_a,length_b): return length_a > length_b
		return a.a.y < b.a.y or (a.a.y == b.a.y and a.a.x < b.a.x))
	return runs

static func _arc_band(center: Vector2, radius: float, width: float, start: float) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for n in range(7):
		var angle := start+PI*.5*n/6.0
		polygon.append(center+Vector2(cos(angle),sin(angle))*radius)
	for n in range(6,-1,-1):
		var angle := start+PI*.5*n/6.0
		polygon.append(center+Vector2(cos(angle),sin(angle))*(radius-width))
	return polygon

static func draw(canvas: CanvasItem, origin: Vector2, cells: Array, pitch: float, editing: bool = false, alpha: float = 1.0) -> void:
	## Trailing alpha fades fill, shared grid and inward perimeter together.
	if not is_instance_valid(canvas) or not origin.is_finite() or not is_finite(pitch) or pitch <= 0.0 or not is_finite(alpha):
		return
	var opacity := clampf(alpha,0.0,1.0)
	if opacity <= 0.0: return
	var geometry := _surface_geometry(cells,pitch)
	if geometry.is_empty(): return
	var by_cell: Dictionary = {}
	for part in geometry:
		by_cell[part.cell] = part
		var polygon := PackedVector2Array()
		for point in part.polygon: polygon.append(origin+point)
		var shades=PackedColorArray()
		for point in polygon:
			var blend=clampf((point.y-origin.y)/(pitch*6.0),0,1)
			var tone=FILL.lerp(Color("526577ce"),blend)
			shades.append(Color(tone,tone.a*opacity))
		canvas.draw_polygon(polygon,shades)
	var width := minf(1.0,pitch*.035)
	var records := _edge_records(cells)
	var border: Color = BORDER.lightened(.10) if editing else BORDER
	border.a *= opacity
	for edge in records:
		var a: Vector2 = origin+edge.a*pitch
		var b: Vector2 = origin+edge.b*pitch
		if edge.count > 1:
			var along: Vector2 = (b-a).normalized()*width*.5
			var shared: Color = GRID.lightened(.08) if editing else GRID
			# A filled inward strip stays visible at integer pitches where a
			# subpixel centered line can miss every native pixel center.
			_band(canvas,a+along,b-along,edge.inward,width,Color(shared,shared.a*opacity))
	var pairs := [[0,1],[1,2],[3,2],[0,3]]
	var runs := _exterior_runs(records)
	for run in runs:
		var along: Vector2 = (run.b-run.a).normalized()
		var head: Dictionary = by_cell[run.head.cell]
		var tail: Dictionary = by_cell[run.tail.cell]
		var start_trim: float = head.radius if head.corners[pairs[run.head.side][0]] else 0.0
		var end_trim: float = tail.radius if tail.corners[pairs[run.tail.side][1]] else 0.0
		_band(canvas,origin+run.a*pitch+along*start_trim,origin+run.b*pitch-along*end_trim,run.inward,width,border)
	var starts := [PI,PI*1.5,0.0,PI*.5]
	for part in geometry:
		var r: float = part.radius
		var centers := [Vector2(r,r),Vector2(pitch-r,r),Vector2(pitch-r,pitch-r),Vector2(r,pitch-r)]
		for corner in range(4):
			if part.corners[corner]:
				canvas.draw_colored_polygon(_arc_band(origin+Vector2(part.cell)*pitch+centers[corner],r,width,starts[corner]),border)
	# A few paired tangent marks belong to the array perimeter, never to modules
	# or item interiors. Tiny capacity thumbnails retain just the rounded trace.
	if pitch < 24.0: return
	var count := 0
	for run in runs:
		if run.a.distance_to(run.b) < 1.75: continue
		var along: Vector2 = (run.b-run.a).normalized()
		var center: Vector2 = origin+(run.a+run.b)*pitch*.5
		var gap := minf(2.0,pitch*.035)
		var length := minf(4.0,pitch*.065)
		var mark: Color = MARK.lightened(.08) if editing else MARK
		mark.a *= opacity
		_band(canvas,center-along*(gap+length),center-along*gap,run.inward,width,mark)
		_band(canvas,center+along*gap,center+along*(gap+length),run.inward,width,mark)
		count += 1
		if count == 3: break

static func footprint(canvas: CanvasItem, origin: Vector2, cells: Array, pitch: float, color: Color, selected: bool = false) -> void:
	## Plain translucent placement shadow when the caller supplies an alpha color.
	## No attached item surface decoration; only selected=true requests a frame.
	if not is_instance_valid(canvas) or not origin.is_finite() or not is_finite(pitch) or pitch <= 0.0:
		return
	var owned: Dictionary = {}
	for cell in _cells(cells):
		owned[cell] = true
	var inset := minf(1.6,pitch*.035)
	var width := minf(1.15,pitch*.025)
	var perimeter := Color(color.darkened(.40),color.a)
	for cell in owned:
		var exterior := [not owned.has(cell+Vector2i.UP),not owned.has(cell+Vector2i.RIGHT),not owned.has(cell+Vector2i.DOWN),not owned.has(cell+Vector2i.LEFT)]
		var low := Vector2(inset if exterior[3] else 0.0,inset if exterior[0] else 0.0)
		var high := Vector2(pitch-(inset if exterior[1] else 0.0),pitch-(inset if exterior[2] else 0.0))
		var rect := Rect2(origin+Vector2(cell)*pitch+low,high-low)
		canvas.draw_rect(rect,color)
		var a := rect.position
		var b := Vector2(rect.end.x,rect.position.y)
		var c := rect.end
		var d := Vector2(rect.position.x,rect.end.y)
		if selected:
			if exterior[0]: _band(canvas,a,b,Vector2.DOWN,width,perimeter)
			if exterior[1]: _band(canvas,b,c,Vector2.LEFT,width,perimeter)
			if exterior[2]: _band(canvas,d,c,Vector2.UP,width,perimeter)
			if exterior[3]: _band(canvas,a,d,Vector2.RIGHT,width,perimeter)
	# One plain occupied surface: no decorative tracks, waves, nodes or links.
	# Shared sides receive neither inset nor strokes.
