extends SceneTree
const G=preload("res://tests/fixtures/playable_fixture_v50.gd")
var game
var viewport
func _initialize()->void:
	root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true);call_deferred("run")
func shot(name:String)->void:
	game.paint_alpha=1;game.paint_offset=Vector2.ZERO;game.motion.transition_left=0;game.transition_image=null
	game.queue_redraw();await process_frame
	RenderingServer.force_draw(true);await process_frame;RenderingServer.force_draw(true);await process_frame
	assert(viewport.get_texture().get_image().save_png("res://build/qa/feedback-v101/after/"+name+".png")==OK)
func run()->void:
	DirAccess.make_dir_recursive_absolute("res://build/qa/feedback-v101/after")
	viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport);game=G.new();viewport.add_child(game);await process_frame
	game.set_process(false);game.set_process_input(false)
	var own=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/data/battle-review-v100/reported-fight.json")).build
	for key in own:game.run[key]=own[key]
	game.run.phase="result";game.run.round=6
	game.combat=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/data/battle-review-v100/replay.json"))
	game.opponent=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/data/battle-review-v100/enemy.json"))
	game.screen="game";game.combat_time=game.combat.duration;game.mouse=Vector2(1410,950)
	game._clear_feedback()
	await shot("01-result-entry")
	game._open_battle_review();await shot("02-all-items-and-timeline")
	game._review_action("item:i18");game._review_action("events_next")
	await shot("03-item-events")
	game._review_action("all_events");game._review_action("play")
	for n in 65:game._process(.1)
	game._review_action("play");await shot("04-paused-field-replay")
	game._review_action("panel");game._review_action("side:1");game._review_action("metric:shield")
	await shot("05-enemy-shield-at-time")
	# Mouse scrub, wheel and hit targets use actual input entry points.
	var input=InputEventMouseButton.new();input.position=game.REVIEW_VIEW.TRACK.get_center();input.button_index=MOUSE_BUTTON_LEFT;input.pressed=true
	game._input(input);input.pressed=false;game._input(input)
	assert(absf(game.review.time-game.review.duration*.5)<.01)
	game._review_action("events_next");await shot("06-scrubbed-timeline")
	game._review_action("close");game.run.phase="shop"
	var star=game.run.items.filter(func(item):return item.kind=="weapon_21020076")[0]
	game._open_item_details(star,"board");game.motion.modal_value=1;game.item_selection_age=game.ITEM_SELECTION_DURATION
	await shot("07-morning-star-detail")
	var log=FileAccess.open("res://build/qa/feedback-v101/after/capture-complete.txt",FileAccess.WRITE)
	log.store_string("7 native background captures; mouse scrub, full event paging, and high-tier star detail; isolated QA; no OS input or audio.")
	game.queue_free();await process_frame;quit()
