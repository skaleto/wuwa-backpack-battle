extends SceneTree
const C=preload("res://scripts/data/catalog.gd")
const TREE=preload("res://scripts/crafting/recipe_tree.gd")
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const D=preload("res://scripts/ui/items/item_description.gd")
var checks=0
var failures=0
var game
var tree=TREE.new()
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():call_deferred("test")
func test():
	ck(tree.has_method("option_rows") and tree.has_method("current_recipe"),"local atlas exposes exact recipe options")
	if failures:finish();return
	game=G.new();root.add_child(game);await process_frame
	game.set_process(false);game.set_process_input(false)
	var saved=C.combinations.duplicate(true)
	var first={"id":"atlas_test_a","base":"w_sword","materials":["whiff"],"target":"weapon_21020044","fee":0,"trade":"获得迅捷；改变星位搭档"}
	var second={"id":"atlas_test_b","base":"w_sword","materials":["tube","tube"],"target":"weapon_21020044","fee":0,"trade":"保留材料的短时强化"}
	var merge={"id":"atlas_test_c","base":"w_broadblade","materials":["whiff"],"target":"weapon_21020044","fee":0}
	C.combinations=[first,second,merge,{"id":"atlas_test_d","base":"weapon_21020044","materials":["whiff"],"target":"weapon_21020064","fee":0}]
	game.run.items=[game.piece("w_sword","a",0,0),game.piece("whiff","b",2,0)];game.run.stash=[game.piece("tube","c",0,0)]
	game.run.round=1;var before=game.run.duplicate(true)
	var rows=tree.call("option_rows",game.run,"w_sword","outgoing")
	ck(rows.size()==2 and rows[0].recipe_id!=rows[1].recipe_id,"same target and base preserve two selectable recipe identities")
	ck(rows[0].complete and not rows[1].complete,"inventory counts distinguish complete and missing input sets")
	ck(rows[1].inputs[1].owned==1 and rows[1].inputs[1].need==2,"repeated ingredients aggregate exact required counts across stash")
	ck(rows[0].summary==first.trade,"branch uses the authored short trade")
	ck(not rows[1].summary.is_empty(),"every branch has an effect or trade")
	ck(tree.call("option_rows",game.run,"weapon_21020044","incoming").size()==3,"merged target exposes every source recipe")
	TREE.open(game,"w_sword");TREE.action(game,"atlas_recipe:atlas_test_b")
	ck(tree.call("current_recipe").id==second.id,"selection binds exact recipe id")
	var exact_comparison=D.V75.new().get_method_list().filter(func(method):return method.name=="recipe_inputs" and method.args.size()==3)
	ck(not exact_comparison.is_empty(),"effect comparison accepts the exact recipe identity")
	if not exact_comparison.is_empty():ck(D.V75.new().call("recipe_inputs",second.base,second.target,second.id)==["w_sword","tube","tube"],"same-base alternative comparison consumes its precise materials")
	TREE.action(game,"atlas_focus:weapon_21020044")
	ck(tree.call("current_recipe").id=="atlas_test_d","successor drill down selects its immediate outgoing option")
	TREE.action(game,"atlas_history")
	ck(tree.call("current_recipe").id==second.id,"back restores exact alternative recipe")
	TREE.action(game,"atlas_material:tube")
	ck(TREE.inspected=="tube","material inspection stays in atlas")
	TREE.action(game,"atlas_history")
	ck(tree.call("current_recipe").id==second.id and TREE.inspected.is_empty(),"material back restores branch and comparison")
	TREE.open(game,"weapon_21020044");TREE.action(game,"atlas_direction:incoming");TREE.action(game,"atlas_recipe:atlas_test_c")
	ck(tree.call("current_recipe").base=="w_broadblade","alternate incoming recipe uses its exact base")
	var previous=tree.call("current_recipe").duplicate(true)
	TREE.show_details(game,"whiff");game.ITEM_PANEL.action(game,"details_back")
	ck(tree.call("current_recipe")==previous,"detail return preserves exact incoming recipe")
	ck(game.run==before,"all atlas reads and navigation leave inventory, gold, round and RNG unchanged")
	# Legacy graph queries retain every DAG route and terminate if bad data contains a cycle.
	ck(["w_broadblade","weapon_21020044","weapon_21020064"] in TREE.paths("w_broadblade"),"legacy paths start from the requested DAG root")
	C.combinations.append({"id":"atlas_cycle","base":"weapon_21020064","materials":["tube"],"target":"w_sword","fee":0})
	var routes=TREE.paths("w_broadblade")
	ck(not routes.is_empty() and routes.all(func(path):return path.size()<=4),"cycle guard bounds every path without hiding finite ancestry")
	for path in routes:
		var unique={}
		for kind in path:unique[kind]=true
		ck(unique.size()==path.size(),"cycle path contains no repeated nodes")
	C.combinations=saved
	for recipe in C.combinations:
		ck(TREE.A.lines(game,TREE.branch_summary(recipe),555,13).size()<=1,"branch meaning fits without truncation "+recipe.id)
		TREE.open(game,recipe.target)
		ck(TREE.coordinates(TREE.root_kind).has(recipe.target),"legacy target remains revealable in merged network "+recipe.id)
	for family in TREE.roots():
		TREE.open(game,family)
		for branch in TREE.branch_pages(family):
			TREE.branch_page=branch
			for stage in TREE.stage_pages(family):
				TREE.stage_page=stage;var positions=TREE.coordinates(family);var nodes=positions.keys()
				for n in nodes.size():
					ck(TREE.GRAPH.encloses(Rect2(positions[nodes[n]],TREE.NODE_SIZE)),"legacy graph stays bounded")
					for m in range(n+1,nodes.size()):ck(not Rect2(positions[nodes[n]],TREE.NODE_SIZE).intersects(Rect2(positions[nodes[m]],TREE.NODE_SIZE)),"legacy merged graph has no node overlap")
	TREE.history.clear();TREE.open(game,"w_sword")
	game.queue_free();await process_frame;finish()
func finish():
	print("RECIPE_ATLAS_V124 ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
