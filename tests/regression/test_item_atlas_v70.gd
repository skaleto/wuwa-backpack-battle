extends SceneTree
const C=preload("res://scripts/data/catalog.gd")
const INFO=preload("res://scripts/ui/items/item_info.gd")
const PANEL=preload("res://scripts/ui/items/item_panel.gd")
const TREE=preload("res://scripts/crafting/recipe_tree.gd")
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
var checks=0
var failures=0
var game
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():call_deferred("run_tests")
func run_tests():
	for expected in [["tea","max_hp","生命上限"],["soup","stamina","体力"],["rations","stamina","体力"],["dragon_food","stamina","体力"],["dragon_feast","stamina","体力"],["violet","counter","反击"]]:
		ck([expected[1],expected[2]] in INFO.type_chips(expected[0]),"real ability tag chip "+expected[0])
	for kind in C.items:
		var d=C.items[kind]
		if not d.get("v60",{}).get("active",false):continue
		if C.is_tag(kind,"material"):ck(INFO.type_chips(kind)[0]==["material","材料"],"material category "+kind)
		if C.is_tag(kind,"weapon"):ck(INFO.type_chips(kind)[0][0]=="weapon","weapon category "+kind)
		var star=d.v60.get("star",{})
		if not star.is_empty():
			var rows=INFO.star_rows(kind);var prose=JSON.stringify(rows)
			ck(prose.contains("["+str(d.target)+"]"),"star uses real tag "+kind)
			ck(not prose.contains("每件"),"event star never promises per-item multiplication "+kind)
			for action in star.actions:
				var receiver="敌方" if action.type in ["damage","break_shield","noise","frost"] else "我方"
				ck(prose.contains(receiver),"star recipient "+kind)
			if float(star.interval)>0:ck(prose.contains("最多每 "+INFO.number(star.interval)+" 秒一次"),"family cooldown "+kind)
	ck(JSON.stringify(INFO.effects("flower")).contains("本件发动"),"flower triggers itself")
	ck(JSON.stringify(INFO.effects("flower")).contains("2 件 · 同件只计一次"),"flower caps unique healers")
	ck(JSON.stringify(INFO.effects("weapon_21020015")).contains("敌方生命 < 35%"),"low HP refers to enemy")
	ck(JSON.stringify(INFO.effects("weapon_21010015")).contains("2 层 × 7 伤"),"upgraded noise special uses current value")
	ck(JSON.stringify(INFO.effects("contract_oath")).contains("伤害 5"),"upgraded derived damage uses current value")
	ck(JSON.stringify(INFO.effects("salt_tea")).contains("生命 < 60%"),"hp60 activation localized")
	ck(JSON.stringify(INFO.effects("cool_tea_pure")).contains("第 6 秒"),"time6 activation localized")
	var cached=C.items.w_gauntlet.v60.rows.duplicate(true)
	C.items.w_gauntlet.v60.rows=[["STALE","999"]]
	ck(not JSON.stringify(INFO.effects("w_gauntlet")).contains("STALE"),"legacy prose cannot override actual actions")
	C.items.w_gauntlet.v60.rows=cached
	var changes=INFO.recipe_changes("w_sword","weapon_21020034")
	ck(["伤害","5.4 → 5.04"] in changes,"first-stage damage tradeoff shown honestly")
	ck(changes.any(func(v):return v[0]=="移除" and str(v[1]).contains("[haste]")),"removed ability displayed")
	ck(changes.any(func(v):return v[0]=="获得" and str(v[1]).contains("[break_shield]")),"gained ability displayed")
	ck(["w_sword","weapon_21020044","weapon_21020064","weapon_21020015"] in TREE.paths("weapon_21020015"),"entire sword ancestry visible")
	var seen=[]
	for family in TREE.roots():
		var positions=TREE.coordinates(family)
		for recipe in TREE.family(family):
			ck(recipe.target not in seen,"unique incoming target "+recipe.target);seen.append(recipe.target)
			ck(positions.has(recipe.base) and positions.has(recipe.target),"edge nodes visible "+recipe.id)
		for node in positions:ck(TREE.GRAPH.encloses(Rect2(positions[node],TREE.NODE_SIZE)),"graph within panel "+node)
	ck(seen.size()==45 and seen.size()==C.combinations.size(),"all 45 edges reachable")
	game=G.new();root.add_child(game);await process_frame
	game.set_process(false);game.set_process_input(false)
	for kind in C.items:
		if not C.items[kind].get("v60",{}).get("active",false):continue
		for row in INFO.rows({"kind":kind}):
			ck(PANEL.rich_width(game,str(row[0]),12)<=300 and PANEL.rich_width(game,str(row[1]),12)<=300,"detail clauses fit at 12px "+kind)
		var chip_x=0.0;var chip_lines=1
		for chip in INFO.type_chips(kind):
			var width=game.font.get_string_size(chip[1],HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+31
			if chip_x+width>300:chip_lines+=1;chip_x=0
			chip_x+=width+5
		ck(chip_lines<=2,"type chips fit bottom area "+kind)

	game.run.items=[game.piece("w_sword","test-sword",1,1)];game.run.stash=[];game.run.phase="shop";game.run.round=5
	var before=game.run.duplicate(true)
	game._open_item_details(game.run.items[0],"board")
	PANEL.action(game,"detail_recipes")
	ck(game.overlay=="item_recipes" and TREE.root_kind=="w_sword","owned base opens full chain")
	for family in TREE.roots():
		TREE.open(game,family);game.motion.modal_value=1;game.motion.modal_target=1;game.queue_redraw()
		await process_frame;await process_frame
		for recipe in TREE.family(family):ck(game.buttons.any(func(b):return b.action=="atlas_node:"+recipe.target),"rendered clickable recipe "+recipe.id)
	TREE.open(game,"weapon_21020064");PANEL.action(game,"atlas_node:weapon_21020015")
	ck(TREE.selected=="weapon_21020015","select later stage")
	PANEL.action(game,"atlas_details")
	ck(game.overlay=="item_details" and game.detail_item.kind=="weapon_21020015","open selected result")
	PANEL.action(game,"details_back")
	ck(game.overlay=="item_recipes" and TREE.selected=="weapon_21020015","return preserves atlas branch")
	PANEL.action(game,"atlas_material:whiff_fast")
	ck(TREE.root_kind=="whiff" and TREE.selected=="whiff_fast","crafted material opens its complete chain")
	TREE.open(game,"w_sword");PANEL.action(game,"atlas_close")
	ck(game.overlay.is_empty(),"atlas returns directly to preparation")
	ck(game.run==before,"all atlas navigation leaves run untouched")
	print("ITEM_ATLAS_V70 ",checks," checks, ",failures," failures")
	game.queue_free();await process_frame;quit(1 if failures else 0)
