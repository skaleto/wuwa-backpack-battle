extends RefCounted
## Opponents spend the same income at actual seeded shelves. They never inspect the player.
const C=preload("res://scripts/data/catalog.gd")
const F=preload("res://scripts/crafting/craft.gd")
const SUP=preload("res://scripts/party/supports.gd")
static func build(inv,round_number:int,seed_value:int)->Dictionary:
	var run=make_run(inv,round_number,seed_value)
	var ghost=inv.snapshot(run,"practice","演练 · "+C.characters[run.leader].name)
	ghost.source="practice"
	for key in ["practice_budget","practice_spend","practice_unspent","practice_method","practice_seed","practice_ledger"]:ghost[key]=run[key].duplicate(true) if run[key] is Array else run[key]
	return ghost
static func make_run(inv,round_number:int,seed_value:int)->Dictionary:
	var target=clampi(round_number,1,10)
	var leaders=C.selectable_leaders()
	var run=inv.new_run(leaders[posmod(seed_value,leaders.size())],posmod(seed_value,4294967296))
	run.practice_method="actual-shelves-v60";run.practice_seed=seed_value;run.practice_ledger=[]
	var route=["charge","haste","shielding"][posmod(seed_value,3)]
	for current in range(1,target+1):
		run.round=current
		if current>1:
			# Previous-round supplies are spent; equipment and paid ingredients persist.
			run.items=run.items.filter(func(i):return not C.is_tag(i.kind,"consumable"))
			run.gold+=8;run.refreshes=0;inv.refresh(run)
		for shelf in (1 if current<=2 else 2):
			var picks=[0,1,2,3,4]
			picks.sort_custom(func(a,b):return utility(run,a,route)>utility(run,b,route))
			purchase(inv,run,5,"capacity")
			for slot in picks:
				if utility(run,slot,route)>0:purchase(inv,run,slot,"shop")
			craft_owned(inv,run)
			if current>=3 and shelf==0:
				var before=int(run.gold)
				if inv.refresh(run,true):record(run,"refresh","",before-int(run.gold))
		# Rearrange legal cells to maximize exact star bonds; no free items or buffs.
		arrange(inv,run)
	run.practice_budget=9+(target-1)*8
	run.practice_spend=run.practice_ledger.reduce(func(sum,row):return sum+int(row.gold),0)
	run.practice_unspent=run.gold
	assert(inv.validate_run(run),"Generated practice build is invalid")
	assert(run.practice_spend+run.practice_unspent==run.practice_budget)
	return run
static func record(run:Dictionary,purpose:String,kind:String,paid:int)->void:
	run.practice_ledger.append({"round":run.round,"purpose":purpose,"kind":kind,"gold":paid,"source":"shop"})
static func utility(run:Dictionary,slot:int,route:String)->float:
	if run.shop[slot].is_empty():return -1
	var kind=run.shop[slot].kind;var d=C.items[kind]
	if d.price>run.gold:return -1
	if C.is_tag(kind,"weapon"):return -1 # One main weapon leaves room for the spatial engine.
	if C.is_tag(kind,"craft_material"):
		var wanted=C.combinations.any(func(r):return kind in r.materials and (run.items+run.stash).any(func(i):return i.kind==r.base) and not (run.items+run.stash).any(func(i):return i.kind==kind))
		return 9 if wanted else -1
	if (run.items+run.stash).any(func(i):return i.kind==kind):return -1
	return 5+(3 if C.is_tag(kind,route) else 0)+(2 if C.is_tag(kind,"echo") else 0)-float(d.price)*.25
static func purchase(inv,run:Dictionary,slot:int,purpose:String)->bool:
	if run.shop[slot].is_empty():return false
	var kind=run.shop[slot].kind
	if C.is_tag(kind,"bag") and inv.coverage(run.bags).size()>=mini(36,6+run.round*4):return false
	var fit=inv.first_fit(inv.make_piece(kind,"candidate"),run.items,run.bags)
	var before=int(run.gold);var ok=false
	if not fit.is_empty():ok=not inv.purchase_at(run,slot,fit,"board").is_empty()
	elif C.is_tag(kind,"craft_material"):ok=inv.buy(run,slot)
	if ok:record(run,purpose,kind,before-int(run.gold))
	return ok
static func craft_owned(inv,run:Dictionary)->void:
	for base in run.items.duplicate(true):
		for recipe in C.combinations:
			if not F.accepts_base(recipe,base.kind) or recipe.round_min>run.round:continue
			if not recipe.materials.all(func(k):return (run.items+run.stash).filter(func(v):return v.kind==k and v.uid!=base.uid).size()>=recipe.materials.count(k)):continue
			var candidate=run.duplicate(true)
			for kind in recipe.materials:F.place_material(candidate,recipe.target,base.uid,kind,inv)
			var tx=F.transact(candidate,recipe.target,base.uid,inv)
			if not tx.ok:continue
			run.clear();run.merge(candidate,true);record(run,"craft",recipe.target,0);break
static func bonds(inv,run:Dictionary)->int:
	var total=0
	for item in run.items:total+=inv.star_links(item,run.items,run).size()
	return total
static func arrange(inv,run:Dictionary)->void:
	var current=bonds(inv,run)
	for item in run.items.duplicate(true):
		var best=item.duplicate(true);var best_score=current
		for rotation in 4:
			for y in inv.HEIGHT:
				for x in inv.WIDTH:
					var candidate=item.duplicate(true);candidate.merge({"x":x,"y":y,"rotation":rotation},true)
					if not inv.can_place(candidate,run.items,run.bags):continue
					var old=run.items;run.items=run.items.filter(func(v):return v.uid!=item.uid)+[candidate]
					var score=bonds(inv,run);run.items=old
					if score>best_score:best=candidate;best_score=score
		if best_score>current:
			run.items=run.items.filter(func(v):return v.uid!=item.uid)+[best];current=best_score
