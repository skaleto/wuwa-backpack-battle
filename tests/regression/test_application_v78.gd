extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const B=preload("res://scripts/battle/battle.gd")
const A=preload("res://scripts/run/run_application.gd")
const LIFE=preload("res://scripts/run/run_lifecycle.gd")
const PREP=preload("res://scripts/inventory/preparation_rules.gd")
const MATCHING=preload("res://scripts/shop/matchmaking.gd")
const SESSION=preload("res://scripts/run/run_session.gd")
const TRANSFER=preload("res://scripts/inventory/stash_transfer.gd")
class MemoryFiles:
	extends RefCounted
	var owner="qa-v78"
	var saved:Array=[]
	var published:Array=[]
	var order:Array=[]
	var enemy:Dictionary={}
	var imported:Dictionary={}
	var exported:Dictionary={}
	func write_json(_path:String,data:Dictionary)->bool:exported=data.duplicate(true);return true
	func import_ghost(_path:String,_publish:bool=true)->Dictionary:return imported.duplicate(true)
	func save(run:Dictionary):saved.append(run.duplicate(true));order.append("save");run.gold=0
	func publish(ghost:Dictionary):published.append(ghost.duplicate(true));order.append("publish");return true
	func opponent(_run:Dictionary)->Dictionary:return enemy.duplicate(true)
var inv=I.new()
var checks=0
var failures=0
func ck(ok,label):
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
	var files=MemoryFiles.new();var engine=B.new();var app=A.new(inv,files,engine)
	var fixture=inv.new_run("aemeath",19)
	# Current application opts into new pocket rules; frozen constructor stays legacy.
	fixture.pocket_version=143
	files.enemy=inv.practice(1,19)
	var began=app.start("aemeath",19)
	for piece in fixture.bags+fixture.items:piece.x+=2;piece.y+=2
	ck(began.ok and began.run==fixture,"new game retains exact centering and seed")
	ck(files.saved.size()==1 and files.saved[0]==fixture,"new game saves once without callback alias")
	var run=began.run
	var before=run.duplicate(true);var enemy_before=files.enemy.duplicate(true)
	var plan=LIFE.begin(run,files.enemy,engine.simulate)
	ck(run==before and files.enemy==enemy_before,"battle planning mutates neither player nor opponent")
	var expected=before.duplicate(true);expected.phase="battle"
	expected.simulation_version=preload("res://scripts/data/catalog.gd").SIMULATION_VERSION
	var battle=engine.simulate(expected,files.enemy,int(expected.seed))
	expected.combat=battle;expected.opponent=files.enemy.duplicate(true)
	ck(plan.run==expected,"battle plan matches old start sequence")
	files.order.clear()
	var started=app.begin(run,files.enemy)
	ck(started.ok and run==expected,"battle commits exact old state")
	ck(files.order==["save","publish"],"battle persists before publishing")
	started.combat.events.clear();started.opponent.items.clear()
	ck(run==expected,"battle result presentation cannot mutate saved simulation")
	var count=files.saved.size();var published=files.published.size()
	ck(not app.begin(run,files.enemy).ok and files.saved.size()==count and files.published.size()==published,"duplicate start has no side effects")
	var result_plan=LIFE.result(run);before=run.duplicate(true)
	ck(run==before and result_plan.run.phase=="result","result planning read only")
	ck(app.finish_replay(run).ok and run.phase=="result","finish replay commits phase")
	count=files.saved.size()
	ck(not app.finish_replay(run).ok and files.saved.size()==count,"replayed completion not persisted again")
	# Compare the prior controller's exact history + finish + cleanup sequence.
	expected=run.duplicate(true)
	expected.history.append({"round":expected.round,"winner":battle.winner,"duration":battle.duration,"build":inv.snapshot(expected,files.owner),"totals":battle.totals.duplicate(true)})
	inv.finish(expected,int(battle.winner))
	if expected.phase=="shop":expected.erase("combat");expected.erase("opponent")
	before=run.duplicate(true);plan=LIFE.advance(run,battle,files.owner,inv)
	ck(run==before and plan.run==expected,"next round plan preserves old history/income/consumption/random sequence")
	var advanced=app.advance(run,battle)
	ck(advanced.ok and run==expected and inv.validate_run(run),"whole next round commits valid old result")
	count=files.saved.size()
	ck(not app.advance(run,battle).ok and files.saved.size()==count,"double next does not grant income")
	for ending in ["wins","losses"]:
		var last=before.duplicate(true);last[ending]=I.PROGRESSION.WIN_TARGET-1 if ending=="wins" else I.PROGRESSION.LOSS_LIMIT-1
		var outcome=battle.duplicate(true);outcome.winner=1 if ending=="wins" else -1;last.combat=outcome
		var finish=LIFE.advance(last,outcome,files.owner,inv)
		ck(finish.ok and finish.run.phase=="ending" and finish.run.has("combat") and finish.run.has("opponent"),"ending retains replay "+ending)
	# Metadata edits are now plans too, with exact ownership and one full validator.
	run=inv.new_run("aemeath",29);files.saved.clear()
	ck(app.commit(run,PREP.primary(run,run.primary)).ok and files.saved.is_empty(),"same primary is successful no-op without writes")
	ck(not app.commit(run,PREP.primary(run,"shop-preview")).ok,"shop identity cannot become primary")
	var held=run.items[-1].duplicate(true)
	ck(app.commit(run,inv.plan_stash(run,held)).ok,"stash through live application")
	plan=PREP.rotate_stored(run,held.uid,2);before=run.duplicate(true)
	ck(run==before and plan.run.stash[-1].rotation==2,"stored rotation preview isolated")
	ck(app.commit(run,plan).ok and run.stash[-1].rotation==2,"stored rotation committed")
	count=files.saved.size()
	ck(not app.commit(run,plan).ok and files.saved.size()==count,"stale rotation rejects without save")
	plan=inv.plan_refresh(run,true);run.gold+=1;before=run.duplicate(true)
	ck(not app.commit(run,plan).ok and run==before,"old refresh cannot overwrite newer economic state")
	plan=inv.plan_refresh(run,true);plan.run.gold=-1;count=files.saved.size()
	ck(not app.commit(run,plan).ok and run==before and files.saved.size()==count,"full application validation rejects invalid candidate atomically")
	# Resume repair and enemy selection use value copies; no disk dependency.
	var old_enemy=files.enemy.duplicate(true);old_enemy.practice_method="old";old_enemy.practice_seed=5
	run.opponent=old_enemy;before=run.duplicate(true)
	var resumed=LIFE.resume(run,old_enemy,inv.practice,inv.PB.METHOD)
	ck(run==before and old_enemy.practice_method=="old" and resumed.opponent.practice_method==inv.PB.METHOD,"resume practice repair isolated")
	var matchmaker=MATCHING.new(inv.practice,inv.PB.METHOD)
	var ghost=inv.snapshot(inv.new_run("aemeath",5),"stranger");ghost.round=4
	var own=ghost.duplicate(true);own.owner="self"
	var inactive=ghost.duplicate(true);inactive.inactive=true
	var obsolete=ghost.duplicate(true);obsolete.simulation_version="old"
	var chosen=matchmaker.choose(4,18,[own,inactive,obsolete,ghost],"self","full",int(ghost.get("supply_version",0)))
	ck(chosen.source=="saved" and chosen.owner=="stranger","matching retains owner/version/inactive filters")
	chosen.items.clear();ck(not ghost.items.is_empty(),"matching result has no pool alias")
	ck(matchmaker.choose(1,18,[ghost],"self").source=="practice","opening cannot bypass fixed practice")
	var cached=matchmaker.practice(1,18);cached.items.clear()
	ck(not matchmaker.practice(1,18).items.is_empty(),"practice cache copies isolated")
	# Import/export policy is application-level; rendering only chooses the message.
	ck(app.export_build(run,"memory") and files.exported==inv.snapshot(run,files.owner),"export exact snapshot through application")
	ck(app.import_opponent(run,"memory").status=="invalid","invalid imported ghost preserved")
	files.imported=ghost.duplicate(true);files.imported.inactive=true
	ck(app.import_opponent(run,"memory").status=="inactive","inactive imported ghost preserved")
	files.imported.erase("inactive");files.imported.round=int(run.round)+2
	ck(app.import_opponent(run,"memory").status=="round","import round gate preserved")
	files.imported.round=run.round
	var imported=app.import_opponent(run,"memory")
	ck(imported.status=="ready" and imported.opponent==files.imported,"valid import selects exact ghost")
	before=run.duplicate(true);app.checkpoint(run)
	ck(run==before and files.saved[-1]==run,"explicit checkpoint cannot alias live state")
	# Animation receives only copied visual facts; ticks cannot write run.
	var transfer=TRANSFER.new();var piece=before.items[0].duplicate(true)
	var events=[{"piece":piece,"from":Rect2(0,0,30,30)}]
	transfer.enqueue(events);events[0].piece.kind="tea"
	ck(transfer.flights[0].piece.kind!=events[0].piece.kind,"transfer events deeply copied")
	transfer.update(.1,[piece.uid],"");ck(transfer.flights.size()==1,"visual time retains owned flight")
	transfer.update(.1,[piece.uid],piece.uid);ck(transfer.flights.is_empty(),"regrab clears only display flight")
	for file in ["build_rules.gd","star_filters.gd","run_lifecycle.gd","matchmaking.gd","stash_transfer.gd"]:
		var code=preload("res://tests/fixtures/layout.gd").read("res://scripts/"+file)
		ck(not code.contains("FileAccess") and not code.contains("storage.save") and not code.contains("game."),file+" has no UI/storage write dependency")
	var battle_code=FileAccess.get_file_as_string("res://scripts/battle/battle_v60.gd")
	ck(not battle_code.contains('preload("res://scripts/inventory/inventory.gd")'),"battle cannot acquire transaction API")
	print("APPLICATION_V78: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
