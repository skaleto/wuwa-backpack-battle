extends SceneTree
const T=preload("res://scripts/ui/pockets/terminal_grid.gd")
const GRID=preload("res://scripts/ui/pockets/frequency_grid.gd")
var terminal=T.new()
var checks=0
var failures=0
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
	check(terminal.has_method("_paper_geometry"),"Q paper has shared rounded contour geometry")
	if terminal.has_method("_paper_geometry"):
		var adjacent=[Vector2i(0,0),Vector2i(1,0)]
		var geometry=terminal.call("_paper_geometry",adjacent,56)
		check(geometry.size()==2 and is_equal_approx(geometry[0].radius,9),"external Q contour radius is 9 at pitch 56")
		check(geometry[0].corners==[true,false,false,true] and geometry[1].corners==[false,true,true,false],"joined cells retain full shared edges without inner round gaps")
		check(GRID.edges(adjacent).size()==7 and GRID.edges(adjacent,true).size()==6,"joined modules share exactly one internal divider")
		var detached=terminal.call("_paper_geometry",[Vector2i.ZERO,Vector2i(2,0)],56)
		check(detached.all(func(part):return part.corners.all(func(v):return v)),"detached paper gets its own complete rounded exterior")
		var concave=terminal.call("_paper_geometry",[Vector2i.ZERO,Vector2i(0,1),Vector2i(1,1)],56)
		check(concave[0].polygon.has(Vector2(56,56)) and concave[2].polygon.has(Vector2(56,56)),"concave interior remains continuous")
	check(T.DANGO_FILLS.satchel==Color("b9a6ef") and T.DANGO_FILLS.pouch==Color("f1d18d"),"pastel ownership palette is richer and distinct")
	print("V54 PAPER ",checks," checks ",failures," failures");quit(1 if failures else 0)
