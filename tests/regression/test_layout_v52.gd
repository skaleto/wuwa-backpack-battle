extends SceneTree
## Real pointer contract for the first approved Dango preparation composition.
const G=preload("res://tests/fixtures/playable_fixture_v50.gd")
var game
var checks=[]
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	checks.append({"ok":ok,"label":label})
	if not ok:printerr("FAIL ",label)
func tick():
	game.queue_redraw();await process_frame
	if DisplayServer.get_name()!="headless":RenderingServer.force_draw(true)
func click(at:Vector2):
	var move=InputEventMouseMotion.new();move.position=at;game._input(move)
	for down in [true,false]:
		var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=at;game._input(e)
	await tick()
func control(action:String)->Rect2:
	for b in game.buttons:
		if b.action==action:return b.rect
	return Rect2()
func run():
	DirAccess.make_dir_recursive_absolute("res://build/qa/ui-v52/checks")
	root.size=Vector2i(1440,960);game=G.new();root.add_child(game);await process_frame;game.set_process(false);game.set_process_input(false)
	game.set_visual_skin("chibi",false);game.motion.modal_value=0;await tick()
	var offers=[]
	for n in 6:offers.append(game._offer_rect(n))
	check(offers[0].position.y==offers[1].position.y and offers[1].position.y==offers[2].position.y,"Q top shelf has three columns")
	check(offers[3].position.y==offers[4].position.y and offers[4].position.y==offers[5].position.y and offers[3].position.y>offers[0].end.y,"Q second shelf has three separate offers")
	check(game._board_screen_rect().is_equal_approx(Rect2(288,180,640,480)),"Q board uses fixed first-draft 8 x 6 lattice")
	for n in 6:
		for m in range(n+1,6):check(not offers[n].intersects(offers[m]),"Q offers do not overlap %d/%d"%[n,m])
		var before=game.run.duplicate(true)
		var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;e.position=offers[n].position+Vector2(50,44);game._input(e)
		check(game.drag_offer_index==n and game.drag_origin=="shop" and game.run==before,"Q offer %d lifts its actual object without purchase"%n)
		var cancel=InputEventKey.new();cancel.keycode=KEY_ESCAPE;cancel.pressed=true;game._input(cancel);await tick()
	for n in 5:
		for offer in game.run.shop:offer["locked"]=false
		var lock_rect=control("lock:"+str(n));var before=game.run.duplicate(true)
		await click(lock_rect.get_center())
		check(game.run.shop[n].locked!=before.shop[n].locked and game.run.gold==before.gold and game.dragging.is_empty(),"Q lock %d is distinct from offer purchase"%n)
	var before=game.run.duplicate(true);await click(control("bag_choice").get_center())
	check(game.run.shop[5].kind!=before.shop[5].kind and game.run.gold==before.gold and game.dragging.is_empty(),"Q sixth control changes bag choice without purchase")
	var battle=control("battle")
	check(battle.size.x>=180 and absf(battle.size.x-battle.size.y)<=10,"Q battle target is a large round action")
	await click(battle.position+Vector2(2,2));check(game.run.phase=="shop","Q round battle excludes rectangle corner")
	await click(battle.get_center());check(game.run.phase=="battle","Q round battle center starts real combat")
	game.reset_slice();game.set_visual_skin("original",false);await tick()
	check(game._offer_rect(0)==Rect2(1074,234,300,80) and game._offer_rect(5)==Rect2(1074,669,300,80),"original vertical shop remains unchanged")
	check(game._board_screen_rect().is_equal_approx(Rect2(game.PREPARATION_ORIGIN,Vector2(8,6)*game.PREPARATION_PITCH)),"original fixed lattice remains unchanged")
	var failures=checks.filter(func(v):return not v.ok).size()
	var f=FileAccess.open("res://build/qa/ui-v52/checks/layout.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"));f.close()
	print("V52 LAYOUT: ",checks.size()," checks, ",failures," failures");game.queue_free();await process_frame;quit(1 if failures else 0)
