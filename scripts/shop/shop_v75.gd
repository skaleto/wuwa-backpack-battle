extends RefCounted
## Approved probability policy. The planner owns RNG; pool math sees only facts.
const SLOTS=preload("res://scripts/shop/supply_slots_v140.gd")
const POOL=preload("res://scripts/shop/playtest_pool.gd")
const C=preload("res://scripts/data/catalog.gd")
const SUPPLY=preload("res://scripts/shop/supply_policy_v122.gd")
static var design:Dictionary=POOL.design

# Compatibility projection for callers still using the inventory query facade.
static func facts(run:Dictionary,inventory)->Dictionary:
	var eligible={};var unlocked={};var owned={}
	for kind in C.items:
		if inventory.shop_eligible(run,kind):eligible[kind]=true
	for recipe in C.supply_recipes(int(run.get("supply_version",0))):
		if inventory.craft_unlocked(run,recipe.target):unlocked[recipe.target]=true
	for piece in run.get("items",[])+run.get("stash",[]):owned[piece.kind]=true
	var partners=[]
	if run.get("pool_mode","full")=="focused":
		for kind in eligible:
			if C.is_tag(kind,"bag") or owned.has(kind):continue
			var candidate=inventory.make_piece(kind,"candidate")
			for other in owned:
				var source=inventory.make_piece(other,"owned")
				if partner_eligible(source,candidate,int(run.get("supply_version",0))) or partner_eligible(candidate,source,int(run.get("supply_version",0))):
					partners.append(kind);break
	return {"round":int(run.round),"supply_version":int(run.get("supply_version",0)),"eligible":eligible,"unlocked":unlocked,"owned":owned,"partners":partners,"bags":inventory.available_bags(run)}

static func partner_eligible(source:Dictionary,target:Dictionary,version:int)->bool:
	return preload("res://scripts/battle/build_rules.gd").accepts_star(source.kind,C.items[source.kind],C.supply_profile(source.kind,version),target.kind,C.items[target.kind],C.supply_profile(target.kind,version))

static func ordinary_pool(data:Dictionary,slot:int)->Dictionary:
	var groups=[[],[],[],[]]
	for kind in C.items:
		if C.is_tag(kind,"bag") or not data.eligible.has(kind):continue
		var is_weapon=C.is_tag(kind,"weapon");var is_echo=C.is_tag(kind,"echo")
		if slot==0 and not is_weapon:continue
		if slot==1 and not is_echo:continue
		if slot==2 and (is_weapon or is_echo):continue
		var tier=int(C.supply_profile(kind,int(data.get("supply_version",0))).get("tier",0))
		if tier>=1 and tier<=4:groups[tier-1].append(kind)
	var category=["weapon","echo","other"][slot] if slot<3 else "mixed"
	var mix=design.shop.category_tiers[category][str(clampi(int(data.round),1,preload("res://scripts/run/run_progression.gd").MAX_ROUNDS))]
	var norm=0.0;var result={}
	for i in 4:
		if not groups[i].is_empty():norm+=float(mix[i])
	if norm<=0:return result
	for i in 4:
		if int(data.get("supply_version",0)) in [127,128,129,140]:
			var shares=preload("res://scripts/shop/supply_policy_v127.gd").shares(groups[i])
			for kind in shares:result[kind]=float(mix[i])/norm*shares[kind]
		elif int(data.get("supply_version",0))==125:
			var shares=preload("res://scripts/shop/supply_policy_v125.gd").shares(groups[i])
			for kind in shares:result[kind]=float(mix[i])/norm*shares[kind]
		else:
			for kind in groups[i]:result[kind]=float(mix[i])/norm/groups[i].size()
	return SUPPLY.commodities(result,int(data.round)) if SUPPLY.enabled(data) else result

static func missing_from(data:Dictionary)->Array:
	var result=[]
	for r in C.supply_recipes(int(data.get("supply_version",0))):
		if str(r.id).begins_with("E125-") and int(data.get("supply_version",0))<125:continue
		if not data.unlocked.has(r.target):continue
		var a=r.base;var b=r.materials[0]
		if data.owned.has(a) and not data.owned.has(b) and data.eligible.has(b) and b not in result:result.append(b)
		if data.owned.has(b) and not data.owned.has(a) and data.eligible.has(a) and a not in result:result.append(a)
	result.sort()
	return result

static func pool(data:Dictionary,slot:int)->Dictionary:
	if int(data.get("supply_version",0))==SLOTS.VERSION:
		var groups=[]
		for category in 3:groups.append(SUPPLY.weighted(ordinary_pool(data,category),data,slot))
		return SLOTS.mix(groups,data.get("bags",[]))
	var result=ordinary_pool(data,slot)
	if SUPPLY.enabled(data):return SUPPLY.weighted(result,data,slot)
	# Focused playtest: half of one slot offers a new compatible star partner.
	# It reads eligibility only, never layout or a predetermined graduation path.
	if slot==3 and not data.get("partners",[]).is_empty():
		var share=float(POOL.design.shop_partner_probability)
		for k in result:result[k]*=1.0-share
		for k in data.partners:result[k]=float(result.get(k,0.0))+share/data.partners.size()
	if slot!=4:return result
	var candidates=missing_from(data)
	if candidates.is_empty():return result
	var assist=float(design.shop.assist_probability)
	for k in result:result[k]*=1.0-assist
	for k in candidates:result[k]=float(result.get(k,0.0))+assist/candidates.size()
	return result

static func ordinary(run:Dictionary,slot:int,inventory)->Dictionary:return ordinary_pool(facts(run,inventory),slot)
static func missing(run:Dictionary,inventory)->Array:return missing_from(facts(run,inventory))
static func distribution(run:Dictionary,slot:int,inventory)->Dictionary:return pool(facts(run,inventory),slot)

static func draw(distribution:Dictionary,rng:RandomNumberGenerator)->String:
	var remaining=rng.randf();var last=""
	for kind in distribution:
		last=kind;remaining-=float(distribution[kind])
		if remaining<0:return kind
	return last

static func roll(data:Dictionary,previous:Array,bag_choices:Array,rng:RandomNumberGenerator)->Array:
	var result=[]
	for slot in 6:
		if slot<previous.size() and previous[slot].get("locked",false):
			result.append(previous[slot].duplicate(true));continue
		var kind=""
		if int(data.get("supply_version",0))==SLOTS.VERSION or slot<5:kind=draw(pool(data,slot),rng)
		elif not bag_choices.is_empty():kind=bag_choices[rng.randi_range(0,bag_choices.size()-1)]
		result.append({"kind":kind,"locked":false} if not kind.is_empty() else {})
	return result

static func offers(run:Dictionary,inventory,rng:RandomNumberGenerator)->Array:
	return roll(facts(run,inventory),run.get("shop",[]),inventory.available_bags(run),rng)
