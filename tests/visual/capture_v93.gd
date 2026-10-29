extends SceneTree
## Real simulator events rendered natively in a hidden nonfocusable SubViewport.
## The fixture owns a separate QA Storage directory. No desktop input is used.
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
var game;var viewport;var report
func _initialize():
	root.hide();root.unfocusable=true;call_deferred("capture")
func shot(label:String):
	game.queue_redraw();await process_frame;RenderingServer.force_draw(true);await process_frame
	RenderingServer.force_draw(true);await process_frame
	assert(viewport.get_texture().get_image().save_png("res://build/qa/gameplay-v93/native/"+label+".png")==OK)
	report.store_line(label);report.flush()
func prepare(leader:String="aemeath"):
	game.reset_slice();game._close_item_details();game.run=game.inventory.new_run(leader,19)
	game.run.shop=[{},{},{},{},{},{}];game.run.items=[];game.run.stash=[];game.run.bags=[];game.run.serial=50;game.run.primary=""
	for y in [0,2,4]:
		for x in [0,3]:game.run.bags.append(game.piece("satchel","bag%d_%d"%[x,y],x,y))
	game.mouse=Vector2(30,930);game._clear_feedback();game.motion.modal_value=0;game.motion.modal_target=0
func begin():
	assert(game.inventory.validate_run(game.run));assert(game.inventory.validate_run(game.opponent))
	game.combat=game.engine.simulate(game.run,game.opponent,31)
	game.run.phase="battle";game.combat_time=0;game.battle_entry_age=1;game.transition_image=null;game.motion.transition_left=0
	report.store_line("REPLAY winner=%s duration=%.1f totals=%s"%[game.combat.winner,game.combat.duration,game.combat.totals])
func seek(t:float):
	game._clear_feedback();game.combat_time=t
	for e in game.combat.events:
		if float(e.time)>t or float(e.time)<t-.75:continue
		game._play_event(e)
		if t>=float(e.time)+game.COMBAT_VFX.TRAVEL and e.kind in ["attack","derived","counter","heal","shield"]:game._apply_impact(e)
	game.projectiles=game.projectiles.filter(func(p):return false)
	game.pending_impacts=[]
func capture():
	var only_historical="--historical-only" in OS.get_cmdline_user_args()
	report=FileAccess.open("res://build/qa/gameplay-v93/native/"+("capture-historical.log" if only_historical else "capture.log"),FileAccess.WRITE)
	viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport);game=G.new();viewport.add_child(game);await process_frame
	game.set_process(false);game.set_process_input(false)
	if only_historical:
		await historical();report.store_line("COMPLETE: historical HUD, hidden native render, isolated QA");report.close()
		game.queue_free();await process_frame;quit();return
	prepare();game.run.items=[game.piece("w_sword","sword",1,1),game.piece("turtle","turtle",1,2),game.piece("cool_tea","tea",4,1)]
	game.run.round=11
	game.opponent=game.run.duplicate(true);game.opponent.items=[game.piece("w_sword","enemy",1,1),game.piece("cool_tea","enemy_tea",4,1)]
	game.run.wins=7;game.run.losses=3;begin();seek(5)
	await shot("01-seven-wins-one-heart-left")
	assert(game.combat.duration>25);seek(25)
	assert(game._vitals_frame().fatigue_rate>0);await shot("02-visible-overtime")
	seek(game.combat.duration+1);game.run.phase="result"
	var rows=game._result_contributions()
	assert(rows.size()==3 and rows.any(func(r):return r.heal>0) and rows.any(func(r):return r.shield>0))
	report.store_line("RESULT ROWS "+str(rows));await shot("03-real-contributions")
	game.run.phase="ending";game.run.wins=8;await shot("04-eight-win-ending")
	game.run.phase="battle";game.run.wins=7;seek(21.9);await shot("05-before-overtime")
	# Each burst shown below was emitted by a complete natural simulation.
	prepare();game.run.items=[game.piece("weapon_21020024","sword",1,1),game.piece("turtle","turtle",1,2)]
	game.opponent=game.run.duplicate(true);game.opponent.items=[game.piece("w_sword","enemy",1,1),game.piece("turtle","enemy_turtle",1,2)];begin()
	for spec in [["heavy","06-heavy-impact"],["derived","07-derived-impact"]]:
		var matches=game.combat.events.filter(func(e):return e.side==0 and (e.get("charged",false) and e.kind=="attack" if spec[0]=="heavy" else e.kind==spec[0]))
		assert(not matches.is_empty());var ev=matches[0]
		seek(float(ev.time)+game.COMBAT_VFX.TRAVEL+.02);report.store_line("IMPACT "+str(ev));await shot(spec[1])
	prepare("lu_hers");game.run.items=[game.piece("weapon_21040064","guard",1,1),game.piece("turtle","turtle",1,2)]
	game.opponent=game.run.duplicate(true);game.opponent.items=[game.piece("w_sword","enemy",1,1),game.piece("turtle","enemy_turtle",1,2)];begin()
	var counters=game.combat.events.filter(func(e):return e.side==0 and e.kind=="counter")
	assert(not counters.is_empty());seek(float(counters[0].time)+game.COMBAT_VFX.TRAVEL+.02)
	report.store_line("IMPACT "+str(counters[0]));await shot("08-counter-impact")
	prepare();game.run.round=11;game.run.wins=7;game.run.losses=3
	game.run.items=[game.piece("w_sword","sword",1,1)]
	var draws=0
	while draws<30:
		assert(game.inventory.refresh(game.run,false));draws+=1
		if game.run.shop.any(func(offer):return not offer.is_empty() and int(game.C.items[offer.kind].get("craft_tier",game.C.items[offer.kind].get("rarity",1)))>=4):break
	assert(game.run.shop.any(func(offer):return not offer.is_empty() and int(game.C.items[offer.kind].get("craft_tier",game.C.items[offer.kind].get("rarity",1)))>=4))
	report.store_line("LATE SHOP draws=%d offers=%s"%[draws,game.run.shop]);await shot("09-round-eleven-generated-shop")
	await historical()
	report.store_line("COMPLETE: hidden native render, isolated QA storage, no desktop input");report.close()
	game.queue_free();await process_frame;quit()

func historical():
	prepare();game.run.round=8;game.run.wins=6;game.run.losses=2;game.run.simulation_version="resonance-v92"
	game.run.items=[game.piece("w_sword","sword",1,1),game.piece("turtle","turtle",1,2)]
	game.opponent=game.run.duplicate(true);game.opponent.items=[game.piece("w_sword","enemy",1,1)]
	var old_engine=load("res://tests/fixtures/data/gameplay-v93/before/scripts/battle_v75.gd").new()
	game.run.combat=old_engine.simulate(game.run,game.opponent,31)
	game.combat=game.storage.legacy_result(game.run);game.run.phase="ending";game.combat_time=float(game.combat.duration)+1
	assert(game._result_title()=="通关" and not "挡伤" in game._result_summary())
	report.store_line("LEGACY "+str(game.combat));await shot("10-historical-six-win-summary")
