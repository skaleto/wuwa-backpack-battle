extends SceneTree
## Native render QA: no visible window, input capture, audio or player Storage.
const T=preload("res://scripts/ui/pockets/terminal_grid.gd")
const SKIN=preload("res://scripts/ui/visual_skin.gd")
const BASE=preload("res://tests/visual/capture_bag_joins_v107.gd")
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const FIX=preload("res://tests/fixtures/bag_trial_fixture_v109.gd")
const OUT="res://build/qa/ui-v109/"
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
	viewport=SubViewport.new();viewport.size=Vector2i(1800,1420);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	for style in ["flat","fold"]:
		SKIN.set_bag_style(style,false)
		for items in [false,true]:
			var sheet=BASE.Sheet.new();sheet.with_items=items;viewport.add_child(sheet)
			await shot(sheet,style+"-joins-"+("items" if items else "empty"))
			sheet.queue_free();await process_frame
		for pair in [["satchel","pouch"],["corner","strip"]]:
			var matrix=Angles.new();matrix.kinds=pair;viewport.add_child(matrix)
			await shot(matrix,style+"-angles-"+pair[0])
			matrix.queue_free();await process_frame
	viewport.size=Vector2i(1440,960)
	var game=G.new();viewport.add_child(game);await process_frame
	game.set_process(false);game.set_process_input(false);game.joined_slice()
	game.run.shop=[{"kind":"w_sword","locked":false},{"kind":"daily_tea","locked":false},{"kind":"turtle","locked":false},{"kind":"daily_tea","locked":false},{"kind":"whiff","locked":false},{"kind":"corner","locked":false}]
	game.run.round=4;game.run.gold=22
	game.run.items=[game.piece("w_sword","cross1",1,0),game.piece("daily_tea","tea",0,1),game.piece("whiff","echo1",1,1),game.piece("turtle","echo2",2,1),game.piece("heron","echo3",2,2)]
	game.run.stash=[game.piece("w_rectifier","stored",0,0),game.piece("daily_tea","stored2",0,0)]
	game.run.primary="cross1";game.mouse=Vector2(25,100);game.hovered={}
	game.paint_alpha=1;game.paint_offset=Vector2.ZERO;game.motion.transition_left=0;game.transition_image=null
	assert(game.inventory.validate_run(game.run))
	var original=game.run.duplicate(true)
	for style in ["flat","fold"]:
		SKIN.set_bag_style(style,false)
		await shot(game,style+"-game")
		game.run.items=[];await shot(game,style+"-game-empty");game.run.items=original.items.duplicate(true)
		assert(game.run==original,"render must not change game state")
	# Switch while holding an item, rotate it with the actual input path, then switch back.
	SKIN.set_bag_style("flat",false)
	var at=game._board_to_screen(game._item_rect(game.run.items[0],game.BOARD).get_center())
	var press=InputEventMouseButton.new();press.position=at;press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;game._input(press)
	assert(not game.dragging.is_empty())
	var held_before=game.dragging.duplicate(true);var run_before=game.run.duplicate(true)
	var toggle=InputEventKey.new();toggle.keycode=KEY_F7;toggle.pressed=true;game._input(toggle)
	assert(SKIN.bag_style=="fold" and game.dragging==held_before and game.run==run_before)
	var rotate=InputEventMouseButton.new();rotate.position=at;rotate.button_index=MOUSE_BUTTON_RIGHT;rotate.pressed=true;game._input(rotate)
	assert(game.dragging.rotation!=held_before.rotation)
	await shot(game,"fold-game-grabbed-rotated")
	game._input(toggle);assert(SKIN.bag_style=="flat")
	await shot(game,"flat-game-grabbed-rotated")
	for style in ["flat","fold"]:
		game.joined_slice();game.run.items=[];game.run.primary=""
		SKIN.set_bag_style(style,false)
		var source=game._board_to_screen(game.BOARD+Vector2(3.5,.5)*game.CELL)
		var destination=game._board_to_screen(game.BOARD+Vector2(3.5,4.5)*game.CELL)
		press.position=source;game._input(press);assert(game.drag_origin=="bag")
		var move=InputEventMouseMotion.new();move.position=destination;game._input(move)
		rotate.position=destination;game._input(rotate)
		await shot(game,style+"-bag-held")
		var release=InputEventMouseButton.new();release.position=destination;release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false;game._input(release)
		var moved=game.run.bags.filter(func(b):return b.uid=="b2")[0]
		assert(moved.x==3 and moved.y==4 and moved.rotation==1,"actual grab, right-click rotation and drop commits the new joined bag")
		assert(game.inventory.validate_run(game.run))
		await shot(game,style+"-bag-moved")
	game.queue_free();await process_frame
	FileAccess.open(OUT+"capture-result.json",FileAccess.WRITE).store_string(JSON.stringify({"images":outputs,"source":"Godot native SubViewport","isolated_storage":true,"focus_input_audio":false,"f7_held_state_preserved":true,"item_right_click_rotation":true,"bag_grab_rotate_drop":true},"\t"))
	quit()

class Angles extends BASE.Sheet:
	var kinds=["satchel","pouch"]
	func _draw()->void:
		draw_rect(Rect2(0,0,1800,1420),Color("373251"))
		draw_string(font,Vector2(42,48),"独立角度拼接 · "+kinds[0]+" × "+kinds[1],HORIZONTAL_ALIGNMENT_LEFT,-1,28,Color("fff0d7"))
		for a in 4:
			for b in 4:
				var panel=Vector2(40+b*445,95+a*325)
				draw_string(font,panel,"%d° / %d°"%[a*90,b*90],HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("e4d8f2"))
				var first=FIX.bag(kinds[0],"a",a);var second=FIX.bag(kinds[1],"b",b)
				T.surface(self,panel+Vector2(16,25),FIX.touching(first,second,Vector2i.RIGHT),53)
				# Same rotations with a perpendicular join, at a compact display size.
				T.surface(self,panel+Vector2(250,150),FIX.touching(first,second,Vector2i.DOWN),25)
