extends RefCounted
const C = preload("res://scripts/compat/v4/catalog.gd")
const SUP = preload("res://scripts/compat/v4/supports.gd")
static var legacy_items: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/compat/catalog-v3.json")).items
const WIDTH = 8
const HEIGHT = 6
const MAX_CAPACITY = 30
const STASH = 6
const MAX_SERIAL = 2147483647
const OWNED_COLLECTIONS = ["items","bags","stash","pending_gifts","pending_rearrange"]
const DIRS = [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]

func rotated(v: Vector2i, turns: int) -> Vector2i:
	for n in range(posmod(turns,4)):
		v=Vector2i(-v.y,v.x)
	return v

func shape_low(kind: String, rotation: int) -> Vector2i:
	var low=Vector2i(100,100)
	for p in C.items[kind].shape:
		var v=rotated(Vector2i(int(p[0]),int(p[1])),rotation)
		low.x=mini(low.x,v.x);low.y=mini(low.y,v.y)
	return low

func cells(item: Dictionary) -> Array:
	if not C.items.has(item.get("kind","")):return []
	var turns=int(item.get("rotation",0))
	var low=shape_low(item.kind,turns)
	return C.items[item.kind].shape.map(func(p):return rotated(Vector2i(int(p[0]),int(p[1])),turns)-low)

func occupied(item: Dictionary) -> Array:
	return cells(item).map(func(v):return v+Vector2i(int(item.get("x",0)),int(item.get("y",0))))

func stars(item: Dictionary) -> Array:
	if not C.items.has(item.get("kind","")):return []
	var turns=int(item.get("rotation",0))
	var low=shape_low(item.kind,turns)
	return C.items[item.kind].get("stars",[]).map(func(p):return rotated(Vector2i(int(p[0]),int(p[1])),turns)-low+Vector2i(int(item.get("x",0)),int(item.get("y",0))))

func coverage(bags: Array) -> Array:
	var result: Array=[]
	for bag in bags:
		for v in occupied(bag):
			if v not in result:result.append(v)
	return result

func in_bounds(v: Vector2i) -> bool:
	return v.x>=0 and v.x<WIDTH and v.y>=0 and v.y<HEIGHT

func can_place(item: Dictionary, items: Array, bags: Array) -> bool:
	if not C.items.has(item.get("kind","")) or C.is_tag(item.kind,"bag"):return false
	var taken: Array=[]
	for other in items:
		if other.get("uid","")!=item.get("uid","?"):taken.append_array(occupied(other))
	var cover=coverage(bags)
	var footprint=occupied(item)
	return not footprint.is_empty() and footprint.all(func(v):return in_bounds(v) and v in cover and v not in taken)

func bags_legal(bags: Array) -> bool:
	if bags.is_empty() or bags.size()>10:return false
	var used: Array=[]
	for bag in bags:
		if not C.is_tag(bag.get("kind",""),"bag"):return false
		for v in occupied(bag):
			if not in_bounds(v) or v in used:return false
			used.append(v)
	if used.size()>MAX_CAPACITY:return false
	var reached: Array=[used[0]]
	var at=0
	while at<reached.size():
		for delta in DIRS:
			var next=reached[at]+delta
			if next in used and next not in reached:reached.append(next)
		at+=1
	return reached.size()==used.size()

func can_place_bag(bag: Dictionary, bags: Array, items: Array) -> bool:
	if not C.is_tag(bag.get("kind",""),"bag"):return false
	var proposed=bags.filter(func(v):return v.get("uid","")!=bag.get("uid","?"))
	proposed.append(bag)
	if not bags_legal(proposed):return false
	var cover=coverage(proposed)
	return items.all(func(v):return occupied(v).all(func(cell):return cell in cover))

func first_fit(item: Dictionary, items: Array, bags: Array) -> Dictionary:
	for rotation in range(4):
		for y in range(HEIGHT):
			for x in range(WIDTH):
				var next=item.duplicate(true)
				next.merge({"x":x,"y":y,"rotation":rotation},true)
				if can_place_bag(next,bags,items) if C.is_tag(next.get("kind",""),"bag") else can_place(next,items,bags):return next
	return {}

func element(item: Dictionary, build: Dictionary) -> String:
	if C.is_tag(item.get("kind",""),"weapon"):
		return C.characters[build.leader].element if primary_weapon(build).get("uid","")==item.get("uid","") and C.items[item.kind].weapon_type==C.characters[build.leader].weapon_type else "neutral"
	return C.items.get(item.get("kind",""),{}).get("element","neutral")

func star_links(source: Dictionary, items: Array, build: Dictionary={}) -> Array:
	if not C.items.has(source.get("kind","")):return []
	var result: Array=[]
	var target=C.items[source.kind].get("target","")
	var points=stars(source)
	for item in items:
		if item.get("uid","")==source.get("uid","?"):continue
		var elem=C.items[item.kind].element if build.is_empty() else element(item,build)
		var match_target=C.is_tag(item.kind,target) or elem==target
		# UI can resolve a matching starter without a build context; combat always supplies the build.
		if build.is_empty() and C.is_tag(item.kind,"weapon"):
			match_target=match_target or (target=="aero" and C.items[item.kind].weapon_type=="broadblade") or (target=="electro" and C.items[item.kind].weapon_type=="rectifier")
		if match_target and occupied(item).any(func(v):return v in points):result.append(item)
	return result

func modifiers(item: Dictionary, items: Array, build: Dictionary={}) -> Dictionary:
	var out={"speed":0.0,"damage":0.0,"energy":0.0,"shield":0.0,"crit":0.12,"multiplier":1.0}
	out.speed=.12 if item.get("tuning","")=="fast" else 0.0
	out.multiplier=1.0+.15*int(item.get("level",0))+(.2 if item.get("tuning","")=="strong" else 0.0)
	var sources: Array=[]
	for source in items:
		if source.kind in ["aero_coin","electro_coin"] and source.kind not in sources and star_links(source,items,build).any(func(v):return v.uid==item.uid):
			out.multiplier*=1.12;sources.append(source.kind)
	if C.is_tag(item.kind,"weapon") and items.any(func(v):return v.kind=="maocai"):out.crit+=.12
	if C.is_tag(item.kind,"echo"):
		for source in items:
			if source.kind!="captain_seal" or not adjacent(source,item):continue
			var elements: Array=[]
			for echo in items:
				if C.is_tag(echo.kind,"echo") and adjacent(source,echo):
					var elem=element(echo,build)
					if elem!="neutral" and elem not in elements:elements.append(elem)
			if elements.size()>=3:out.multiplier*=1.1;break
	return out

func adjacent(a: Dictionary,b: Dictionary) -> bool:
	return occupied(a).any(func(v):return occupied(b).any(func(w):return absi(v.x-w.x)+absi(v.y-w.y)==1))

func recipes(_items: Array) -> Array:return []
func fuse(_run: Dictionary) -> int:return 0

func make_piece(kind: String,uid: String) -> Dictionary:
	return {"kind":kind,"uid":uid,"rotation":0,"x":0,"y":0,"level":0,"tuning":""}

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

func new_run(leader: String, seed_value: int) -> Dictionary:
	if not C.characters.has(leader):return {}
	var run={"version":4,"ruleset":C.RULESET,"catalogue_hash":C.catalogue_hash,"leader":leader,"round":1,"wins":0,"losses":0,"gold":9,"seed":seed_value,"serial":2,"phase":"shop","items":[],"stash":[],"shop":[],"history":[],"relay":[],"primary":"i1","refreshes":0,"pending_gifts":[],"pending_rearrange":[],"golden_acquired":false,"roster":[],"supports":[],"recruited_round":0,"bags":[make_piece("satchel","b1")]}
	for entry in [[C.characters[leader].starter,"i1"],["nutrition","i2"]]:
		run.items.append(first_fit(make_piece(entry[0],entry[1]),run.items,run.bags))
	refresh(run)
	return run

func purchased_capacity(run: Dictionary) -> int:
	var total=coverage(run.get("bags",[])).size()
	for item in run.get("stash",[]):
		if C.is_tag(item.get("kind",""),"bag"):total+=cells(item).size()
	return total

func replacement_options(run: Dictionary,kind: String) -> Array:
	var result: Array=[]
	if run.get("phase","")!="shop" or kind not in ["pouch","strip","corner","travel"] or int(run.get("round",1))<int(C.items[kind].round_min):return result
	var total=purchased_capacity(run)
	for bag in run.get("bags",[]):
		var footprint=occupied(bag)
		if run.get("items",[]).any(func(v):return occupied(v).any(func(cell):return cell in footprint)):continue
		if total-footprint.size()+C.items[kind].shape.size()>MAX_CAPACITY:continue
		for rotation in range(4):
			var candidate=make_piece(kind,bag.uid);candidate.x=int(bag.x);candidate.y=int(bag.y);candidate.rotation=rotation
			var bags=run.bags.filter(func(v):return v.uid!=bag.uid)
			bags.append(candidate)
			if bags_legal(bags) and run.items.all(func(v):return can_place(v,run.items,bags)):
				result.append({"bag_uid":bag.uid,"rotation":rotation});break
	return result

func replace_bag(run: Dictionary,target_uid: String,new_kind: String,rotation: int) -> bool:
	if run.get("phase","")!="shop" or new_kind not in ["pouch","strip","corner","travel"] or not bounded_integer(rotation,0,3) or run.get("shop",[]).size()!=6 or run.shop[5].get("kind","")!=new_kind:return false
	if int(run.get("round",1))<int(C.items[new_kind].round_min):return false
	var targets=run.get("bags",[]).filter(func(v):return v.uid==target_uid)
	if targets.size()!=1:return false
	var target=targets[0]
	var footprint=occupied(target)
	if run.items.any(func(v):return occupied(v).any(func(cell):return cell in footprint)):return false
	if purchased_capacity(run)-footprint.size()+C.items[new_kind].shape.size()>MAX_CAPACITY:return false
	var price=maxi(0,int(C.items[new_kind].price)-int(floor(float(C.items[target.kind].price)*.5)))
	if run.gold<price:return false
	var identity=next_identity(run)
	if identity.is_empty():return false
	var next_serial=int(identity.serial);var fresh_uid=identity.uid
	var candidate=make_piece(new_kind,fresh_uid);candidate.x=int(target.x);candidate.y=int(target.y);candidate.rotation=rotation
	var proposed=run.bags.filter(func(v):return v.uid!=target_uid)
	proposed.append(candidate)
	if not bags_legal(proposed) or not run.items.all(func(v):return can_place(v,run.items,proposed)):return false
	# Mutate only after every geometric, ownership, and financial check has passed.
	run.bags=proposed;run.serial=next_serial;run.gold-=price;run.shop[5]={}
	return true

func available_bags(run: Dictionary) -> Array:
	var out: Array=[]
	var total=purchased_capacity(run)
	for kind in ["pouch","strip","corner","travel"]:
		if int(run.get("round",1))>=int(C.items[kind].round_min) and (total+C.items[kind].shape.size()<=MAX_CAPACITY or not replacement_options(run,kind).is_empty()):out.append(kind)
	return out

func set_bag_offer(run: Dictionary,kind: String) -> bool:
	if run.get("phase","")!="shop" or kind not in available_bags(run) or run.shop.size()!=6:return false
	run.shop[5]={"kind":kind,"locked":false}
	return true

func refresh(run: Dictionary, charge: bool=false) -> bool:
	if run.get("phase","")!="shop":return false
	var cost=1 if charge and int(run.get("refreshes",0))>0 else 0
	if int(run.get("gold",0))<cost:return false
	var rng=RandomNumberGenerator.new();rng.seed=int(run.seed)
	var pool=C.items.keys().filter(func(k):return not C.is_tag(k,"bag") and not C.is_tag(k,"keepsake") and shop_eligible(run,k))
	var previous=run.shop.duplicate(true)
	var next: Array=[{},{},{},{},{},{}]
	var seen_consumables: Array=[]
	var seen_golden=false
	for n in range(5):
		if n<previous.size() and previous[n].get("locked",false):
			next[n]=previous[n].duplicate(true)
			if C.is_tag(next[n].kind,"consumable"):seen_consumables.append(next[n].kind)
			if C.is_tag(next[n].kind,"golden"):seen_golden=true
	for n in range(5):
		if not next[n].is_empty():continue
		var weighted: Array=[]
		for kind in pool:
			if C.is_tag(kind,"consumable") and not seen_consumables.is_empty():continue
			if C.is_tag(kind,"golden") and seen_golden:continue
			var def=C.items[kind]
			var match_slot=(n==0 or n==3) and C.is_tag(kind,"weapon") or n==1 and C.is_tag(kind,"echo") or n==2 and not C.is_tag(kind,"weapon") and not C.is_tag(kind,"echo") or n==4
			if not match_slot:continue
			# Three-star/basic options stay useful amid the full armory; expensive five-stars are scarce.
			var weight=4 if C.is_tag(kind,"weapon") and int(def.get("original_rarity",3))<=3 else 2 if int(def.rarity)<=2 else 1
			if n==3 and C.is_tag(kind,"weapon") and def.weapon_type!=C.characters[run.leader].weapon_type:weight*=3
			if def.element==C.characters[run.leader].element:weight*=2
			for _copy in range(weight):weighted.append(kind)
		if weighted.is_empty():continue
		var kind=weighted[rng.randi_range(0,weighted.size()-1)]
		if n==3 and run.has("pending_carrier_type"):
			var carriers=pool.filter(func(k):return C.is_tag(k,"weapon") and C.items[k].weapon_type==run.pending_carrier_type and int(C.items[k].price)<=3)
			carriers.sort()
			if not carriers.is_empty():kind=carriers[rng.randi_range(0,carriers.size()-1)];run.erase("pending_carrier_type")
		if not charge and run.round==1 and n==1:kind={"jiyan":"whiff","yinlin":"violet","verina":"turtle"}[run.leader]
		next[n]={"kind":kind,"locked":false}
		if C.is_tag(kind,"consumable"):seen_consumables.append(kind)
		if C.is_tag(kind,"golden"):seen_golden=true
	if previous.size()==6:
		next[5]=previous[5].duplicate(true)
	else:
		var options=available_bags(run)
		if not options.is_empty():next[5]={"kind":options[0],"locked":false}
	run.gold-=cost
	if charge:run.refreshes=int(run.get("refreshes",0))+1
	run.shop=next;run.seed=int(rng.randi())
	return true

func signature_owned(build: Dictionary,kind: String) -> bool:
	var def=C.items[kind]
	if not def.get("strict_signature",false):return true
	var owners=build.get("roster",[]).duplicate()
	if C.characters.has(build.get("leader","")):owners.append(C.characters[build.leader].roster_id)
	return def.get("signature_owner_ids",[]).any(func(id):return id in owners)

func shop_eligible(run: Dictionary,kind: String) -> bool:
	if not C.items.has(kind):return false
	var def=C.items[kind]
	if not def.get("released",true) or int(run.get("round",1))<int(def.round_min):return false
	if C.is_tag(kind,"golden") and run.get("golden_acquired",false):return false
	if C.is_tag(kind,"weapon"):
		if def.weapon_type not in SUP.unlocked_types(run) or not signature_owned(run,kind):return false
		if def.get("strict_signature",false) and int(run.get("round",1))<4:return false
	return true

func legacy_offer(run: Dictionary,offer: Dictionary) -> bool:
	return run.get("migrated_from",0)==3 and offer.get("legacy_v3",false)==true and legacy_items.has(offer.get("kind","")) and int(run.get("round",1))>=int(legacy_items[offer.kind].round_min)

func recruit(run: Dictionary,role_id: String) -> bool:
	if run.get("phase","")!="shop" or int(run.get("round",1))<2 or not SUP.valid_team(run) or role_id not in SUP.candidates(run) or int(run.get("recruited_round",0))==int(run.round):return false
	if not bounded_integer(run.get("recruited_round",null),0,int(run.round)):return false
	var cost=SUP.price(C.roster[role_id])
	if not bounded_integer(run.get("gold",0),cost,2147483647):return false
	var old_types=SUP.unlocked_types(run)
	run.gold-=cost;run.roster.append(role_id);run.recruited_round=int(run.round)
	if run.supports.size()<SUP.MAX_SUPPORTS:run.supports.append(role_id)
	# Keep all offers and locks intact. The next refresh's expansion slot guarantees a cheap carrier.
	if C.roster[role_id].weapon_type not in old_types:run.pending_carrier_type=C.roster[role_id].weapon_type
	return true

func set_supports(run: Dictionary,ordered_ids: Array) -> bool:
	if run.get("phase","")!="shop":return false
	var proposed=run.duplicate(true);proposed.supports=ordered_ids.duplicate()
	if not SUP.valid_team(proposed):return false
	run.supports=ordered_ids.duplicate();return true

func toggle_lock(run: Dictionary,index: int) -> bool:
	if run.get("phase","")!="shop" or index<0 or index>=5 or run.shop.size()!=6 or run.shop[index].is_empty():return false
	var locked=bool(run.shop[index].get("locked",false))
	if not locked and run.shop.slice(0,5).filter(func(v):return v.get("locked",false)).size()>=2:return false
	run.shop[index].locked=not locked
	return true

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
	return relics<=3 and golden<=1 and revives<=1

func purchase_price(run: Dictionary,index: int) -> int:
	if index<0 or index>=run.get("shop",[]).size() or run.shop[index].is_empty():return 0
	var offer=run.shop[index]
	var price=int(C.items[offer.kind].price)
	if index<5 and bool(offer.get("locked",false)) and run.items.any(func(v):return v.kind=="cheongsam"):price=maxi(1,price-1)
	return price

func buy(run: Dictionary,index: int) -> bool:
	if run.get("phase","")!="shop" or index<0 or index>=6 or run.shop.size()!=6 or run.shop[index].is_empty() or run.stash.size()>=STASH:return false
	var kind=run.shop[index].get("kind","")
	if not C.items.has(kind) or C.is_tag(kind,"keepsake") or (C.is_tag(kind,"golden") and run.get("golden_acquired",false)):return false
	if not C.items[kind].get("released",true) or not (shop_eligible(run,kind) or legacy_offer(run,run.shop[index])):return false
	if C.is_tag(kind,"bag") and (kind not in available_bags(run) or purchased_capacity(run)+C.items[kind].shape.size()>MAX_CAPACITY):return false
	if not bounded_integer(run.get("capacity_refund_round",0),0,int(run.round)):return false
	var price=purchase_price(run,index)
	if run.gold<price or not collection_legal(run.items+run.stash+[make_piece(kind,"purchase")],run.leader):return false
	var identity=next_identity(run)
	if identity.is_empty():return false
	run.gold-=price;run.serial=identity.serial
	run.stash.append(make_piece(kind,identity.uid))
	if index==5 and int(run.get("capacity_refund_round",0))!=int(run.round) and run.items.any(func(v):return v.kind=="field_notes"):
		run.gold+=1;run.capacity_refund_round=int(run.round)
	if C.is_tag(kind,"golden"):run.golden_acquired=true
	run.shop[index]={}
	return true

func find_piece(run: Dictionary,uid: String) -> Dictionary:
	for key in ["items","bags","stash"]:
		for item in run.get(key,[]):
			if item.uid==uid:return item
	return {}

func bag_transaction(run: Dictionary,bag: Dictionary) -> Dictionary:
	var tx={"ok":false,"items":run.get("items",[]).duplicate(true),"bags":run.get("bags",[]).duplicate(true),"stash":run.get("stash",[]).duplicate(true),"error":""}
	if not valid_piece(bag) or not C.is_tag(bag.kind,"bag"):
		tx.error="无效包袋";return tx
	var old=find_piece(run,bag.uid)
	if old.is_empty() or old.kind!=bag.kind:
		tx.error="包袋未购买";return tx
	tx.bags=tx.bags.filter(func(v):return v.uid!=bag.uid)
	tx.bags.append(bag.duplicate(true))
	if not bags_legal(tx.bags):
		tx.error="包袋须连边、不重叠，容量最多30格";return tx
	tx.stash=tx.stash.filter(func(v):return v.uid!=bag.uid)
	if run.bags.any(func(v):return v.uid==bag.uid):
		var old_cells=occupied(old)
		var delta=posmod(int(bag.rotation)-int(old.rotation),4)
		var rotation_low=Vector2i(100,100)
		for v in cells(old):
			var turned=rotated(v,delta)
			rotation_low.x=mini(rotation_low.x,turned.x);rotation_low.y=mini(rotation_low.y,turned.y)
		for item in tx.items.duplicate(true):
			var footprint=occupied(item)
			if not footprint.any(func(v):return v in old_cells):continue
			if not footprint.all(func(v):return v in old_cells):
				tx.items=tx.items.filter(func(v):return v.uid!=item.uid)
				tx.stash.append(item);continue
			var low=Vector2i(100,100)
			for v in footprint:
				var moved=rotated(v-Vector2i(int(old.x),int(old.y)),delta)-rotation_low+Vector2i(int(bag.x),int(bag.y))
				low.x=mini(low.x,moved.x);low.y=mini(low.y,moved.y)
			for live in tx.items:
				if live.uid==item.uid:live.x=low.x;live.y=low.y;live.rotation=posmod(int(live.rotation)+delta,4)
	if tx.stash.size()>STASH:
		tx.error="准备区需要空位";return tx
	for item in tx.items:
		if not can_place(item,tx.items,tx.bags):
			tx.error="包袋移动后的物品发生碰撞";return tx
	tx.ok=true
	return tx

func place(run: Dictionary,item: Dictionary) -> bool:
	if run.get("phase","")!="shop" or not valid_piece(item):return false
	var owned=find_piece(run,item.uid)
	if owned.is_empty() or owned.kind!=item.kind or int(owned.get("level",0))!=int(item.get("level",0)) or owned.get("tuning","")!=item.get("tuning",""):return false
	if C.is_tag(item.kind,"bag"):
		var tx=bag_transaction(run,item)
		if not tx.ok:return false
		run.items=tx.items;run.bags=tx.bags;run.stash=tx.stash
	else:
		if not can_place(item,run.items,run.bags):return false
		run.stash=run.stash.filter(func(v):return v.uid!=item.uid)
		run.items=run.items.filter(func(v):return v.uid!=item.uid)
		run.items.append(item.duplicate(true))
	clean_relay(run);claim_pending(run)
	return true

func stash(run: Dictionary,item: Dictionary) -> bool:
	if run.get("phase","")!="shop" or run.stash.size()>=STASH or C.is_tag(item.get("kind",""),"bag") or not run.items.any(func(v):return v.uid==item.get("uid","")):return false
	var owned=find_piece(run,item.uid).duplicate(true)
	run.items=run.items.filter(func(v):return v.uid!=item.uid)
	run.stash.append(owned)
	clean_relay(run);return true

func sell(run: Dictionary,item: Dictionary) -> bool:
	if run.get("phase","")!="shop":return false
	var owned=find_piece(run,item.get("uid",""))
	if owned.is_empty():return false
	if C.is_tag(owned.kind,"bag"):
		if run.bags.any(func(v):return v.uid==owned.uid):
			if run.items.any(func(v):return occupied(v).any(func(cell):return cell in occupied(owned))):return false
			var remaining=run.bags.filter(func(v):return v.uid!=owned.uid)
			if not bags_legal(remaining):return false
			run.bags=remaining
	run.items=run.items.filter(func(v):return v.uid!=owned.uid)
	run.stash=run.stash.filter(func(v):return v.uid!=owned.uid)
	run.gold+=maxi(0,int(floor(float(C.items[owned.kind].price)*.5)))
	clean_relay(run);claim_pending(run)
	return true

func primary_weapon(build: Dictionary) -> Dictionary:
	var weapons=build.get("items",[]).filter(func(v):return C.is_tag(v.get("kind",""),"weapon"))
	for item in weapons:
		if item.uid==build.get("primary",""):return item
	if C.characters.has(build.get("leader","")):
		for item in weapons:
			if C.items[item.kind].weapon_type==C.characters[build.leader].weapon_type:return item
	return weapons[0] if not weapons.is_empty() else {}

func valid_relay(build: Dictionary,uids: Array) -> bool:
	if uids.is_empty():return true
	if uids.size()<2 or uids.size()>3:return false
	var path: Array=[]
	for uid in uids:
		if not uid is String or uids.count(uid)!=1:return false
		var matches=build.get("items",[]).filter(func(v):return v.uid==uid)
		if matches.size()!=1:return false
		path.append(matches[0])
	if not C.is_tag(path[0].kind,"weapon") or not C.is_tag(path[1].kind,"echo") or not adjacent(path[0],path[1]):return false
	return path.size()==2 or ((C.is_tag(path[2].kind,"relic") or C.is_tag(path[2].kind,"keepsake")) and adjacent(path[1],path[2]))

func set_relay(run: Dictionary,uids: Array) -> bool:
	if run.get("phase","")!="shop" or not valid_relay(run,uids):return false
	run.relay=uids.duplicate();return true

func clean_relay(run: Dictionary) -> void:
	if not valid_relay(run,run.get("relay",[])):run.relay=[]
	if not run.items.any(func(v):return v.uid==run.get("primary","") and C.is_tag(v.kind,"weapon")):run.primary=primary_weapon(run).get("uid","")

func relay_path(build: Dictionary) -> Array:
	var uids=build.get("relay",[])
	if not uids.is_empty() and valid_relay(build,uids):
		return uids.map(func(uid):return build.items.filter(func(v):return v.uid==uid)[0])
	var weapon=primary_weapon(build)
	var echoes=build.get("items",[]).filter(func(v):return C.is_tag(v.kind,"echo"))
	if weapon.is_empty():return []
	if not echoes.is_empty():return [weapon,echoes[0]]
	var outro=weapon.duplicate(true);outro.uid="leader-outro:"+str(build.get("leader",""));outro.leader_outro=true
	return [weapon,outro]

func apply_material(run: Dictionary,material_uid: String,target_uid: String,choice: String) -> bool:
	if run.get("phase","")!="shop" or material_uid==target_uid:return false
	var material=find_piece(run,material_uid);var target=find_piece(run,target_uid)
	if material.is_empty() or target.is_empty() or not C.is_tag(target.kind,"echo"):return false
	if material.kind=="tube":
		if int(target.get("level",0))>=2:return false
		target.level=int(target.get("level",0))+1
	elif material.kind=="tuner":
		if choice not in ["fast","strong"] or not target.get("tuning","").is_empty():return false
		target.tuning=choice
	else:return false
	run.items=run.items.filter(func(v):return v.uid!=material_uid)
	run.stash=run.stash.filter(func(v):return v.uid!=material_uid)
	claim_pending(run);return true

func gift(run: Dictionary,kind: String) -> void:
	if C.is_tag(kind,"keepsake") and (run.items+run.stash+run.get("pending_gifts",[])+run.get("pending_rearrange",[])).any(func(v):return v.kind==kind):return
	var identity=next_identity(run)
	if identity.is_empty():return
	run.serial=identity.serial
	var item=make_piece(kind,identity.uid)
	if run.stash.size()<STASH:run.stash.append(item)
	else:run.pending_gifts.append(item)

func grant_milestones(run: Dictionary,catch_up: bool=false) -> void:
	for kind in C.items:
		var def=C.items[kind]
		if C.is_tag(kind,"keepsake") and def.get("owner","")==run.leader and def.has("gift_round") and (int(def.gift_round)==int(run.round) or (catch_up and int(def.gift_round)<=int(run.round))):gift(run,kind)

func claim_pending(run: Dictionary) -> void:
	for key in ["pending_gifts","pending_rearrange"]:
		if not run.has(key):run[key]=[]
		while run.stash.size()<STASH and not run[key].is_empty():run.stash.append(run[key].pop_front())

func finish(run: Dictionary,winner: int) -> Dictionary:
	if run.get("phase","")!="result" or winner not in [-1,0,1]:return {}
	var used=run.get("combat",{}).get("used",[[],[]])
	if used is Array and used.size()==2 and used[0] is Array:
		run.items=run.items.filter(func(v):return not(C.is_tag(v.kind,"consumable") and v.uid in used[0]))
	if winner==1:run.wins+=1
	else:run.losses+=1
	if run.wins>=6 or run.losses>=3:run.phase="ending"
	else:
		var previous_round=int(run.round)
		run.round+=1;run.gold+=8+(1 if winner==1 else 0);run.phase="shop";run.refreshes=0
		if previous_round<=2:gift(run,"soup" if previous_round==1 else "nutrition")
		if run.round==2:gift(run,C.characters[run.leader].core)
		grant_milestones(run)
		run.shop=[];refresh(run)
	clean_relay(run);claim_pending(run)
	return {"fused":0,"used":used[0] if used is Array and used.size()==2 else []}

func bounded_integer(value: Variant,low: int,high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=low and float(value)<=high and int(value)==value

func valid_piece(item: Variant) -> bool:
	if not item is Dictionary or not C.items.has(item.get("kind","")) or not item.get("uid") is String or item.uid.is_empty() or item.uid.length()>80:return false
	if not C.items[item.kind].get("released",true):return false
	if not bounded_integer(item.get("x",null),0,WIDTH-1) or not bounded_integer(item.get("y",null),0,HEIGHT-1) or not bounded_integer(item.get("rotation",null),0,3):return false
	if not bounded_integer(item.get("level",0),0,2) or not item.get("tuning","") is String or item.get("tuning","") not in ["","fast","strong"]:return false
	if not C.is_tag(item.kind,"echo") and (item.get("level",0)!=0 or item.get("tuning","")!=""):return false
	return true

func validate_ghost(raw: Variant,allow_empty: bool=false) -> bool:
	if not raw is Dictionary or raw.get("version",0)!=4 or raw.get("ruleset","")!=C.RULESET or raw.get("catalogue_hash","")!=C.catalogue_hash or not C.characters.has(raw.get("leader","")) or not raw.get("items") is Array or not raw.get("bags") is Array:return false
	if not raw.has("roster") or not raw.has("supports") or not SUP.valid_team(raw):return false
	if raw.items.size()>MAX_CAPACITY or (raw.items.is_empty() and not allow_empty) or not bounded_integer(raw.get("round",0),1,10):return false
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
	return true

func validate_run(raw: Variant) -> bool:
	if not validate_ghost(raw,true):return false
	if not raw.get("stash") is Array or raw.stash.size()>STASH or not raw.get("shop") is Array or raw.shop.size()!=6 or raw.get("phase","") not in ["shop","battle","result","ending"]:return false
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
		if not raw.get(key,[]) is Array or raw.get(key,[]).size()>64:return false
		for item in raw.get(key,[]):
			if not valid_piece(item) or item.uid in ids:return false
			ids.append(item.uid)
		if key!="stash":owned+=raw.get(key,[])
	if not collection_legal(owned,raw.leader) or (owned.any(func(v):return C.is_tag(v.kind,"golden")) and not raw.get("golden_acquired",false)):return false
	var locks=0;var consumables: Array=[]
	for n in range(6):
		var offer=raw.shop[n]
		if not offer is Dictionary:return false
		if offer.is_empty():continue
		if not C.items.has(offer.get("kind","")) or not offer.get("locked",false) is bool:return false
		if (n==5)!=C.is_tag(offer.kind,"bag") or C.is_tag(offer.kind,"keepsake"):return false
		if not C.items[offer.kind].get("released",true) or (not shop_eligible(raw,offer.kind) and not legacy_offer(raw,offer)):return false
		if offer.get("locked",false):
			if n==5:return false
			locks+=1
		if C.is_tag(offer.kind,"consumable"):
			if not consumables.is_empty():return false
			consumables.append(offer.kind)
	return locks<=2

func snapshot(run: Dictionary,owner: String,name: String="") -> Dictionary:
	var ghost={"version":4,"ruleset":C.RULESET,"catalogue_hash":C.catalogue_hash,"leader":run.leader,"round":run.round,"bags":[],"items":[],"relay":run.get("relay",[]).duplicate(),"primary":primary_weapon(run).get("uid",""),"golden_acquired":bool(run.get("golden_acquired",false)) or run.items.any(func(v):return C.is_tag(v.kind,"golden")),"roster":run.get("roster",[]).duplicate(),"supports":run.get("supports",[]).duplicate(),"owner":owner,"name":name if not name.is_empty() else C.characters[run.leader].name+"的行囊"}
	for key in ["items","bags"]:
		for item in run[key]:
			var clean=make_piece(item.kind,item.uid)
			for field in ["x","y","rotation","level"]:clean[field]=int(item.get(field,0))
			clean.tuning=item.get("tuning","")
			ghost[key].append(clean)
	return ghost

func practice(round_number: int,seed_value: int) -> Dictionary:
	round_number=clampi(round_number,1,10)
	var leader=["jiyan","yinlin","verina"][posmod(round_number+seed_value,3)]
	var run=new_run(leader,seed_value);run.round=round_number;run.items=[]
	if round_number>=2:run.bags.append(make_piece("pouch","b2"));run.bags[-1].x=3
	if round_number>=3:run.bags.append(make_piece("travel","b3"));run.bags[-1].y=2
	if round_number>=5:run.bags.append(make_piece("travel","b4"));run.bags[-1].x=3;run.bags[-1].y=2
	var sets={"jiyan":["w_broadblade","whiff","nutrition","soup","aero_coin","feilian","strategy","verdant","heron","contract"],"yinlin":["w_rectifier","whiff","nutrition","violet","electro_coin","puppet","thundering","variation","stringmaster","contract"],"verina":["w_rectifier","turtle","nutrition","rocksteady","flower","bellborne","rectifier25","heron","contract","w_sword"]}
	var kinds=sets[leader].slice(0,mini(10,2+round_number))
	if round_number>=4:kinds[0]="verdant" if leader=="jiyan" else "stringmaster" if leader=="yinlin" else "rectifier25"
	for n in range(kinds.size()):
		var item=make_piece(kinds[n],"npc"+str(n))
		if C.is_tag(item.kind,"echo"):item.level=mini(2,maxi(0,round_number-3)/2)
		var fitted=first_fit(item,run.items,run.bags)
		if not fitted.is_empty() and collection_legal(run.items+[fitted],leader):run.items.append(fitted)
	run.primary=primary_weapon(run).get("uid","")
	# Training ghosts have the same crew rules as players. Add only carriers that
	# physically fit the existing modules; crew does not modify HP or victory rules.
	if round_number>=2:
		var desired=2 if round_number>=4 else 1
		var pool: Array=[]
		for id in C.roster:
			if C.roster[id].released and C.roster[id].element==C.characters[leader].element and id!=C.characters[leader].roster_id:pool.append(id)
		var ranking="practice:"+str(seed_value)+":"+str(round_number)+":"+leader
		pool.sort_custom(func(a,b):return (ranking+a).sha256_text()<(ranking+b).sha256_text())
		for _slot in range(desired):
			var matching=pool.filter(func(id):return not SUP.carrier(run,id).is_empty())
			var candidates=matching+pool.filter(func(id):return id not in matching)
			for id in candidates:
				var weapon=SUP.carrier(run,id)
				if weapon.is_empty():
					var kind={"sword":"w_sword","pistol":"w_pistol","gauntlet":"w_gauntlet","rectifier":"w_rectifier","broadblade":"w_broadblade"}[C.roster[id].weapon_type]
					weapon=first_fit(make_piece(kind,"npc-carrier-"+str(run.roster.size())),run.items,run.bags)
					if weapon.is_empty():continue
					run.items.append(weapon)
				run.roster.append(id);run.supports.append(id);pool.erase(id);break
		run.recruited_round=3 if run.roster.size()==2 else 2 if run.roster.size()==1 else 0
	var ghost=snapshot(run,"practice","演练 · "+C.characters[leader].name);ghost.source="practice"
	return ghost
