extends SceneTree
const G=preload("res://tests/fixtures/playable_fixture_v50.gd")
var game
var checks=[]
func _initialize():
	DirAccess.make_dir_recursive_absolute("user://qa-reports/")
	call_deferred("run")
func check(ok:bool,label:String):
	checks.append({"ok":ok,"label":label})
	if not ok:printerr("FAIL ",label)
func at(x:float,y:float)->Vector2:return game._board_to_screen(game.BOARD+Vector2(x,y)*game.CELL)
func run():
	root.size=Vector2i(1440,960);game=G.new();root.add_child(game);await process_frame;game.set_process(false);game.set_process_input(false)
	for kind in ["puppet","answer"]:
		check(game.inventory.cells({"kind":kind,"rotation":0})==[Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)],"compact full body uses complete square "+kind)
	var inv=game.inventory
	var bags=[game.piece("satchel","b1",0,0),game.piece("satchel","b2",5,4)]
	check(inv.bags_legal(bags),"disconnected bags are legal")
	var full=[]
	for y in 6:
		for x in 4:full.append(game.piece("pouch","p%d-%d"%[x,y],x*2,y))
	# Pouch is a 2 by 2 square; fill with sixteen horizontal strips instead.
	full=[]
	for y in 6:
		for x in 2:
			var strip=game.piece("strip","s%d-%d"%[x,y],x*3,y);strip.rotation=1;full.append(strip)
	check(inv.coverage(full).size()==36 and inv.bags_legal(full),"36 visible cells and twelve bags are legal")
	var invalid=bags.duplicate(true);invalid[1].x=0;invalid[1].y=0
	check(not inv.bags_legal(invalid),"overlapping bags remain invalid")
	invalid=bags.duplicate(true);invalid[1].x=7
	check(not inv.bags_legal(invalid),"out of bounds remains invalid")
	game.run.bags=bags;game.run.items=[];game.run.primary="";game.storage.save(game.run)
	check(game.storage.resume().get("bags",[])==bags,"disconnected bags save and resume")
	game.reset_slice();game.set_visual_skin("chibi",false);game.motion.modal_value=0;game.motion.modal_target=0
	game.item_selection_age=game.ITEM_SELECTION_DURATION*.5
	var rect=Rect2(300,300,100,100);var lifted=game._selection_rect(rect)
	check(lifted.get_center().distance_to(rect.get_center())<=4.01 and lifted.size.x/rect.size.x<=1.0201,"selection lift is subtle 4px and at most 1.02 scale")
	game.mouse=at(.5,.5)
	check(game._held_pose().get_scale().x/game._board_transform().get_scale().x<=1.0201,"held item scale stays at most 1.02")
	game._open_item_details(game.run.items[0],"board")
	check(game.has_method("_detail_card_rect"),"anchored detail card exposes screen-clamped bounds")
	if game.has_method("_detail_card_rect"):
		var card=game._detail_card_rect()
		check(card.size.x>=300 and card.size.x<=360 and Rect2(8,8,1424,944).encloses(card),"detail card is compact and screenclamped")
	game.overlay="";game.motion.modal_value=0;game.motion.modal_target=0
	game.dragging=game.run.bags[1].duplicate(true);game.drag_origin="bag";game.drag_offset=Vector2i.ZERO;game.drag_pressed=false;game.mouse=at(.5,.5)
	var before=game.run.duplicate(true);game.toast_timer=0;game._mouse_up()
	check(game.run==before and game.toast_timer==0 and game.overlay.is_empty(),"invalid bag drop is atomic without text or modal")
	check(game.has_method("_item_body_at"),"visible body has a shared pick and hover hit test")
	check(game.has_method("audio_diagnostics"),"event audio diagnostics available")
	var failure=checks.filter(func(v):return not v.ok).size()
	var f=FileAccess.open("user://qa-reports/direct-play-v53.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failure},"\t"));f.close()
	print("V53 DIRECT PLAY ",checks.size()," checks ",failure," failures")
	game.queue_free();await process_frame;quit(1 if failure else 0)
