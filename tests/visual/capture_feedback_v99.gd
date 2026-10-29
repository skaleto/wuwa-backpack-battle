extends SceneTree
const G=preload("res://tests/fixtures/playable_fixture_v50.gd")
const TREE=preload("res://scripts/crafting/recipe_tree.gd")
const DIAGRAM=preload("res://scripts/ui/items/item_star_diagram.gd")
var game
var viewport
func _initialize():
	root.hide();root.unfocusable=true
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")
func shot(name:String):
	game.paint_alpha=1;game.paint_offset=Vector2.ZERO;game.motion.modal_value=1;game.motion.modal_target=1
	game.queue_redraw();await process_frame
	RenderingServer.force_draw(true);await process_frame;RenderingServer.force_draw(true);await process_frame
	assert(viewport.get_texture().get_image().save_png("res://build/qa/feedback-v99/after/"+name+".png")==OK)
func run():
	viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport);game=G.new();viewport.add_child(game);await process_frame
	game.set_process(false);game.set_process_input(false)
	game.run=game.inventory.new_run("aemeath",19);game.run.round=4;game.run.serial=20;game.run.shop=[{},{},{},{},{},{}]
	game.run.bags=[game.piece("satchel","b1",1,1),game.piece("pouch","b2",4,1)]
	game.run.items=[game.piece("weapon_21020074","i1",1,1),game.piece("daily_tea","i2",1,2),game.piece("echo_glacio","i3",3,2)]
	game.run.primary="i1";game.run.stash=[];game.screen="game";game.mouse=Vector2(960,900)
	game._open_item_details(game.run.items[0],"board");game.item_selection_age=1
	await shot("01-feijing-details")
	game.ITEM_PANEL.action(game,"detail_recipes");TREE.action(game,"atlas_node:weapon_21020086")
	await shot("02-feijing-locked-recipe")
	TREE.action(game,"atlas_material:echo_glacio");await shot("03-recipe-star-diagram")
	TREE.action(game,"atlas_close")
	game.run.bags.append(game.piece("satchel","b3",1,3))
	game.run.items.append(game.piece("w_sword","i4",1,3))
	game._open_item_details(game.run.items[0],"board");game.item_selection_age=1
	await shot("04-one-linked-item")
	# Long cards must stay in the viewport; all real relative cells fit the miniature.
	var total=0
	for kind in game.C.items:
		game._open_item_details({"kind":kind,"rotation":0},"recipe")
		assert(Rect2(0,0,1440,960).encloses(game._detail_card_rect()),kind)
		var model=game._item_star_snapshot({"kind":kind,"rotation":0},"recipe")
		var rect=Rect2(0,0,135,80);var layout=DIAGRAM.layout(model,rect)
		for cell in layout.cells:assert(rect.encloses(cell),kind)
		for star in layout.stars:assert(rect.has_point(star.center),kind)
		total+=1
	var f=FileAccess.open("res://build/qa/feedback-v99/after/capture-complete.txt",FileAccess.WRITE)
	f.store_string("4 native background captures; "+str(total)+" item cards and star layouts checked; isolated QA storage, no input or audio.");f.close()
	game.queue_free();await process_frame;await create_timer(.2).timeout;quit()
