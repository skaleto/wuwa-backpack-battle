extends RefCounted
## Whole phase transitions produce isolated candidate states. No UI or file I/O.
const SESSION=preload("res://scripts/run/run_session.gd")
static func start(leader:String,seed_value:int,inventory,pool_mode:String="full")->Dictionary:
	var next=inventory.new_run(leader,seed_value,pool_mode)
	if next.is_empty():return {"ok":false}
	next.pocket_version=preload("res://scripts/inventory/pocket_rules_current.gd").VERSION
	# Existing new-game canvas placement; persisted layouts are never recentered.
	for piece in next.bags+next.items:
		piece.x+=2;piece.y+=2
	return {"ok":true,"source":SESSION.stamp({}),"run":next}
static func begin(run:Dictionary,opponent:Dictionary,simulate:Callable)->Dictionary:
	if run.get("phase","")!="shop" or not run.get("recruitment",{}).get("candidates",[]).is_empty() or run.get("items",[]).is_empty():return {"ok":false}
	var next=run.duplicate(true);next.phase="battle"
	next.simulation_version=preload("res://scripts/party/recruitment.gd").simulation_version(next)
	var enemy=opponent.duplicate(true)
	var combat=simulate.call(next,enemy,int(next.seed))
	next.combat=combat.duplicate(true);next.opponent=enemy.duplicate(true)
	return {"ok":true,"source":SESSION.stamp(run),"run":next,"combat":combat,"opponent":enemy}
static func result(run:Dictionary)->Dictionary:
	if run.get("phase","")!="battle":return {"ok":false}
	var next=run.duplicate(true);next.phase="result"
	return {"ok":true,"source":SESSION.stamp(run),"run":next}
static func advance(run:Dictionary,combat:Dictionary,owner:String,inventory)->Dictionary:
	if run.get("phase","")!="result":return {"ok":false}
	var next=run.duplicate(true)
	next.history.append({"round":next.round,"winner":combat.winner,"duration":combat.duration,"build":inventory.snapshot(next,owner),"totals":combat.totals.duplicate(true)})
	var settlement=inventory.plan_finish(next,int(combat.winner))
	if not settlement.ok:return {"ok":false}
	next=settlement.run
	if next.phase in ["shop","recruit"]:
		next.erase("combat");next.erase("opponent")
	return {"ok":true,"source":SESSION.stamp(run),"run":next,"settlement":settlement.value}
static func resume(saved:Dictionary,opponent:Dictionary,practice:Callable,method:String)->Dictionary:
	var next=saved.duplicate(true);var enemy=opponent.duplicate(true)
	if next.phase=="shop" and enemy.get("source","")=="practice" and int(next.round)<=3 and enemy.get("practice_method","")!=method:
		enemy=practice.call(int(next.round),int(enemy.get("practice_seed",int(next.seed)%31)))
		if next.has("opponent"):next.opponent=enemy.duplicate(true)
	return {"run":next,"opponent":enemy}
