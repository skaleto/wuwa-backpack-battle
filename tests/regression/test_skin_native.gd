extends SceneTree
const G=preload("res://tests/fixtures/playable_fixture_v50.gd")
var game
var checks=[]
func _initialize():call_deferred("run")
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
		root.get_texture().get_image().save_png("res://build/qa/demo-v50/skins/"+name+".png")
func paired(name:String):
	var state={"run":game.run.duplicate(true),"combat":game.combat.duplicate(true),"time":game.combat_time,"cursor":game.event_cursor,"opponent":game.opponent.duplicate(true)}
	for skin in ["original","chibi"]:
		game.set_visual_skin(skin,false);await shot(name+"-"+skin)
		check(state=={"run":game.run.duplicate(true),"combat":game.combat.duplicate(true),"time":game.combat_time,"cursor":game.event_cursor,"opponent":game.opponent.duplicate(true)},name+" "+skin+" exact frozen state")
func run():
	root.size=Vector2i(1440,960);game=G.new();root.add_child(game);await process_frame;game.set_process(false);game.set_process_input(false)
	game.age=8;game.selection_age=2;game.phase_age=2;game.reroll_age=2;game.motion.transition_left=0
	game.screen="camp";await paired("01-selection")
	game.screen="game";await paired("02-preparation")
	game.mouse=game._sell_rect().get_center();game.motion.hover_values["sell_area"]=1.0
	await paired("11-sell-caption")
	game.mouse=Vector2.ZERO;game.motion.hover_values["sell_area"]=0.0
	game._open_item_details(game.run.shop[0],"shop");await paired("03-shop-details")
	game._open_item_details(game.run.items[0],"board");await paired("03-details")
	game.overlay="";game._action("forge");await paired("04-forge")
	game.overlay="crew";await paired("05-recruit")
	game.overlay="catalogue";await paired("06-catalogue")
	game.overlay="ghosts";await paired("07-ghosts")
	game.overlay=""
	game.run.bags=[game.piece("satchel","b1",0,0),game.piece("pouch","b2",3,0),game.piece("strip","b3",5,0),game.piece("corner","b4",0,2),game.piece("travel","b5",2,2)]
	var blade=game.piece("w_sword","cross2",0,1);blade.rotation=1
	game.run.items=[game.piece("w_rectifier","cross1",2,0),blade];game.run.primary="cross1"
	await paired("10-five-bags-crossing")
	game.reset_slice();game._start_battle();game.battle_entry_age=1;game.combat_time=3.85;game.paused=true;await paired("08-battle")
	game._action("skip");game._process(.05);game.motion.transition_left=0;await paired("09-result")
	var failures=checks.filter(func(v):return not v.ok).size()
	var file=FileAccess.open("res://build/qa/demo-v50/skins/native-pairs.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"));file.close()
	print("SKIN NATIVE: ",checks.size()," checks, ",failures," failures");game.queue_free();await process_frame;quit(1 if failures else 0)
