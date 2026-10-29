extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const B=preload("res://scripts/battle/battle.gd")
const P=preload("res://scripts/online/async_pvp.gd")
class Files:
	extends RefCounted
	var owner="qa-owner"
	var data={}
	var fail=false
	var opponent_calls=0
	func save_checked(run:Dictionary)->bool:
		if fail:return false
		data=run.duplicate(true);return true
	func opponent(_run):opponent_calls+=1;return {}
	func archive_completed(_run):return true
var failures=0
var checks=0
func ck(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
	if not FileAccess.file_exists("res://scripts/online/async_run_application.gd"):
		ck(false,"async application exists");quit(1);return
	var inv=I.new();var store=Files.new();var app=load("res://scripts/online/async_run_application.gd").new(inv,store,B.new())
	var started=app.start("aemeath",11);var run=started.run
	ck(started.ok and run.mode=="async" and store.opponent_calls==0,"new async game never invokes offline opponent")
	var before=run.duplicate(true);store.fail=true
	ck(not app.prepare_match(run,"alice").ok and run==before,"failed freeze save keeps live state unchanged")
	store.fail=false
	ck(app.prepare_match(run,"alice").ok and run.pvp.stage=="pending","freeze persists before matching")
	ck(not app.commit(run,inv.plan_refresh(run,true)).ok,"cannot mutate inventory after match freeze")
	var frozen=run.pvp.duplicate(true);var recovered=app.resume(store.data)
	ck(recovered.run.pvp==frozen and recovered.opponent.is_empty(),"pending restart retains frozen own build without selecting bot")
	var bot=inv.practice(1,11,"full",int(run.get("supply_version",0)))
	store.fail=true;before=run.duplicate(true)
	ck(not app.lock_opponent(run,bot,"bot","empty_pool").ok and run==before,"failed lock does not start battle")
	store.fail=false
	ck(app.lock_opponent(run,bot,"bot","empty_pool").ok,"bot fallback explicitly locked")
	ck(not app.lock_opponent(run,bot,"bot","late_callback").ok,"late result cannot replace locked opponent")
	var resumed=app.resume(store.data)
	ck(resumed.opponent==bot and store.opponent_calls==0,"resume keeps exact locked opponent")
	var battle=app.begin(run,bot)
	ck(battle.ok and run.phase=="battle" and run.combat==store.data.combat,"simulation persisted before presentation")
	ck(not app.begin(run,bot).ok,"double start rejected")
	ck(app.finish_replay(run).ok,"replay finishes through original phase transition")
	before=run.duplicate(true);store.fail=true
	ck(not app.advance(run,run.combat).ok and run==before,"failed settlement cannot award income")
	store.fail=false
	ck(app.advance(run,run.combat).ok and run.round==2 and run.pvp.stage=="idle","settles once and clears lock for next round")
	ck(not app.advance(run,{}).ok and store.opponent_calls==0,"duplicate next has no reward or bot lookup")
	var final_run=app.start("aemeath",71).run;final_run.round=4;final_run.wins=0;final_run.losses=3
	ck(app.prepare_match(final_run,"alice").ok,"prepare elimination round")
	var last_bot=inv.practice(4,11,"full",int(final_run.supply_version))
	app.lock_opponent(final_run,last_bot,"bot","empty_pool");app.begin(final_run,last_bot)
	final_run.combat.winner=-1;app.finish_replay(final_run);app.advance(final_run,final_run.combat)
	ck(final_run.phase=="ending" and final_run.pvp.get("source")=="bot","ending retains opponent provenance")
	print("async run ",checks," checks, failures ",failures);quit(1 if failures else 0)
