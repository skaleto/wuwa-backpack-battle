extends SceneTree
## Real game drawing/input, isolated save, hidden native viewport, silent audio.
const SKIN=preload("res://scripts/ui/visual_skin.gd")
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const JOINS=preload("res://tests/visual/capture_bag_joins_v107.gd")
const ANGLES=preload("res://tests/visual/capture_bag_styles_v109.gd")
const OUT="res://build/qa/ui-v110/after/"
var viewport:SubViewport
var outputs=[]
func _initialize()->void:
	root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true)
	DirAccess.make_dir_recursive_absolute(OUT);call_deferred("run")
func shot(node:CanvasItem,name:String)->void:
	node.queue_redraw();await process_frame;RenderingServer.force_draw(true);await process_frame
	assert(viewport.get_texture().get_image().save_png(OUT+name+".png")==OK)
	outputs.append(name);print("CAPTURE ",name)
func run()->void:
	viewport=SubViewport.new();viewport.size=Vector2i(1440,960)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var game=G.new();viewport.add_child(game);await process_frame
	assert(SKIN.bag_style=="storybook","normal startup adopts the approved first concept")
	game.set_process(false);game.set_process_input(false);game.joined_slice()
	game.run.items=[game.piece("w_sword","cross1",1,0),game.piece("daily_tea","tea",0,1),game.piece("whiff","echo1",1,1),game.piece("turtle","echo2",2,1),game.piece("heron","echo3",2,2)]
	game.run.primary="cross1";game.mouse=Vector2(25,100);game.hovered={}
	game.paint_alpha=1;game.paint_offset=Vector2.ZERO;game.motion.transition_left=0;game.transition_image=null
	assert(game.inventory.validate_run(game.run))
	var original=game.run.duplicate(true)
	await shot(game,"01-preparation")
	assert(game.run==original,"drawing must not alter the run")
	game.run.items=[];await shot(game,"02-empty-bags");game.run.items=original.items.duplicate(true)
	var at=game._board_to_screen(game._item_rect(game.run.items[0],game.BOARD).get_center())
	var press=InputEventMouseButton.new();press.position=at;press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;game._input(press)
	assert(game.drag_origin=="board" and game.dragging.uid=="cross1","item body wins over any new bag decoration")
	var rotation=game.dragging.rotation
	var rotate=InputEventMouseButton.new();rotate.position=at;rotate.button_index=MOUSE_BUTTON_RIGHT;rotate.pressed=true;game._input(rotate)
	assert(game.dragging.rotation!=rotation)
	await shot(game,"03-held-item-rotated")
	game.joined_slice();game.run.items=[];game.run.primary=""
	var source=game._board_to_screen(game.BOARD+Vector2(3.5,.5)*game.CELL)
	var destination=game._board_to_screen(game.BOARD+Vector2(3.5,4.5)*game.CELL)
	press.position=source;game._input(press);assert(game.drag_origin=="bag")
	var move=InputEventMouseMotion.new();move.position=destination;game._input(move)
	rotate.position=destination;game._input(rotate)
	await shot(game,"04-held-bag")
	var release=InputEventMouseButton.new();release.position=destination;release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false;game._input(release)
	var moved=game.run.bags.filter(func(b):return b.uid=="b2")[0]
	assert(moved.x==3 and moved.y==4 and moved.rotation==1)
	assert(game.inventory.validate_run(game.run));await shot(game,"05-rotated-bag-joined")
	game.joined_slice();game.run=original.duplicate(true);game._start_battle()
	assert(game.run.phase=="battle")
	game.battle_entry_age=1.0;game.combat_time=3.0
	await shot(game,"06-battle");game.hide()
	viewport.size=Vector2i(1800,1420)
	for with_items in [false,true]:
		var sheet=JOINS.Sheet.new();sheet.with_items=with_items;viewport.add_child(sheet)
		await shot(sheet,"joins-"+("items" if with_items else "empty"));sheet.queue_free();await process_frame
	for pair in [["satchel","pouch"],["corner","strip"]]:
		var matrix=ANGLES.Angles.new();matrix.kinds=pair;viewport.add_child(matrix)
		await shot(matrix,"angles-"+pair[0]);matrix.queue_free();await process_frame
	game.queue_free();await process_frame
	FileAccess.open(OUT+"result.json",FileAccess.WRITE).store_string(JSON.stringify({"images":outputs,"source":"Godot native SubViewport","ordinary_startup":true,"isolated_storage":true,"real_pointer_untouched":true,"item_priority_rotation":true,"bag_grab_rotate_drop":true,"battle":true},"\t"))
	print("V110 NATIVE QA COMPLETE");quit()
