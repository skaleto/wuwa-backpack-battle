extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const C=preload("res://scripts/data/catalog.gd")
const D=preload("res://scripts/ui/items/item_description.gd")
const A=preload("res://scripts/ui/apricot_ui.gd")
const TREE=preload("res://scripts/crafting/recipe_tree.gd")
var game
var checks=0
var failures=0
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():call_deferred("run")
func redraw():
	game.motion.modal_value=1;game.motion.modal_target=1;game.queue_redraw();await process_frame;await process_frame
func click(id:String):
	var found=game.buttons.filter(func(b):return b.action==id and b.enabled)
	ck(not found.is_empty(),"click target exists "+id)
	if found.is_empty():return
	game.mouse=found[0].rect.get_center();game._mouse_down()
func run():
	game=G.new();root.add_child(game);await process_frame
	game.set_process(false);game.set_process_input(false)
	var count=0
	for kind in C.items:
		if not C.items[kind].get("v60",{}).get("active",false):continue
		count+=1
		var clauses=D.effects(kind)
		ck(not clauses.is_empty(),"description "+kind)
		var text="".join(clauses)
		for bad in ["hp50","time6","cooldown","matched_healer_shield","STALE"]:ck(not text.contains(bad),"no raw rule names "+kind+bad)
		var pages=A.pages(game,clauses,310,164,16);var rebuilt=""
		for page in pages:
			for row in page:
				ck(row.y+23<=164,"page bounds "+kind)
				rebuilt+=row.text
		ck(rebuilt==text,"no dropped clause while paginating "+kind)
		game._open_item_details({"kind":kind,"rotation":0},"recipe")
		ck(Rect2(0,0,1440,960).encloses(game._detail_card_rect()),"detail within viewport "+kind)
	ck(count==106,"all active catalog entries checked")
	var sword="".join(D.effects("w_sword"));var upgraded="".join(D.effects("weapon_21020044"))
	ck(sword.contains("补给被消耗时") and sword.contains("2层[haste]迅捷"),"starter star target and outcome")
	ck(upgraded.contains("攻击物品攻击时") and upgraded.contains("星位同族触发间隔：3秒"),"target star event and cooldown")
	ck("".join(D.changes("w_sword","weapon_21020044")).contains("迅捷1层 → 充能1层"),"replaced self buff shown")
	ck("".join(D.changes("w_sword","weapon_21020044")).contains("迅捷2层 → 充能1层"),"replaced star effect shown")
	ck("".join(D.effects("weapon_21020015")).contains("敌方生命低于35%"),"special refers to enemy health")
	ck("".join(D.effects("flower")).contains("同件只计一次"),"unique star matching cap")
	var previous=C.items.w_sword.v60.rows.duplicate(true);C.items.w_sword.v60.rows=[["STALE","999"]]
	ck("".join(D.effects("w_sword"))==sword,"derived prose ignores cached rows");C.items.w_sword.v60.rows=previous
	game.reset_slice();game.run.items=[game.piece("w_sword","s",0,0)];game.run.stash=[]
	game.run.round=2;var before=game.run.duplicate(true)
	game._open_item_details(game.run.items[0],"board");await redraw()
	click("detail_recipes");await redraw()
	ck(game.overlay=="item_recipes","actual click opens atlas")
	var rows=TREE.counts(game,TREE.incoming(TREE.selected))
	ck(rows[0].owned==1 and rows[1].owned==0,"missing material inventory")
	click("atlas_material:mat_43020011");await redraw()
	ck(game.overlay=="item_recipes" and TREE.inspected=="mat_43020011","material viewed in place")
	click("atlas_history");await redraw()
	ck(TREE.inspected.is_empty() and TREE.selected=="weapon_21020044","back restores selection")
	click("atlas_node:weapon_21020034");await redraw()
	ck(TREE.selected=="weapon_21020034" and game.overlay=="item_recipes","branch click stays on page")
	for family in TREE.roots():
		TREE.open(game,family);await redraw()
		var rects=[]
		for position in TREE.coordinates(family).values():
			var rect=Rect2(position,TREE.NODE_SIZE)
			for other in rects:ck(not rect.intersects(other),"family nodes do not overlap "+family)
			rects.append(rect)
		ck(game.buttons.all(func(b):return b.action!="atlas_forge"),"no extra forge navigation")
		for recipe in TREE.family(family):
			TREE.action(game,"atlas_node:"+recipe.target);await redraw()
			ck(TREE.selected==recipe.target,"all outputs selectable "+recipe.id)
	click("atlas_close")
	ck(game.overlay.is_empty(),"close returns to board")
	ck(game.run==before,"read-only navigation leaves state unchanged")
	game._action("forge");await redraw()
	ck(game.overlay=="item_recipes","bottom craft entry uses same atlas")
	click("atlas_close")
	ck(game.run==before,"global atlas entry is read-only")
	game.run.stash=[game.piece("mat_43020011","m",0,0)]
	rows=TREE.counts(game,TREE.incoming("weapon_21020044"))
	ck(rows[1].owned==1,"stash contributes to owned quantity")
	ck(game.FORGE.ready_options(game.run,game.inventory).is_empty(),"owned stash material is not craft-ready")
	print("APRICOT_V74 ",checks," checks, ",failures," failures")
	game.queue_free();await process_frame;quit(1 if failures else 0)
