extends RefCounted
## Pure operation planning. Mutating helpers receive only isolated candidates.
## Inventory supplies shared geometry, identity and validation adapters.
const C=preload("res://scripts/data/catalog.gd")
const SHOP=preload("res://scripts/shop/shop_v75.gd")

static func bag_kinds(run:Dictionary)->Array:
	var kinds:Array=["pouch","strip","corner","travel"]
	if int(run.get("supply_version",0))>=129:kinds.append_array(preload("res://scripts/data/pocket_catalog_v129.gd").spec.keys())
	return kinds.filter(func(kind):return C.items.has(kind))

static func offer_round(inv,kind:String)->int:
	# Small spatial choices are available immediately; large travel packs retain
	# their third-round gate. This is supply policy, not a footprint migration.
	return 1 if kind in ["pouch","strip","corner"] else int(C.items[kind].round_min)

static func _apply_set_bag_offer(inv,run: Dictionary,kind: String) -> bool:
	# Retired compatibility entry: an offer changes only through normal refresh.
	return false

static func _apply_refresh(inv,run: Dictionary, charge: bool=false) -> bool:
	if run.get("phase","")!="shop":return false
	var cost=preload("res://scripts/party/recruitment.gd").refresh_cost(run,charge)
	if int(run.get("gold",0))<cost:return false
	var rng=RandomNumberGenerator.new();rng.seed=int(run.seed)
	var next=SHOP.offers(run,inv,rng)
	run.gold-=cost
	if charge:run.refreshes=int(run.get("refreshes",0))+1
	preload("res://scripts/party/recruitment.gd").guarantee_special(inv,run,next)
	run.shop=next;run.seed=int(rng.randi())
	run.erase("pending_carrier_type")
	return true

static func shop_eligible(inv,run: Dictionary,kind: String) -> bool:
	if not C.items.has(kind):return false
	if C.is_tag(kind,"bag"):return kind in bag_kinds(run) and int(run.get("round",1))>=offer_round(inv,kind)
	if C.items[kind].get("crew_supply","").is_empty() and not preload("res://scripts/shop/playtest_pool.gd").includes(run,kind):return false
	var def=C.items[kind];var spec=C.supply_profile(kind,int(run.get("supply_version",0)))
	if int(spec.get("introduced_version",0))>int(run.get("supply_version",0)):return false
	if not def.get("crew_supply","").is_empty() and not preload("res://scripts/party/recruitment.gd").supply_allowed(run,def.crew_supply):return false
	return not spec.is_empty() and bool(spec.active) and not bool(spec.craft_only) and int(run.get("round",1))>=int(spec.shop_round) and inv.craft_unlocked(run,kind)

static func legacy_offer(inv,run: Dictionary,offer: Dictionary) -> bool:
	return run.get("migrated_from",0)==3 and offer.get("legacy_v3",false)==true and inv.legacy_items.has(offer.get("kind","")) and int(run.get("round",1))>=int(inv.legacy_items[offer.kind].round_min)

static func _apply_toggle_lock(inv,run: Dictionary,index: int) -> bool:
	if run.get("phase","")!="shop" or index<0 or index>=6 or run.shop.size()!=6 or run.shop[index].is_empty():return false
	var locked=bool(run.shop[index].get("locked",false))
	if not locked and run.shop.filter(func(v):return v.get("locked",false)).size()>=2:return false
	run.shop[index].locked=not locked
	return true

static func plan_set_bag_offer(inv,run: Dictionary,kind: String) -> Dictionary:
	var next=run.duplicate(true)
	var value=_apply_set_bag_offer(inv,next,kind)
	return inv.operation_plan(run,next,value,value)

static func plan_refresh(inv,run: Dictionary, charge: bool=false) -> Dictionary:
	var next=run.duplicate(true)
	var value=_apply_refresh(inv,next,charge)
	return inv.operation_plan(run,next,value,value)

static func plan_toggle_lock(inv,run: Dictionary,index: int) -> Dictionary:
	var next=run.duplicate(true)
	var value=_apply_toggle_lock(inv,next,index)
	return inv.operation_plan(run,next,value,value)

