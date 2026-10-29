extends SceneTree
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const PB=preload("res://scripts/shop/practice_budget.gd")
const OLD=preload("res://tests/fixtures/practice_before_v70.gd")
const S=preload("res://scripts/storage/storage.gd")
var failures=[];var checks=0
func ck(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize():call_deferred("test")
func test():
	var inv=I.new()
	for seed_value in [2,13,30]:
		for r in [1,2,3]:
			var run=PB.make_run(inv,r,seed_value)
			ck(run.practice_method=="shop-opening-v70","opening method is versioned")
			ck(inv.validate_run(run),"practice remains legal")
			ck(run.practice_spend+run.practice_unspent==9+(r-1)*8,"same income reconciles")
			ck(run.practice_unspent>=[4,6,6][r-1],"opening reserves money at fixed round pace")
			ck(not run.practice_ledger.any(func(row):return row.purpose=="refresh"),"opening uses one actual shelf per round")
			for current in range(1,r+1):
				ck(run.practice_ledger.filter(func(row):return row.round==current and row.purpose=="shop").size()<=current,"fixed purchase-count ramp")
			for row in run.practice_ledger:
				if row.purpose in ["shop","capacity"]:ck(row.gold==int(C.items[row.kind].price),"full public catalogue price")
			ck(run==PB.make_run(inv,r,seed_value),"seeded practice deterministic")
		var raw=inv.new_run("aemeath",seed_value)
		raw.practice_ledger=[]
		OLD.purchase(inv,raw,5,"capacity")
		for slot in [1,3,2,4]:OLD.purchase(inv,raw,slot,"shop")
		var expected=raw.duplicate(true);var actual=raw.duplicate(true)
		OLD.arrange(inv,expected);PB.arrange(inv,actual)
		ck(actual==expected,"fast arrangement exactly matches reference legal placements")
	var s=S.new("/tmp/resonance-v70-tests-%d"%OS.get_process_id())
	var run=inv.new_run("aemeath",8)
	var ghost=inv.snapshot(run,"other-player")
	ck(s.publish(ghost),"isolated foreign ghost published")
	var before=run.duplicate(true);var enemy=s.opponent(run)
	ck(enemy.source=="practice","first three rounds retain practice even with saved ghosts")
	ck(run==before,"opponent selection does not mutate player")
	enemy.items.clear()
	ck(not s.opponent(run).items.is_empty(),"cached opponents are independent copies")
	for r in [2,3]:
		run.round=r;ck(s.opponent(run).source=="practice","fixed opening rounds ignore imported harder ghosts")
	run.round=4;ghost.round=4;ck(s.publish(ghost),"later ghost published")
	ck(s.opponent(run).source=="saved","saved matching resumes after opening")
	print("OPENING_V70 ",checks," checks, ",failures.size()," failures")
	quit(1 if not failures.is_empty() else 0)
