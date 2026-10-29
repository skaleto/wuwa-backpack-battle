extends SceneTree
## Pure geometry and headless draw checks; never constructs player storage.
const T=preload("res://scripts/ui/pockets/terminal_grid.gd")
const GRID=preload("res://scripts/ui/pockets/frequency_grid.gd")
const SKIN=preload("res://scripts/ui/visual_skin.gd")
var checks=0
var failures=0
var terminal=T.new()

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)

func _initialize()->void:call_deferred("run")

func run()->void:
	check(terminal.has_method("_fabric_uv"),"cloth supports continuous board-space UVs")
	if terminal.has_method("_fabric_uv"):
		var source=Rect2(20,40,800,800);var texture_size=Vector2(1024,1024)
		var start=terminal.call("_fabric_uv",Vector2.ZERO,56,source,texture_size)
		var left=terminal.call("_fabric_uv",Vector2(55.99,28),56,source,texture_size)
		var right=terminal.call("_fabric_uv",Vector2(56.01,28),56,source,texture_size)
		var far=terminal.call("_fabric_uv",Vector2(112,28),56,source,texture_size)
		check(left.distance_to(right)<.0001,"texture phase is continuous across a cell boundary")
		check(far.x>right.x and right.x>start.x,"neighboring cells advance through the source instead of restarting")
		var lower=terminal.call("_fabric_uv",Vector2(0,56),56,source,texture_size)
		var beside=terminal.call("_fabric_uv",Vector2(56,0),56,source,texture_size)
		check(is_equal_approx(lower.y-start.y,beside.x-start.x),"square fabric has equal scale in both board axes")
		var end=terminal.call("_fabric_uv",Vector2(448,336),56,source,texture_size)
		check(end.x<=source.end.x/texture_size.x and end.y<=source.end.y/texture_size.y,"full 8 x 6 board stays inside authored source without texture repeat")
	var grid_args=0
	for method in terminal.get_script().get_script_method_list():
		if method.name=="placement_grid":grid_args=method.args.size()
	check(grid_args==7,"placement grid accepts independent board or stash lining")
	# Every 3 x 3 occupancy includes straight joins, L/T joins, diagonal contact,
	# detached pieces and a ring. Shared vertices must survive convex rounding.
	for mask in range(1,512):
		var cells=[]
		for i in 9:
			if mask & (1<<i):cells.append(Vector2i(i%3,i/3))
		var geometry=T._paper_geometry(cells,56)
		var by_cell={}
		for part in geometry:by_cell[part.cell]=part
		for edge in GRID._edge_records(cells):
			if edge.count!=2:continue
			var neighbor=edge.cell+GRID.DIRECTIONS[edge.side]
			for point in [edge.a*56,edge.b*56]:
				check(by_cell[edge.cell].polygon.has(point) and by_cell[neighbor].polygon.has(point),"joined polygons meet exactly at both shared-edge endpoints")
		for i in 9:
			var cell=Vector2i(i%3,i/3)
			var center=(Vector2(cell)+Vector2.ONE*.5)*56
			check(geometry.any(func(part):return Geometry2D.is_point_in_polygon(center,part.polygon))==cells.has(cell),"cloth covers exactly the owned cell centers")
	if grid_args==7:
		var before_skin=SKIN.current
		var probe=DrawProbe.new();root.add_child(probe)
		await process_frame
		await process_frame
		check(probe.draws>0,"native canvas exercises cloth and original drawing paths")
		check(probe.bags==probe.before and probe.pulses==probe.before_pulses,"drawing never mutates bag ownership or pulse input")
		probe.queue_free();SKIN.set_skin(before_skin,false)
		await process_frame
	print("V64 TRAVEL GRID ",checks," checks ",failures," failures")
	quit(1 if failures else 0)

class DrawProbe extends Node2D:
	var terminal=T.new()
	var bags=[{"kind":"satchel","uid":"same-a","x":0,"y":0,"rotation":0},{"kind":"satchel","uid":"same-b","x":3,"y":0,"rotation":0},{"kind":"pouch","uid":"third","x":2,"y":2,"rotation":0}]
	var pulses={"same-a":.4}
	var before=bags.duplicate(true)
	var before_pulses=pulses.duplicate(true)
	var draws=0
	func _draw()->void:
		for skin in ["original","chibi"]:
			SKIN.set_skin(skin,false)
			terminal.call("placement_grid",self,Vector2.ZERO,Vector2i(8,6),56,1.0,0.0,"board")
			terminal.call("placement_grid",self,Vector2(0,360),Vector2i(8,1),56,.8,48.0,"stash")
			T.surface(self,Vector2.ZERO,bags,56,"same-a",.9,pulses)
			draws+=1
