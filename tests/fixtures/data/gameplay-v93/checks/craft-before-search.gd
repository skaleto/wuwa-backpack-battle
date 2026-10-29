extends RefCounted
## Compatibility entry points for existing callers; no authoritative rule copies.
const C=preload("res://scripts/data/catalog.gd")
const BOOK=preload("res://scripts/crafting/recipe_book.gd")
const RULES=preload("res://scripts/crafting/craft_rules.gd")
const HANDLER=preload("res://tests/fixtures/data/gameplay-v93/checks/craft-handler-before-search.gd")
const PLACE=preload("res://tests/fixtures/data/gameplay-v93/before/scripts/craft_placement.gd")
const SESSION=preload("res://scripts/run/run_session.gd")
static func accepts_base(recipe:Dictionary,kind:String)->bool:return BOOK.accepts_base(recipe,kind)
static func rejected(target:String,reason:String,materials:Array=[])->Dictionary:return RULES.rejected(target,reason,materials)
static func recipe_relations(run:Dictionary,inventory,extra:Array=[])->Array:return HANDLER.recipe_relations(run,inventory,extra)
static func relationships(run:Dictionary,inventory,extra:Array=[])->Array:return HANDLER.relationships(run,inventory,extra)
static func preview(run:Dictionary,target:String,base_uid:String,inventory,placement:Dictionary={})->Dictionary:return HANDLER.plan(run,target,base_uid,inventory,placement)
static func nearest_fit(piece:Dictionary,items:Array,bags:Array,inventory)->Dictionary:return PLACE.nearest_fit(piece,items,bags,inventory.spatial())
static func material_status(run:Dictionary,target:String,base_uid:String,inventory)->Array:return HANDLER.material_status(run,target,base_uid,inventory)
static func place_material(run:Dictionary,target:String,base_uid:String,kind:String,inventory,persist:Callable=Callable())->Dictionary:
	return SESSION.commit(run,HANDLER.material_plan(run,target,base_uid,kind,inventory),inventory.validate_run,persist)
static func transact(run:Dictionary,target:String,base_uid:String,inventory,placement:Dictionary={},persist:Callable=Callable())->Dictionary:
	return SESSION.commit(run,preview(run,target,base_uid,inventory,placement),inventory.validate_run,persist)
static func guidance(live:Dictionary,projected:Dictionary,held:Dictionary,held_uid:String,offer_index:int,inventory)->Dictionary:
	return HANDLER.guidance(live,projected,held,held_uid,offer_index,inventory)
static func pair_recipes(run:Dictionary,a:Dictionary,b:Dictionary,inventory)->Array:
	if run.get("phase","")!="shop" or a.get("uid","")==b.get("uid","") or a.get("uid","").is_empty() or b.get("uid","").is_empty():return []
	var result:Array=[]
	for recipe in BOOK.pairs(C.combinations,a.get("kind",""),b.get("kind","")):
		var forward=recipe.base==a.get("kind","") and recipe.materials[0]==b.get("kind","")
		if not inventory.craft_unlocked(run,recipe.target):continue
		result.append({"target":recipe.target,"base_uid":a.uid if forward else b.uid,"material_uid":b.uid if forward else a.uid})
	return result

static func ready_options(run:Dictionary,inventory)->Array:
	return display_options(run,inventory).filter(func(v):return v.ok)

static func display_options(run: Dictionary,inventory) -> Array:
	var result:Array=[]
	var seen:Dictionary={}
	if run.get("phase","")!="shop":return result
	for base in run.get("items",[]):
		for recipe in BOOK.for_base(C.combinations,base.kind):
			var candidate=preview(run,recipe.target,base.uid,inventory)
			if not candidate.ok and candidate.get("reason","")!="储物空位不足":continue
			var inputs=candidate.consumed.duplicate();inputs.sort()
			var key=recipe.target+JSON.stringify(inputs)
			if seen.has(key):continue
			seen[key]=true
			candidate.erase("run");candidate.base_uid=base.uid
			result.append(candidate)
	return result

# Revalidate the exact previewed ingredients and landing; never silently choose
# another identical ingredient or relocate the output after a pointer press.
static func commit_ready(run: Dictionary,candidate: Dictionary,inventory,persist:Callable=Callable()) -> Dictionary:
	var target=str(candidate.get("target",""))
	if not candidate.has_all(["base_uid","output","consumed"]):return rejected(target,"配方状态已变化")
	if candidate.has("source") and candidate.source!=SESSION.stamp(run):return rejected(target,"配方状态已变化")
	var output=candidate.output
	if not output is Dictionary or not output.has_all(["x","y","rotation"]):return rejected(target,"配方状态已变化")
	var placement={"x":output.x,"y":output.y,"rotation":output.rotation}
	var stored=candidate.get("destination","board")=="stash"
	var fresh=preview(run,target,str(candidate.base_uid),inventory,{} if stored else placement)
	if stored and fresh.ok and (fresh.get("destination","")!="stash" or fresh.output!=candidate.output or fresh.get("stash_index",-1)!=candidate.get("stash_index",-1)):return rejected(target,"配方状态已变化")
	if not fresh.ok:return fresh
	if fresh.consumed!=candidate.consumed:return rejected(target,"配方状态已变化")
	return SESSION.commit(run,fresh,inventory.validate_run,persist)

# Inventory is passed in so neither the catalogue nor this transaction module
# needs to preload the controller which calls it.
static func options(run: Dictionary,base_uid: String,inventory) -> Array:
	var bases=run.get("items",[]).filter(func(v):return v.uid==base_uid)
	if bases.size()!=1:return []
	var result: Array=[]
	for recipe in BOOK.for_base(C.combinations,bases[0].kind):
		var status=preview(run,recipe.target,base_uid,inventory)
		status.erase("run");result.append(status)
	return result

static func plan_buy_material(run:Dictionary,kind:String,inventory)->Dictionary:
	# Only a real visible offer can be purchased through the recipe page.
	if not C.is_tag(kind,"craft_material"):return {"ok":false,"value":false}
	for index in range(run.get("shop",[]).size()):
		if run.shop[index].get("kind","")==kind:return inventory.plan_buy(run,index)
	return {"ok":false,"value":false}
static func buy_material(run:Dictionary,kind:String,inventory)->bool:
	return bool(inventory.commit_operation(run,plan_buy_material(run,kind,inventory)).get("ok",false))
