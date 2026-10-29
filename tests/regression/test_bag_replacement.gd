extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
var inventory=I.new()
var checks=0
var failures=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func p(kind: String,x: int,y: int,uid: String) -> Dictionary:
	var item=inventory.make_piece(kind,uid);item.x=x;item.y=y;return item
func full_run() -> Dictionary:
	var run=inventory.new_run("jiyan",71);run.round=5;run.gold=20;run.items=[];run.stash=[];run.primary=""
	run.bags=[p("satchel",0,0,"b1"),p("travel",3,0,"b2"),p("travel",0,2,"b3"),p("travel",3,2,"b4"),p("travel",0,4,"b5")]
	run.shop=[{},{},{},{},{},{"kind":"pouch","locked":false}]
	return run
func _initialize() -> void:
	var run=full_run();var before=run.duplicate(true)
	check(inventory.buy(run,5) and inventory.purchased_capacity(run)==34,"ordinary bag purchase expands beyond thirty cells")
	run=full_run();before=run.duplicate(true)
	var almost=full_run();almost.bags.pop_back();almost.stash=[p("strip",0,0,"owned-stash")]
	before=almost.duplicate(true)
	check(inventory.buy(almost,5) and inventory.purchased_capacity(almost)==31,"unplaced purchased bags count toward visible board limit")
	check(inventory.has_method("replacement_options") and inventory.has_method("replace_bag"),"atomic replacement API exists")
	if not inventory.has_method("replacement_options"):finish();return
	var options=inventory.replacement_options(run,"pouch")
	check(not options.is_empty() and options.all(func(v):return v.has("bag_uid") and v.has("rotation")),"eligible empty bag replacements include target and rotation")
	check("pouch" in inventory.available_bags(run),"full-capacity rack keeps eligible replacement choices visible")
	run.items=[p("nutrition",0,0,"contents")]
	check(not inventory.replacement_options(run,"pouch").any(func(v):return v.bag_uid=="b1"),"bag containing any item cannot be replaced")
	run.items=[p("w_rectifier",2,1,"crossing")]
	check(not inventory.replacement_options(run,"pouch").any(func(v):return v.bag_uid in ["b1","b2"]),"crossing item makes both supporting bags ineligible")
	before=run.duplicate(true)
	check(not inventory.replace_bag(run,"b1","pouch",0) and run==before,"invalid replacement preserves bags items money and serial")
	run=full_run();before=run.duplicate(true)
	check(not inventory.replace_bag(run,"b1","travel",0) and run==before,"replacement must match fixed-rack offer")
	run.round=1;run.shop[5]={"kind":"travel","locked":false};before=run.duplicate(true)
	check(not inventory.replace_bag(run,"b1","travel",0) and run==before,"replacement respects large-pack round unlock")
	run=full_run();run.gold=0;before=run.duplicate(true)
	check(not inventory.replace_bag(run,"b1","pouch",0) and run==before,"unaffordable replacement never mutates finances")
	run=full_run();run.bags[-1].paid_cost=4;var serial=int(run.serial);var gold=int(run.gold)
	check(inventory.replace_bag(run,"b5","pouch",0),"empty connected replacement commits successfully")
	check(inventory.coverage(run.bags).size()==28 and run.bags.size()==5 and run.stash.is_empty(),"replacement removes old six-cell module and installs four-cell module atomically")
	check(run.serial==serial+1 and run.gold==gold+1 and run.shop[5].is_empty(),"replacement deducts new price minus 75 percent old paid cost and consumes fixed offer")
	check(not run.bags.any(func(v):return v.uid=="b5") and run.bags.any(func(v):return v.kind=="pouch" and v.x==0 and v.y==4 and v.uid=="i"+str(serial+1)),"replacement retains origin with a fresh purchased UID")
	check(inventory.validate_run(run),"committed replacement remains a valid saved run")
	check("travel" in inventory.available_bags(run),"twenty-eight-cell rack offers eligible replacement when expansion cannot fit")
	run=full_run();run.bags.append(p("pouch",6,0,"legacy-bag"));before=run.duplicate(true)
	check(inventory.buy(run,5) and inventory.purchased_capacity(run)==38,"thirty-four owned cells can expand within visible board")
	run=full_run();run.bags=preload("res://tests/fixtures/capacity_fixture_v111.gd").full_bags(inventory)
	before=run.duplicate(true)
	check(inventory.coverage(run.bags).size()==63 and not inventory.buy(run,5) and run==before,"full visible board rejects additional paid capacity atomically")
	run=full_run();gold=int(run.gold)
	check(inventory.replace_bag(run,"b5","pouch",0) and run.gold==gold-2,"zero-cost bag never creates catalogue refund")
	finish()
func finish() -> void:
	print("RESULT: ",checks," replacement checks, ",failures," failures")
	quit(1 if failures else 0)
