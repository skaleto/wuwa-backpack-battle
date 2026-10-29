extends SceneTree
## Hidden native rendering; isolated Storage, no real pointer events or sound.
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const FIX=preload("res://tests/fixtures/capacity_fixture_v111.gd")
const OUT="res://build/qa/capacity-v111/after/"
var viewport:SubViewport
var images=[]
func _initialize()->void:
	root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true)
	DirAccess.make_dir_recursive_absolute(OUT);call_deferred("run_capture")
func shot(game,name:String)->void:
	game.queue_redraw();await process_frame;RenderingServer.force_draw(true);await process_frame
	assert(viewport.get_texture().get_image().save_png(OUT+name+".png")==OK)
	images.append(name);print("CAPTURE ",name)
func run_capture()->void:
	viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var game=G.new();viewport.add_child(game);await process_frame
	game.set_process(false);game.set_process_input(false)
	game.paint_alpha=1;game.paint_offset=Vector2.ZERO;game.motion.transition_left=0;game.transition_image=null
	game.mouse=Vector2(25,100);game.hovered={}
	assert(game.inventory.coverage(game.run.bags).size()==6)
	await shot(game,"01-starting-six")
	game.run.bags=FIX.full_bags(game.inventory);game.run.bags[0].kind="satchel"
	game.run.items=[];game.run.primary="";game.run.stash=[];game.run.serial=200;game.run.round=6;game.run.gold=20
	for kind in ["w_sword","heron","turtle","whiff","daily_tea","zig","w_sword","heron","daily_tea","turtle","w_sword","zig","whiff"]:
		var p=game.inventory.make_piece(kind,"display%d"%game.run.items.size())
		var placed=game.inventory.first_fit(p,game.run.items,game.run.bags)
		assert(not placed.is_empty());game.run.items.append(placed)
	game.run.primary=game.run.items[0].uid
	# A real click/drag/release places an owned one-cell item at the new last cell.
	game.run.stash=[game.piece("mat_43020011","corner",0,0)]
	assert(game.inventory.validate_run(game.run))
	var start=game._stash_rect(0).get_center();var end=game._board_to_screen(game.BOARD+Vector2(8.5,6.5)*game.CELL)
	var press=InputEventMouseButton.new();press.position=start;press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;game._input(press)
	assert(game.dragging.get("uid","")=="corner")
	var motion=InputEventMouseMotion.new();motion.position=end;game._input(motion)
	await shot(game,"02-last-cell-held")
	var release=InputEventMouseButton.new();release.position=end;release.button_index=MOUSE_BUTTON_LEFT;game._input(release)
	var placed=game.inventory.find_piece(game.run,"corner")
	assert(placed.x==8 and placed.y==6 and game.run.stash.is_empty())
	for n in 40:game._process(1.0/60.0)
	game.mouse=Vector2(25,100);game.hovered={}
	var before=game.run.duplicate(true)
	await shot(game,"03-expanded-equipped")
	assert(game.run==before)
	game.opponent=game.inventory.snapshot(game.run,"capacity-native-other")
	game._start_battle();assert(game.run.phase=="battle")
	game.battle_entry_age=1.0;game.combat_time=3.0
	await shot(game,"04-battle")
	for side in 2:assert(game.Q_BATTLE.BOARDS[side].grow(.001).encloses(game._board_screen_rect(side)))
	game.queue_free();await process_frame
	FileAccess.open(OUT+"result.json",FileAccess.WRITE).store_string(JSON.stringify({"images":images,"source":"Godot native SubViewport","grid":[9,7],"capacity":63,"initial":6,"isolated_storage":true,"real_pointer_untouched":true,"last_cell_drag_release":true,"battle_both_boards_fit":true},"\t"))
	print("V111 NATIVE QA COMPLETE");quit()
