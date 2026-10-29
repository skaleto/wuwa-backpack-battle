extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const OUT="res://build/qa/ui-v65/native-input/"
var game
var checks=0
var failures=0
func _initialize():call_deferred("test")
func check(value:bool,label:String):
	checks+=1
	if not value:failures+=1;printerr("FAIL ",label)
func pointer(at:Vector2,down:bool,button:int=MOUSE_BUTTON_LEFT):
	var event=InputEventMouseButton.new();event.position=at;event.pressed=down;event.button_index=button;game._input(event)
func move(at:Vector2):
	var event=InputEventMouseMotion.new();event.position=at;game._input(event)
func tick(delta:float):
	game._process(delta);game.queue_redraw();await process_frame
func shot(name:String):
	game.queue_redraw();await process_frame
	if DisplayServer.get_name()!="headless":
		RenderingServer.force_draw(true);await process_frame;RenderingServer.force_draw(true)
		root.get_texture().get_image().save_png(OUT+name+".png")
func cell(x:float,y:float)->Vector2:return game._board_to_screen(game.BOARD+Vector2(x,y)*game.CELL)
func reset(skin:String):
	game.reset_slice();game.set_visual_skin(skin,false);game.buttons=[]
	game.run.shop[1]={"kind":"whiff","locked":false};game.run.gold=20
	game._clear_feedback();game.storage.save(game.run)
func test():
	DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1440,960)
	game=G.new();root.add_child(game);await process_frame;game.set_process(false);game.set_process_input(false)
	check(game.has_method("_item_drop_preview"),"game exposes exact nonmutating placement preview")
	check(game.get("stash_transfer")!=null,"game owns stash transfer animation")
	if failures:game.queue_free();await process_frame;quit(1);return
	for skin in ["chibi","original"]:
		reset(skin);await tick(.4)
		var before=game.run.duplicate(true);var source=game._offer_rect(1).get_center()
		pointer(source,true);move(cell(.5,.5));await tick(.02)
		var preview=game._item_drop_preview()
		check(preview.ok and preview.displaced.size()==1,skin+" occupied purchase preview accepts and names whole displaced item")
		check(game.run==before and game.storage.resume().gold==before.gold,skin+" preview never writes ownership or disk")
		await shot(skin+"-01-preview")
		pointer(game.mouse,false)
		check(game.run==preview.run,skin+" release commits exact preview")
		check(game.stash_transfer.flights.is_empty() and game.carry_replacement and game.dragging.uid==preview.displaced[0].uid and game.overlay.is_empty(),skin+" displaced item is immediately held without popup")
		check(game.storage.resume().stash==game.run.stash,skin+" committed displaced storage saved")
		await tick(.14);await shot(skin+"-02-transfer")
		await tick(.5);check(game.stash_transfer.flights.is_empty(),skin+" flight lands and clears")
		await shot(skin+"-03-landed")
		# V103 storage pages do not reject purchase/displacement.
		reset(skin)
		for n in 6:game.run.stash.append(game.inventory.make_piece("whiff","stored"+str(n)))
		before=game.run.duplicate(true);pointer(game._offer_rect(1).get_center(),true);move(cell(.5,.5))
		preview=game._item_drop_preview()
		check(preview.ok and game.run==before and preview.run.stash.size()==7,skin+" V103 seventh storage preview remains exact and readonly")
		await shot(skin+"-04-full-preview");pointer(game.mouse,false)
		check(game.run==preview.run and game.carry_replacement and game.overlay.is_empty(),skin+" V103 seventh displaced item is held after purchase")
		reset(skin)
		for n in 6:game.run.stash.append(game.inventory.make_piece("whiff","stored"+str(n)))
		await tick(.4);pointer(game._stash_rect(0).get_center(),true);move(cell(.5,.5))
		preview=game._item_drop_preview();check(preview.ok,skin+" stored incoming receives capacity credit")
		pointer(game.mouse,false)
		check(game.run==preview.run and game.run.stash.size()==6,skin+" stored incoming displaces without consuming an extra slot")
		await tick(.5)
		reset(skin)
		for n in 3:game.run.stash.append(game.inventory.make_piece("whiff","slot"+str(n)))
		var actual_slots=game.run.stash.duplicate(true)
		pointer(game._stash_rect(0).get_center(),true);move(cell(.5,.5))
		preview=game._item_drop_preview()
		var display=game._stash_display_preview()
		check(display.run.stash==preview.run.stash and display.run.stash[0].uid=="slot1" and game.run.stash==actual_slots,skin+" preview reflows stored icons to exact future slots without mutating storage")
		await shot(skin+"-06-stash-reflow");pointer(game.mouse,false);await tick(.5)
		# Multiple-object displacement through actual input.
		reset(skin);game.run.items=[]
		for n in 2:game.run.items.append(game.piece("whiff","target"+str(n),n,0))
		game.run.primary="";game.run.stash=[game.piece("w_sword","incoming",0,0)]
		pointer(game._stash_rect(0).get_center(),true);move(cell(.5,.5))
		preview=game._item_drop_preview()
		check(preview.ok and preview.displaced.size()==2,skin+" long item preview selects two whole occupants")
		pointer(game.mouse,false)
		check(game.run==preview.run and game.stash_transfer.flights.size()==1 and game.carry_replacement,skin+" one displaced item is held and the other falls into its slot")
		await tick(.13);await shot(skin+"-05-multiple");await tick(.6)
		check(game.inventory.validate_run(game.run),skin+" interaction ends with valid inventory")
		# A manually carried item is already at the stash when released; do not
		# replay its travel from the old board position a second time.
		reset(skin);var weapon=game.run.items[0];var grip=game._board_to_screen(game._item_rect(weapon,game.BOARD).get_center())
		pointer(grip,true);move(game._stash_rect(0).get_center());pointer(game.mouse,false)
		check(game.run.stash.any(func(v):return v.uid==weapon.uid) and game.stash_transfer.flights.size()==1 and game.stash_transfer.flights[0].from.get_center().distance_to(game.mouse)<game.CELL*2,skin+" manual stash drop falls from the held pose only once")
		# Right-click while holding a replacement remains the same pivot behavior.
		reset(skin);pointer(game._offer_rect(0).get_center(),true);move(cell(.5,.5))
		var pivot=game._held_center_screen();pointer(game.mouse,true,MOUSE_BUTTON_RIGHT);await tick(.08)
		check(game._held_center_screen().is_equal_approx(pivot),skin+" replacement rotation keeps held center")
		var event=InputEventKey.new();event.keycode=KEY_ESCAPE;event.pressed=true;game._input(event)
	print("DROP_FEEDBACK_V65: ",checks," checks, ",failures," failures")
	game.queue_free();await process_frame;quit(1 if failures else 0)
