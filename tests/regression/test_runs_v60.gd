extends SceneTree
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const F=preload("res://scripts/crafting/craft.gd")
const PB=preload("res://scripts/shop/practice_budget.gd")
const B=preload("res://scripts/battle/battle.gd")
var checks=0;var fails=0;var report=[]
func ck(ok:bool,label:String):
	checks+=1
	if not ok:fails+=1;printerr("FAIL ",label)
func _initialize():call_deferred("run_tests")
func run_tests():
	var inv=I.new()
	for leader in C.selectable_leaders():
		var run=inv.new_run(leader,81)
		for round_number in [1,2,3,5]:
			run.round=round_number;run.gold=99
			var found={};var bag_kinds={}
			for n in 40:
				inv.refresh(run,true);ck(inv.validate_run(run),"legal shelf "+leader+str(round_number))
				for offer in run.shop:
					if offer.is_empty():continue
					ck(C.items[offer.kind].v60.active,"inactive item excluded")
					found[offer.kind]=true
				bag_kinds[run.shop[5].kind]=true
			ck(bag_kinds.size()>=3,"multiple pocket shapes")
			ck(found.has("whiff") or found.has("turtle") or found.has("zig"),"affordable echoes accessible")
	for recipe in C.combinations:
		var run=inv.new_run("aemeath",3);run.round=recipe.round_min;run.items=[];run.stash=[];run.bags=[];run.primary="";run.serial=2
		for y in range(0,6,2):
			for x in range(0,8,2):
				var bag=inv.make_piece("pouch","b%d-%d"%[x,y]);bag.x=x;bag.y=y;run.bags.append(bag)
		var base=inv.make_piece(recipe.base,"i1");run.items.append(base)
		if C.is_tag(base.kind,"weapon"):run.primary=base.uid
		run.stash=[inv.make_piece(recipe.materials[0],"i2")]
		ck(inv.validate_run(run),"recipe fixture legal "+recipe.id)
		ck(F.place_material(run,recipe.target,base.uid,recipe.materials[0],inv).ok,"recipe partner place "+recipe.id)
		var before=run.duplicate(true)
		ck(not F.transact(run,recipe.target,base.uid,inv,{"x":8,"y":5,"rotation":0}).ok and run==before,"invalid output atomic "+recipe.id)
		var tx=F.transact(run,recipe.target,base.uid,inv)
		ck(tx.ok and run.items.size()==1 and run.items[0].kind==recipe.target and inv.validate_run(run),"exact recipe successful "+recipe.id)
		ck(run.gold==before.gold,"zero extra crafting fee")
	var builds=[]
	for seed in [50,83,1729]:
		for r in [1,3,6]:
			var build=PB.make_run(inv,r,seed)
			ck(inv.validate_run(build),"practice legal")
			ck(build.practice_spend+build.practice_unspent==9+(r-1)*8,"opponent budget")
			for item in build.items:ck(C.items[item.kind].v60.active,"opponent uses live item")
			report.append({"seed":seed,"round":r,"items":build.items.map(func(i):return i.kind),"spent":build.practice_spend,"stars":PB.bonds(inv,build)})
			if r==3:builds.append(build)
	for a in builds.size():
		for b in builds.size():
			var result=B.new().simulate(builds[a],builds[b],4,false)
			var mirror=B.new().simulate(builds[b],builds[a],4,false)
			ck(result.winner==-mirror.winner,"mirrored matchup winner")
			report.append({"a":a,"b":b,"winner":result.winner,"duration":result.duration,"damage":result.totals.map(func(s):return s.damage)})
	DirAccess.make_dir_recursive_absolute("res://build/qa/v60/checks")
	var f=FileAccess.open("res://build/qa/v60/checks/runs.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":fails,"samples":report},"\t"));f.close()
	print("RUNS_V60 ",checks," checks, ",fails," failures")
	quit(1 if fails else 0)
