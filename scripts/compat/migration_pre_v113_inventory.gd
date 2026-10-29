extends "res://scripts/inventory/inventory.gd"
## Freeze the qualification rules changed by V113 only. Existing migration
## geometry, supply schedules and schema validation remain authoritative.
var qualification_catalogue:Dictionary=C.data

func historical_types(build:Dictionary)->Array:
	var leader=qualification_catalogue.characters.get(build.get("leader",""),{})
	if leader.is_empty():return []
	var types=[leader.weapon_type]
	for id in build.get("roster",[]):
		if qualification_catalogue.roster.has(id):types.append(qualification_catalogue.roster[id].weapon_type)
	return types

func signature_owned(build:Dictionary,kind:String)->bool:
	var definition=qualification_catalogue.items.get(kind,{})
	if not definition.get("strict_signature",false):return true
	var owners=build.get("roster",[]).duplicate()
	owners.append(qualification_catalogue.characters.get(build.get("leader",""),{}).get("roster_id",""))
	return definition.get("signature_owner_ids",[]).any(func(id):return id in owners)

func craft_unlocked(build:Dictionary,kind:String)->bool:
	if not qualification_catalogue.items.has(kind):return false
	var definition=qualification_catalogue.items[kind]
	return ("weapon" not in definition.get("tags",[]) or definition.weapon_type in historical_types(build)) and signature_owned(build,kind)

func validate_ghost(raw:Variant,allow_empty:bool=false)->bool:
	if not super.validate_ghost(raw,allow_empty):return false
	var leader=qualification_catalogue.characters.get(raw.leader,{})
	if leader.is_empty():return false
	for id in raw.roster:
		var role=qualification_catalogue.roster.get(id,{})
		if role.is_empty() or not role.released or role.element!=leader.element or id==leader.roster_id:return false
	return true

func validate_run(raw:Variant)->bool:
	if not super.validate_run(raw):return false
	return not raw.has("pending_carrier_type") or raw.pending_carrier_type in historical_types(raw)

func new_run(leader:String,seed_value:int,pool_mode:String="full")->Dictionary:
	var run=super.new_run_supply(leader,seed_value,pool_mode,0)
	run.erase("recruitment")
	return run
