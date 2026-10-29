extends SceneTree
const T=preload("res://scripts/ui/pockets/terminal_grid.gd")
const GRID=preload("res://scripts/ui/pockets/frequency_grid.gd")
var checks=0
var failures=0
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
	# All 3x3 masks cover holes, concave turns, disconnected and diagonal bags.
	for mask in range(1,512):
		var owner={}
		for i in 9:
			if mask&(1<<i):owner[Vector2i(i%3,i/3)]=true
		for cap in T._inner_corners(owner,56):
			check(owner.has(cap.cell),"inner-turn tint always belongs to an occupied cell")
			check(not Geometry2D.triangulate_polygon(cap.polygon).is_empty(),"every rounded inward-turn fill can triangulate")
			var round=true
			for p in cap.polygon.slice(1):round=round and absf(p.distance_to(cap.center)-cap.radius)<.001
			check(round,"curve and face use the same radius")
			for y in range(-1,4):
				for x in range(-1,4):
					check(not Geometry2D.is_point_in_polygon((Vector2(x,y)+Vector2.ONE*.5)*56,cap.polygon),"cosmetic corner fillet never covers any grid-cell center")
		for edge in GRID._edge_records(owner.keys()):
			if edge.count==1:
				check(T._rim_cut(edge.a,owner,10.5)+T._rim_cut(edge.b,owner,10.5)<56,"rounded boundary segments always retain positive length")
	print("CLOTH_CORNERS_V67: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
