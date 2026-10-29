extends SceneTree
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const D=preload("res://scripts/ui/items/item_description.gd")
const INFO=preload("res://scripts/ui/items/item_info.gd")
const TREE=preload("res://scripts/crafting/recipe_tree.gd")
var checks=0
var failures=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL "+message)
func _init()->void:
	# Frozen prior rules; V125 replacements covered by ecosystem suites.
	preload("res://tests/fixtures/catalog_fixture_v124.gd").apply()
	check(" ".join(D.effects("turtle")).contains("每4秒") and " ".join(D.effects("turtle")).contains("治疗4"),"independent turtle support clock shown")
	check(" ".join(D.effects("revive")).contains("净化1"),"revive V75 cleanse instead of legacy resurrection")
	check(str(INFO.live_effects("tube")).contains("下一击"),"material shows its real star buff")
	check(str(INFO.type_chips("turtle")).contains("healing"),"heal capability uses existing icon alias")
	check(str(INFO.type_chips("inferno")).contains("break_shield"),"actual conditional breaker capability is shown")
	for root in TREE.roots():
		TREE.open(null,root);var pos=TREE.coordinates(root);var ids=pos.keys()
		for a in ids.size():
			for b in range(a+1,ids.size()):check(not Rect2(pos[ids[a]],TREE.NODE_SIZE).intersects(Rect2(pos[ids[b]],TREE.NODE_SIZE)),"graph no overlap "+ids[a]+"/"+ids[b])
	# V124 adds 24 branches, including Zig as a new recipe root.
	check(TREE.roots().size()==34 and "zig" in TREE.roots() and C.combinations.size()==165,"complete approved recipe forest")
	var seen=[]
	for root in TREE.roots():
		TREE.open(null,root)
		for branch in TREE.branch_pages(root):
			TREE.branch_page=branch
			for stage in TREE.stage_pages(root):
				TREE.stage_page=stage;var pos=TREE.coordinates(root);var ids=pos.keys()
				for id in ids:
					if id not in seen:seen.append(id)
					check(TREE.GRAPH.encloses(Rect2(pos[id],TREE.NODE_SIZE)),"page node stays in frame "+id)
				for a in ids.size():
					for b in range(a+1,ids.size()):check(not Rect2(pos[ids[a]],TREE.NODE_SIZE).intersects(Rect2(pos[ids[b]],TREE.NODE_SIZE)),"all pages no overlap")
	for recipe in C.combinations:
		check(recipe.target in seen,"recipe reachable "+recipe.target)
		TREE.open(null,recipe.target);check(TREE.coordinates(TREE.root_kind).has(recipe.target),"selected target auto revealed "+recipe.target)
	TREE.open(null,"weapon_21050066");TREE.remember();var branch=TREE.branch_page;var stage=TREE.stage_page;var selected=TREE.selected
	TREE.open(null,"w_broadblade");TREE.action(null,"atlas_history")
	check(TREE.branch_page==branch and TREE.stage_page==stage and TREE.selected==selected,"history restores graph pages and selection")
	var profiles=0
	for kind in C.items:
		if not C.items[kind].has("v75"):continue
		profiles+=1;var prose=" ".join(D.effects(kind))
		check(not prose.is_empty(),"profile effects populated "+kind)
		for forbidden in ["预算","候选","上版","无额外机制"]:check(not prose.contains(forbidden),"no internal prose "+kind)
		check(INFO.effects(kind)==INFO.live_effects(kind),"one effects adapter "+kind)
	check(profiles==212,"all approved profiles represented")
	check(not str(D.stats("turtle")).contains("攻击间隔"),"support clock does not pretend to attack")
	var changes=" ".join(D.changes("rocksteady","bellborne"))
	check(changes.contains(C.items.echo_glacio.name) and changes.contains("霜渐"),"recipe comparison includes second consumed input")
	var sword=" ".join(D.effects("weapon_21020044"))
	check(sword.count("迅捷1")==1,"不归孤军 states baseline haste once")
	check(sword.contains("连续6秒无攻击") and sword.contains("不再延长迅捷"),"不归孤军 retains inactivity condition")
	var healer=" ".join(D.effects("weapon_21050036"))
	check(healer.count("治疗12")==1 and not healer.contains("每5秒治疗12，生命15"),"星序 numeric healing and life baseline not repeated by own clause")
	check(healer.contains("最多两件") and healer.contains("下一击各+3") and healer.contains("间隔5秒"),"星序 retains full star reward and interval")
	check(not INFO.V75.own_text("weapon_21050066").contains("充能1"),"幽冥 does not invent charge absent from numeric profile")
	var haste_recipe=TREE.incoming("weapon_21020044")
	var haste_change=" ".join(D.changes(haste_recipe.base,haste_recipe.target))
	check(not haste_change.contains("获得获得") and haste_change.contains("每2次攻击获得1层"),"recipe haste frequency uses natural language")
	var material_recipe=TREE.incoming("weapon_21010013")
	check(not " ".join(D.changes(material_recipe.base,material_recipe.target)).contains("用于合成配方"),"recipe comparison omits noncombat material boilerplate")
	var i=I.new();check(i.has_method("replacement_quote"),"replacement has shared transaction/display quote")
	print("UI V75: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
