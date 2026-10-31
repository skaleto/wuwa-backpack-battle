extends RefCounted
## Application boundary: connects plans, one commit and persistence/ghost publishing.
## Receives existing services, never a scene or drawing context.
const SESSION=preload("res://scripts/run/run_session.gd")
const LIFE=preload("res://scripts/run/run_lifecycle.gd")
var inventory
var storage
var engine
func _init(items,files,simulation):
	inventory=items;storage=files;engine=simulation
func commit(run:Dictionary,plan:Dictionary)->Dictionary:
	return SESSION.commit(run,plan,inventory.validate_run,storage.save)
func preserve_result(run:Dictionary)->bool:
	return storage.archive_completed(run) if storage.has_method("archive_completed") else true
func start(leader:String,seed_value:int,pool_mode:String="full",previous:Dictionary={})->Dictionary:
	var run={}
	var plan=LIFE.start(leader,seed_value,inventory,pool_mode)
	if not plan.get("ok",false) or not preserve_result(previous):return {"ok":false}
	if storage.has_method("protect_existing_run") and not storage.protect_existing_run():return {"ok":false,"error":"save_failed"}
	var result=commit(run,plan)
	return {"ok":result.ok,"run":run,"opponent":storage.opponent(run) if result.ok else {}}
func resume(saved:Dictionary)->Dictionary:
	var legacy=bool(saved.get("recruitment_legacy",false))
	var version=preload("res://scripts/party/recruitment.gd").simulation_version(saved)
	var previous=saved.get("recruitment",{}).get("version",0)==114
	var method=inventory.PB.METHOD+"-crew114" if previous else inventory.PB.METHOD+"-legacy" if legacy else inventory.PB.METHOD
	if int(saved.get("supply_version",0))>0:method+="-supply"+str(int(saved.supply_version))
	var enemy=saved.opponent if saved.has("opponent") else storage.opponent(saved)
	if saved.phase=="shop" and (enemy.get("simulation_version","")!=version or enemy.get("pool_mode","full")!=saved.get("pool_mode","full") or int(enemy.get("supply_version",0))!=int(saved.get("supply_version",0)) or int(enemy.get("pocket_version",0))!=int(saved.get("pocket_version",0))):enemy=storage.opponent(saved)
	var builder=func(round_number,seed_value):return inventory.PB.build(inventory,round_number,seed_value,saved.get("pool_mode","full"),true) if legacy else inventory.PB.build(inventory,round_number,seed_value,saved.get("pool_mode","full"),false,114) if previous else inventory.practice(round_number,seed_value,saved.get("pool_mode","full"),int(saved.get("supply_version",0)),int(saved.get("pocket_version",0)))
	return LIFE.resume(saved,enemy,builder,method)
func begin(run:Dictionary,opponent:Dictionary)->Dictionary:
	var plan=LIFE.begin(run,opponent,engine.simulate)
	var result=commit(run,plan)
	if result.ok:
		storage.publish(inventory.snapshot(run,storage.owner))
	return result
func finish_replay(run:Dictionary)->Dictionary:
	return commit(run,LIFE.result(run))
func advance(run:Dictionary,combat:Dictionary)->Dictionary:
	var plan=LIFE.advance(run,combat,storage.owner,inventory)
	if not plan.get("ok",false):return {"ok":false}
	if not preserve_result(run):return {"ok":false,"error":"history_save"}
	if storage.has_method("battle_reference"):
		var replay_id=storage.battle_reference(run)
		if not replay_id.is_empty():plan.run.history[-1].replay_id=replay_id
	var result=commit(run,plan)
	if result.ok and run.phase=="shop":result.opponent=storage.opponent(run)
	return result
func export_build(run:Dictionary,path:String)->bool:
	return storage.write_json(path,inventory.snapshot(run,storage.owner))
func import_opponent(run:Dictionary,path:String)->Dictionary:
	var ghost=storage.import_ghost(path,false)
	if ghost.is_empty():return {"status":"invalid"}
	if ghost.get("inactive",false):return {"status":"inactive"}
	if ghost.get("pool_mode","full")!=run.get("pool_mode","full") or int(ghost.get("supply_version",0))!=int(run.get("supply_version",0)) or int(ghost.get("pocket_version",0))!=int(run.get("pocket_version",0)):return {"status":"version"}
	if absi(int(ghost.round)-int(run.round))>1:return {"status":"round"}
	if ghost.get("simulation_version",preload("res://scripts/data/catalog.gd").SIMULATION_VERSION)!=preload("res://scripts/party/recruitment.gd").simulation_version(run):return {"status":"version"}
	if not storage.publish(ghost):return {"status":"invalid"}
	return {"status":"ready","opponent":ghost}
func checkpoint(run:Dictionary)->void:storage.save(run.duplicate(true))

func confirm_recruit(run:Dictionary,role:String,reward:String="")->Dictionary:
	var result=commit(run,preload("res://scripts/party/recruitment.gd").plan_confirm(inventory,run,role,reward))
	if result.ok:result.opponent=storage.opponent(run)
	return result
func configure_crew(run:Dictionary,config:Dictionary)->Dictionary:
	return commit(run,preload("res://scripts/party/recruitment.gd").plan_configure(inventory,run,config))

func abandon(run:Dictionary,expected_stamp:String)->Dictionary:
	if run.is_empty() or run.get("phase","")=="ending" or SESSION.stamp(run)!=expected_stamp:return {"ok":false,"error":"stale"}
	if not preserve_result(run):return {"ok":false,"error":"history_save"}
	if not storage.abandon_run(run):return {"ok":false,"error":"save_failed"}
	run.clear()
	return {"ok":true}
