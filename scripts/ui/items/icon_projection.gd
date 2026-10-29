extends RefCounted
## Pure alpha-aware fitting and native clipping. Source images are never edited.
## descriptor points/bounds are rotated coordinates relative to image_center.
## fit.position maps ORIGINAL, uncentered texture pixels into footprint coordinates:
##   Transform2D(fit.angle, Vector2.ONE * fit.scale, 0, fit.position) * source_pixel
## draw adds origin to that result and retains the caller's canvas transform.
const GRID = preload("res://scripts/ui/pockets/frequency_grid.gd")

static func _mass_analysis(raw_points: PackedVector2Array, weights: PackedByteArray, image_center: Vector2, angle: float, size: Vector2) -> Dictionary:
	var total := 0.0
	var mean_x := 0.0
	var mean_y := 0.0
	for n in range(raw_points.size()):
		total += weights[n]
		mean_x += float(raw_points[n].x)*weights[n]
		mean_y += float(raw_points[n].y)*weights[n]
	var centroid := Vector2(mean_x/total,mean_y/total) if total > 0.0 else image_center
	# A radial alpha-mass quantile is a geometric protection proxy, never a
	# semantic face detector. Include all ties on the central75% radial boundary.
	var radius_squared := 0.0
	var protected_total := 0.0
	var maximum := 1.0
	for corner in [Vector2.ZERO,Vector2(size.x,0),size,Vector2(0,size.y)]:
		maximum = maxf(maximum,centroid.distance_squared_to(corner))
	var histogram := PackedFloat64Array()
	histogram.resize(8192)
	histogram.fill(0.0)
	for n in range(raw_points.size()):
		var bin := clampi(floori(raw_points[n].distance_squared_to(centroid)/maximum*8192.0),0,8191)
		histogram[bin] += weights[n]
	var cumulative := 0.0
	for n in range(histogram.size()):
		cumulative += histogram[n]
		if cumulative >= total*.75:
			radius_squared = (n+1)/8192.0*maximum
			break
	var points := PackedVector2Array()
	var protected := PackedByteArray()
	var samples := PackedVector2Array()
	var sample_weights := PackedByteArray()
	var sample_protected := PackedByteArray()
	var sample_total := 0.0
	var sample_core_total := 0.0
	var sample_step := clampi(ceili(maxf(size.x,size.y)/80.0),4,16)
	var offset := floori(sample_step*.5)
	for n in range(raw_points.size()):
		var raw := raw_points[n]
		var point := (raw-image_center).rotated(angle)
		var core := raw.distance_squared_to(centroid) <= radius_squared
		points.append(point)
		protected.append(1 if core else 0)
		if core: protected_total += weights[n]
		if int(raw.x)%sample_step == offset and int(raw.y)%sample_step == offset:
			samples.append(point)
			sample_weights.append(weights[n])
			sample_protected.append(1 if core else 0)
			sample_total += weights[n]
			if core: sample_core_total += weights[n]
	return {"mass_points":points,"mass_weights":weights,"mass_protected":protected,"mass_total":total,"mass_protected_total":protected_total,"mass_samples":samples,"mass_sample_weights":sample_weights,"mass_sample_protected":sample_protected,"mass_sample_total":sample_total,"mass_sample_core_total":sample_core_total,"mass_centroid_source":centroid,"protected_radius_squared":radius_squared,"protected_fraction":protected_total/total if total > 0.0 else 1.0}

static func descriptor(source: Image, angle: float = 0.0, include_mass: bool = true) -> Dictionary:
	var safe_angle := angle if is_finite(angle) else 0.0
	var size := Vector2.ONE
	if source != null and not source.is_empty():
		size = Vector2(source.get_width(),source.get_height())
	var center := size*.5
	var points := PackedVector2Array()
	var validation := PackedVector2Array()
	var low := Vector2(INF,INF)
	var high := Vector2(-INF,-INF)
	var step := clampi(ceili(maxf(size.x,size.y)/96.0),4,8)
	var mass_raw := PackedVector2Array()
	var mass_weights := PackedByteArray()
	if source != null and not source.is_empty():
		var readable: Image = source
		if source.is_compressed() or source.get_format() != Image.FORMAT_RGBA8:
			readable = source.duplicate() as Image
			if readable.is_compressed():
				readable.decompress()
			readable.convert(Image.FORMAT_RGBA8)
		var data := readable.get_data()
		var width := readable.get_width()
		var height := readable.get_height()
		var column_low: Array[int] = []
		var column_high: Array[int] = []
		column_low.resize(width)
		column_high.resize(width)
		column_low.fill(-1)
		column_high.fill(-1)
		var interior := PackedVector2Array()
		for y in range(height):
			var left := -1
			var right := -1
			for x in range(width):
				var alpha: int = data[(y*width+x)*4+3]
				if include_mass and alpha > 0:
					mass_raw.append(Vector2(x+.5,y+.5))
					mass_weights.append(alpha)
				if alpha <= 20: # alpha > 0.08, in 8-bit source data
					continue
				if left < 0: left = x
				right = x
				if column_low[x] < 0: column_low[x] = y
				column_high[x] = y
				if x%step == step/2 and y%step == step/2:
					interior.append((Vector2(x+.5,y+.5)-center).rotated(safe_angle))
			if left < 0:
				continue
			# Exact end-pixel corners on every occupied scanline protect narrow tips.
			# Bounds therefore use the alpha silhouette, even at an arbitrary angle.
			for p in [Vector2(left,y),Vector2(left,y+1),Vector2(right+1,y),Vector2(right+1,y+1)]:
				var rotated: Vector2 = (p-center).rotated(safe_angle)
				low = low.min(rotated)
				high = high.max(rotated)
				validation.append(rotated)
				if y%step == 0 or y == height-1:
					points.append(rotated)
		for x in range(width):
			if column_low[x] < 0:
				continue
			for p in [Vector2(x,column_low[x]),Vector2(x+1,column_low[x]),Vector2(x,column_high[x]+1),Vector2(x+1,column_high[x]+1)]:
				var rotated: Vector2 = (p-center).rotated(safe_angle)
				validation.append(rotated)
				if x%step == 0 or x == width-1:
					points.append(rotated)
		points.append_array(interior)
		validation.append_array(interior)
	var empty := validation.is_empty()
	if empty:
		low = Vector2(INF,INF)
		high = Vector2(-INF,-INF)
		for p in [Vector2.ZERO,Vector2(size.x,0),size,Vector2(0,size.y)]:
			var rotated: Vector2 = (p-center).rotated(safe_angle)
			low = low.min(rotated)
			high = high.max(rotated)
			points.append(rotated)
		validation = points.duplicate()
	var search := PackedVector2Array()
	var stride := maxi(1,ceili(points.size()/240.0))
	for n in range(0,points.size(),stride):
		search.append(points[n])
	var result := {"angle":safe_angle,"image_size":size,"image_center":center,"bounds":Rect2(low,high-low),"points":points,"search_points":search,"validation_points":validation,"sample_step":step,"empty":empty}
	# Strict fitting only needs the silhouette. Avoid retaining every alpha pixel
	# for four orientations of the larger complete sprites in the game cache.
	if include_mass:result.merge(_mass_analysis(mass_raw,mass_weights,center,safe_angle,size))
	return result

static func _empty_fit(angle: float = 0.0) -> Dictionary:
	var safe_angle := angle if is_finite(angle) else 0.0
	return {"position":Vector2.ZERO,"scale":0.0,"angle":safe_angle,"source_size":Vector2.ONE,"transform":Transform2D(safe_angle,Vector2.ZERO,0.0,Vector2.ZERO),"mode":"empty"}

static func _result(desc: Dictionary, center: Vector2, scale: float, padding: float, mode: String) -> Dictionary:
	var position: Vector2 = center-Vector2(desc.image_center).rotated(float(desc.angle))*scale
	var transform := Transform2D(float(desc.angle),Vector2.ONE*scale,0.0,position)
	return {"position":position,"scale":scale,"angle":float(desc.angle),"source_size":Vector2(desc.image_size),"center":center,"bounds":Rect2(center+desc.bounds.position*scale,desc.bounds.size*scale),"transform":transform,"padding":padding,"mode":mode}

static func _inside_cell(point: Vector2, cell: Vector2i, owned: Dictionary, pitch: float, padding: float) -> bool:
	if not owned.has(cell):
		return false
	var local := point-Vector2(cell)*pitch
	var epsilon := .002
	if local.x < -epsilon or local.y < -epsilon or local.x > pitch+epsilon or local.y > pitch+epsilon: return false
	if local.x < padding-epsilon and not owned.has(cell+Vector2i.LEFT): return false
	if local.y < padding-epsilon and not owned.has(cell+Vector2i.UP): return false
	if local.x > pitch-padding+epsilon and not owned.has(cell+Vector2i.RIGHT): return false
	if local.y > pitch-padding+epsilon and not owned.has(cell+Vector2i.DOWN): return false
	return true

static func _owned(point: Vector2, owned: Dictionary, pitch: float, padding: float) -> bool:
	var cell := Vector2i(floori(point.x/pitch),floori(point.y/pitch))
	if _inside_cell(point,cell,owned,pitch,padding):
		return true
	# Polygon boundaries are closed. At zero padding an alpha pixel corner may
	# lie on the right/bottom edge whose floor() happens to select an absent cell.
	var local := point-Vector2(cell)*pitch
	if local.x < .002 and _inside_cell(point,cell+Vector2i.LEFT,owned,pitch,padding): return true
	if local.y < .002 and _inside_cell(point,cell+Vector2i.UP,owned,pitch,padding): return true
	if local.x < .002 and local.y < .002 and _inside_cell(point,cell+Vector2i(-1,-1),owned,pitch,padding): return true
	return false

static func _contains(points: PackedVector2Array, center: Vector2, scale: float, owned: Dictionary, pitch: float, padding: float) -> bool:
	for point in points:
		if not _owned(point*scale+center,owned,pitch,padding):
			return false
	return true

static func _rectangles(cells: Array[Vector2i], owned: Dictionary, pitch: float) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for cell in cells:
		var width := 2147483647
		var rows := 0
		while owned.has(cell+Vector2i(0,rows)):
			var row_width := 0
			while owned.has(cell+Vector2i(row_width,rows)):
				row_width += 1
			width = mini(width,row_width)
			rows += 1
			result.append(Rect2(Vector2(cell)*pitch,Vector2(width,rows)*pitch))
	return result

static func _find_position(scale: float, bounds: Rect2, shape: Rect2, desc: Dictionary, owned: Dictionary, pitch: float, padding: float, anchors: Array[Vector2]) -> Array:
	var low := shape.position+Vector2.ONE*padding-bounds.position*scale
	var high := shape.end-Vector2.ONE*padding-bounds.end*scale
	if high.x < low.x-.002 or high.y < low.y-.002:
		return []
	high = high.max(low)
	var candidates: Array[Vector2] = [(low+high)*.5]
	for anchor in anchors:
		var p := anchor-bounds.get_center()*scale
		candidates.append(Vector2(clampf(p.x,low.x,high.x),clampf(p.y,low.y,high.y)))
	# Translation search spans the real polyomino, including its elbows and arms.
	for y in range(7):
		for x in range(7):
			candidates.append(low+(high-low)*Vector2(x/6.0,y/6.0))
	var seen: Dictionary = {}
	for center in candidates:
		if seen.has(center):
			continue
		seen[center] = true
		if _contains(desc.search_points,center,scale,owned,pitch,padding) and _contains(desc.validation_points,center,scale,owned,pitch,padding):
			return [center]
	return []

static func fit(cells: Array, desc: Dictionary, pitch: float, padding: float = 3.0) -> Dictionary:
	var angle := float(desc.get("angle",0.0))
	if not is_finite(pitch) or pitch <= 0.0 or not is_finite(padding) or not is_finite(angle):
		return _empty_fit()
	for key in ["bounds","points","search_points","validation_points","image_size","image_center"]:
		if not desc.has(key):
			return _empty_fit(angle)
	var bounds: Rect2 = desc.bounds
	if not bounds.position.is_finite() or not bounds.size.is_finite() or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return _empty_fit(angle)
	var unique: Array[Vector2i] = GRID._cells(cells)
	if unique.is_empty():
		return _empty_fit(angle)
	var margin := clampf(padding,0.0,pitch*.45)
	var owned: Dictionary = {}
	var low := unique[0]
	var high := low+Vector2i.ONE
	var centroid := Vector2.ZERO
	var anchors: Array[Vector2] = []
	for cell in unique:
		owned[cell] = true
		low = low.min(cell)
		high = high.max(cell+Vector2i.ONE)
		var center := (Vector2(cell)+Vector2.ONE*.5)*pitch
		centroid += center
		anchors.append(center)
	centroid /= unique.size()
	anchors.push_front(centroid)
	var shape := Rect2(Vector2(low)*pitch,Vector2(high-low)*pitch)
	var rectangles := _rectangles(unique,owned,pitch)
	var best_scale := 0.0
	var best_center := Vector2.ZERO
	var best_distance := INF
	for rect in rectangles:
		var target := rect.grow(-margin)
		var scale := minf(target.size.x/bounds.size.x,target.size.y/bounds.size.y)
		var center := target.get_center()-bounds.get_center()*scale
		var distance := target.get_center().distance_squared_to(centroid)
		anchors.append(rect.get_center())
		if scale > best_scale+.00001 or (is_equal_approx(scale,best_scale) and distance < best_distance):
			best_scale = scale
			best_center = center
			best_distance = distance
	var result := _result(desc,best_center,best_scale,margin,"rectangle")
	var upper := minf((shape.size.x-margin*2.0)/bounds.size.x,(shape.size.y-margin*2.0)/bounds.size.y)
	if unique.size() == (high.x-low.x)*(high.y-low.y) or upper <= best_scale+.0001:
		return result
	var position := _find_position(upper,bounds,shape,desc,owned,pitch,margin,anchors)
	if not position.is_empty():
		return _result(desc,position[0],upper,margin,"silhouette")
	var lower := best_scale
	for _iteration in range(8):
		var scale := (lower+upper)*.5
		position = _find_position(scale,bounds,shape,desc,owned,pitch,margin,anchors)
		if position.is_empty():
			upper = scale
		else:
			lower = scale
			result = _result(desc,position[0],scale,margin,"silhouette")
	return result

static func _mass_score(points: PackedVector2Array, weights: PackedByteArray, protected: PackedByteArray, total: float, core_total: float, center: Vector2, scale: float, owned: Dictionary, pitch: float, max_loss: float, core_loss: float, early: bool = false) -> Dictionary:
	var lost := 0.0
	var core_lost := 0.0
	for n in range(points.size()):
		var at := points[n]*scale+center
		var cell := Vector2i(floori(at.x/pitch),floori(at.y/pitch))
		if not owned.has(cell):
			lost += weights[n]
			if protected[n]: core_lost += weights[n]
			if early and (lost > total*max_loss or core_lost > core_total*core_loss):
				return {"retained":0.0,"protected":0.0,"legal":false}
	return {"retained":1.0-lost/total if total > 0.0 else 1.0,"protected":1.0-core_lost/core_total if core_total > 0.0 else 1.0,"legal":lost <= total*max_loss and core_lost <= core_total*core_loss}

static func _readable_position(scale: float, bounds: Rect2, shape: Rect2, desc: Dictionary, owned: Dictionary, pitch: float, padding: float, budget: float) -> Array:
	var low := shape.position+Vector2.ONE*padding-bounds.position*scale
	var high := shape.end-Vector2.ONE*padding-bounds.end*scale
	if high.x < low.x-.002 or high.y < low.y-.002: return []
	high = high.max(low)
	var best: Array = []
	var retained := -1.0
	for y in range(9):
		for x in range(9):
			var center := low+(high-low)*Vector2(x/8.0,y/8.0)
			var score := _mass_score(desc.mass_samples,desc.mass_sample_weights,desc.mass_sample_protected,desc.mass_sample_total,desc.mass_sample_core_total,center,scale,owned,pitch,maxf(0.0,budget-.001),.004,true)
			if score.legal and score.retained > retained:
				retained = score.retained
				best = [center]
	return best

static func _readable_metadata(fitted: Dictionary, baseline: Dictionary, score: Dictionary, budget: float, verified: bool) -> Dictionary:
	var result := fitted.duplicate(false)
	result["mode"] = "empty" if float(fitted.scale) <= 0.0 else ("readable" if float(fitted.scale) > float(baseline.scale)*1.05 else "strict")
	result["strict_mode"] = baseline.mode
	result["strict_scale"] = float(baseline.scale)
	result["retained_mass"] = float(score.retained)
	result["protected_mass"] = float(score.protected)
	result["max_loss"] = budget
	result["mass_verified"] = verified
	return result

static func readable_fit(cells: Array, desc: Dictionary, pitch: float, padding: float = 3.0, max_loss: float = .08) -> Dictionary:
	## Optional enlargement: at most8% of all nonzero alpha mass may be clipped,
	## while >=99.5% of the radial central75% mass remains. This geometric proxy
	## does not identify faces. fit() remains the strict default for every caller.
	var unknown := {"retained":1.0,"protected":1.0}
	var empty := _empty_fit()
	if not is_finite(max_loss): return _readable_metadata(empty,empty,unknown,0.0,false)
	var budget := clampf(max_loss,0.0,.08)
	var baseline := fit(cells,desc,pitch,padding)
	if float(baseline.scale) <= 0.0 or not baseline.position.is_finite():
		return _readable_metadata(empty,empty,unknown,budget,false)
	for key in ["mass_points","mass_weights","mass_protected","mass_total","mass_protected_total","mass_samples","mass_sample_weights","mass_sample_protected","mass_sample_total","mass_sample_core_total"]:
		if not desc.has(key): return _readable_metadata(baseline,baseline,unknown,budget,false)
	if desc.mass_points.size() != desc.mass_weights.size() or desc.mass_points.size() != desc.mass_protected.size() or desc.mass_samples.size() != desc.mass_sample_weights.size() or desc.mass_samples.size() != desc.mass_sample_protected.size():
		return _readable_metadata(baseline,baseline,unknown,budget,false)
	var owned: Dictionary = {}
	var unique: Array[Vector2i] = GRID._cells(cells)
	var low := unique[0]
	var high := low+Vector2i.ONE
	for cell in unique:
		owned[cell] = true
		low = low.min(cell)
		high = high.max(cell+Vector2i.ONE)
	var baseline_score := _mass_score(desc.mass_points,desc.mass_weights,desc.mass_protected,desc.mass_total,desc.mass_protected_total,baseline.center,baseline.scale,owned,pitch,budget,.005)
	var fallback := _readable_metadata(baseline,baseline,baseline_score,budget,true)
	if budget <= 0.0 or desc.mass_total <= 0.0 or desc.mass_sample_total <= 0.0 or desc.mass_sample_core_total <= 0.0: return fallback
	var margin: float = baseline.padding
	var bounds: Rect2 = desc.bounds
	var shape := Rect2(Vector2(low)*pitch,Vector2(high-low)*pitch)
	var upper := minf((shape.size.x-margin*2.0)/bounds.size.x,(shape.size.y-margin*2.0)/bounds.size.y)
	if not is_finite(upper) or upper <= float(baseline.scale)*1.05: return fallback
	var proposals: Array = []
	var best_scale: float = baseline.scale
	var interval := (upper-best_scale)/20.0
	for n in range(1,21):
		var scale := float(baseline.scale)+interval*n
		var position := _readable_position(scale,bounds,shape,desc,owned,pitch,margin,budget)
		if not position.is_empty():
			proposals.append({"scale":scale,"center":position[0]})
			best_scale = scale
	for _refinement in range(4):
		interval *= .5
		var scale := minf(upper,best_scale+interval)
		var position := _readable_position(scale,bounds,shape,desc,owned,pitch,margin,budget)
		if not position.is_empty():
			proposals.append({"scale":scale,"center":position[0]})
			best_scale = scale
	proposals.sort_custom(func(a: Dictionary,b: Dictionary): return a.scale > b.scale)
	for proposal in proposals:
		if float(proposal.scale) <= float(baseline.scale)*1.05: break
		# Full cached pixel-center mass validation makes sampled search conservative.
		# No Image reads, resampling, alpha editing, or per-frame source analysis.
		var exact := _mass_score(desc.mass_points,desc.mass_weights,desc.mass_protected,desc.mass_total,desc.mass_protected_total,proposal.center,proposal.scale,owned,pitch,budget,.005)
		if exact.legal:
			return _readable_metadata(_result(desc,proposal.center,proposal.scale,margin,"readable"),baseline,exact,budget,true)
	return fallback

static func _clip_patches(size: Vector2, cells: Array, pitch: float, fitted: Dictionary) -> Array:
	var result: Array = []
	if not size.is_finite() or size.x <= 0.0 or size.y <= 0.0 or not is_finite(pitch) or pitch <= 0.0:
		return result
	var raw_position: Variant = fitted.get("position",Vector2.ZERO)
	if not raw_position is Vector2 or not raw_position.is_finite():
		return result
	var scale := float(fitted.get("scale",0.0))
	var angle := float(fitted.get("angle",0.0))
	if not is_finite(scale) or scale <= 0.0 or not is_finite(angle):
		return result
	var transform := Transform2D(angle,Vector2.ONE*scale,0.0,raw_position)
	var inverse := transform.affine_inverse()
	var quad := PackedVector2Array([transform*Vector2.ZERO,transform*Vector2(size.x,0),transform*size,transform*Vector2(0,size.y)])
	for point in quad:
		if not point.is_finite():
			return result
	for cell in GRID._cells(cells):
		var a := Vector2(cell)*pitch
		var clip := PackedVector2Array([a,a+Vector2(pitch,0),a+Vector2.ONE*pitch,a+Vector2(0,pitch)])
		for polygon in Geometry2D.intersect_polygons(quad,clip):
			if polygon.size() < 3 or Geometry2D.triangulate_polygon(polygon).is_empty():
				continue
			var uv := PackedVector2Array()
			for point in polygon:
				var source_pixel: Vector2 = inverse*point
				uv.append(Vector2(clampf(source_pixel.x/size.x,0.0,1.0),clampf(source_pixel.y/size.y,0.0,1.0)))
			result.append({"polygon":polygon,"uv":uv})
	return result

static func draw(canvas: CanvasItem, texture: Texture2D, cells: Array, origin: Vector2, pitch: float, fitted: Dictionary, tint: Color = Color.WHITE) -> void:
	if not is_instance_valid(canvas) or not is_instance_valid(texture) or not origin.is_finite():
		return
	for patch in _clip_patches(texture.get_size(),cells,pitch,fitted):
		var points := PackedVector2Array()
		for point in patch.polygon:
			points.append(origin+point)
		canvas.draw_polygon(points,PackedColorArray([tint]),patch.uv,texture)
