extends SceneTree
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const B=preload("res://scripts/battle/battle.gd")
const F=preload("res://scripts/crafting/craft.gd")
var inv=I.new()
var engine=B.new()
var checks=0
var failures=0
var records=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
	for seed_value in [50,83,1729]:
		for strategy in ["upgrade","echo_guard"]:play(seed_value,strategy)
	var file=FileAccess.open("res://build/qa/demo-v50/normal-runs.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"method":"Normal random shop; actual prices, gold, refreshes and completion rules. Scripted choices are QA samples, not balance or fun proof.","runs":records,"checks":checks,"failures":failures},"\t"));file.close()
	print("V50 NORMAL RUNS: ",records.size()," complete runs, ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
func rank(kind:String,strategy:String)->int:
	if C.is_tag(kind,"bag"):return 4
	if strategy=="upgrade":return 0 if kind=="whiff" else 1 if C.is_tag(kind,"echo") else 2 if C.is_tag(kind,"weapon") else 3
	return 0 if kind in ["turtle","rocksteady"] else 1 if C.is_tag(kind,"echo") else 2 if C.is_tag(kind,"consumable") else 3
func purchase(r:Dictionary,index:int,ledger:Array)->bool:
	var offer=r.shop[index]
	if offer.is_empty():return false
	var kind=str(offer.kind)
	if r.items.any(func(v):return v.kind==kind) and not C.is_tag(kind,"consumable"):return false
	if C.is_tag(kind,"weapon") and r.items.filter(func(v):return C.is_tag(v.kind,"weapon")).size()>=2:return false
	var candidate=inv.first_fit(inv.make_piece(kind,"candidate"),r.items,r.bags)
	if candidate.is_empty():return false
	var gold=int(r.gold)
	var bought=inv.purchase_at(r,index,candidate,"board")
	if bought.is_empty():return false
	ledger.append({"action":"buy","kind":kind,"uid":bought.uid,"paid":gold-int(r.gold),"x":bought.x,"y":bought.y,"rotation":bought.rotation})
	return true
func equip_gifts(r:Dictionary):
	for item in r.stash.duplicate(true):
		var fit=inv.first_fit(item,r.items,r.bags)
		if not fit.is_empty():inv.place(r,fit)
func upgrade(r:Dictionary,ledger:Array):
	var base=inv.primary_weapon(r)
	if r.round<2 or base.get("kind","")!="w_rectifier":return
	var prior=r.duplicate(true)
	var staged=[]
	# Real spatial tradeoff: park neighbouring gear in storage before buying
	# the material; later re-equipping costs space, never creates free pieces.
	for item in r.items.duplicate(true):
		if item.uid==base.uid or not inv.adjacent(base,item):continue
		if inv.stash(r,item):staged.append({"action":"stash","uid":item.uid,"kind":item.kind})
	if not F.buy_material(r,"mat_43020031",inv):r.clear();r.merge(prior,true);return
	if not F.place_material(r,"weapon_21050044",base.uid,"mat_43020031",inv).ok:r.clear();r.merge(prior,true);return
	var preview=F.preview(r,"weapon_21050044",base.uid,inv)
	if not preview.ok:r.clear();r.merge(prior,true);return
	var output=preview.output
	var tx=F.transact(r,"weapon_21050044",base.uid,inv,{"x":output.x,"y":output.y,"rotation":output.rotation})
	check(tx.ok,"normal paid material upgrade commits chosen location")
	ledger.append_array(staged)
	ledger.append({"action":"craft","target":"weapon_21050044","paid":int(prior.gold)-int(r.gold),"consumed":tx.consumed,"output":tx.output})
	# A player can move an echo to reconnect after seeing the changed footprint.
	for echo in (r.items+r.stash).filter(func(v):return C.is_tag(v.kind,"echo") and float(C.items[v.kind].get("damage",0))>0):
		if r.items.any(func(v):return v.uid==echo.uid) and inv.adjacent(output,echo):return
		for y in range(I.HEIGHT):
			for x in range(I.WIDTH):
				var moved=echo.duplicate(true);moved.x=x;moved.y=y
				if inv.can_place(moved,r.items,r.bags) and inv.adjacent(output,moved):
					inv.place(r,moved);ledger.append({"action":"move","uid":echo.uid,"x":x,"y":y});return
func play(seed_value:int,strategy:String):
	var r=inv.new_run("encore",seed_value)
	var record={"seed":seed_value,"leader":"encore","strategy":strategy,"rounds":[]}
	for n in range(10):
		if r.phase=="ending":break
		var row={"round":r.round,"start_gold":r.gold,"shops":[],"actions":[]}
		row.shops.append(r.shop.duplicate(true))
		if strategy=="upgrade" and r.round==2:purchase(r,5,row.actions)
		if strategy=="upgrade":upgrade(r,row.actions)
		equip_gifts(r)
		for draw in range(3):
			row.shops.append(r.shop.duplicate(true))
			var indices=[0,1,2,3,4,5]
			indices.sort_custom(func(a,b):return rank(r.shop[a].get("kind","tea"),strategy)<rank(r.shop[b].get("kind","tea"),strategy))
			for index in indices:purchase(r,index,row.actions)
			if draw<2 and r.gold>1:
				var previous=int(r.gold);check(inv.refresh(r,true),"normal refresh succeeds")
				row.actions.append({"action":"refresh","paid":previous-int(r.gold)})
		check(inv.validate_run(r),"normal shopping leaves valid run")
		var opponent=inv.practice(int(r.round),posmod(seed_value+n*7,31))
		row.opponent={"leader":opponent.leader,"budget":opponent.practice_budget,"spent":opponent.practice_spend,"seed":opponent.practice_seed}
		check(int(opponent.practice_budget)==9+8*(int(r.round)-1),"independent opponent uses standard round budget")
		r.phase="battle";var fight=engine.simulate(r,opponent,int(r.seed),false);r.combat=fight
		row.end_gold=r.gold;row.build=inv.snapshot(r,"qa-normal-v50");row.winner=fight.winner;row.duration=fight.duration
		row.chases=fight.events.filter(func(e):return e.side==0 and e.kind=="coordinated" and e.has("consumed_marks")).size()
		row.consumed_marks=fight.events.filter(func(e):return e.side==0 and e.kind=="coordinated" and e.has("consumed_marks")).reduce(func(total,e):return total+int(e.consumed_marks),0)
		row.actual_advance=fight.events.filter(func(e):return e.side==0 and e.kind=="cooldown_advance").reduce(func(total,e):return total+float(e.old_ready_time-e.new_ready_time),0.0)
		r.phase="result";inv.finish(r,int(fight.winner));check(inv.validate_run(r),"normal settlement preserves valid run")
		record.rounds.append(row)
	check(r.phase=="ending","normal run reaches actual win/loss ending")
	record.wins=r.wins;record.losses=r.losses;record.final_gold=r.gold;records.append(record)
	print("SAMPLE ",seed_value," ",strategy," ",r.wins,"W/",r.losses,"L ",record.rounds.size()," rounds")
