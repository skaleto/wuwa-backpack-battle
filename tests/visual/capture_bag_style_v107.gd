extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const T=preload("res://scripts/ui/pockets/terminal_grid.gd")
const OLD=preload("res://build/qa/ui-v106/before/terminal_grid.gd")
const SKIN=preload("res://scripts/ui/visual_skin.gd")
const Q=preload("res://scripts/ui/items/item_quality.gd")
const FORM=preload("res://scripts/ui/pockets/bag_form.gd")
const SLOTS=preload("res://scripts/ui/pockets/bag_slots.gd")
const OUT="res://build/qa/ui-v107/after/"
var game
var viewport
func _initialize()->void:
	root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true)
	DirAccess.make_dir_recursive_absolute(OUT);call_deferred("run")
func shot(name:String)->void:
	game.paint_alpha=1;game.paint_offset=Vector2.ZERO;game.motion.transition_left=0;game.transition_image=null
	game.queue_redraw();await process_frame;RenderingServer.force_draw(true);await process_frame
	assert(viewport.get_texture().get_image().save_png(OUT+name+".png")==OK)
func run()->void:
	viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport);game=G.new();viewport.add_child(game);await process_frame
	game.set_process(false);game.set_process_input(false);game.joined_slice()
	game.run.shop=[{"kind":"w_sword","locked":false},{"kind":"daily_tea","locked":false},{"kind":"turtle","locked":false},{"kind":"daily_tea","locked":false},{"kind":"whiff","locked":false},{"kind":"corner","locked":false}]
	game.run.round=4;game.run.gold=22
	game.run.items=[game.piece("w_sword","cross1",1,0),game.piece("daily_tea","tea",0,1),game.piece("whiff","echo1",1,1),game.piece("turtle","echo2",2,1),game.piece("heron","echo3",2,2)]
	game.run.stash=[game.piece("w_rectifier","stored",0,0),game.piece("daily_tea","stored2",0,0)]
	game.run.primary="cross1";game.mouse=Vector2(25,100);game.hovered={}
	assert(game.inventory.validate_run(game.run))
	await shot("01-preparation")
	var original=game.run.items.duplicate(true)
	game.run.items=[]
	await shot("02-empty-containers")
	game.run.items=original
	var at=game._board_to_screen(game._item_rect(game.run.items[0],game.BOARD).get_center())
	var press=InputEventMouseButton.new();press.position=at;press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true
	game._input(press)
	await shot("03-grabbed-item")
	game.queue_free();await process_frame
	FileAccess.open(OUT+"game-capture-complete.txt",FileAccess.WRITE).store_string("3 native game captures: preparation, empty bags, grabbed item; isolated QA storage, hidden unfocusable viewport, Dummy audio.\n")
	quit()
