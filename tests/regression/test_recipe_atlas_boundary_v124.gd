extends SceneTree
const TREE=preload("res://scripts/crafting/recipe_tree.gd")
const C=preload("res://scripts/data/catalog.gd")
var checks=0
var failures=0
func ck(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
	var tree=TREE.new()
	ck(tree.has_method("presentation"),"atlas projects detached values before rendering")
	if failures:finish();return
	TREE.open(null,"weapon_21020044")
	var navigation=TREE.navigation_state();var inventory_counts={"weapon_21020044":1,"spicy_meat":1}
	var before_counts=inventory_counts.duplicate(true);var before_navigation=navigation.duplicate(true);var catalog=C.items.duplicate(true)
	var model=tree.call("presentation",inventory_counts,navigation,true)
	ck(model.focus.name==C.items.weapon_21020044.name,"header model describes current focus")
	ck(not model.has("run") and not model.has("items") and not model.has("stash"),"view receives counts and display values rather than a game or run")
	ck(model.options.any(func(row):return row.recipe_id=="V124_01" and row.complete),"detached model carries actual complete branch")
	model.focus.name="changed";model.options[0].inputs[0].owned=999;model.result.stats.clear()
	ck(inventory_counts==before_counts and navigation==before_navigation and C.items==catalog,"mutating returned model cannot change source facts or catalog")
	var view=load("res://scripts/ui/crafting/recipe_atlas_view.gd").new()
	for pair in [["atlas_recipe:V124_01","select_recipe"],["atlas_focus:weapon_21020104","focus"],["atlas_history","back"],["atlas_close","close"],["atlas_details","details"]]:
		var intent=view.call("intent",pair[0])
		ck(intent.type==pair[1],"view returns navigation intent "+pair[0])
	ck(TREE.navigation_state()==before_navigation,"creating every navigation intent has no state write")
	ck(view.call("intent","buy:0").is_empty(),"view does not accept gameplay actions")
	finish()
func finish():
	print("RECIPE_ATLAS_BOUNDARY_V124 ",checks," checks, ",failures," failures");quit(1 if failures else 0)
