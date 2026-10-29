extends SceneTree
const G=preload("res://tests/fixtures/playable_fixture_v50.gd")
var game
var checks=[]
func check(ok:bool,label:String):
	checks.append({"ok":ok,"label":label})
	if not ok:printerr("FAIL ",label)
func _initialize():call_deferred("run")
func snapshot()->Dictionary:
	return {"run":game.run.duplicate(true),"opponent":game.opponent.duplicate(true),"combat":game.combat.duplicate(true),"cursor":game.event_cursor,"time":game.combat_time,"speed":game.speed,"paused":game.paused,"screen":game.screen,"overlay":game.overlay}
func run():
	game=G.new();root.add_child(game);await process_frame;game.set_process(false);game.set_process_input(false)
	check(game.has_method("set_visual_skin"),"game exposes display-only switch")
	if game.has_method("set_visual_skin"):
		for phase in ["prepare","drag","forge","paused_battle","result"]:
			game.reset_slice()
			if phase=="drag":game._begin_shop_drag(0)
			if phase=="forge":game._action("forge");game._action("forge_confirm")
			if phase in ["paused_battle","result"]:
				game._start_battle();game.combat_time=3.85;game.event_cursor=7;game.paused=true;game.speed=2.0
				if phase=="result":game.run.phase="result"
			var before=snapshot()
			for n in 4:
				if n%2==0:
					var key_event=InputEventKey.new();key_event.keycode=KEY_F6;key_event.pressed=true;game._input(key_event)
				else:game.set_visual_skin("original",false)
				check(snapshot()==before,phase+" switch "+str(n)+" preserves live state")
			check(game.dragging.is_empty() and game.forge_output.is_empty(),phase+" cancels only uncommitted gestures")
			for style in ["paper","patchwork"]:
				game.SKIN.set_bag_style(style,false)
				check(snapshot()==before,phase+" bag style "+style+" preserves all gameplay/replay state")
		var switch_before=snapshot()
		var pointer=InputEventMouseButton.new();pointer.button_index=MOUSE_BUTTON_LEFT;pointer.pressed=true;pointer.position=game.VISUAL_SKIN_BUTTON.get_center();game._input(pointer)
		check(snapshot()==switch_before,"visible pointer switch preserves exact live state")
		check(not game.VISUAL_SKIN_BUTTON.has_point(game._wallet_position()),"skin control leaves wallet visible")
		game.set_visual_skin("chibi",false)
		for kind in ["w_sword","w_rectifier"]:
			game._ensure_icon(kind)
			var fit=game._projection_for(kind,0,56)
			check(fit.transform.get_scale().is_equal_approx(Vector2.ONE*fit.scale),kind+" alpha fit preserves original aspect")
		game.overlay="item_details";var before=snapshot();var ev=InputEventKey.new();ev.keycode=KEY_F6;ev.pressed=true;game._input(ev)
		check(game.SKIN.current=="original" and snapshot()==before,"F6 works in modal without closing or mutating it")
	var failures=checks.filter(func(v):return not v.ok).size()
	print("SKIN INTEGRATION: ",checks.size()," checks, ",failures," failures")
	game.queue_free();await process_frame;quit(1 if failures else 0)
