extends RefCounted
## Pure operation planning. Mutating helpers receive only isolated candidates.
## Inventory supplies shared geometry, identity and validation adapters.
const C=preload("res://scripts/data/catalog.gd")
const SUP=preload("res://scripts/party/supports.gd")

static func _apply_recruit(inv,run: Dictionary,role_id: String) -> bool:
	if run.has("recruitment"):return false
	if run.get("phase","")!="shop" or int(run.get("round",1))<2 or not SUP.valid_team(run) or role_id not in SUP.candidates(run) or int(run.get("recruited_round",0))==int(run.round):return false
	if not inv.bounded_integer(run.get("recruited_round",null),0,int(run.round)):return false
	var cost=SUP.price(C.roster[role_id])
	if not inv.bounded_integer(run.get("gold",0),cost,2147483647):return false
	run.gold-=cost;run.roster.append(role_id);run.recruited_round=int(run.round)
	if run.supports.size()<SUP.MAX_SUPPORTS:run.supports.append(role_id)
	return true

static func _apply_set_supports(inv,run: Dictionary,ordered_ids: Array) -> bool:
	if run.has("recruitment"):return false
	if run.get("phase","")!="shop":return false
	var proposed=run.duplicate(true);proposed.supports=ordered_ids.duplicate()
	if not SUP.valid_team(proposed):return false
	run.supports=ordered_ids.duplicate();return true

static func plan_recruit(inv,run: Dictionary,role_id: String) -> Dictionary:
	var next=run.duplicate(true)
	var value=_apply_recruit(inv,next,role_id)
	return inv.operation_plan(run,next,value,value)

static func plan_set_supports(inv,run: Dictionary,ordered_ids: Array) -> Dictionary:
	var next=run.duplicate(true)
	var value=_apply_set_supports(inv,next,ordered_ids)
	return inv.operation_plan(run,next,value,value)

