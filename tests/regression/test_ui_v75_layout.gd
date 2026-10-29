extends SceneTree
const G=preload("res://scripts/game.gd")
const C=preload("res://scripts/data/catalog.gd")
const A=preload("res://scripts/ui/apricot_ui.gd")
const D=preload("res://scripts/ui/items/item_description.gd")
const INFO=preload("res://scripts/ui/items/item_info.gd")
const P=preload("res://scripts/ui/items/item_panel.gd")
const TREE=preload("res://scripts/crafting/recipe_tree.gd")
const ICONS=preload("res://scripts/ui/ability_icons.gd")
class DrawProbe extends G:
	var rendered_prices=[]
	func _text(value:String,position:Vector2,size:int,color:Color)->void:
		if value.contains("标价"):rendered_prices.append(value)
		super._text(value,position,size,color)
	func _draw()->void:
		if not detail_item.is_empty():ITEM_PANEL.details(self)
var checks=0
var failures=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL "+message)
func _init()->void:call_deferred("test")
func check_pages(g,paragraphs:Array,width:float,height:float,size:int)->void:
	var pages=A.pages(g,paragraphs,width,height,size);var joined=""
	for page in pages:
		for line in page:
			check(line.y+size+7<=height+.001,"page text within allocated height")
			joined+=line.text
	check(joined=="".join(paragraphs),"pagination loses no text")
func test()->void:
	var game=DrawProbe.new();game.storage=G.S.new("/tmp/resonance-layout-v75-"+str(Time.get_ticks_usec()));game.muted=true
	root.add_child(game);await process_frame
	game.run=game.inventory.new_run("jiyan",15);game.screen="game";game.set_process(false)
	for kind in C.items:
		if not C.items[kind].has("v75"):continue
		game.detail_item=game.inventory.make_piece(kind,"probe");game.detail_anchor=Rect2(1420,940,20,20)
		var rect=game._detail_card_rect();var y=160+D.stats(kind).size()*32;var bottom=rect.size.y-112
		check(Rect2(8,8,1424,944).encloses(rect),"detail frame in viewport "+kind)
		check(bottom-y-70>=46,"effects retain at least two lines "+kind)
		check_pages(game,D.effects(kind),rect.size.x-58,bottom-y-70,16)
		var offset=Vector2.ZERO
		for chip in INFO.type_chips(kind):
			check(ICONS.supports(chip[0]),"chip glyph exists "+chip[0])
			var width=game.font.get_string_size(chip[1],HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+32
			if offset.x+width>rect.size.x-46:offset=Vector2(0,offset.y+26)
			offset.x+=width+5
		check(offset.y+23<=49,"chip rows fit before recipe button "+kind)
	for recipe in C.combinations:
		var kind=recipe.target;var y=139+D.stats(kind,recipe.base).size()*32
		var changes=D.changes(recipe.base,kind);var height=clampf(595-y-(126 if not changes.is_empty() else 0),126,350)
		check_pages(game,D.effects(kind),330,height-65,15)
		if not changes.is_empty():check_pages(game,changes,330,77,14)
	TREE.open(game,"weapon_21050066");var before=[TREE.root_kind,TREE.selected,TREE.branch_page,TREE.stage_page]
	game.detail_item=game.inventory.make_piece(TREE.selected,"probe");TREE.show_details(game,"turtle")
	P.action(game,"details_back")
	check([TREE.root_kind,TREE.selected,TREE.branch_page,TREE.stage_page]==before,"details return restores atlas pagination")
	# Observe the real details drawing callback, not a duplicate price-format helper.
	game.run=game.inventory.new_run("jiyan",7);game.run.items[0].paid_cost=8;game.run.items[0].cost_basis="actual";game.run.items[0].erase("salvage_credit")
	game.opponent=game.inventory.snapshot(game.inventory.new_run("yinlin",8),"other")
	var player=game.run.items[0];var enemy=game.opponent.items[0];enemy.paid_cost=2;enemy.cost_basis="actual"
	var run_before=game.run.duplicate(true)
	for origin in ["enemy","shop","recipe","catalogue"]:
		# Identical IDs (and for the non-enemy cases identical kind) cannot confer ownership.
		var item=enemy if origin=="enemy" else player
		game.rendered_prices.clear();game._open_item_details(item,origin);game.queue_redraw()
		await process_frame;await process_frame
		check(not game.rendered_prices.is_empty(),"price caption actually drawn for "+origin)
		var text=" ".join(game.rendered_prices)
		check(not text.contains("实付") and not text.contains("估值") and not text.contains("卖出"),"non-owned origin never displays player payment: "+origin)
	var same_kind_enemy=player.duplicate(true);same_kind_enemy.paid_cost=2
	game.rendered_prices.clear();game._open_item_details(same_kind_enemy,"enemy");game.queue_redraw()
	await process_frame;await process_frame
	check(not game.rendered_prices.is_empty(),"same-kind enemy caption actually drawn")
	check(not " ".join(game.rendered_prices).contains("实付") and not " ".join(game.rendered_prices).contains("卖出"),"same UID and same kind still do not make enemy item owned")
	for origin in ["board","stash","bag","pocket"]:
		var item=game.run.bags[0] if origin in ["bag","pocket"] else player
		game.rendered_prices.clear();game._open_item_details(item,origin);game.queue_redraw()
		await process_frame;await process_frame
		check(not game.rendered_prices.is_empty(),"owned caption actually drawn for "+origin)
		var text=" ".join(game.rendered_prices)
		check(text.contains("实付0") and text.contains("卖出0") if origin in ["bag","pocket"] else text.contains("实付8") and text.contains("卖出6"),"owned origin retains true transaction prices: "+origin)
	check(game.run==run_before,"drawing price captions never mutates ownership or costs")
	print("UI V75 layout: %d checks, %d failures"%[checks,failures]);game.queue_free();await process_frame;quit(1 if failures else 0)
