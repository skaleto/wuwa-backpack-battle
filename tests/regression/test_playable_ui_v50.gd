extends SceneTree
const G=preload("res://tests/fixtures/playable_fixture_v50.gd")
var game
var OUT="res://build/qa/demo-v50/"
var checks=[]
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="):OUT=arg.trim_prefix("--evidence-dir=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("run")
func check(ok:bool,label:String):
	checks.append({"ok":ok,"label":label})
	if not ok:printerr("FAIL ",label)
func tick(n:int=1):
	for i in n:
		game._process(1.0/30);game.queue_redraw();await process_frame
		if DisplayServer.get_name()!="headless":RenderingServer.force_draw(false,1.0/30)
func point(x:float,y:float)->Vector2:return game._board_to_screen(game.BOARD+Vector2(x,y)*game.CELL)
func move(p:Vector2):
	var ev=InputEventMouseMotion.new();ev.position=p;game._input(ev);await tick()
func button(down:bool,id:int=MOUSE_BUTTON_LEFT):
	var ev=InputEventMouseButton.new();ev.position=game.mouse;ev.pressed=down;ev.button_index=id;game._input(ev);await tick()
func key(code:int):
	var ev=InputEventKey.new();ev.keycode=code;ev.pressed=true;game._input(ev);await tick()
func action(id:String,settle:int=12):
	var matches=game.buttons.filter(func(v):return v.action==id and v.enabled)
	check(not matches.is_empty(),"visible pointer action "+id)
	if matches.is_empty():return
	await move(matches[0].rect.get_center());await button(true);await button(false);await tick(settle)
func shot(name:String):
	if DisplayServer.get_name()=="headless":return
	await tick(2);root.get_texture().get_image().save_png(OUT+name+".png")
func until(time:float):
	for i in range(1000):
		if game.combat_time>=time:return
		await tick()
func run():
	root.size=Vector2i(1440,960);game=G.new();root.add_child(game);await process_frame;game.set_process(false);game.set_process_input(false)
	await tick(12);await shot("01-preparation-linked")
	var before=game.run.duplicate(true)
	await action("forge");await shot("02-recipe")
	await action("forge_confirm")
	check(game.run==before,"forge button opens placement without consuming")
	check(game.get("forge_output") is Dictionary and not game.get("forge_output").is_empty(),"full board output ghost is active")
	if game.get("forge_output") is Dictionary and not game.get("forge_output").is_empty():
		await move(point(.5,.5));await shot("03-craft-legal-adjacency-lost")
		await button(true,MOUSE_BUTTON_RIGHT);await button(false,MOUSE_BUTTON_RIGHT)
		check(game.forge_output.rotation==1 and game.run==before,"right button rotates preview without mutation")
		await shot("04-craft-rotated")
		await move(point(2.5,.5));await button(true);await button(false)
		check(game.run==before and not game.forge_output.is_empty(),"illegal chosen collision remains uncommitted")
		await shot("05-craft-invalid")
		await key(KEY_ESCAPE);check(game.run==before and game.forge_output.is_empty(),"Esc cancels output preview atomically")
		await action("forge");await action("forge_confirm")
		await move(point(.5,.5));await button(true);await button(false);await tick(12)
		check(game.run.items.size()==3 and game.run.serial==5 and game.run.gold==before.gold,"legal click commits exact recipe once")
		check(game.inventory.adjacent(game.inventory.primary_weapon(game.run),game._piece_by_uid("i2")),"chosen square result retains edge adjacency")
		await shot("06-crafted-unlinked")
		await move(point(2.5,.5));await button(true);await move(point(3.5,.5));await tick(12);await button(false);await tick(12)
		check(not game.inventory.adjacent(game.inventory.primary_weapon(game.run),game._piece_by_uid("i2")),"real echo drag away removes adjacency")
		await move(point(3.5,.5));await button(true);await move(point(2.5,.5));await button(false);await tick(12)
		check(game.inventory.adjacent(game.inventory.primary_weapon(game.run),game._piece_by_uid("i2")),"real echo drag back beside square restores adjacency")
		await shot("07-adjacency-restored")
	# Fixed presentation fixture: three chases should not depend on the current
	# practice opponent shopping policy. Live opponents are tested separately.
	game.opponent=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/presentation-opponent-v50.json"))
	game.overlay="";await tick(12);await action("battle",0)
	check(game.run.phase=="battle","battle starts from real build")
	check(game.transition_image==null and game.battle_entry_age<1.0,"preparation-to-battle transition moves actual board without screenshot copy")
	await shot("08-preparation-battle-transition")
	await tick(32)
	for side in range(2):
		var rect=game._board_screen_rect(side)
		check(rect.size.x>=528 and rect.size.y>=396,"battle region accommodates legible 8x6 grid "+str(side))
		check(is_equal_approx(game._board_transform(side).get_scale().x*game.CELL,66),"battle cell pitch is 66 pixels "+str(side))
	await until(3.85);await shot("09a-battle-marks")
	await until(4.0);await shot("09b-battle-mark-transfer")
	await until(4.23);await shot("09c-battle-chase")
	await until(4.5);await shot("09d-battle-advance")
	check(game.combat.events.any(func(e):return e.kind=="cooldown_advance"),"native battle contains actual candidate advance")
	game.paused=true;var frozen=game.combat_time;await tick(5);check(game.combat_time==frozen,"pause freezes replay and causal feedback")
	game.paused=false;game._action("skip");await tick(8);await shot("10-result")
	check(game.run.phase in ["result","ending"],"battle settles")
	check(game.has_method("_chase_summary_rows"),"postbattle has item chase rows")
	if game.has_method("_chase_summary_rows"):
		var rows=game._chase_summary_rows()
		check(rows.size()>0 and rows.size()<=3,"postbattle item summary is capped at three rows")
		if not rows.is_empty():check(rows[0].chases==3 and rows[0].marks==5 and is_equal_approx(rows[0].advance,1.5),"postbattle reports three actual chases, five consumed marks and 1.5 seconds actual advance")
	game.reset_slice();game.run.items=[]
	var serial=0
	for cell in [Vector2i(0,0),Vector2i(2,0),Vector2i(4,0),Vector2i(0,1),Vector2i(2,1),Vector2i(4,1),Vector2i(0,2),Vector2i(0,3)]:
		serial+=1;game.run.items.append(game.piece("w_rectifier","i"+str(serial),cell.x,cell.y))
	game.run.primary="i1";game.run.serial=serial;game._action("battle");game.transition_image=null;game.motion.transition_left=0
	await until(4.5);game.paused=true
	check(game._current_frame().waiting[0].values().any(func(v):return v),"real stamina-starved weapons are ready and waiting")
	await shot("11-ready-waiting-stamina")
	var failures=checks.filter(func(v):return not v.ok).size()
	var file=FileAccess.open(OUT+("ui-headless" if DisplayServer.get_name()=="headless" else "native-verification")+".json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"));file.close()
	print("V50 UI: ",checks.size()," checks, ",failures," failures");game.queue_free();await process_frame;quit(1 if failures else 0)
