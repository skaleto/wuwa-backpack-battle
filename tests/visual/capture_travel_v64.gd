extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const OUT="res://build/qa/ui-v64/after/"
var game
var checks=[]
func _initialize():
	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("run")
func check(ok:bool,label:String):
	checks.append({"ok":ok,"label":label})
	if not ok:printerr("FAIL ",label)
func shot(name:String):
	game.motion.modal_value=1 if not game.overlay.is_empty() else 0
	game.motion.modal_target=game.motion.modal_value
	game.paint_alpha=1;game.paint_offset=Vector2.ZERO
	game.queue_redraw();await process_frame
	if DisplayServer.get_name()!="headless":
		RenderingServer.force_draw(true);await process_frame;RenderingServer.force_draw(true);await process_frame
		root.get_texture().get_image().save_png(OUT+name+".png")
func paired(name:String):
	var state={"run":game.run.duplicate(true),"combat":game.combat.duplicate(true),"time":game.combat_time,"cursor":game.event_cursor,"opponent":game.opponent.duplicate(true)}
	for skin in ["original","chibi"]:
		game.set_visual_skin(skin,false);await shot(name+"-"+skin)
		check(state=={"run":game.run.duplicate(true),"combat":game.combat.duplicate(true),"time":game.combat_time,"cursor":game.event_cursor,"opponent":game.opponent.duplicate(true)},name+" "+skin+" identical frozen gameplay state")
func run():
	root.size=Vector2i(1440,960);game=G.new();root.add_child(game);await process_frame
	game.set_process(false);game.set_process_input(false)
	game.screen="camp";await paired("01-selection")
	game.screen="game";await paired("02-preparation")
	game._open_item_details(game.run.items[0],"board");game.item_selection_age=game.ITEM_SELECTION_DURATION
	await paired("03-details")
	game.overlay="";game.joined_slice()
	check(game.inventory.bags_legal(game.run.bags),"five independent bags are legal")
	for item in game.run.items:
		check(game.inventory.can_place(item,game.run.items,game.run.bags),"cross-bag item placement is legal: "+item.uid)
		var owners=game.run.bags.filter(func(b):return game.inventory.occupied(item).any(func(cell):return cell in game.inventory.occupied(b)))
		check(owners.size()>1,"item spans independently movable bags: "+item.uid)
	await paired("04-joined")
	game.overlay="catalogue";await shot("05-catalogue");game.overlay=""
	game.reset_slice();game._start_battle();game.battle_entry_age=1;game.combat_time=3.85;game.paused=true
	await paired("06-battle")
	var failures=checks.filter(func(v):return not v.ok).size()
	var file=FileAccess.open("res://build/qa/ui-v64/native-pairs.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"));file.close()
	print("V64 NATIVE: ",checks.size()," checks, ",failures," failures")
	game.queue_free();await process_frame;quit(1 if failures else 0)
