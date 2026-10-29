extends SceneTree
## A frozen real battle, rendered without activating a window or using player saves.
const OUT = "res://build/qa/pockets-v129-concepts/shield/"
var g
var viewport: SubViewport
var tag = "after"
var checks = 0
func ck(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		printerr("FAIL ", label)
		quit(1)
func _initialize() -> void:
	root.hide(); root.unfocusable = true
	AudioServer.set_bus_mute(0, true)
	call_deferred("capture")
func shot(name: String) -> void:
	g.queue_redraw()
	await process_frame
	RenderingServer.force_draw(true)
	await process_frame
	ck(viewport.get_texture().get_image().save_png(OUT + tag + "-" + name + ".png") == OK, name)
func capture() -> void:
	if DisplayServer.get_name() == "headless": quit(2); return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="): tag = arg.trim_prefix("--tag=")
	DirAccess.make_dir_recursive_absolute(OUT)
	viewport = SubViewport.new(); viewport.size = Vector2i(1440, 960)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	g = preload("res://tests/fixtures/travel_fixture_v64.gd").new()
	viewport.add_child(g); await process_frame
	g.set_process(false); g.set_process_input(false)
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/data/feedback-v120/input/hsin-round10.json"))
	ck(g.storage.write_json(g.storage.root_path + "run.json", raw), "QA record")
	g.run = g.storage.resume(); g.opponent = g.run.opponent.duplicate(true)
	g.combat = g.run.combat.duplicate(true); g.run.phase = "battle"
	g.screen = "game"; g.combat_time = .62; g.event_cursor = 0
	g.battle_entry_age = 1; g.mouse = Vector2(1430, 950)
	g._clear_feedback(); g.paused = true
	var frozen = g.combat.duplicate(true)
	var run_before = g.run.duplicate(true)
	var disk_before = FileAccess.get_file_as_bytes(g.storage.root_path + "run.json")
	ck(g._vitals_frame().sides[0].shield > 0, "real recorded shield is visible")
	await shot("persistent")
	var event = g.combat.events.filter(func(e): return e.kind == "shield" and e.value > 0)[0].duplicate(true)
	event.arrived = true
	g._play_event(event)
	ck(g.motion.events.any(func(e): return e.kind == "shield"), "real shield gain still has feedback")
	for tick in [0.04, 0.12, 0.26, 0.43]:
		for e in g.motion.events:
			if e.kind == "shield": e.age = tick
		await shot("gain-%02d" % int(tick * 100))
	var effects = g.motion.events.duplicate(true)
	g._process(.5)
	ck(g.motion.events == effects, "pause freezes the shield feedback")
	g.motion.update(1, 1)
	ck(g.motion.events.is_empty(), "shield feedback expires")
	ck(g.combat == frozen and g.run == run_before, "render and feedback cannot alter battle or inventory")
	ck(FileAccess.get_file_as_bytes(g.storage.root_path + "run.json") == disk_before, "no save writes")
	FileAccess.open(OUT + tag + "-validation.txt", FileAccess.WRITE).store_string("Hidden unfocusable native SubViewport, 1440x960. Frozen hsin-round10 recording. Independent QA Storage. %s checks passed. No system input.\n" % checks)
	g.queue_free(); await process_frame
	print("SHIELD_V129 ", tag, " ", checks, " checks passed")
	quit()
