extends RefCounted
## Pure operation planning. Mutating helpers receive only isolated candidates.
## Inventory supplies shared geometry, identity and validation adapters.
const C=preload("res://scripts/data/catalog.gd")
const FEATURES=preload("res://scripts/run/demo_features.gd")
const SHOP_ACTIONS=preload("res://scripts/shop/shop_actions.gd")
const PROGRESSION=preload("res://scripts/run/run_progression.gd")

static func _apply_gift(inv,run: Dictionary,kind: String) -> void:
	if C.is_tag(kind,"keepsake") and (run.items+run.stash+run.get("pending_gifts",[])+run.get("pending_rearrange",[])).any(func(v):return v.kind==kind):return
	var identity=inv.next_identity(run)
	if identity.is_empty():return
	run.serial=identity.serial
	var item=inv.make_piece(kind,identity.uid)
	run.stash.append(item)

static func _apply_grant_milestones(inv,run: Dictionary,catch_up: bool=false) -> void:
	if C.SIMULATION_VERSION!="resonance-v60":return
	for kind in C.items:
		var def=C.items[kind]
		if FEATURES.item_enabled(kind) and C.is_tag(kind,"keepsake") and def.get("owner","")==run.leader and def.has("gift_round") and (int(def.gift_round)==int(run.round) or (catch_up and int(def.gift_round)<=int(run.round))):_apply_gift(inv,run,kind)

static func _apply_claim_pending(inv,run: Dictionary) -> void:
	for key in ["pending_gifts","pending_rearrange"]:
		if not run.has(key):run[key]=[]
		while not run[key].is_empty():run.stash.append(run[key].pop_front())

static func _apply_finish(inv,run: Dictionary,winner: int) -> Dictionary:
	if run.get("phase","")!="result" or winner not in [-1,0,1]:return {}
	var used=run.get("combat",{}).get("used",[[],[]])
	# used records per-battle provision activations, never an inventory deletion list.
	var delta=PROGRESSION.result_delta(winner)
	run.wins+=delta.wins;run.losses+=delta.losses
	if run.wins>=PROGRESSION.WIN_TARGET or run.losses>=PROGRESSION.LOSS_LIMIT:run.phase="ending"
	else:
		run.simulation_version=preload("res://scripts/party/recruitment.gd").simulation_version(run)
		run.round+=1;run.gold+=inv.ECONOMY.income(winner,run.round);run.phase="shop";run.refreshes=0
		if C.SIMULATION_VERSION=="resonance-v60" and run.round==2 and FEATURES.item_enabled(C.characters[run.leader].core):_apply_gift(inv,run,C.characters[run.leader].core)
		_apply_grant_milestones(inv,run)
		if run.has("recruitment"):
			if not preload("res://scripts/party/recruitment.gd").open_draft(inv,run,int(run.round)-1):SHOP_ACTIONS._apply_refresh(inv,run)
		else:
			run.shop=[];SHOP_ACTIONS._apply_refresh(inv,run)
	inv.clean_relay(run);_apply_claim_pending(inv,run)
	return {"fused":0,"used":used[0] if used is Array and used.size()==2 else []}

static func plan_gift(inv,run: Dictionary,kind: String) -> Dictionary:
	var next=run.duplicate(true)
	_apply_gift(inv,next,kind)
	return inv.operation_plan(run,next,null,true)

static func plan_grant_milestones(inv,run: Dictionary,catch_up: bool=false) -> Dictionary:
	var next=run.duplicate(true)
	_apply_grant_milestones(inv,next,catch_up)
	return inv.operation_plan(run,next,null,true)

static func plan_claim_pending(inv,run: Dictionary) -> Dictionary:
	var next=run.duplicate(true)
	_apply_claim_pending(inv,next)
	return inv.operation_plan(run,next,null,true)

static func plan_finish(inv,run: Dictionary,winner: int) -> Dictionary:
	var next=run.duplicate(true)
	var value=_apply_finish(inv,next,winner)
	return inv.operation_plan(run,next,value,not value.is_empty())

