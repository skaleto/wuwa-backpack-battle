extends SceneTree
const B=preload("res://scripts/battle/battle.gd")
const F=preload("res://scripts/ui/battle/battle_feedback.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
var checks=0
var failures=0
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func bare()->Dictionary:return {"round":1,"leader":"","items":[],"bags":[],"supports":[]}
func _initialize():call_deferred("test")
func test():
	var b=B.new();var ctx=b.begin(bare(),bare(),17)
	ctx.time=21.8;b.step(ctx,21.9)
	ck(not ctx.events.any(func(e):return e.kind=="fatigue"),"fatigue never starts early")
	var before=ctx.states.map(func(s):return s.hp)
	b.step(ctx,22.0)
	var fatigue=ctx.events.filter(func(e):return e.kind=="fatigue")
	ck(fatigue.size()==2,"22 seconds emits one fatigue debit for each side")
	for e in fatigue:
		ck(e.uid=="fatigue" and e.get("source","")=="overtime" and int(e.get("target_side",-1))==e.side,"fatigue has explicit non-item source and affected side")
		ck(is_equal_approx(float(e.value),float(before[e.side])-float(ctx.states[e.side].hp)),"fatigue value equals actual HP loss")
	ck(is_equal_approx(ctx.states[0].hp,101.9),"22-second fatigue timing and amount unchanged")
	ctx.states[0].hp=.05;ctx.states[0].shield=30;ctx.states[1].hp=0
	var start=ctx.events.size();b.step(ctx,22.1)
	fatigue=ctx.events.slice(start).filter(func(e):return e.kind=="fatigue")
	ck(fatigue.size()==1 and is_equal_approx(float(fatigue[0].value),.05),"last fatigue debit is capped to remaining HP and preserves fractional precision")
	ck(ctx.states[0].shield==30 and ctx.states[0].hp==0,"fatigue still bypasses shield and ends at zero HP")
	ck(ctx.totals[0].damage==0 and ctx.totals[0].damage_by_uid.is_empty(),"fatigue never enters weapon damage totals")
	ck(is_equal_approx(float(ctx.totals[0].get("fatigue",-1)),.15),"fatigue accumulates separately from weapon damage")
	var frame=b.frame(22.1,ctx)
	ck(is_equal_approx(float(frame.get("fatigue_rate",-1)),1.15),"replay frame exposes current overtime rate")
	ck(is_equal_approx(float(frame.sides[0].get("fatigue",-1)),.15),"replay frame exposes cumulative fatigue loss by side")
	start=ctx.events.size();b.step(ctx,22.2)
	ck(not ctx.events.slice(start).any(func(e):return e.kind=="fatigue"),"dead sides never emit fabricated fatigue loss")
	# Real shield/heal/damage events, including shield destroyed without blocking.
	var inv=I.new();var shield=inv.make_piece("cool_tea","guard");var healer=inv.make_piece("turtle","heal");var blade=inv.make_piece("w_sword","blade")
	ctx=b.begin(bare(),bare(),17)
	b.add_shield(ctx,0,8,0,shield.uid);b.add_shield(ctx,0,4,0,"later")
	b.deal_v75_damage(ctx,1,blade,5,1,true,"attack")
	ctx.pending.append({"side":1,"actions":[{"type":"break_shield","value":4,"item":blade}]});b.commit_pending(ctx,2)
	b.deal_v75_damage(ctx,1,blade,5,3,true,"attack")
	b.heal(ctx,0,healer,20,4);b.heal(ctx,0,healer,20,5)
	var snapshot=ctx.events.duplicate(true)
	var own=F.contribution(ctx.events,0,"guard",INF);var later=F.contribution(ctx.events,0,"later",INF)
	ck(own.shield==8 and not own.has("absorbed"),"item shows actual shield gained without inventing absorption ownership")
	ck(later.shield==4 and not later.has("absorbed"),"later shield grant also has no invented absorption ownership")
	ck(F.contribution(ctx.events,0,"heal",INF).heal==2,"only effective healing counts")
	ck(F.contribution(ctx.events,1,"guard",INF).shield==0,"shield contribution is side isolated")
	var projection=F.new()
	ck(projection.has_method("absorption"),"actual absorption is available as a team statistic")
	if projection.has_method("absorption"):
		ck(projection.call("absorption",ctx.events,0,INF)==8,"only actual blocked damage counts as absorption; destroyed shield does not")
		ck(projection.call("absorption",ctx.events,1,INF)==0,"absorption isolates target side")
		ck(projection.call("absorption",ctx.events,0,.5)==0,"future absorption does not leak into display")
	var feedback=F.new()
	ck(feedback.has_method("result_contributions"),"result projection exposes real item contributions")
	if feedback.has_method("result_contributions"):
		var rows=feedback.call("result_contributions",ctx.events,0,[shield,healer,blade,{"uid":"later","kind":"cool_tea"}])
		ck(rows.size()==3,"result shows at most three contributing real items")
		ck(rows.all(func(r):return r.damage+r.heal+r.shield>0 and r.uid!="blade"),"zero contributions do not create result rows")
	ck(ctx.events==snapshot,"feedback projection does not modify replay events")
	# Repeated fractional amounts must not accumulate display-rounding errors.
	ctx=b.begin(bare(),bare(),17)
	b.deal_v75_damage(ctx,1,blade,1.234,1,true,"attack")
	b.heal(ctx,0,healer,1.234,2);b.add_shield(ctx,0,2.345,3,shield.uid)
	ck(is_equal_approx(F.contribution(ctx.events,1,"blade",INF).damage,ctx.totals[1].damage),"item damage projection uses actual damage instead of rounded event labels")
	ck(is_equal_approx(F.contribution(ctx.events,0,"heal",INF).heal,ctx.totals[0].heal),"effective heal contribution retains actual fractional amount")
	ck(is_equal_approx(F.contribution(ctx.events,0,"guard",INF).shield,ctx.totals[0].shield),"shield grant contribution retains actual fractional amount")
	# Real charged attack metadata must survive planning -> damage -> animation.
	var build=bare();build.items=[blade];ctx=b.begin(build,bare(),17);ctx.states[0].charge=6
	b.activate(ctx,0,blade,1);b.commit_pending(ctx,1)
	var hits=ctx.events.filter(func(e):return e.kind=="attack" and e.side==0)
	ck(not hits.is_empty() and hits.all(func(e):return e.get("charged",false)),"charged damage retains its actual heavy attack identity")
	var game=G.new();root.add_child(game);await process_frame;game.set_process(false);game.set_process_input(false)
	game._clear_feedback();game.audio.requested.clear();game.run=build;game.opponent=bare();game.run.phase="battle"
	var tired=b.event(22,0,"fatigue",.1,"fatigue","疲劳");tired.target_side=0
	game._play_event(tired)
	ck(game.floats.is_empty() and game.pending_impacts.is_empty() and game.audio.requested.is_empty() and game.flashes.is_empty(),"frequent fatigue events never spam floaters, flashes, projectiles or audio")
	if not hits.is_empty():
		game._play_event(hits[0]);ck(game.projectiles[-1].strong,"actual charged attack launches heavy feedback")
		game._apply_impact(hits[0]);ck(game.combat_vfx.impacts[-1].strong,"actual charged attack arrives with heavy impact")
		ck(game.audio.requested=={"attack":1},"V95: one attack has a weapon sound; arrival keeps visual impact without a second sound")
	# A real ordinary hit followed by a heavy hit needs room for the local cue.
	ctx=b.begin(build,bare(),17);b.activate(ctx,0,blade,2);b.commit_pending(ctx,2)
	var ordinary_hits=ctx.events.filter(func(e):return e.kind=="attack" and e.side==0)
	if not ordinary_hits.is_empty() and not hits.is_empty():
		game._clear_feedback();game._apply_impact(ordinary_hits[0]);game._apply_impact(hits[0])
		var distance=(game._floating_position(game.floats[0])-game._floating_position(game.floats[1])).abs()
		ck(distance.x>=100 or distance.y>=64,"special impact cue cannot overlap another actual damage number")
	ck(game.has_method("_result_title"),"ending title uses the shared historical/current progression projection")
	if game.has_method("_result_title"):
		game.run.phase="ending";game.run.wins=6;game.run.simulation_version="resonance-v92";game.combat={"winner":1}
		ck(game.call("_result_title")=="通关","completed historical six-win run remains cleared")
		game.run.simulation_version="resonance-v93"
		ck(game.call("_result_title")=="结束","six wins never display a new-version clear")
		game.run.wins=8;ck(game.call("_result_title")=="通关","current eight-win completed run displays clear")
	ck(game.has_method("_result_summary"),"result summary distinguishes missing legacy event evidence")
	if game.has_method("_result_summary"):
		game.combat={"legacy_result":true,"events":[],"totals":[{"damage":44.0}]}
		ck(game.call("_result_summary")=="输出 44.0","legacy summary preserves damage and omits unknown absorption")
		game.combat={"totals":[{"damage":44.0}]}
		ck(game.call("_result_summary")=="输出 44.0","missing event ledger never fabricates zero absorption")
		game.combat={"events":snapshot,"totals":[{"damage":44.0}]}
		ck(game.call("_result_summary")=="输出 44.0 · 挡伤 8.0","current complete ledger displays actual absorption")
	ck(game.has_method("_hud_limits"),"both HUDs consume the shared progression display limits")
	if game.has_method("_hud_limits"):
		game.run.phase="ending";game.run.wins=6;game.run.losses=2;game.run.simulation_version="resonance-v92"
		var original=game.run.duplicate(true)
		ck(game.call("_hud_limits")=={"wins":6,"losses":3},"completed historical HUD has six victory pips and three heart slots")
		ck(game.run==original,"historical HUD projection cannot mutate saved state")
		game.run.phase="result"
		ck(game.call("_hud_limits")=={"wins":8,"losses":4},"pending historical result uses the current ongoing-run HUD")
		game.run.phase="ending";game.run.simulation_version="resonance-v93"
		ck(game.call("_hud_limits")=={"wins":8,"losses":4},"current terminal HUD retains eight victory pips and four heart slots")
	game.queue_free();await process_frame
	print("BATTLE_READABILITY_V93 ",checks," checks, ",failures," failures");quit(1 if failures else 0)
