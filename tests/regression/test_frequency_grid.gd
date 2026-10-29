extends SceneTree
## QA-only geometry / projection tests. This scene never constructs storage or a run.
const INVENTORY = preload("res://scripts/inventory/inventory.gd")
const CATALOG = preload("res://scripts/data/catalog.gd")
var grid: Script
var projection: Script
var checks := 0
var failures := 0
var catalog_fixtures: Array = []
var synthetic_fixtures: Array = []
var readable_fixtures: Array = []
var started_usec := Time.get_ticks_usec()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	for path in ["res://scripts/ui/pockets/frequency_grid.gd", "res://scripts/ui/items/icon_projection.gd"]:
		check(ResourceLoader.exists(path), "required native presentation helper exists: " + path)
	if failures:
		finish_without_render()
		return
	grid = load("res://scripts/ui/pockets/frequency_grid.gd")
	projection = load("res://scripts/ui/items/icon_projection.gd")
	test_edges_and_rects()
	test_rounded_surface()
	if "--grid-only" in OS.get_cmdline_user_args():
		call_deferred("render_tech_gallery")
		return
	test_silhouettes()
	test_clipping()
	test_catalog()
	test_readable_fit()
	call_deferred("render_gallery")

func test_edges_and_rects() -> void:
	var draw_args := 0
	for method in grid.get_script_method_list():
		if method.name == "draw": draw_args = method.args.size()
	check(draw_args == 6,"grid draw offers trailing optional alpha for stage transitions")
	var cells: Array = [[0,0], Vector2i(1,0), [0,0], null, [1], [0.5,1], ["x",2]]
	var all: Array = grid.edges(cells)
	check(all.size() == 7, "two adjacent cells deduplicate to seven unique edges")
	check(grid.edges(cells, true).size() == 6, "shared edge excluded from exterior")
	var shared := 0
	var seen: Dictionary = {}
	for edge in all:
		check(edge.size() == 2 and edge[0] is Vector2 and edge[1] is Vector2, "edges use cell-unit Vector2 endpoints")
		var key := str(edge[0]) + ":" + str(edge[1])
		check(not seen.has(key), "an undirected edge is emitted once")
		seen[key] = true
		if edge[0].x == 1 and edge[1].x == 1:
			shared += 1
	check(shared == 1, "adjacent modules share one grid stroke")
	var elbow: Array = [[0,0], [0,1], [1,1]]
	var tee: Array = [[0,0], [1,0], [2,0], [1,1]]
	check(grid.edges(elbow).size() == 10 and grid.edges(elbow, true).size() == 8, "L exterior follows the unowned corner")
	check(grid.edges(tee).size() == 13 and grid.edges(tee, true).size() == 10, "T exterior has no rectangular enclosure")
	var ring: Array = [[0,0], [1,0], [2,0], [0,1], [2,1], [0,2], [1,2], [2,2]]
	check(grid.edges(ring, true).size() == 16, "ring retains both outer and inner boundaries")
	for shape in [cells, elbow, tee, ring]:
		var rects: Array = grid.cell_rects(Vector2(7,11), shape, 40.0, 1.0)
		for i in range(rects.size()):
			check(rects[i].size == Vector2(38,38), "cell inset stays within its true boundary")
			for j in range(i):
				check(not rects[i].intersects(rects[j], false), "adjacent rect interiors do not overlap")
		for hole in [Vector2(1.5,0.5), Vector2(2.5,1.5)]:
			if not grid._cells(shape).has(Vector2i(int(hole.x),int(hole.y))):
				check(rects.all(func(r: Rect2): return not r.has_point(Vector2(7,11) + hole * 40.0)), "unowned L/T cell is outside the fill geometry")
	check(grid.cell_rects(Vector2.ZERO, cells, 0.0).is_empty(), "invalid pitch gives no cell geometry")
	check(grid.cell_rects(Vector2.ZERO, [[0,0]], 4.0, 99.0).is_empty(), "overlarge inset does not invert a rect")
	grid.draw(null, Vector2.ZERO, cells, 40.0)
	grid.footprint(null, Vector2.ZERO, elbow, 40.0, Color.WHITE)

func test_rounded_surface() -> void:
	check(grid.has_method("_surface_geometry"),"rounded merged array provides bounded surface geometry")
	if not grid.has_method("_surface_geometry"): return
	var shapes: Array = [[[0,0]],[[0,0],[1,0],[0,0]],[[0,0],[0,1],[1,1]],[[0,0],[1,0],[2,0],[1,1]],[[0,0],[1,0],[2,0],[0,1],[2,1],[0,2],[1,2],[2,2]]]
	for shape in shapes:
		for pitch in [16.0,25.0,56.0]:
			var geometry: Array = grid._surface_geometry(shape,pitch)
			check(geometry.size() == grid._cells(shape).size(),"rounded fill emits each unique owned cell once")
			for part in geometry:
				check(part.radius > 0.0 and part.radius <= pitch*.10,"convex rounding remains modest")
				check(not Geometry2D.triangulate_polygon(part.polygon).is_empty(),"rounded cell polygon triangulates")
				var low: Vector2 = Vector2(part.cell)*pitch
				for point in part.polygon:
					check(point.is_finite() and point.x >= low.x-.001 and point.y >= low.y-.001 and point.x <= low.x+pitch+.001 and point.y <= low.y+pitch+.001,"rounded vertices stay inside true owned cell")
				check(Geometry2D.is_point_in_polygon(low+Vector2.ONE*pitch*.5,part.polygon),"rounding preserves every owned cell center")
			for point in [Vector2(1.5,.5),Vector2(1.5,1.5),Vector2(2.5,1.5)]:
				if not grid._cells(shape).has(Vector2i(int(point.x),int(point.y))):
					check(geometry.all(func(part: Dictionary):return not Geometry2D.is_point_in_polygon(point*pitch,part.polygon)),"rounded L/T/ring still excludes unowned cells")
	var single: Array = grid._surface_geometry([[0,0]],56.0)
	check(not Geometry2D.is_point_in_polygon(Vector2(.5,.5),single[0].polygon),"exposed convex corner is actually rounded inward")
	var pair: Array = grid._surface_geometry([[0,0],[1,0]],56.0)
	check(Geometry2D.is_point_in_polygon(Vector2(55.5,.5),pair[0].polygon) and Geometry2D.is_point_in_polygon(Vector2(56.5,.5),pair[1].polygon),"internal module join stays continuous without corner cuts")
	check(grid._surface_geometry([[0,0]],INF).is_empty(),"invalid rounded-surface pitch emits no geometry")

class TechGallery extends Node2D:
	var grid: Script
	var shapes: Array
	var background := Color("f2efe4")
	func _draw() -> void:
		draw_rect(Rect2(0,0,1160,800),background)
		draw_string(ThemeDB.fallback_font,Vector2(24,33),"Merged rounded 2D array / plain placement shadows",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("244b4e"))
		for shape in shapes:
			draw_string(ThemeDB.fallback_font,shape.origin-Vector2(0,16),shape.label,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("244b4e"))
			grid.draw(self,shape.origin,shape.cells,56.0)
		draw_string(ThemeDB.fallback_font,Vector2(24,486),"Plain drag shadow",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("244b4e"))
		grid.footprint(self,Vector2(24,506),[[0,0],[0,1],[1,1]],56.0,Color(.45,.78,.62,.42),false)
		draw_string(ThemeDB.fallback_font,Vector2(192,486),"Explicit selected shadow only",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("244b4e"))
		grid.footprint(self,Vector2(192,506),[[0,0],[1,0],[2,0],[1,1]],56.0,Color(.9,.45,.4,.42),true)
		for fixture in [[Vector2(536,536),0.0,"alpha0"],[Vector2(670,536),INF,"invalid alpha"],[Vector2(802,536),-1.0,"clamped alpha"]]:
			draw_string(ThemeDB.fallback_font,fixture[0]-Vector2(0,16),fixture[2],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("244b4e"))
			grid.draw(self,fixture[0],[[0,0],[1,0],[0,1],[1,1]],36.0,false,fixture[1])
		grid.draw(self,Vector2(536,644),[[0,0],[1,0],[0,1],[1,1]],36.0,false,.5)
		draw_string(ThemeDB.fallback_font,Vector2(536,628),"half alpha",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("244b4e"))
		draw_set_transform_matrix(Transform2D(.13,Vector2.ONE*.85,0.0,Vector2(946,560)))
		grid.draw(self,Vector2.ZERO,[[0,0],[1,0],[0,1]],36.0)
		draw_rect(Rect2(0,90,10,10),Color("24a9ff"))
		draw_set_transform_matrix(Transform2D.IDENTITY)

func render_tech_gallery() -> void:
	var merged: Array = []
	for y in range(3):
		for x in range(6): merged.append([x,y])
	merged.append_array([[6,1],[6,2],[7,2],[2,3],[3,3],[4,3],[3,4],[0,0],null])
	var gallery := TechGallery.new()
	gallery.grid = grid
	gallery.shapes = [{"origin":Vector2(24,96),"cells":merged,"label":"One merged array, shared boundaries"},{"origin":Vector2(536,96),"cells":[[0,0],[1,0],[2,0],[0,1],[1,1],[2,1]],"label":"Rounded rectangle"},{"origin":Vector2(776,96),"cells":[[0,0],[0,1],[1,1]],"label":"L contour"},{"origin":Vector2(536,284),"cells":[[0,0],[1,0],[2,0],[1,1]],"label":"T contour"},{"origin":Vector2(776,284),"cells":[[0,0],[1,0],[2,0],[0,1],[2,1],[0,2],[1,2],[2,2]],"label":"Ring retains inner hole"}]
	root.content_scale_size = Vector2i(1160,800)
	root.size = Vector2i(1160,800)
	root.add_child(gallery)
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var screenshot := root.get_texture().get_image()
		check(screenshot.save_png("/tmp/frequency-grid-tech-v5.png") == OK,"native rounded-tech gallery saved in QA tmp")
		check(screenshot.get_pixel(536,96).is_equal_approx(gallery.background),"native exposed convex corner is cut inward")
		check(not screenshot.get_pixel(546,106).is_equal_approx(gallery.background),"native interior immediately after rounded corner stays filled")
		var fill_color := screenshot.get_pixel(564,124)
		check(not screenshot.get_pixel(591,124).is_equal_approx(fill_color) or not screenshot.get_pixel(592,124).is_equal_approx(fill_color),"native shared grid remains visible at normal pitch")
		check(not screenshot.get_pixel(564,96).is_equal_approx(fill_color),"native inward perimeter remains visible at normal pitch")
		for shape in gallery.shapes:
			var high := Vector2i.ZERO
			var unique: Array = grid._cells(shape.cells)
			for cell in unique: high = high.max(cell+Vector2i.ONE)
			var outside_painted := 0
			for y in range(-2,high.y*56+2):
				for x in range(-2,high.x*56+2):
					var cell := Vector2i(floori((x+.5)/56.0),floori((y+.5)/56.0))
					if not unique.has(cell) and not screenshot.get_pixel(int(shape.origin.x)+x,int(shape.origin.y)+y).is_equal_approx(gallery.background): outside_painted += 1
			check(outside_painted == 0,shape.label+" native rounding/trace/ticks never paint holes or unowned cells")
		var shadow_color := screenshot.get_pixel(52,534)
		check(not shadow_color.is_equal_approx(gallery.background),"plain shadow is visible and translucent")
		var changed_pixels := 0
		for cell in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,1)]:
			for y in range(3,53,5):
				for x in range(3,53,5):
					if not screenshot.get_pixel(24+cell.x*56+x,506+cell.y*56+y).is_equal_approx(shadow_color): changed_pixels += 1
		check(changed_pixels == 0,"default placement shadow has no tracks, nodes, inner lines or attached frame")
		check(screenshot.get_pixel(108,534).is_equal_approx(gallery.background),"plain placement shadow preserves its L hole")
		for point in [Vector2i(554,554),Vector2i(688,554),Vector2i(820,554)]:
			check(screenshot.get_pixel(point.x,point.y).is_equal_approx(gallery.background),"alpha0/nonfinite/negative grid paint remains absent")
		var marker: Vector2 = Transform2D(.13,Vector2.ONE*.85,0.0,Vector2(946,560))*Vector2(5,95)
		check(screenshot.get_pixel(int(marker.x),int(marker.y)).b > .95,"rounded array preserves caller canvas transform")
	finish_without_render()

func make_image(size: Vector2i, rectangles: Array) -> Image:
	var source := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	source.fill(Color.TRANSPARENT)
	for rect in rectangles:
		source.fill_rect(rect, Color("ec68bd"))
	return source

func rotated_cells(cells: Array, turns: int) -> Array:
	var out: Array = []
	var low := Vector2i(100000,100000)
	for p in cells:
		var v := Vector2i(p[0],p[1])
		for _turn in range(turns):
			v = Vector2i(-v.y,v.x)
		out.append(v)
		low = low.min(v)
	return out.map(func(v: Vector2i): return v-low)

func owned(point: Vector2, cells: Array, pitch: float) -> bool:
	var at := Vector2i(floori(point.x/pitch),floori(point.y/pitch))
	for p in cells:
		var cell: Vector2i = p if p is Vector2i else Vector2i(p[0],p[1])
		if cell == at:
			return true
	return false

func verify_fit(source: Image, cells: Array, desc: Dictionary, fitted: Dictionary, pitch: float, label: String, exhaustive: bool = false) -> void:
	check(fitted.has("position") and fitted.has("scale") and fitted.has("angle"), label + " transform contract exists")
	check(fitted.position.is_finite() and is_finite(float(fitted.scale)) and is_finite(float(fitted.angle)), label + " finite transform")
	check(float(fitted.scale) > 0.0, label + " positive natural scale")
	var transform := Transform2D(float(fitted.angle),Vector2.ONE*float(fitted.scale),0.0,fitted.position)
	check(is_equal_approx(transform.x.length(),transform.y.length()), label + " aspect ratio is preserved")
	check(is_equal_approx(float(fitted.angle),float(desc.angle)), label + " descriptor rotation is retained")
	var outside := 0
	var sample_count := 0
	var stride := 1 if exhaustive else maxi(1,ceili(maxi(source.get_width(),source.get_height())/80.0))
	for y in range(0,source.get_height(),stride):
		for x in range(0,source.get_width(),stride):
			if source.get_pixel(x,y).a > 0.08:
				sample_count += 1
				if not owned(transform * Vector2(x+.5,y+.5),cells,pitch):
					outside += 1
	check(sample_count > 0 and outside == 0, label + " visible alpha samples remain in actual occupied cells (" + str(outside) + " outside)")

func test_silhouettes() -> void:
	var rect := make_image(Vector2i(96,64),[Rect2i(22,20,32,24)])
	var before := rect.get_data()
	var rect_desc: Dictionary = projection.descriptor(rect)
	check(rect.get_data() == before, "descriptor leaves the source pixels unchanged")
	check(rect_desc.image_size == Vector2(96,64), "descriptor retains original texture coordinates")
	check(rect_desc.bounds.size == Vector2(32,24), "transparent padding does not constrain fit bounds")
	var fitted: Dictionary = projection.fit([[0,0],[1,0]],rect_desc,48.0,3.0)
	verify_fit(rect,[[0,0],[1,0]],rect_desc,fitted,48.0,"offset rectangle",true)
	var transform := Transform2D(float(fitted.angle),Vector2.ONE*float(fitted.scale),0.0,fitted.position)
	check((transform * Vector2(38,32)).is_equal_approx(Vector2(48,24)), "translation centers visible art rather than the full texture")
	check(is_equal_approx(float(fitted.scale),42.0/24.0), "rectangle uses the largest natural scale")
	var elbow: Array = [[0,0],[0,1],[1,1]]
	var tee: Array = [[0,0],[1,0],[2,0],[1,1]]
	var l_image := make_image(Vector2i(96,96),[Rect2i(0,0,48,96),Rect2i(48,48,48,48)])
	var t_image := make_image(Vector2i(144,96),[Rect2i(0,0,144,48),Rect2i(48,48,48,48)])
	var bulky := make_image(Vector2i(96,96),[Rect2i(0,0,96,96)])
	var flush: Dictionary = projection.fit(elbow,projection.descriptor(l_image),48.0,0.0)
	check(is_equal_approx(float(flush.scale),1.0), "zero-padding L silhouette can reach the closed cell boundary at natural scale")
	for fixture in [[l_image,elbow,"L"],[t_image,tee,"T"],[bulky,elbow,"bulky fallback"]]:
		for turn in range(4):
			var source: Image = fixture[0]
			var shape := rotated_cells(fixture[1],turn)
			var desc: Dictionary = projection.descriptor(source,turn*PI/2.0)
			var fit: Dictionary = projection.fit(shape,desc,48.0,3.0)
			verify_fit(source,shape,desc,fit,48.0,str(fixture[2])+" turn "+str(turn),true)
			if fixture[2] != "bulky fallback":
				check(float(fit.scale) > .78, str(fixture[2])+" silhouette uses multiple branches beyond the largest rectangular slot")
			else:
				check(float(fit.scale) <= .50, "bulky square stays recognizable inside one legal branch")
			if turn == 0:
				synthetic_fixtures.append({"source":source,"cells":shape,"fit":fit,"label":fixture[2]})
	var slanted: Dictionary = projection.descriptor(rect,.35)
	var slanted_fit: Dictionary = projection.fit([[0,0],[1,0],[0,1],[1,1]],slanted,48.0,3.0)
	verify_fit(rect,[[0,0],[1,0],[0,1],[1,1]],slanted,slanted_fit,48.0,"arbitrary base angle",true)
	for args in [[[],rect_desc,48.0],[elbow,{},48.0],[elbow,rect_desc,0.0],[elbow,rect_desc,INF]]:
		var result: Dictionary = projection.fit(args[0],args[1],args[2])
		check(result.position.is_finite() and is_finite(float(result.scale)) and float(result.scale) == 0.0, "invalid fit inputs return a finite empty transform")
		check(result.transform.x == Vector2.ZERO and result.transform.y == Vector2.ZERO, "empty transform agrees with its zero scale")
	var empty_desc: Dictionary = projection.descriptor(Image.create(8,8,false,Image.FORMAT_RGBA8))
	var empty_fit: Dictionary = projection.fit([[0,0]],empty_desc,48.0)
	check(empty_desc.bounds.size == Vector2(8,8) and float(empty_fit.scale) > 0.0, "fully transparent image has a finite rectangular fallback")
	projection.draw(null,null,elbow,Vector2.ZERO,48.0,fitted)

func polygon_area(polygon: PackedVector2Array) -> float:
	var sum := 0.0
	for n in range(polygon.size()):
		sum += polygon[n].cross(polygon[(n+1)%polygon.size()])
	return absf(sum)*.5

func test_clipping() -> void:
	var fixtures: Array = [
		[[0,0],[0,1],[1,1]],
		[[0,0],[1,0],[2,0],[1,1]],
		[[0,0],[1,0],[2,0],[0,1],[2,1],[0,2],[1,2],[2,2]]
	]
	for cells in fixtures:
		var patches: Array = projection._clip_patches(Vector2(192,192),cells,48.0,{"position":Vector2.ZERO,"scale":1.0,"angle":0.0})
		check(patches.size() == cells.size(), "oversized texture clips to each unique owned cell")
		var area := 0.0
		for patch in patches:
			area += polygon_area(patch.polygon)
			var center := Vector2.ZERO
			for point in patch.polygon:
				center += point
				check(point.is_finite(), "clipped polygon vertices are finite")
			center /= patch.polygon.size()
			check(owned(center,cells,48.0), "each clip polygon lies in an owned cell")
			for n in range(patch.polygon.size()):
				check(owned(center.lerp(patch.polygon[n],.99),cells,48.0), "clip polygon interior excludes holes")
			for uv in patch.uv:
				check(uv.is_finite() and uv.x >= 0.0 and uv.y >= 0.0 and uv.x <= 1.0 and uv.y <= 1.0, "inverse-source UV remains finite and within the original texture")
		check(is_equal_approx(area,cells.size()*48.0*48.0), "clip area equals the occupied polyomino and excludes all holes")
	check(projection._clip_patches(Vector2(96,96),[[0,0]],48.0,{"position":Vector2.ZERO,"scale":0.0,"angle":0.0}).is_empty(), "zero-scale art gives no clipped polygons")

func test_catalog() -> void:
	var inventory := INVENTORY.new()
	var kinds := 0
	for kind in CATALOG.items:
		if CATALOG.is_tag(kind,"bag"):
			continue
		var path: String = "res://" + str(CATALOG.items[kind].get("asset_path","")).trim_prefix("res://")
		var source := Image.new()
		var load_error := source.load(ProjectSettings.globalize_path(path))
		check(load_error == OK, str(kind) + " original file opens without changing import state")
		check(source != null and not source.is_empty(), str(kind) + " original catalog art loads")
		if source == null or source.is_empty():
			continue
		kinds += 1
		var base_angle := float(CATALOG.items[kind].get("draw_hint",{}).get("angle_radians",0.0))
		for turn in range(4):
			var cells: Array = inventory.cells({"kind":kind,"rotation":turn})
			var desc: Dictionary = projection.descriptor(source,base_angle+turn*PI/2.0)
			var fit: Dictionary = projection.fit(cells,desc,48.0,3.0)
			verify_fit(source,cells,desc,fit,48.0,str(kind)+" turn "+str(turn),true)
			if turn == kinds%4:
				catalog_fixtures.append({"kind":kind,"source":source,"cells":cells,"desc":desc,"fit":fit,"turn":turn})
	var expected_kinds=CATALOG.items.keys().filter(func(k):return not CATALOG.is_tag(k,"bag")).size()
	check(kinds == expected_kinds, "all actual non-bag catalog images are tested at four rotations")

func exact_mass(source: Image, cells: Array, desc: Dictionary, fitted: Dictionary, pitch: float) -> Dictionary:
	var transform := Transform2D(float(fitted.angle),Vector2.ONE*float(fitted.scale),0.0,fitted.position)
	var data := source.get_data()
	var total := 0.0
	var kept := 0.0
	var protected_total := 0.0
	var protected_kept := 0.0
	for y in range(source.get_height()):
		for x in range(source.get_width()):
			var alpha := float(data[(y*source.get_width()+x)*4+3])
			if alpha <= 0.0: continue
			var point := Vector2(x+.5,y+.5)
			var protected: bool = point.distance_squared_to(desc.mass_centroid_source) <= float(desc.protected_radius_squared)
			var inside := owned(transform*point,cells,pitch)
			total += alpha
			if inside: kept += alpha
			if protected:
				protected_total += alpha
				if inside: protected_kept += alpha
	return {"retained":kept/total,"protected":protected_kept/protected_total,"protected_fraction":protected_total/total}

func test_readable_fit() -> void:
	check(projection.has_method("readable_fit"), "optional bounded readable_fit API exists")
	if not projection.has_method("readable_fit"):
		return
	var inventory := INVENTORY.new()
	var live_inventory := INVENTORY.new()
	# The optional clipping API still needs its original concave fixtures.
	# V53 live echoes are complete rectangles and must retain the strict fit.
	inventory.footprint_catalogue=JSON.parse_string(FileAccess.get_file_as_string("res://data/compat/catalog-pre-v53.json")).items
	for kind in ["feilian","inferno","thundering","puppet"]:
		var source := Image.new()
		source.load(ProjectSettings.globalize_path("res://"+str(CATALOG.items[kind].asset_path)))
		source.convert(Image.FORMAT_RGBA8)
		var original := source.get_data()
		for turn in range(4):
			var cells: Array = inventory.cells({"kind":kind,"rotation":turn})
			var desc: Dictionary = projection.descriptor(source,turn*PI/2.0)
			var current_cells: Array = live_inventory.cells({"kind":kind,"rotation":turn})
			var current_strict: Dictionary = projection.fit(current_cells,desc,56.0)
			var current_readable: Dictionary = projection.readable_fit(current_cells,desc,56.0)
			check(current_readable.mode=="strict" and current_readable.scale==current_strict.scale and current_readable.position==current_strict.position,kind+" V53 rectangle R"+str(turn)+" keeps complete strict projection")
			var strict: Dictionary = projection.fit(cells,desc,56.0)
			var readable: Dictionary = projection.readable_fit(cells,desc,56.0)
			var label: String = kind+" readable R"+str(turn)
			check(readable.position.is_finite() and is_finite(float(readable.scale)) and readable.scale > strict.scale*1.05, label+" provides >5% bounded enlargement")
			check(readable.mode == "readable", label+" reports its optional clipping mode")
			check(is_equal_approx(float(readable.angle),float(strict.angle)) and is_equal_approx(readable.transform.x.length(),readable.transform.y.length()), label+" preserves rotation and aspect")
			var mass := exact_mass(source,cells,desc,readable,56.0)
			check(float(mass.retained) >= .92, label+" retains >=92% of ALL nonzero alpha mass")
			check(float(mass.protected) >= .995, label+" retains >=99.5% of protected central mass")
			check(float(mass.protected_fraction) >= .75, label+" protects at least the radial central75% of source alpha mass")
			check(is_equal_approx(float(readable.retained_mass),float(mass.retained)) and is_equal_approx(float(readable.protected_mass),float(mass.protected)), label+" reports exact cached-source mass retention")
			var no_loss: Dictionary = projection.readable_fit(cells,desc,56.0,3.0,0.0)
			check(no_loss.position == strict.position and no_loss.scale == strict.scale and no_loss.mode == "strict", label+" zero loss budget preserves strict baseline")
			var capped: Dictionary = projection.readable_fit(cells,desc,56.0,3.0,1.0)
			check(capped.max_loss <= .08 and capped.retained_mass >= .92, label+" budget cannot exceed8%")
			for patch in projection._clip_patches(source.get_size(),cells,56.0,readable):
				var center := Vector2.ZERO
				for point in patch.polygon: center += point
				center /= patch.polygon.size()
				check(owned(center,cells,56.0), label+" clipped image patch stays in owned cell")
				for point in patch.polygon:
					check(owned(center.lerp(point,.99),cells,56.0), label+" clip excludes L/T holes")
				for uv in patch.uv: check(uv.is_finite(),label+" clipped UV remains finite")
			readable_fixtures.append({"kind":kind,"turn":turn,"source":source,"cells":cells,"desc":desc,"strict":strict,"readable":readable})
		check(source.get_data() == original,kind+" optional fitting never edits source pixels")
	var desc: Dictionary = projection.descriptor(make_image(Vector2i(32,32),[Rect2i(0,0,32,32)]))
	for args in [[[],desc,56.0,3.0,.08],[[[0,0]],{},56.0,3.0,.08],[[[0,0]],desc,INF,3.0,.08],[[[0,0]],desc,56.0,INF,.08],[[[0,0]],desc,56.0,3.0,INF]]:
		var result: Dictionary = projection.readable_fit(args[0],args[1],args[2],args[3],args[4])
		check(result.position.is_finite() and is_finite(float(result.scale)) and result.scale == 0.0,"invalid readable inputs produce finite empty fit")
	var transparent: Dictionary = projection.descriptor(Image.create(8,8,false,Image.FORMAT_RGBA8))
	var empty: Dictionary = projection.readable_fit([[0,0]],transparent,56.0)
	check(empty.mode == "strict" and empty.retained_mass == 1.0 and empty.protected_mass == 1.0,"transparent source keeps finite strict fallback")
	var rectangle: Dictionary = projection.readable_fit([[0,0]],desc,56.0)
	check(rectangle.mode == "strict" and rectangle.scale == projection.fit([[0,0]],desc,56.0).scale,"rectangular footprint preserves natural strict fit")

class Gallery extends Node2D:
	var grid: Script
	var projection: Script
	var fixtures: Array
	var synthetic: Array
	var textures: Array = []
	var clip_texture: Texture2D
	var background := Color("f2efe4")
	func _draw() -> void:
		draw_rect(Rect2(0,0,1600,1180),background)
		draw_string(ThemeDB.fallback_font,Vector2(24,30),"Native 2D frequency grid / alpha silhouette projection",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("244b4e"))
		var joined: Array = [[0,0],[1,0],[2,0],[0,1],[1,1],[2,1],[3,1],[3,2],[4,2],[0,2],[1,2],[2,2]]
		grid.draw(self,Vector2(24,62),joined,44.0)
		grid.footprint(self,Vector2(24,62),[[0,0],[1,0],[2,0]],44.0,Color("e4ead3"))
		grid.footprint(self,Vector2(24,62),[[0,1],[0,2],[1,2]],44.0,Color("d7e8e6"),true)
		grid.draw(self,Vector2(270,62),[[0,0],[1,0],[2,0],[0,1],[2,1],[0,2],[1,2],[2,2]],38.0,true)
		for i in range(synthetic.size()):
			var fixture: Dictionary = synthetic[i]
			var at := Vector2(418+i*180,66)
			grid.draw(self,at,fixture.cells,48.0)
			grid.footprint(self,at,fixture.cells,48.0,Color("e9dce6"))
			projection.draw(self,textures[fixtures.size()+i],fixture.cells,at,48.0,fixture.fit)
			draw_string(ThemeDB.fallback_font,at+Vector2(0,136),fixture.label,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("244b4e"))
		# Deliberately oversized art proves exact clipping even when fitting is bypassed.
		projection.draw(self,clip_texture,[[0,0],[0,1],[1,1]],Vector2(1010,66),48.0,{"position":Vector2.ZERO,"scale":1.0,"angle":0.0})
		# Both helpers must retain a caller-established transform.
		draw_set_transform_matrix(Transform2D(.12,Vector2(.7,.7),0.0,Vector2(1240,58)))
		grid.draw(self,Vector2.ZERO,[[0,0],[1,0],[0,1]],48.0)
		projection.draw(self,clip_texture,[[0,0],[1,0],[0,1]],Vector2.ZERO,48.0,{"position":Vector2.ZERO,"scale":1.0,"angle":0.0})
		draw_rect(Rect2(0,110,10,10),Color("24a9ff"))
		draw_set_transform_matrix(Transform2D.IDENTITY)
		var has_alpha := false
		for method in grid.get_script_method_list():
			if method.name == "draw" and method.args.size() == 6: has_alpha = true
		if has_alpha:
			grid.draw(self,Vector2(1160,206),[[0,0],[1,0]],18.0,false,0.0)
		for i in range(fixtures.size()):
			var fixture: Dictionary = fixtures[i]
			var at := Vector2(24+(i%8)*197,264+floori(i/8.0)*223)
			var pitch := 34.0
			grid.draw(self,at,fixture.cells,pitch)
			grid.footprint(self,at,fixture.cells,pitch,Color("e8e6d4"))
			var fit: Dictionary = projection.fit(fixture.cells,fixture.desc,pitch,2.0)
			projection.draw(self,textures[i],fixture.cells,at,pitch,fit)
			draw_string(ThemeDB.fallback_font,at+Vector2(0,160),fixture.kind+" R"+str(fixture.turn),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("244b4e"))

func render_gallery() -> void:
	var gallery := Gallery.new()
	gallery.grid = grid
	gallery.projection = projection
	gallery.fixtures = catalog_fixtures
	gallery.synthetic = synthetic_fixtures
	for fixture in catalog_fixtures + synthetic_fixtures:
		gallery.textures.append(ImageTexture.create_from_image(fixture.source))
	var clip_source := make_image(Vector2i(144,96),[Rect2i(0,0,144,96)])
	gallery.clip_texture = ImageTexture.create_from_image(clip_source)
	root.content_scale_size = Vector2i(1600,1180)
	root.size = Vector2i(1600,1180)
	root.add_child(gallery)
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var screenshot := root.get_texture().get_image()
		check(screenshot.save_png("/tmp/frequency-grid-v5.png") == OK, "native gallery PNG is saved outside the project")
		check(screenshot.get_pixel(1082,90).is_equal_approx(gallery.background), "clipped oversized art leaves L hole untouched")
		check(screenshot.get_pixel(1082,138).is_equal_approx(Color("ec68bd")), "clipped oversized art reaches the owned lower L arm")
		check(screenshot.get_pixel(23,84).is_equal_approx(gallery.background), "grid perimeter bands never extend beyond the owned boundary")
		check(screenshot.get_pixel(327,119).is_equal_approx(gallery.background), "merged grid leaves a ring hole unpainted")
		check(screenshot.get_pixel(1169,215).is_equal_approx(gallery.background),"alpha0 grid leaves native pixels unchanged")
		var marker: Vector2 = Transform2D(.12,Vector2(.7,.7),0.0,Vector2(1240,58)) * Vector2(5,115)
		check(screenshot.get_pixel(floori(marker.x),floori(marker.y)).b > .95, "projection leaves the caller's nonidentity transform active")
	gallery.queue_free()
	await process_frame
	await render_readable_gallery()
	finish_without_render()

class ReadableGallery extends Node2D:
	var grid: Script
	var projection: Script
	var fixtures: Array
	var textures: Array = []
	var background := Color("f2efe4")
	func _draw() -> void:
		draw_rect(Rect2(0,0,1600,950),background)
		draw_string(ThemeDB.fallback_font,Vector2(24,28),"Strict (left) / optional bounded readable fit (right), pitch56, exact mass validation",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("244b4e"))
		for index in range(fixtures.size()):
			var fixture: Dictionary = fixtures[index]
			var at := Vector2(155+int(fixture.turn)*355,75+floori(index/4.0)*213)
			if fixture.turn == 0:
				draw_string(ThemeDB.fallback_font,Vector2(24,at.y+20),fixture.kind,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("244b4e"))
			for side in range(2):
				var origin := at+Vector2(side*176,0)
				grid.draw(self,origin,fixture.cells,56.0)
				grid.footprint(self,origin,fixture.cells,56.0,Color("e3e7d8"))
				projection.draw(self,textures[index],fixture.cells,origin,56.0,fixture.strict if side == 0 else fixture.readable)
				var gain: float = (float(fixture.readable.scale)/float(fixture.strict.scale)-1.0)*100.0
				var loss: float = (1.0-float(fixture.readable.retained_mass))*100.0
				var label := "R"+str(fixture.turn)+" strict" if side == 0 else "+"+str(snappedf(gain,.1))+"% / "+str(snappedf(loss,.1))+"% mass loss"
				draw_string(ThemeDB.fallback_font,origin+Vector2(0,190),label,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("244b4e"))

func render_readable_gallery() -> void:
	var gallery := ReadableGallery.new()
	gallery.grid = grid
	gallery.projection = projection
	gallery.fixtures = readable_fixtures
	var metrics: Array = []
	for fixture in readable_fixtures:
		gallery.textures.append(ImageTexture.create_from_image(fixture.source))
		metrics.append({"kind":fixture.kind,"turn":fixture.turn,"strict_scale":fixture.strict.scale,"readable_scale":fixture.readable.scale,"gain_percent":(float(fixture.readable.scale)/float(fixture.strict.scale)-1.0)*100.0,"retained_mass":fixture.readable.retained_mass,"protected_mass":fixture.readable.protected_mass,"mode":fixture.readable.mode})
	var report := FileAccess.open("/tmp/frequency-readable-fit-v5.json",FileAccess.WRITE)
	report.store_string(JSON.stringify(metrics,"\t"))
	report.close()
	root.content_scale_size = Vector2i(1600,950)
	root.size = Vector2i(1600,950)
	root.add_child(gallery)
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var screenshot := root.get_texture().get_image()
		check(screenshot.save_png("/tmp/frequency-readable-fit-v5.png") == OK,"native optional-readable gallery is saved")
		for index in range(readable_fixtures.size()):
			var fixture: Dictionary = readable_fixtures[index]
			var at := Vector2(155+int(fixture.turn)*355,75+floori(index/4.0)*213)
			var high := Vector2i.ZERO
			for cell in fixture.cells: high = high.max(cell+Vector2i.ONE)
			for y in range(high.y):
				for x in range(high.x):
					if fixture.cells.has(Vector2i(x,y)): continue
					for side in range(2):
						var point := at+Vector2(side*176,0)+(Vector2(x,y)+Vector2.ONE*.5)*56.0
						check(screenshot.get_pixel(int(point.x),int(point.y)).is_equal_approx(gallery.background),fixture.kind+" native strict/readable image leaves rotated L/T hole untouched")

func finish_without_render() -> void:
	print("FREQUENCY GRID RESULT: ",checks," checks, ",failures," failures; ",catalog_fixtures.size()," catalog images at four rotations; ",snappedf((Time.get_ticks_usec()-started_usec)/1000000.0,.01),"s")
	quit(1 if failures else 0)
