extends SceneTree
## Fully purchased runs. No shelf injection, free capacity or extra gold.
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const PB=preload("res://scripts/shop/practice_budget.gd")
const OLD=preload("res://tests/fixtures/practice_before_v70.gd")
const B=preload("res://scripts/battle/battle.gd")
var inv=I.new();var failures=[];var samples=[];var checks=0
func ck(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize():call_deferred("sample")
func play(leader:String,seed_value:int,policy:String,version:String)->Dictionary:
	var run=inv.new_run(leader,seed_value)
	run.practice_ledger=[]
	var income=9;var rows=[];var route=["charge","haste","shielding"][posmod(seed_value,3)]
	for round_index in 3:
		var enemy_seed=int(run.seed)%31
		var enemy=(OLD if version=="before" else PB).build(inv,int(run.round),enemy_seed)
		var shelves=[]
		for shelf in (1 if policy=="unoptimized" else 2):
			if shelf>0:
				var before=int(run.gold)
				if inv.refresh(run,true):OLD.record(run,"refresh","",before-int(run.gold))
			shelves.append(run.shop.map(func(v):return v.get("kind","")))
			OLD.purchase(inv,run,5,"capacity")
			var picks=[1,3,4,2,0]
			if policy=="competent":picks.sort_custom(func(a,b):return OLD.utility(run,a,route)>OLD.utility(run,b,route))
			for slot in picks:
				if OLD.utility(run,slot,route)>0:OLD.purchase(inv,run,slot,"shop")
			PB.craft_owned(inv,run)
		if policy=="competent":PB.arrange(inv,run)
		ck(inv.validate_run(run),"sample purchased arrangement legal")
		var spent=run.practice_ledger.reduce(func(total,row):return total+int(row.gold),0)
		ck(int(run.gold)==income-spent,"actual cash ledger reconciles")
		var before=run.duplicate(true)
		var result=B.new().simulate(run,enemy,seed_value+round_index,false)
		ck(run==before,"simulation leaves acquisitions intact")
		rows.append({"round":run.round,"shelves":shelves,"items":run.items.duplicate(true),"stash":run.stash.duplicate(true),"bags":run.bags.duplicate(true),"gold":run.gold,"spent":spent,"income":income,"stars":PB.bonds(inv,run),"opponent_seed":enemy_seed,"opponent":enemy,"winner":result.winner,"duration":result.duration,"damage":result.totals.map(func(v):return v.damage)})
		run.phase="result";run.combat=result
		var before_gold=int(run.gold)
		ck(not inv.finish(run,int(result.winner)).is_empty(),"real battle settlement")
		income+=int(run.gold)-before_gold
	return {"leader":leader,"seed":seed_value,"policy":policy,"version":version,"rounds":rows,"ledger":run.practice_ledger}
func sample():
	for version in ["before","after"]:
		for policy in ["unoptimized","competent"]:
			for leader in C.selectable_leaders():
				for seed_value in [2,13,30]:samples.append(play(leader,seed_value,policy,version))
			print("SAMPLED ",version," ",policy)
	var summary=[]
	for version in ["before","after"]:
		for policy in ["unoptimized","competent"]:
			for r in 3:
				var rows=samples.filter(func(v):return v.version==version and v.policy==policy).map(func(v):return v.rounds[r])
				summary.append({"version":version,"policy":policy,"round":r+1,"count":rows.size(),"wins":rows.filter(func(v):return v.winner==1).size(),"draws":rows.filter(func(v):return v.winner==0).size(),"losses":rows.filter(func(v):return v.winner==-1).size()})
	var report={"catalogue_hash":C.catalogue_hash,"checks":checks,"failures":failures,"summary":summary,"samples":samples}
	var file=FileAccess.open("res://build/qa/ui-v70/checks/acquisition-samples.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print(JSON.stringify(summary));print("SAMPLES_V70 ",checks," checks, ",failures.size()," failures")
	quit(1 if not failures.is_empty() else 0)
