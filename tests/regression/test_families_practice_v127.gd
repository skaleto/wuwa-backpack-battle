extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const C=preload("res://scripts/data/catalog.gd")
const P=preload("res://scripts/shop/practice_budget.gd")
const MATCH=preload("res://scripts/shop/matchmaking.gd")
var checks=0
var failures=0
class ProbeInventory extends "res://scripts/inventory/inventory.gd":
	func validate_run(raw:Variant)->bool:
		var result=super.validate_run(raw)
		if not result and raw is Dictionary and raw.has("practice_budget"):
			print("PRACTICE_DIAGNOSTIC ",JSON.stringify({"ghost":validate_ghost(raw,true),"hash":raw.get("catalogue_hash")==C.catalogue_hash,"leader":raw.leader,"round":raw.round,"phase":raw.phase,"seed":raw.seed,"serial":raw.serial,"serial_valid":valid_serial(raw),"shop":raw.shop,"gold":raw.gold,"primary":raw.primary,"items":raw.items,"bags":raw.bags,"recruitment":raw.recruitment,"recruited_round":raw.recruited_round,"roster":raw.roster,"supports":raw.supports,"supply":raw.get("supply_version",0)}))
		return result
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:call_deferred("test")
func test()->void:
	preload("res://tests/fixtures/catalog_fixture_v127.gd").apply()
	var inv=ProbeInventory.new();var player=inv.new_run("aemeath",19);var unchanged=player.duplicate(true)
	var matchmaker=MATCH.new(inv.practice,P.METHOD)
	var ghost=matchmaker.choose(1,int(player.seed),[],"qa-only","full",127)
	ck(inv.validate_ghost(ghost) and ghost.source=="practice","native travel fixture seed19 reaches a legal current practice opponent")
	ck(player==unchanged,"opponent construction does not modify the player")
	var stable=ghost.duplicate(true);ghost.items.clear()
	if "--fixture" in OS.get_cmdline_user_args():
		print("PRACTICE_FIXTURE ",JSON.stringify({"player_seed":player.seed,"practice_seed":int(player.seed)%31,"ledger":stable.practice_ledger,"items":stable.items}))
		# Reproduce the incomplete metadata projection in this disposable process.
		# The ghost is valid; the surviving shop offer alone invalidates the run.
		var history=P.make_run(inv,1,int(player.seed)%31,"full",false,115,127)
		var tags=C.items.magnifier.tags.duplicate();C.items.magnifier.tags=["keepsake"]
		var plain=I.new();var ghost_valid=plain.validate_ghost(history,true);var run_valid=plain.validate_run(history)
		C.items.magnifier.tags=tags
		print("PRACTICE_OLD_METADATA_REPRO ",JSON.stringify({"ghost_valid":ghost_valid,"run_valid":run_valid,"shop_slot4":history.shop[4],"restored_run_valid":plain.validate_run(history)}))
		quit();return
	ck(matchmaker.choose(1,int(player.seed),[],"qa-only","full",127)==stable,"practice cache returns isolated copies")
	ck(P.METHOD=="shop-procurement-v116","public procurement method remains unchanged")
	for seed_value in C.selectable_leaders().size():
		var leader=C.selectable_leaders()[seed_value]
		for round_number in range(1,12):
			var run=P.make_run(inv,round_number,seed_value,"full",false,115,127)
			ck(not run.is_empty() and inv.validate_run(run),"valid procurement for "+leader+" round "+str(round_number))
			if run.is_empty():continue
			ck(run.leader==leader and int(run.supply_version)==127,"exact seeded leader and supply version")
			ck(run.practice_spend+run.gold==run.practice_budget,"public spending reconciles for "+leader+" round "+str(round_number))
			ck(run.practice_ledger.all(func(row):return row.source=="public_transaction"),"all procurement actions retain public transaction provenance")
			if round_number<=3:ck(run.gold>=P.OPENING_RESERVE[round_number-1],"opening reserve preserved")
			if round_number==11:ck(run==P.make_run(inv,round_number,seed_value,"full",false,115,127),"final-round construction is deterministic for "+leader)
		print("PRACTICE_LEADER_COMPLETE ",leader)
	print("FAMILIES_PRACTICE_V127 ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
