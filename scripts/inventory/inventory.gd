extends RefCounted
const PROGRESSION=preload("res://scripts/run/run_progression.gd")
const ECONOMY=preload("res://scripts/shop/economy.gd")
const SPACE=preload("res://scripts/inventory/item_space.gd")
const CRAFT_RULES=preload("res://scripts/crafting/craft_rules.gd")
const SHOP=preload("res://scripts/shop/shop_v75.gd")
const FEATURES=preload("res://scripts/run/demo_features.gd")
const C = preload("res://scripts/data/catalog.gd")
const SUP = preload("res://scripts/party/supports.gd")
const PB = preload("res://scripts/shop/practice_budget.gd")
const POCKETS = preload("res://scripts/inventory/pocket_rules_current.gd")
const FORGE = preload("res://scripts/crafting/craft.gd")
static var legacy_items: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/compat/catalog-v3.json")).items
const WIDTH = SPACE.WIDTH
const HEIGHT = SPACE.HEIGHT
const MAX_CAPACITY = WIDTH*HEIGHT
const HISTORICAL_STASH_LIMIT = 6
const MAX_SERIAL = 2147483647
const OWNED_COLLECTIONS = ["items","bags","stash","pending_gifts","pending_rearrange"]
const DIRS = [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]
# Only a migration validator supplies these; live inventory always uses C.
var footprint_catalogue:Dictionary={}
var accepted_catalogue_hash:String=""

const BUILD=preload("res://scripts/battle/build_rules.gd")
var _space=SPACE.new(C.items)
var _build=BUILD.new(_space)
func build_rules():
	spatial()
	return _build
const TRANSACTIONS=preload("res://scripts/inventory/inventory_transactions.gd")
const SHOP_ACTIONS=preload("res://scripts/shop/shop_actions.gd")
const CREW_ACTIONS=preload("res://scripts/party/crew_actions.gd")
const ROUND_RULES=preload("res://scripts/run/round_rules.gd")
const SESSION=preload("res://scripts/run/run_session.gd")

func spatial():
	_space.overrides=footprint_catalogue
	return _space
func shape_definition(kind:String)->Dictionary:return spatial().definition(kind)
func rotated(v:Vector2i,turns:int)->Vector2i:return spatial().rotated(v,turns)
func shape_low(kind:String,rotation:int)->Vector2i:return spatial().shape_low(kind,rotation)
func cells(item:Dictionary)->Array:return spatial().cells(item)
func occupied(item:Dictionary)->Array:return spatial().occupied(item)
func stars(item:Dictionary)->Array:return spatial().stars(item)
func coverage(bags:Array)->Array:return spatial().coverage(bags)
func in_bounds(v:Vector2i)->bool:return spatial().in_bounds(v)
func can_place(item:Dictionary,items:Array,bags:Array)->bool:return spatial().can_place(item,items,bags)

func bags_legal(bags: Array) -> bool:
	if bags.size()>MAX_CAPACITY:return false
	var used: Array=[]
	for bag in bags:
		if not C.is_tag(bag.get("kind",""),"bag"):return false
		for v in occupied(bag):
			if not in_bounds(v) or v in used:return false
			used.append(v)
	if used.size()>MAX_CAPACITY:return false
	return true

func can_place_bag(bag: Dictionary, bags: Array, items: Array) -> bool:
	if not C.is_tag(bag.get("kind",""),"bag"):return false
	var proposed=bags.filter(func(v):return v.get("uid","")!=bag.get("uid","?"))
	proposed.append(bag)
	if not bags_legal(proposed):return false
	var cover=coverage(proposed)
	return items.all(func(v):return occupied(v).all(func(cell):return cell in cover))

func first_fit(item: Dictionary, items: Array, bags: Array) -> Dictionary:
	var is_bag=C.is_tag(item.get("kind",""),"bag");var space=spatial()
	var area={} if is_bag else space.placement_area(item,items,bags)
	if not is_bag and area.is_empty():return {}
	for rotation in range(4):
		var turned=item.duplicate(true);turned.rotation=rotation
		var local=[] if is_bag else space.cells(turned)
		for y in range(HEIGHT):
			for x in range(WIDTH):
				var offset=Vector2i(x,y)
				if not is_bag and not space.fits_cells(local.map(func(v):return v+offset),area):continue
				var next=turned.duplicate(true)
				next.merge({"x":x,"y":y,"rotation":rotation},true)
				if not is_bag or can_place_bag(next,bags,items):return next
	return {}

func element(item: Dictionary, build: Dictionary) -> String:
	return build_rules().element(item,build)

func star_eligible(source:Dictionary,item:Dictionary)->bool:
	return build_rules().star_eligible(source,item)

func star_links(source: Dictionary, items: Array, _build: Dictionary={}) -> Array:
	return build_rules().star_links(source,items,_build)

func echo_weight(item: Dictionary, items: Array) -> float:
	return build_rules().echo_weight(item,items)

func pocket_bonus(item: Dictionary,build: Dictionary) -> Dictionary:
	return build_rules().pocket_bonus(item,build)

func modifiers(item: Dictionary, items: Array, build: Dictionary={}) -> Dictionary:
	return build_rules().modifiers(item,items,build)

func adjacent(a:Dictionary,b:Dictionary)->bool:return spatial().adjacent(a,b)

func recipes(_items: Array) -> Array:return []
func fuse(_run: Dictionary) -> int:return 0

func make_piece(kind: String,uid: String) -> Dictionary:
	return {"kind":kind,"uid":uid,"rotation":0,"x":0,"y":0,"level":0,"tuning":"","paid_cost":0,"cost_basis":"known_free"}

func valid_serial(run: Dictionary) -> bool:
	if not bounded_integer(run.get("serial",null),0,MAX_SERIAL):return false
	for key in OWNED_COLLECTIONS:
		if not run.get(key,[]) is Array:return false
		for piece in run.get(key,[]):
			if not piece is Dictionary or not piece.get("uid") is String:return false
			var number=uid_serial(piece.uid)
			if number<0 or number>int(run.serial):return false
	return true

# Zero denotes an unrelated ID (or i0); -1 denotes an out-of-range positive counter ID.
# Compare decimal text before conversion, since oversized input can wrap a signed int.
func uid_serial(uid: String) -> int:
	if not uid.begins_with("i"):return 0
	var suffix=uid.substr(1)
	if not suffix.is_valid_int() or suffix.begins_with("-"):return 0
	if suffix.begins_with("+"):suffix=suffix.substr(1)
	while suffix.length()>1 and suffix.begins_with("0"):suffix=suffix.substr(1)
	var ceiling=str(MAX_SERIAL)
	if suffix.length()>ceiling.length() or (suffix.length()==ceiling.length() and suffix>ceiling):return -1
	return int(suffix)

# Allocation is a preview; callers commit serial only after their other checks pass.
func next_identity(run: Dictionary) -> Dictionary:
	if not valid_serial(run) or int(run.serial)>=MAX_SERIAL:return {}
	var next_serial=int(run.serial)+1;var uid="i"+str(next_serial)
	for key in OWNED_COLLECTIONS:
		if run.get(key,[]).any(func(v):return v.uid==uid):return {}
	return {"serial":next_serial,"uid":uid}

func new_run(leader: String, seed_value: int,pool_mode:String="full") -> Dictionary:
	return new_run_supply(leader,seed_value,pool_mode,140)

func new_run_supply(leader:String,seed_value:int,pool_mode:String="full",supply_version:int=140)->Dictionary:
	if not C.characters.has(leader):return {}
	if supply_version not in [0,122,125,127,128,129,140]:return {}
	var run={"version":5,"ruleset":C.RULESET,"catalogue_hash":C.catalogue_hash,"leader":leader,"round":1,"wins":0,"losses":0,"gold":ECONOMY.starting_gold(),"seed":seed_value,"serial":2,"phase":"shop","items":[],"stash":[],"shop":[],"history":[],"relay":[],"primary":"i1","refreshes":0,"pending_gifts":[],"pending_rearrange":[],"golden_acquired":false,"roster":[],"supports":[],"recruited_round":0,"bags":[make_piece("satchel","b1")]}
	if pool_mode not in ["full","focused"]:return {}
	run.pool_mode=pool_mode
	if supply_version!=0:run.supply_version=supply_version
	run.recruitment=preload("res://scripts/party/recruitment.gd").initial()
	var weapon=make_piece(C.characters[leader].starter,"i1")
	weapon.salvage_credit=int(ECONOMY.rules.starter_credit)
	var supply=make_piece(C.characters[leader].get("starter_supply","nutrition"),"i2")
	for rotation in 4:
		for y in 2:
			for x in 3:
				var w=weapon.duplicate(true);w.merge({"rotation":rotation,"x":x,"y":y},true)
				if not can_place(w,[],run.bags):continue
				var food=first_fit(supply,[w],run.bags)
				if not food.is_empty():run.items=[w,food];break
			if not run.items.is_empty():break
		if not run.items.is_empty():break
	if run.items.is_empty():
		run.items=[first_fit(weapon,[],run.bags)];run.stash=[supply]
	refresh(run)
	return run

func purchased_capacity(run: Dictionary) -> int:
	return TRANSACTIONS.purchased_capacity(self,run)

func replacement_options(run: Dictionary,kind: String) -> Array:
	return TRANSACTIONS.replacement_options(self,run,kind)

static func resale_value(piece:Dictionary)->int:
	return TRANSACTIONS.resale_value(null,piece)

func replacement_quote(run:Dictionary,target_uid:String,new_kind:String)->Dictionary:
	return TRANSACTIONS.replacement_quote(self,run,target_uid,new_kind)

func replace_bag(run: Dictionary,target_uid: String,new_kind: String,rotation: int,offer_index:int=5) -> bool:
	return bool(commit_operation(run,plan_replace_bag(run,target_uid,new_kind,rotation,offer_index)).get("ok",false))

func plan_replace_bag(run: Dictionary,target_uid: String,new_kind: String,rotation: int,offer_index:int=5) -> Dictionary:
	return TRANSACTIONS.plan_replace_bag(self,run,target_uid,new_kind,rotation,offer_index)

func available_bags(run: Dictionary) -> Array:
	return TRANSACTIONS.available_bags(self,run)

func offer_round(kind:String)->int:
	return SHOP_ACTIONS.offer_round(self,kind)

func needed_materials(run:Dictionary)->Array:
	return SHOP.missing(run,self)

func set_bag_offer(run: Dictionary,kind: String) -> bool:
	return bool(commit_operation(run,plan_set_bag_offer(run,kind)).get("ok",false))

func plan_set_bag_offer(run: Dictionary,kind: String) -> Dictionary:
	return SHOP_ACTIONS.plan_set_bag_offer(self,run,kind)

func refresh(run: Dictionary, charge: bool=false) -> bool:
	return bool(commit_operation(run,plan_refresh(run,charge)).get("ok",false))

func plan_refresh(run: Dictionary, charge: bool=false) -> Dictionary:
	return SHOP_ACTIONS.plan_refresh(self,run,charge)

func craft_owners(build:Dictionary)->Array:
	var owners=build.get("roster",[]).duplicate()
	if C.characters.has(build.get("leader","")):owners.append(C.characters[build.leader].roster_id)
	return owners
func signature_owned(build:Dictionary,kind:String)->bool:
	return CRAFT_RULES.signature_owned(C.items[kind],craft_owners(build))
func craft_unlocked(run:Dictionary,kind:String)->bool:
	if not C.items.has(kind):return false
	return CRAFT_RULES.unlocked(C.items[kind],craft_owners(run),SUP.unlocked_types(run))
func craft_requirements(run:Dictionary,kind:String)->Dictionary:
	return CRAFT_RULES.requirements(C.items[kind],craft_owners(run),SUP.unlocked_types(run))

func shop_eligible(run: Dictionary,kind: String) -> bool:
	return SHOP_ACTIONS.shop_eligible(self,run,kind)

func legacy_offer(run: Dictionary,offer: Dictionary) -> bool:
	return SHOP_ACTIONS.legacy_offer(self,run,offer)

func recruit(run: Dictionary,role_id: String) -> bool:
	return bool(commit_operation(run,plan_recruit(run,role_id)).get("ok",false))

func plan_recruit(run: Dictionary,role_id: String) -> Dictionary:
	return CREW_ACTIONS.plan_recruit(self,run,role_id)

func set_supports(run: Dictionary,ordered_ids: Array) -> bool:
	return bool(commit_operation(run,plan_set_supports(run,ordered_ids)).get("ok",false))

func plan_set_supports(run: Dictionary,ordered_ids: Array) -> Dictionary:
	return CREW_ACTIONS.plan_set_supports(self,run,ordered_ids)

func toggle_lock(run: Dictionary,index: int) -> bool:
	return bool(commit_operation(run,plan_toggle_lock(run,index)).get("ok",false))

func plan_toggle_lock(run: Dictionary,index: int) -> Dictionary:
	return SHOP_ACTIONS.plan_toggle_lock(self,run,index)

func collection_legal(items: Array,leader: String) -> bool:
	var relics=0;var golden=0;var revives=0;var core_kinds: Array=[]
	for item in items:
		if not C.items.has(item.get("kind","")):return false
		var def=C.items[item.kind]
		if C.is_tag(item.kind,"keepsake"):
			if def.get("owner","")!=leader or item.kind in core_kinds:return false
			core_kinds.append(item.kind)
		if C.is_tag(item.kind,"golden"):golden+=1
		elif C.is_tag(item.kind,"relic"):relics+=1
		if item.kind=="revive":revives+=1
	return true # Space and shared star intervals bound the active V60 pool.

func purchase_price(run: Dictionary,index: int) -> int:
	return TRANSACTIONS.purchase_price(self,run,index)

func buy(run: Dictionary,index: int) -> bool:
	return bool(commit_operation(run,plan_buy(run,index)).get("ok",false))

func plan_buy(run: Dictionary,index: int) -> Dictionary:
	return TRANSACTIONS.plan_buy(self,run,index)

func purchase_at(run: Dictionary,index: int,preview: Dictionary,destination: String) -> Dictionary:
	var result=commit_operation(run,plan_purchase_at(run,index,preview,destination))
	return result.get("value",{}) if result.get("ok",false) else {}

func plan_purchase_at(run: Dictionary,index: int,preview: Dictionary,destination: String) -> Dictionary:
	return TRANSACTIONS.plan_purchase_at(self,run,index,preview,destination)

func placement_preview(run: Dictionary,piece: Dictionary,shop_index: int=-1) -> Dictionary:
	return TRANSACTIONS.placement_preview(self,run,piece,shop_index)

func find_piece(run: Dictionary,uid: String) -> Dictionary:
	for key in ["items","bags","stash"]:
		for item in run.get(key,[]):
			if item.uid==uid:return item
	return {}

func bag_transaction(run: Dictionary,bag: Dictionary) -> Dictionary:
	return TRANSACTIONS.bag_transaction(self,run,bag)

func _item_transaction(run: Dictionary,item: Dictionary) -> Dictionary:
	return TRANSACTIONS._item_transaction(self,run,item)

func place(run: Dictionary,item: Dictionary) -> bool:
	return bool(commit_operation(run,plan_place(run,item)).get("ok",false))

func plan_place(run: Dictionary,item: Dictionary) -> Dictionary:
	return TRANSACTIONS.plan_place(self,run,item)

func stash_preview(run: Dictionary,item: Dictionary) -> Dictionary:
	return TRANSACTIONS.stash_preview(self,run,item)

func stash(run: Dictionary,item: Dictionary) -> bool:
	return bool(commit_operation(run,plan_stash(run,item)).get("ok",false))

func plan_stash(run: Dictionary,item: Dictionary) -> Dictionary:
	return TRANSACTIONS.plan_stash(self,run,item)

func sell(run: Dictionary,item: Dictionary) -> bool:
	return bool(commit_operation(run,plan_sell(run,item)).get("ok",false))

func plan_sell(run: Dictionary,item: Dictionary) -> Dictionary:
	return TRANSACTIONS.plan_sell(self,run,item)

func primary_weapon(build: Dictionary) -> Dictionary:
	return build_rules().primary_weapon(build)

func valid_relay(build: Dictionary,uids: Array) -> bool:
	return build_rules().valid_relay(build,uids)

func set_relay(run: Dictionary,uids: Array) -> bool:
	if run.get("phase","")!="shop" or not valid_relay(run,uids):return false
	var plan=preload("res://scripts/inventory/preparation_rules.gd").relay(run,uids,valid_relay)
	return bool(commit_operation(run,plan).get("ok",false))

func clean_relay(run: Dictionary) -> void:
	if not valid_relay(run,run.get("relay",[])):run.relay=[]
	if not run.items.any(func(v):return v.uid==run.get("primary","") and C.is_tag(v.kind,"weapon")):run.primary=primary_weapon(run).get("uid","")

func relay_path(build: Dictionary) -> Array:
	return build_rules().relay_path(build)

func apply_material(run: Dictionary,material_uid: String,target_uid: String,choice: String) -> bool:
	return false # Tubes and tuners participate only in exact recipes.

func gift(run: Dictionary,kind: String) -> void:
	commit_operation(run,plan_gift(run,kind))

func plan_gift(run: Dictionary,kind: String) -> Dictionary:
	return ROUND_RULES.plan_gift(self,run,kind)

func grant_milestones(run: Dictionary,catch_up: bool=false) -> void:
	commit_operation(run,plan_grant_milestones(run,catch_up))

func plan_grant_milestones(run: Dictionary,catch_up: bool=false) -> Dictionary:
	return ROUND_RULES.plan_grant_milestones(self,run,catch_up)

func claim_pending(run: Dictionary) -> void:
	commit_operation(run,plan_claim_pending(run))

func plan_claim_pending(run: Dictionary) -> Dictionary:
	return ROUND_RULES.plan_claim_pending(self,run)

func finish(run: Dictionary,winner: int) -> Dictionary:
	var result=commit_operation(run,plan_finish(run,winner))
	return result.get("value",{}) if result.get("ok",false) else {}

func plan_finish(run: Dictionary,winner: int) -> Dictionary:
	return ROUND_RULES.plan_finish(self,run,winner)

func bounded_integer(value: Variant,low: int,high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=low and float(value)<=high and int(value)==value

func valid_piece(item: Variant) -> bool:
	if not item is Dictionary or not C.items.has(item.get("kind","")) or not item.get("uid") is String or item.uid.is_empty() or item.uid.length()>80:return false
	if item.has("cost_basis") and item.cost_basis not in ["known_free","actual","legacy_estimate","mixed"]:return false
	if item.has("paid_cost") and not bounded_integer(item.paid_cost,0,2147483647):return false
	if item.has("salvage_credit") and not bounded_integer(item.salvage_credit,0,2147483647):return false
	if not C.items[item.kind].get("released",true) and not C.items[item.kind].get("demo_available",false):return false
	if not bounded_integer(item.get("x",null),0,WIDTH-1) or not bounded_integer(item.get("y",null),0,HEIGHT-1) or not bounded_integer(item.get("rotation",null),0,3):return false
	if item.has("crew_star") and (not bounded_integer(item.crew_star,0,3) or C.items[item.kind].get("stars",[]).is_empty()):return false
	if not bounded_integer(item.get("level",0),0,2) or not item.get("tuning","") is String or item.get("tuning","") not in ["","fast","strong"]:return false
	if not C.is_tag(item.kind,"echo") and (item.get("level",0)!=0 or item.get("tuning","")!=""):return false
	return true

func validate_ghost(raw: Variant,allow_empty: bool=false) -> bool:
	var expected_hash=C.catalogue_hash if accepted_catalogue_hash.is_empty() else accepted_catalogue_hash
	if not raw is Dictionary or raw.get("version",0)!=5 or raw.get("ruleset","")!=C.RULESET or raw.get("catalogue_hash","")!=expected_hash or not C.characters.has(raw.get("leader","")) or not raw.get("items") is Array or not raw.get("bags") is Array:return false
	if raw.get("pool_mode","full") not in ["full","focused"]:return false
	if not bounded_integer(raw.get("pocket_version",0),0,143) or int(raw.get("pocket_version",0)) not in [0,143]:return false
	if not bounded_integer(raw.get("supply_version",0),0,140) or int(raw.get("supply_version",0)) not in [0,122,125,127,128,129,140]:return false
	if not raw.get("inactive",false) is bool or (raw.get("inactive",false) and not raw.items.is_empty()):return false
	if not raw.has("roster") or not raw.has("supports") or not SUP.valid_team(raw):return false
	if not preload("res://scripts/party/recruitment.gd").valid_state(self,raw):return false
	if raw.items.size()>MAX_CAPACITY or (raw.items.is_empty() and not allow_empty and not raw.get("inactive",false)) or not bounded_integer(raw.get("round",0),1,PROGRESSION.MAX_ROUNDS):return false
	var all_ids: Array=[]
	for pieces in [raw.items,raw.bags]:
		for item in pieces:
			if not valid_piece(item) or item.uid in all_ids:return false
			all_ids.append(item.uid)
	if not raw.bags.all(func(v):return C.is_tag(v.kind,"bag")) or not bags_legal(raw.bags):return false
	if not raw.items.all(func(v):return not C.is_tag(v.kind,"bag") and can_place(v,raw.items,raw.bags)):return false
	if not collection_legal(raw.items,raw.leader) or not raw.get("relay",[]) is Array or not valid_relay(raw,raw.get("relay",[])):return false
	if not raw.get("primary","") is String:return false
	if not raw.get("primary","").is_empty() and not raw.items.any(func(v):return v.uid==raw.primary and C.is_tag(v.kind,"weapon")):return false
	# Migrated ghosts retain displaced equipment; validate that ownership too.
	var all_owned=raw.items.duplicate()
	for key in ["stash","pending_gifts","pending_rearrange"]:
		if not raw.get(key,[]) is Array:return false
		if (key!="stash" or not accepted_catalogue_hash.is_empty()) and raw.get(key,[]).size()>(256 if key=="pending_rearrange" else 128):return false
		for piece in raw.get(key,[]):
			if not valid_piece(piece) or piece.uid in all_ids:return false
			all_ids.append(piece.uid);all_owned.append(piece)
	if raw.get("inactive",false) and all_owned.is_empty():return false
	if not collection_legal(all_owned,raw.leader):return false
	return true

func validate_run(raw: Variant) -> bool:
	if not validate_ghost(raw,true):return false
	if not raw.get("stash") is Array or (not accepted_catalogue_hash.is_empty() and raw.stash.size()>HISTORICAL_STASH_LIMIT) or not raw.get("shop") is Array or raw.shop.size()!=6 or raw.get("phase","") not in ["shop","battle","result","ending","recruit"]:return false
	if not raw.get("history",null) is Array or not valid_serial(raw):return false
	for key in ["gold","serial","seed","wins","losses","refreshes"]:
		if not bounded_integer(raw.get(key,0),0,4294967295 if key=="seed" else 2147483647):return false
	if not bounded_integer(raw.get("recruited_round",null),0,int(raw.round)):return false
	if not bounded_integer(raw.get("capacity_refund_round",0),0,int(raw.round)):return false
	if raw.roster.is_empty() and int(raw.recruited_round)!=0:return false
	if not raw.roster.is_empty() and int(raw.recruited_round)<raw.roster.size()+1:return false
	if raw.has("pending_carrier_type") and (not raw.pending_carrier_type is String or raw.pending_carrier_type not in SUP.unlocked_types(raw)):return false
	var ids: Array=(raw.items+raw.bags).map(func(v):return v.uid)
	if not raw.get("golden_acquired",false) is bool:return false
	var owned=raw.items+raw.stash
	for key in ["stash","pending_gifts","pending_rearrange"]:
		if not raw.get(key,[]) is Array:return false
		if (key!="stash" or not accepted_catalogue_hash.is_empty()) and raw.get(key,[]).size()>(256 if key=="pending_rearrange" else 128):return false
		for item in raw.get(key,[]):
			if not valid_piece(item) or item.uid in ids:return false
			ids.append(item.uid)
		if key!="stash":owned+=raw.get(key,[])
	if not collection_legal(owned,raw.leader) or (owned.any(func(v):return C.is_tag(v.kind,"golden")) and not raw.get("golden_acquired",false)):return false
	var locks=0
	for n in range(6):
		var offer=raw.shop[n]
		if not offer is Dictionary:return false
		if offer.is_empty():continue
		if not C.items.has(offer.get("kind","")) or not offer.get("locked",false) is bool:return false
		if C.is_tag(offer.kind,"keepsake"):return false
		if int(raw.get("supply_version",0))<140 and (n==5)!=C.is_tag(offer.kind,"bag"):return false
		if (not C.items[offer.kind].get("released",true) and not C.items[offer.kind].get("demo_available",false)) or (not shop_eligible(raw,offer.kind) and not legacy_offer(raw,offer)):return false
		if offer.has("bundle"):
			if n not in [3,4] or not offer.bundle is Array or offer.bundle.size()!=2 or not offer.bundle.all(func(k):return k is String and shop_eligible(raw,k)) or offer.bundle[0]!=offer.kind or offer.bundle[0]==offer.bundle[1]:return false
			if not bounded_integer(offer.get("bundle_price",null),0,2147483647) or int(offer.bundle_price)!=int(ceil((int(C.items[offer.bundle[0]].price)+int(C.items[offer.bundle[1]].price))*.8)):return false
			if preload("res://scripts/party/recruitment.gd").bond_id(raw)!="artisan+supply":return false
		if offer.get("locked",false):
			locks+=1
	return locks<=2

func snapshot(run: Dictionary,owner: String,name: String="") -> Dictionary:
	var ghost={"version":5,"ruleset":C.RULESET,"catalogue_hash":C.catalogue_hash,"leader":run.leader,"round":run.round,"bags":[],"items":[],"relay":run.get("relay",[]).duplicate(),"primary":primary_weapon(run).get("uid",""),"golden_acquired":bool(run.get("golden_acquired",false)) or run.items.any(func(v):return C.is_tag(v.kind,"golden")),"roster":run.get("roster",[]).duplicate(),"supports":run.get("supports",[]).duplicate(),"owner":owner,"name":name if not name.is_empty() else C.characters[run.leader].name+"的行囊"}
	ghost.pool_mode=run.get("pool_mode","full")
	if run.has("supply_version"):ghost.supply_version=int(run.supply_version)
	if run.has("pocket_version"):ghost.pocket_version=int(run.pocket_version)
	if run.get("recruitment_legacy",false):ghost.recruitment_legacy=true
	if run.has("recruitment"):
		ghost.recruitment=run.recruitment.duplicate(true)
		ghost.recruitment.candidates=[]
	ghost.simulation_version=run.get("simulation_version",preload("res://scripts/party/recruitment.gd").simulation_version(run))
	for key in ["items","bags"]:
		for item in run[key]:
			var clean=make_piece(item.kind,item.uid)
			for field in ["x","y","rotation","level"]:clean[field]=int(item.get(field,0))
			clean.tuning=item.get("tuning","")
			if item.has("paid_cost"):
				clean.paid_cost=int(item.paid_cost);clean.cost_basis=item.get("cost_basis","actual")
			if item.has("cost_basis"):clean.cost_basis=item.cost_basis
			if item.has("salvage_credit"):clean.salvage_credit=int(item.salvage_credit)
			if item.has("crew_star"):clean.crew_star=int(item.crew_star)
			ghost[key].append(clean)
	return ghost

func practice(round_number: int,seed_value: int,pool_mode:String="full",supply_version:int=0,pocket_version:int=0) -> Dictionary:
	var build=PB.build(self,round_number,seed_value,pool_mode,false,115,supply_version)
	if pocket_version>0:build.pocket_version=pocket_version
	return build
# Pure plan metadata and the compatibility commit boundary. Historical builders
# pass incomplete snapshots; their operation-specific checks remain authoritative.
# A complete source receives full validation as well. Application commits always
# inject validate_run directly through RunSession.
func operation_stamp(run:Dictionary)->String:return SESSION.stamp(run)
func operation_plan(run:Dictionary,next:Dictionary,value:Variant,ok:bool)->Dictionary:
	return {"ok":ok,"source":SESSION.stamp(run),"run":next if ok else run.duplicate(true),"value":value}
func commit_operation(run:Dictionary,plan:Dictionary)->Dictionary:
	var expected:Dictionary=plan.get("run",{}).duplicate(true)
	var complete=validate_run(run)
	return SESSION.commit(run,plan,func(candidate):return candidate==expected and (not complete or validate_run(candidate)))
