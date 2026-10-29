extends RefCounted
## Pure operation planning. Mutating helpers receive only isolated candidates.
## Inventory supplies shared geometry, identity and validation adapters.
const ECONOMY=preload("res://scripts/shop/economy.gd")
const C=preload("res://scripts/data/catalog.gd")
const ROUND_RULES=preload("res://scripts/run/round_rules.gd")

static func purchased_capacity(inv,run: Dictionary) -> int:
	var total=inv.coverage(run.get("bags",[])).size()
	for item in run.get("stash",[]):
		if C.is_tag(item.get("kind",""),"bag"):total+=inv.cells(item).size()
	return total

static func replacement_options(inv,run: Dictionary,kind: String) -> Array:
	var result: Array=[]
	if run.get("phase","")!="shop" or not inv.shop_eligible(run,kind) or not C.is_tag(kind,"bag"):return result
	var total=purchased_capacity(inv,run)
	for bag in run.get("bags",[]):
		var footprint=inv.occupied(bag)
		if run.get("items",[]).any(func(v):return inv.occupied(v).any(func(cell):return cell in footprint)):continue
		if total-footprint.size()+C.items[kind].shape.size()>inv.MAX_CAPACITY:continue
		for rotation in range(4):
			var candidate=inv.make_piece(kind,bag.uid);candidate.x=int(bag.x);candidate.y=int(bag.y);candidate.rotation=rotation
			var bags=run.bags.filter(func(v):return v.uid!=bag.uid)
			bags.append(candidate)
			if inv.bags_legal(bags) and run.items.all(func(v):return inv.can_place(v,run.items,bags)):
				result.append({"bag_uid":bag.uid,"rotation":rotation});break
	return result

static func resale_value(inv,piece:Dictionary)->int:
	return ECONOMY.resale(piece)

static func replacement_quote(inv,run:Dictionary,target_uid:String,new_kind:String)->Dictionary:
	var target=inv.find_piece(run,target_uid)
	if target.is_empty() or not C.is_tag(target.kind,"bag") or not C.items.has(new_kind):return {}
	var refund=resale_value(inv,target)
	return {"refund":refund,"price":maxi(0,int(C.items[new_kind].price)-refund),"cashback":maxi(0,refund-int(C.items[new_kind].price))}

static func _apply_replace_bag(inv,run: Dictionary,target_uid: String,new_kind: String,rotation: int) -> bool:
	if run.get("phase","")!="shop" or not inv.shop_eligible(run,new_kind) or not C.is_tag(new_kind,"bag") or not inv.bounded_integer(rotation,0,3) or run.get("shop",[]).size()!=6 or run.shop[5].get("kind","")!=new_kind:return false
	if int(run.get("round",1))<inv.offer_round(new_kind):return false
	var targets=run.get("bags",[]).filter(func(v):return v.uid==target_uid)
	if targets.size()!=1:return false
	var target=targets[0]
	var footprint=inv.occupied(target)
	if run.items.any(func(v):return inv.occupied(v).any(func(cell):return cell in footprint)):return false
	if purchased_capacity(inv,run)-footprint.size()+C.items[new_kind].shape.size()>inv.MAX_CAPACITY:return false
	var quote=replacement_quote(inv,run,target_uid,new_kind)
	var price=int(quote.price)
	if run.gold<price:return false
	var identity=inv.next_identity(run)
	if identity.is_empty():return false
	var next_serial=int(identity.serial);var fresh_uid=identity.uid
	var candidate=inv.make_piece(new_kind,fresh_uid);candidate.paid_cost=int(C.items[new_kind].price);candidate.cost_basis="actual";candidate.x=int(target.x);candidate.y=int(target.y);candidate.rotation=rotation
	var proposed=run.bags.filter(func(v):return v.uid!=target_uid)
	proposed.append(candidate)
	if not inv.bags_legal(proposed) or not run.items.all(func(v):return inv.can_place(v,run.items,proposed)):return false
	# Mutate only after every geometric, ownership, and financial check has passed.
	run.bags=proposed;run.serial=next_serial;run.gold+=int(quote.cashback)-price;run.shop[5]={}
	return true

static func available_bags(inv,run: Dictionary) -> Array:
	var out: Array=[]
	var total=purchased_capacity(inv,run)
	for kind in preload("res://scripts/shop/shop_actions.gd").bag_kinds(run):
		if int(run.get("round",1))>=inv.offer_round(kind) and (total+C.items[kind].shape.size()<=inv.MAX_CAPACITY or not replacement_options(inv,run,kind).is_empty()):out.append(kind)
	return out

static func purchase_price(inv,run: Dictionary,index: int) -> int:
	if index<0 or index>=run.get("shop",[]).size() or run.shop[index].is_empty():return 0
	var offer=run.shop[index]
	var price=int(offer.get("bundle_price",C.items[offer.kind].price))
	return price

static func _apply_buy(inv,run: Dictionary,index: int) -> bool:
	return _apply_buy_to_stash(inv,run,index)

# Purchase and placement commit together. Storage has no gameplay item limit.
static func _apply_purchase_at(inv,run: Dictionary,index: int,preview: Dictionary,destination: String) -> Dictionary:
	if destination not in ["board","stash"]:return {}
	preview=preview.duplicate(true)
	if destination=="stash":preview.x=0;preview.y=0
	if not inv.valid_piece(preview):return {}
	if index<0 or index>=run.get("shop",[]).size() or run.shop[index].get("kind","")!=preview.kind:return {}
	var tx=run.duplicate(true)
	if not _apply_buy_to_stash(inv,tx,index):return {}
	var bundle=run.shop[index].has("bundle")
	var purchased_index=tx.stash.size()-(2 if bundle else 1)
	var purchased=tx.stash[purchased_index].duplicate(true)
	purchased.rotation=preview.rotation
	if destination=="board":
		purchased.x=preview.x;purchased.y=preview.y
		if not _apply_place(inv,tx,purchased):return {}
	else:tx.stash[purchased_index]=purchased
	run.merge(tx,true)
	return purchased

# Preview executes the same transaction on an isolated snapshot, including
# purchase identity, price, displaced ownership, relay cleanup and pending gifts.
static func placement_preview(inv,run: Dictionary,piece: Dictionary,shop_index: int=-1) -> Dictionary:
	var tx=run.duplicate(true)
	var result={"ok":false,"run":tx,"piece":{},"displaced":[],"error":""}
	if shop_index>=0:
		result.piece=_apply_purchase_at(inv,tx,shop_index,piece,"board")
		result.ok=not result.piece.is_empty()
	else:
		result.ok=_apply_place(inv,tx,piece)
		if result.ok:result.piece=inv.find_piece(tx,piece.uid).duplicate(true)
	if result.ok:
		for original in run.get("items",[]):
			if not tx.items.any(func(v):return v.uid==original.uid) and tx.stash.any(func(v):return v.uid==original.uid):
				result.displaced.append(original.duplicate(true))
		return result
	result.error="无法购买或放置"
	if not inv.valid_piece(piece):result.error="无效物品";return result
	if run.get("phase","")!="shop":result.error="当前无法整理";return result
	# Diagnose the same failed transaction without exposing a partially purchased
	# snapshot. The real input and result.run remain unchanged on every rejection.
	var diagnostic=run.duplicate(true)
	var candidate=piece.duplicate(true)
	if shop_index>=0:
		if shop_index>=run.get("shop",[]).size() or run.shop[shop_index].get("kind","")!=piece.kind:return result
		if int(run.gold)<purchase_price(inv,run,shop_index):result.error="金币不足";return result
		if not _apply_buy_to_stash(inv,diagnostic,shop_index):return result
		candidate=diagnostic.stash[-1].duplicate(true)
		candidate.merge({"x":piece.x,"y":piece.y,"rotation":piece.rotation},true)
	var proposal=bag_transaction(inv,diagnostic,candidate) if C.is_tag(candidate.kind,"bag") else _item_transaction(inv,diagnostic,candidate)
	if not proposal.ok:result.error=proposal.error
	return result

static func _apply_buy_to_stash(inv,run: Dictionary,index: int) -> bool:
	if run.get("phase","")!="shop" or index<0 or index>=6 or run.shop.size()!=6 or run.shop[index].is_empty():return false
	var kind=run.shop[index].get("kind","")
	if run.shop[index].has("bundle"):
		var offer=run.shop[index];var kinds=offer.bundle;var price=int(offer.bundle_price)
		if not kinds is Array or kinds.size()!=2 or kinds[0]==kinds[1] or kinds[0]!=kind or not kinds.all(func(k):return inv.shop_eligible(run,k)) or int(run.gold)<price or int(run.serial)>inv.MAX_SERIAL-2:return false
		var total=int(C.items[kinds[0]].price)+int(C.items[kinds[1]].price)
		if price!=int(ceil(total*.8)):return false
		var paid=0
		for n in 2:
			var id=inv.next_identity(run)
			if id.is_empty():return false
			run.serial=id.serial
			var piece=inv.make_piece(kinds[n],id.uid);piece.paid_cost=int(floor(price*float(C.items[kinds[n]].price)/total)) if n==0 else price-paid;piece.cost_basis="actual";paid+=piece.paid_cost;run.stash.append(piece)
		run.gold-=price;run.shop[index]={};return true
	if not C.items.has(kind) or C.is_tag(kind,"keepsake"):return false
	if (not C.items[kind].get("released",true) and not C.items[kind].get("demo_available",false)) or not (inv.shop_eligible(run,kind) or inv.legacy_offer(run,run.shop[index])):return false
	if C.is_tag(kind,"bag") and (kind not in available_bags(inv,run) or purchased_capacity(inv,run)+C.items[kind].shape.size()>inv.MAX_CAPACITY):return false
	if not inv.bounded_integer(run.get("capacity_refund_round",0),0,int(run.round)):return false
	var price=purchase_price(inv,run,index)
	if run.gold<price or not inv.collection_legal(run.items+run.stash+[inv.make_piece(kind,"purchase")],run.leader):return false
	var identity=inv.next_identity(run)
	if identity.is_empty():return false
	run.gold-=price;run.serial=identity.serial
	var purchased=inv.make_piece(kind,identity.uid);purchased.paid_cost=price;purchased.cost_basis="actual"
	run.stash.append(purchased)
	if C.is_tag(kind,"golden"):run.golden_acquired=true
	run.shop[index]={}
	return true

static func bag_transaction(inv,run: Dictionary,bag: Dictionary) -> Dictionary:
	var tx={"ok":false,"items":run.get("items",[]).duplicate(true),"bags":run.get("bags",[]).duplicate(true),"stash":run.get("stash",[]).duplicate(true),"error":""}
	if not inv.valid_piece(bag) or not C.is_tag(bag.kind,"bag"):
		tx.error="无效包袋";return tx
	var old=inv.find_piece(run,bag.uid)
	if old.is_empty() or old.kind!=bag.kind:
		tx.error="包袋未购买";return tx
	if run.bags.any(func(v):return v.uid==bag.uid) and int(old.x)==int(bag.x) and int(old.y)==int(bag.y) and int(old.rotation)==int(bag.rotation):
		tx.ok=true;return tx
	var crossing: Array=[]
	tx.bags=tx.bags.filter(func(v):return v.uid!=bag.uid)
	var placed_bag=old.duplicate(true)
	placed_bag.merge({"x":bag.x,"y":bag.y,"rotation":bag.rotation},true)
	tx.bags.append(placed_bag)
	tx.stash=tx.stash.filter(func(v):return v.uid!=bag.uid)
	if run.bags.any(func(v):return v.uid==bag.uid):
		var old_cells=inv.occupied(old)
		var delta=posmod(int(bag.rotation)-int(old.rotation),4)
		var rotation_low=Vector2i(100,100)
		for v in inv.cells(old):
			var turned=inv.rotated(v,delta)
			rotation_low.x=mini(rotation_low.x,turned.x);rotation_low.y=mini(rotation_low.y,turned.y)
		for item in tx.items.duplicate(true):
			var footprint=inv.occupied(item)
			if not footprint.any(func(v):return v in old_cells):continue
			if not footprint.all(func(v):return v in old_cells):
				crossing.append(item);continue
			var low=Vector2i(100,100)
			for v in footprint:
				var moved=inv.rotated(v-Vector2i(int(old.x),int(old.y)),delta)-rotation_low+Vector2i(int(bag.x),int(bag.y))
				low.x=mini(low.x,moved.x);low.y=mini(low.y,moved.y)
			for live in tx.items:
				if live.uid==item.uid:live.x=low.x;live.y=low.y;live.rotation=posmod(int(live.rotation)+delta,4)
	if not inv.bags_legal(tx.bags):
		tx.error="包袋重叠或超出格盘";return tx
	for item in crossing:
		if not inv.can_place(item,tx.items,tx.bags):
			tx.items=tx.items.filter(func(v):return v.uid!=item.uid)
			tx.stash.append(item)
	for item in tx.items:
		if not inv.can_place(item,tx.items,tx.bags):
			tx.error="包袋移动后的物品发生碰撞";return tx
	tx.ok=true
	return tx

static func _item_transaction(inv,run: Dictionary,item: Dictionary) -> Dictionary:
	var tx={"ok":false,"items":[],"stash":[],"error":""}
	if not inv.valid_piece(item) or C.is_tag(item.kind,"bag"):
		tx.error="无效物品";return tx
	var owned=inv.find_piece(run,item.uid)
	if owned.is_empty() or owned.kind!=item.kind or int(owned.get("level",0))!=int(item.get("level",0)) or owned.get("tuning","")!=item.get("tuning",""):
		tx.error="物品未购买或已变化";return tx
	# Keep can_place strict for validators, crafting and automatic fitting. An
	# explicit item drop may displace occupants only after full coverage is valid.
	if not inv.can_place(item,[],run.bags):
		tx.error="物品超出已购格组";return tx
	tx.stash=run.stash.filter(func(v):return v.uid!=item.uid).duplicate(true)
	var footprint=inv.occupied(item)
	for other in run.items:
		if other.uid==item.uid:continue
		if inv.occupied(other).any(func(cell):return cell in footprint):tx.stash.append(other.duplicate(true))
		else:tx.items.append(other.duplicate(true))
	var placed=owned.duplicate(true)
	placed.merge({"x":item.x,"y":item.y,"rotation":item.rotation},true)
	tx.items.append(placed)
	tx.ok=true
	return tx

static func _apply_place(inv,run: Dictionary,item: Dictionary) -> bool:
	if run.get("phase","")!="shop" or not inv.valid_piece(item):return false
	var owned=inv.find_piece(run,item.uid)
	if owned.is_empty() or owned.kind!=item.kind or int(owned.get("level",0))!=int(item.get("level",0)) or owned.get("tuning","")!=item.get("tuning",""):return false
	if C.is_tag(item.kind,"bag"):
		var tx=bag_transaction(inv,run,item)
		if not tx.ok:return false
		run.items=tx.items;run.bags=tx.bags;run.stash=tx.stash
	else:
		var tx=_item_transaction(inv,run,item)
		if not tx.ok:return false
		run.items=tx.items;run.stash=tx.stash
	inv.clean_relay(run);ROUND_RULES._apply_claim_pending(inv,run)
	return true

# Storing a bag removes its coverage atomically. Every item losing even one
# covered cell travels whole to its own slot, including cross-bag equipment.
static func stash_preview(inv,run: Dictionary,item: Dictionary) -> Dictionary:
	var result={"ok":false,"run":run.duplicate(true),"piece":{},"displaced":[],"error":""}
	if run.get("phase","")!="shop" or not inv.validate_run(run):
		result.error="当前无法整理";return result
	var owned=inv.find_piece(run,str(item.get("uid","")))
	if owned.is_empty() or not (run.items+run.bags).any(func(v):return v.uid==owned.uid):
		result.error="物品未放入";return result
	var proposed=item.duplicate(true);proposed.x=owned.x;proposed.y=owned.y
	if not inv.valid_piece(proposed) or proposed.kind!=owned.kind or int(proposed.get("level",0))!=int(owned.get("level",0)) or proposed.get("tuning","")!=owned.get("tuning",""):
		result.error="物品未购买或已变化";return result
	var next=run.duplicate(true)
	var stored=owned.duplicate(true);stored.rotation=proposed.rotation
	next.stash.append(stored)
	if C.is_tag(owned.kind,"bag"):
		next.bags=next.bags.filter(func(v):return v.uid!=owned.uid)
		var cover=inv.coverage(next.bags)
		for piece in run.items:
			if inv.occupied(piece).all(func(cell):return cell in cover):continue
			next.items=next.items.filter(func(v):return v.uid!=piece.uid)
			next.stash.append(piece.duplicate(true))
			result.displaced.append(piece.duplicate(true))
	else:next.items=next.items.filter(func(v):return v.uid!=owned.uid)
	inv.clean_relay(next)
	if not inv.validate_run(next):
		result.displaced=[];result.error="无法收纳";return result
	result.ok=true;result.run=next;result.piece=stored
	return result

static func _apply_sell(inv,run: Dictionary,item: Dictionary) -> bool:
	if run.get("phase","")!="shop":return false
	var owned=inv.find_piece(run,item.get("uid",""))
	if owned.is_empty():return false
	if C.is_tag(owned.kind,"bag"):
		if run.bags.any(func(v):return v.uid==owned.uid):
			if run.items.any(func(v):return inv.occupied(v).any(func(cell):return cell in inv.occupied(owned))):return false
			var remaining=run.bags.filter(func(v):return v.uid!=owned.uid)
			if not inv.bags_legal(remaining):return false
			run.bags=remaining
	run.items=run.items.filter(func(v):return v.uid!=owned.uid)
	run.stash=run.stash.filter(func(v):return v.uid!=owned.uid)
	run.gold+=resale_value(inv,owned)
	inv.clean_relay(run);ROUND_RULES._apply_claim_pending(inv,run)
	return true

static func plan_replace_bag(inv,run: Dictionary,target_uid: String,new_kind: String,rotation: int) -> Dictionary:
	var next=run.duplicate(true)
	var value=_apply_replace_bag(inv,next,target_uid,new_kind,rotation)
	return inv.operation_plan(run,next,value,value)

static func plan_buy(inv,run: Dictionary,index: int) -> Dictionary:
	var next=run.duplicate(true)
	var value=_apply_buy(inv,next,index)
	return inv.operation_plan(run,next,value,value)

static func plan_purchase_at(inv,run: Dictionary,index: int,preview: Dictionary,destination: String) -> Dictionary:
	var next=run.duplicate(true)
	var value=_apply_purchase_at(inv,next,index,preview,destination)
	return inv.operation_plan(run,next,value,not value.is_empty())

static func plan_place(inv,run: Dictionary,item: Dictionary) -> Dictionary:
	var result=placement_preview(inv,run,item)
	result.source=inv.operation_stamp(run)
	result.value=bool(result.ok)
	return result

static func plan_stash(inv,run: Dictionary,item: Dictionary) -> Dictionary:
	var result=stash_preview(inv,run,item)
	result.source=inv.operation_stamp(run)
	result.value=bool(result.ok)
	return result

static func plan_sell(inv,run: Dictionary,item: Dictionary) -> Dictionary:
	var next=run.duplicate(true)
	var value=_apply_sell(inv,next,item)
	return inv.operation_plan(run,next,value,value)

