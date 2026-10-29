extends SceneTree
## Native-event smoke route, isolated from the player's save and preferences.
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const OUT="res://build/qa/ui-v65/native-input/"
var game
var checks=[]
func _initialize():
	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("run")
func check(ok:bool,label:String):
	checks.append({"ok":ok,"label":label})
	if not ok:printerr("FAIL ",label)
func pointer(at:Vector2,down:bool,button:int=MOUSE_BUTTON_LEFT):
	var e=InputEventMouseButton.new();e.position=at;e.pressed=down;e.button_index=button
	game._input(e)
func move(at:Vector2):
	var e=InputEventMouseMotion.new();e.position=at;game._input(e)
func tick(delta:float):
	game._process(delta);game.queue_redraw();await process_frame
func shot(name:String):
	game.queue_redraw();await process_frame
	if DisplayServer.get_name()!="headless":
		RenderingServer.force_draw(true);await process_frame
		RenderingServer.force_draw(true)
		root.get_texture().get_image().save_png(OUT+name+".png")
func at(x:float,y:float)->Vector2:
	return game._board_to_screen(game.BOARD+Vector2(x,y)*game.CELL)
func run():
	root.size=Vector2i(1440,960);game=G.new();root.add_child(game);await process_frame
	game.set_process(false);game.set_process_input(false);game.set_visual_skin("chibi",false)
	await tick(.3)
	var before=game.run.duplicate(true)
	var offer=game._offer_rect(0).get_center();move(offer);pointer(offer,true)
	check(game.run==before and not game.dragging.is_empty(),"shop press is a preview without purchase")
	var center=game._held_center_screen();pointer(offer,true,MOUSE_BUTTON_RIGHT)
	await tick(.08)
	check(game._held_center_screen().distance_to(center)<.01 and game.dragging.rotation==1,"right-click rotates about held center")
	move(at(7.5,4.5));await tick(.03);await shot("02-rotated-shop-preview")
	pointer(game.mouse,false);check(game.run==before and game.rejection_left>0 and game.overlay.is_empty(),"invalid placement rejects with local feedback, no purchase or popup")
	await shot("03-invalid-shop-release");await tick(.4)
	var echo=game._offer_rect(1).get_center();move(echo);pointer(echo,true)
	move(game._stash_rect(0).get_center());pointer(game.mouse,false)
	check(game.run.stash.size()==1 and game.run.shop[1].is_empty() and game.run.gold==before.gold-2,"valid stash release buys once for displayed price")
	await tick(.3);await shot("04-stash-purchase")
	var bag=game._offer_rect(5).get_center();move(bag);pointer(bag,true)
	move(at(4.5,1.5));pointer(game.mouse,false);await tick(.3)
	check(game.run.bags.size()==2 and game.run.gold==before.gold-5,"independent bag purchases at valid detached position")
	await shot("05-detached-bag-purchase")
	# Existing UI paths drive a complete auto battle, not a constructed result.
	var launch=game.QL.BATTLE.get_center();move(launch);pointer(launch,true);pointer(launch,false)
	check(game.run.phase=="battle" and not game.combat.is_empty(),"native battle button starts simulation")
	for n in 18:await tick(.2)
	await shot("06-live-battle")
	for n in 500:
		if game.run.phase=="result":break
		await tick(.2)
	check(game.run.phase=="result","auto battle reaches result")
	await tick(.5);await shot("07-result")
	check(game.inventory.validate_run(game.run),"result preserves a legal inventory")
	var failures=checks.filter(func(v):return not v.ok).size()
	var file=FileAccess.open("res://build/qa/ui-v65/native-flow.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"mode":DisplayServer.get_name()},"\t"));file.close()
	print("V65 NATIVE FLOW ",checks.size()," checks ",failures," failures")
	game.queue_free();await process_frame;quit(1 if failures else 0)
