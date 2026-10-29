extends RefCounted
## Craft planning and read models. Legacy validation/identity are narrow adapters
## during this slice; domain queries receive only geometry and projected facts.
const C=preload("res://scripts/data/catalog.gd")
const BOOK=preload("res://scripts/crafting/recipe_book.gd")
const RULES=preload("res://scripts/crafting/craft_rules.gd")
const PLACE=preload("res://scripts/crafting/craft_placement.gd")
const SESSION=preload("res://scripts/run/run_session.gd")
static func rejected(target:String,reason:String,materials:Array=[])->Dictionary:return RULES.rejected(target,reason,materials)
static func eligibility(run:Dictionary,inventory,recipes:Array)->Dictionary:
	var targets:Array=[]
	for recipe in recipes:
		if inventory.craft_unlocked(run,recipe.target):targets.append(recipe.target)
	return {"phase":run.get("phase",""),"targets":targets}
static func recipe_relations(run:Dictionary,inventory,extra:Array=[],display_stash:Variant=null)->Array:
	if run.get("phase","")!="shop":return []
	var stored=run.get("stash",[]) if display_stash==null else display_stash
	var kinds={}
	for item in run.get("items",[])+stored+extra:kinds[item.kind]=true
	var recipes=C.combinations.filter(func(v):return v.materials.size()==1 and kinds.has(v.base) and kinds.has(v.materials[0]))
	return RULES.relations(recipes,eligibility(run,inventory,recipes),run.get("items",[]),stored,extra,inventory.spatial())
static func assess(run: Dictionary,target: String,base_uid: String,inventory,placement: Dictionary={},validated:bool=false,recipe_id:String="") -> Dictionary:
	if not validated and not inventory.validate_run(run):return rejected(target,"存档状态异常")
	if run.phase!="shop":return rejected(target,"当前不可合成")
	var matched=RULES.resolve_inputs(C.combinations,target,base_uid,run.items,run.stash,C.items,inventory.spatial(),recipe_id)
	var materials:Array=matched.materials
	if not inventory.craft_unlocked(run,target):return rejected(target,"当前配方不可用",materials)
	if not matched.ok:return matched
	var base=matched.base;var consumed:Array=matched.consumed
	var identity=inventory.next_identity(run)
	if identity.is_empty():return rejected(target,"物品编号已用尽",materials)
	var remaining=run.items.filter(func(v):return v.uid not in consumed)
	var output=inventory.make_piece(target,identity.uid)
	var estimated=run.items.any(func(v):return v.uid in consumed and v.get("cost_basis","")=="legacy_estimate")
	var mixed=run.items.any(func(v):return v.uid in consumed and v.get("cost_basis","")=="mixed")
	output.cost_basis="mixed" if mixed else "legacy_estimate" if estimated else "actual"
	var credit=run.items.filter(func(v):return v.uid in consumed).reduce(func(total,v):return total+int(v.get("salvage_credit",0)),0)
	if credit>0:output.salvage_credit=credit
	output.paid_cost=run.items.filter(func(v):return v.uid in consumed).reduce(func(total,v):return total+int(v.get("paid_cost",0)),0)
	for field in ["x","y","rotation"]:output[field]=placement.get(field,base[field])
	var destination="board"
	if not placement.is_empty():
		if not placement.has_all(["x","y","rotation"]) or not inventory.valid_piece(output) or not inventory.can_place(output,remaining,run.bags):
			var invalid=rejected(target,"此处放不下成品",materials)
			invalid.output=output;invalid.consumed=consumed;invalid.recipe_id=matched.recipe_id;return invalid
	else:
		var landing=PLACE.automatic(output,remaining,run.bags,run.stash.size(),inventory.spatial())
		output=landing.output;destination=landing.destination
	# These are output-specific validity facts, not a simulated full transaction.
	if not inventory.valid_piece(output) or not inventory.collection_legal(remaining+[output]+run.stash+run.get("pending_gifts",[])+run.get("pending_rearrange",[]),run.leader):return rejected(target,"成品无法合法入匣",materials)
	var before=run.items.filter(func(v):return v.uid in consumed).reduce(func(total,v):return total+inventory.cells(v).size(),0)
	var result={"ok":true,"target":target,"recipe_id":matched.recipe_id,"reason":"可以锻造","materials":materials,"consumed":consumed,"output":output,"saved_cells":before-inventory.cells(output).size(),"serial":identity.serial}
	if destination=="stash":result.destination="stash";result.stash_index=run.stash.size()
	return result

static func plan(run:Dictionary,target:String,base_uid:String,inventory,placement:Dictionary={},recipe_id:String="")->Dictionary:
	var result=assess(run,target,base_uid,inventory,placement,false,recipe_id)
	if not result.ok:return result
	var next=run.duplicate(true)
	next.items=next.items.filter(func(v):return v.uid not in result.consumed)
	if result.get("destination","board")=="stash":next.stash.append(result.output.duplicate(true))
	else:next.items.append(result.output.duplicate(true))
	next.serial=result.serial
	if C.is_tag(target,"golden"):next.golden_acquired=true
	if run.get("primary","") in result.consumed and C.is_tag(target,"weapon"):next.primary=result.output.uid
	inventory.clean_relay(next)
	preload("res://scripts/party/recruitment.gd").after_craft(inventory,run,next,result.consumed,result.output)
	if not inventory.validate_run(next):return rejected(target,"成品无法合法入匣",result.materials)
	result.erase("serial");result.run=next;result.source=SESSION.stamp(run)
	result.crew_rewards=(next.items+next.stash).filter(func(v):return v.uid!=result.output.uid and not (run.items+run.stash).any(func(p):return p.uid==v.uid)).duplicate(true)
	result.changes={"consumed":run.items.filter(func(v):return v.uid in result.consumed).duplicate(true),"created":[result.output.duplicate(true)]+result.crew_rewards}
	return result

static func relationships(run:Dictionary,inventory,extra:Array=[],display_stash:Variant=null)->Array:
	var facts=recipe_relations(run,inventory,extra,display_stash);var result:Array=[];var assessments={}
	var valid=inventory.validate_run(run) if facts.any(func(v):return v.adjacent) else false
	for fact in facts:
		# Stable compatibility shape; relationship identity never depends on capacity.
		var relation={"target":fact.target,"recipe_id":fact.recipe_id,"base_uid":fact.base_uid,"material_uid":fact.material_uid,"uids":fact.uids,"ready":false,"adjacent":fact.adjacent,"output":{},"blocked":[],"valid":[]}
		if valid and fact.adjacent:
			var key=JSON.stringify([fact.recipe_id,fact.target,fact.base_uid])
			if not assessments.has(key):assessments[key]=assess(run,fact.target,fact.base_uid,inventory,{},true,fact.recipe_id)
			var status=assessments[key]
			relation.ready=status.ok and fact.base_uid in status.consumed and fact.material_uid in status.consumed
			if relation.ready:
				relation.output=status.output
				if status.get("destination","")=="stash":relation.destination="stash";relation.stash_index=status.stash_index
			else:
				var base=run.items.filter(func(v):return v.uid==fact.base_uid)[0]
				var blocked=assess(run,fact.target,fact.base_uid,inventory,{"x":base.x,"y":base.y,"rotation":base.rotation},true,fact.recipe_id)
				if fact.base_uid in blocked.consumed and fact.material_uid in blocked.consumed and blocked.has("output"):
					relation.output=blocked.output
					var remaining=run.items.filter(func(v):return v.uid not in blocked.consumed)
					var footprint=PLACE.footprint(blocked.output,remaining,run.bags,inventory.spatial())
					relation.blocked=footprint.blocked;relation.valid=footprint.valid
		result.append(relation)
	return result

# Ownership is derived from the live state, independently of dry drag placement.
static func guidance(live:Dictionary,projected:Dictionary,held:Dictionary,held_uid:String,offer_index:int,inventory,visible_stash_uids:Variant=null)->Dictionary:
	var state=projected;var extra:Array=[];var nodes={}
	var owned_ids=(live.items+live.stash).map(func(v):return v.uid)
	if not held.is_empty() and held_uid not in (state.items+state.stash).map(func(v):return v.uid):extra.append(held.duplicate(true))
	for item in state.items:nodes[item.uid]={"piece":item.duplicate(true),"origin":"board","owned":item.uid in owned_ids}
	var displayed:Array=[]
	for n in state.stash.size():
		var item=state.stash[n]
		if visible_stash_uids!=null and item.uid not in visible_stash_uids and item.uid!=held_uid:continue
		displayed.append(item)
		nodes[item.uid]={"piece":item.duplicate(true),"origin":"stash","index":n,"owned":item.uid in owned_ids}
	for item in extra:nodes[item.uid]={"piece":item.duplicate(true),"origin":"held","owned":item.uid in owned_ids}
	for n in state.shop.size():
		if state.shop[n].is_empty() or n==offer_index:continue
		var offer={"kind":state.shop[n].kind,"uid":"offer:"+str(n)}
		extra.append(offer);nodes[offer.uid]={"piece":offer,"origin":"shop","index":n,"owned":false}
	var relations=relationships(state,inventory,extra,displayed)
	for relation in relations:
		var a=nodes[relation.base_uid];var b=nodes[relation.material_uid]
		# Relations contain the two distinct exact inputs of a complete recipe.
		# Live ownership is independent of adjacency, destination space or dry purchases.
		relation.materials_complete=a.owned and b.owned
		relation.ready=relation.ready and a.owned and b.owned
	# Shop hints query types without expanding every stored duplicate pair.
	# Representative counts follow actual per-recipe requirements, including same-kind inputs.
	var required={}
	for recipe in C.combinations:
		for kind in [recipe.base]+recipe.materials:
			required[kind]=maxi(int(required.get(kind,0)),recipe.materials.count(kind)+(1 if recipe.base==kind else 0))
	var sample:Array=[];var counts={};var offers={};var matching:Array=[]
	for uid in nodes:
		if nodes[uid].origin=="shop":offers[uid]=nodes[uid].index
	if not offers.is_empty():
		for item in state.stash:
			if int(counts.get(item.kind,0))>=int(required.get(item.kind,0)):continue
			counts[item.kind]=int(counts.get(item.kind,0))+1;sample.append(item)
		for fact in recipe_relations(state,inventory,extra,sample):
			for uid in fact.uids:
				if offers.has(uid) and offers[uid] not in matching:matching.append(offers[uid])
	return {"relations":relations,"nodes":nodes,"held_uid":held_uid,"matching_offers":matching}

static func material_status(run: Dictionary,target: String,base_uid: String,inventory,recipe_id:String="") -> Array:
	var selected=RULES.resolve_inputs(C.combinations,target,base_uid,run.get("items",[]),run.get("stash",[]),C.items,inventory.spatial(),recipe_id)
	var bases=run.get("items",[]).filter(func(v):return v.uid==base_uid)
	var base={} if bases.is_empty() else bases[0]
	var result: Array=[];var kinds: Array=[]
	for kind in selected.materials:
		if kind in kinds:continue
		kinds.append(kind)
		var equipped=run.get("items",[]).filter(func(v):return v.kind==kind and v.uid!=base_uid)
		var stored=run.get("stash",[]).filter(func(v):return v.kind==kind)
		var near=equipped.filter(func(v):return not base.is_empty() and inventory.adjacent(base,v))
		result.append({"kind":kind,"required":selected.materials.count(kind),"owned":equipped.size()+stored.size(),"near":near.size(),"stash":stored.size(),"board":equipped.size(),"price":int(C.items[kind].price)})
	return result

static func material_plan(run: Dictionary,target: String,base_uid: String,kind: String,inventory,recipe_id:String="") -> Dictionary:
	if not inventory.validate_run(run) or run.phase!="shop":return {"ok":false,"reason":"当前不可摆放"}
	var bases=run.items.filter(func(v):return v.uid==base_uid)
	if bases.size()!=1:return {"ok":false,"reason":"先选择物品和成品"}
	# Legacy callers already specify the desired material; it can identify an
	# alternative before that material is adjacent to the base.
	var candidates=C.combinations if not recipe_id.is_empty() else C.combinations.filter(func(v):return kind in v.materials)
	var selected=RULES.resolve_inputs(candidates,target,base_uid,run.items,run.stash,C.items,inventory.spatial(),recipe_id)
	var recipes=BOOK.for_target(C.combinations,target,str(selected.get("recipe_id","")))
	if recipes.size()!=1:return {"ok":false,"reason":"先选择物品和成品"}
	var base=bases[0];var recipe=recipes[0]
	if not BOOK.accepts_base(recipe,base.kind) or kind not in selected.materials:
		return {"ok":false,"reason":"该材料不属于当前配方"}
	var row=material_status(run,target,base_uid,inventory,recipe.id).filter(func(v):return v.kind==kind)[0]
	if row.near>=row.required:return {"ok":false,"reason":"材料已在物品旁"}
	var pieces=(run.stash+run.items).filter(func(v):return v.kind==kind and v.uid!=base_uid and not run.items.any(func(p):return p.uid==v.uid and inventory.adjacent(base,p)))
	var space=inventory.spatial();var base_cells=space.occupied(base)
	for item in pieces:
		var area=space.placement_area(item,run.items,run.bags)
		for rotation in range(4):
			var turned=item.duplicate(true);turned.rotation=rotation
			var local=space.cells(turned)
			for y in range(inventory.HEIGHT):
				for x in range(inventory.WIDTH):
					var offset=Vector2i(x,y);var footprint=local.map(func(v):return v+offset)
					if not space.adjacent_cells(base_cells,footprint) or not space.fits_cells(footprint,area):continue
					var moved=item.duplicate(true);moved.merge({"x":x,"y":y,"rotation":rotation},true)
					var next=run.duplicate(true)
					if not inventory.place(next,moved) or not inventory.validate_run(next):continue
					return {"ok":true,"recipe_id":recipe.id,"item":moved,"reason":"材料已放到物品旁","run":next,"source":SESSION.stamp(run)}
	return {"ok":false,"reason":"相邻处无空位" if not pieces.is_empty() else "先购买材料"}


# One offered ingredient + actual owned partners, independent of displayed pages.
# Reuse recipe facts/eligibility. One representative per stored kind is enough
# for the current two-input relationship query and avoids an unbounded cross product.
static func shop_partners(run:Dictionary,index:int,inventory)->Array:
	if index<0 or index>=run.get("shop",[]).size() or run.shop[index].is_empty():return []
	var offer={"kind":run.shop[index].kind,"uid":"offer:"+str(index)}
	var sample=[];var kinds={};var by_uid={}
	for item in run.items:by_uid[item.uid]=item
	for item in run.stash:
		if kinds.has(item.kind):continue
		kinds[item.kind]=true;sample.append(item);by_uid[item.uid]=item
	var result=[];var seen={}
	for relation in recipe_relations(run,inventory,[offer],sample):
		if offer.uid not in relation.uids:continue
		var uid=relation.material_uid if relation.base_uid==offer.uid else relation.base_uid
		if not by_uid.has(uid) or seen.has(by_uid[uid].kind):continue
		seen[by_uid[uid].kind]=true;result.append(by_uid[uid].duplicate(true))
	return result
