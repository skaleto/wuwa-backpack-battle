extends SceneTree
## Frozen pre-refactor traces include exact state and deterministic battle event hashes.
const I=preload("res://scripts/inventory/inventory.gd")
const B=preload("res://scripts/battle/battle.gd")
const C=preload("res://scripts/data/catalog.gd")
const FIXTURE="res://tests/fixtures/process_v77_behavior.json"
var inventory=I.new()
var traces:Array=[]
func step(label:String,run:Dictionary,value:Variant=null):
	traces.append({"label":label,"state":JSON.stringify(run).sha256_text(),"value":JSON.stringify(value)})
func scenarios():
	for leader in C.selectable_leaders():
		for seed_value in [17,238,911]:
			var run=inventory.new_run(leader,seed_value)
			step(leader+":"+str(seed_value)+":start",run)
			for round_index in 3:
				run.gold=60
				step("lock",run,inventory.toggle_lock(run,0))
				step("refresh-free",run,inventory.refresh(run,true))
				step("refresh-paid",run,inventory.refresh(run,true))
				step("unlock",run,inventory.toggle_lock(run,0))
				for index in 5:
					step("buy-"+str(index),run,inventory.buy(run,index))
					if run.stash.is_empty():continue
					var held=run.stash[-1].duplicate(true)
					var fit=inventory.first_fit(held,run.items,run.bags)
					if not fit.is_empty():step("place",run,inventory.place(run,fit))
				if not run.stash.is_empty():step("sell",run,inventory.sell(run,run.stash[-1]))
				if not run.items.is_empty():
					var held=run.items[-1].duplicate(true)
					var before=JSON.stringify(run)
					var preview=inventory.stash_preview(run,held)
					step("stash-preview",run,preview)
					assert(JSON.stringify(run)==before)
					step("stash",run,inventory.stash(run,held))
					if preview.ok:step("restore",run,inventory.place(run,held))
				var candidates=I.SUP.candidates(run)
				if not candidates.is_empty():step("recruit",run,inventory.recruit(run,candidates[0]))
				var supports=run.supports.duplicate();supports.reverse()
				step("supports",run,inventory.set_supports(run,supports))
				step("bad-purchase",run,inventory.purchase_at(run,42,inventory.make_piece("w_sword","preview"),"board"))
				var opponent=inventory.practice(int(run.round),seed_value%31)
				run.phase="battle"
				var battle=B.new().simulate(run,opponent,int(run.seed))
				step("battle",run,JSON.stringify(battle).sha256_text())
				run.combat=battle;run.opponent=opponent;run.phase="result"
				step("finish",run,inventory.finish(run,1))
				run.erase("combat");run.erase("opponent")
func _initialize():
	scenarios()
	var baseline=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var failures=0
	if baseline.size()!=traces.size():failures+=1;printerr("Trace count changed")
	for index in mini(baseline.size(),traces.size()):
		if baseline[index]!=traces[index]:
			failures+=1
			if failures<12:printerr("Trace mismatch ",index," ",traces[index].label," expected ",baseline[index]," got ",traces[index])
	print("PROCESS_EQUIVALENCE_V78: ",traces.size()," snapshots, ",failures," failures")
	quit(1 if failures else 0)
