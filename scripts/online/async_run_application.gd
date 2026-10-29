extends "res://scripts/run/run_application.gd"
## Async mode uses the same plans and simulation, with durable match locks.
const PVP=preload("res://scripts/online/async_pvp.gd")
func _write(run:Dictionary,plan:Dictionary)->Dictionary:
	if not plan.get("ok",false):return plan
	if plan.get("source","")!=SESSION.stamp(run):return {"ok":false,"error":"stale"}
	if not inventory.validate_run(plan.get("run",{})):return {"ok":false,"error":"invalid"}
	var next:Dictionary=plan.run.duplicate(true)
	if next!=run and not storage.save_checked(next):return {"ok":false,"error":"save_failed"}
	return SESSION.commit(run,plan,inventory.validate_run)
func commit(run:Dictionary,plan:Dictionary)->Dictionary:
	if run.get("phase","")=="shop" and run.get("pvp",{}).get("stage","idle")!="idle":return {"ok":false,"error":"match_frozen"}
	return _write(run,plan)
func start(leader:String,seed_value:int,pool_mode:String="full",previous:Dictionary={})->Dictionary:
	var run={};var plan=LIFE.start(leader,seed_value,inventory,pool_mode)
	if not plan.get("ok",false) or not preserve_result(previous):return {"ok":false}
	if storage.has_method("protect_existing_run") and not storage.protect_existing_run():return {"ok":false,"error":"save_failed"}
	plan.run.mode="async";plan.run.pvp={"run_id":PVP.random_id(),"stage":"idle","recent":[]}
	var result=_write(run,plan)
	return {"ok":result.ok,"run":run,"opponent":{}}
func resume(saved:Dictionary)->Dictionary:
	return {"run":saved.duplicate(true),"opponent":saved.get("opponent",{}).duplicate(true)}
func prepare_match(run:Dictionary,player_id:String)->Dictionary:
	if run.get("phase","")!="shop" or run.get("pvp",{}).get("stage","")!="idle" or not run.get("recruitment",{}).get("candidates",[]).is_empty():return {"ok":false}
	var frozen=PVP.freeze(inventory,run,player_id,str(run.pvp.run_id))
	if not frozen.ok:return frozen
	var next=run.duplicate(true);next.pvp.stage="pending"
	next.pvp.frozen=frozen.bytes.get_string_from_utf8();next.pvp.sha256=frozen.sha256;next.pvp.player_id=player_id
	return _write(run,{"ok":true,"source":SESSION.stamp(run),"run":next})
func lock_opponent(run:Dictionary,enemy:Dictionary,source:String,reason:String="")->Dictionary:
	if run.get("phase","")!="shop" or run.get("pvp",{}).get("stage","")!="pending" or source not in ["player","bot"]:return {"ok":false}
	if not inventory.validate_ghost(enemy) or enemy.get("inactive",false) or PVP.pool_id(enemy)!=PVP.pool_id(run) or int(enemy.round)!=int(run.round):return {"ok":false,"error":"opponent"}
	var next=run.duplicate(true);next.opponent=enemy.duplicate(true);next.pvp.stage="locked"
	next.pvp.source=source;next.pvp.reason=reason
	if source=="player":
		next.pvp.recent.append(str(enemy.owner))
		if next.pvp.recent.size()>8:next.pvp.recent.pop_front()
	return _write(run,{"ok":true,"source":SESSION.stamp(run),"run":next})
func begin(run:Dictionary,opponent:Dictionary)->Dictionary:
	if run.get("phase","")!="shop" or run.get("pvp",{}).get("stage","")!="locked" or run.get("opponent",{})!=opponent:return {"ok":false}
	if not PVP.matches_frozen(inventory,run):return {"ok":false,"error":"snapshot_changed"}
	return _write(run,LIFE.begin(run,opponent,engine.simulate))
func advance(run:Dictionary,combat:Dictionary)->Dictionary:
	if run.get("combat",{})!=combat:return {"ok":false}
	var plan=LIFE.advance(run,combat,storage.owner,inventory)
	if not plan.get("ok",false) or not preserve_result(run):return {"ok":false}
	if storage.has_method("battle_reference"):
		var replay_id=storage.battle_reference(run)
		if not replay_id.is_empty():plan.run.history[-1].replay_id=replay_id
	if plan.run.phase in ["shop","recruit"]:plan.run.pvp={"run_id":run.pvp.run_id,"stage":"idle","recent":run.pvp.get("recent",[]).duplicate()}
	var result=_write(run,plan);result.opponent={}
	return result
func confirm_recruit(run:Dictionary,role:String,reward:String="")->Dictionary:
	var result=commit(run,preload("res://scripts/party/recruitment.gd").plan_confirm(inventory,run,role,reward));result.opponent={};return result
func import_opponent(_run:Dictionary,_path:String)->Dictionary:return {"status":"invalid"}
func checkpoint(run:Dictionary)->void:storage.save_checked(run.duplicate(true))
