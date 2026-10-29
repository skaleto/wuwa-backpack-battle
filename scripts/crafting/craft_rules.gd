extends RefCounted
const BOOK=preload("res://scripts/crafting/recipe_book.gd")
## Compatibility queries retain their shape; signatures keep lore, not ownership gates.
static func signature_owned(_definition:Dictionary,_owners:Array)->bool:
	return true
static func unlocked(definition:Dictionary,owners:Array,weapon_types:Array)->bool:
	return requirements(definition,owners,weapon_types).unlocked
static func requirements(definition:Dictionary,_owners:Array,_weapon_types:Array)->Dictionary:
	var type=str(definition.get("weapon_type","")) if "weapon" in definition.get("tags",[]) else ""
	return {"owners":[],"owner_met":true,"weapon_type":type,"type_met":true,"unlocked":true}
static func recruitment_hint(_definition:Dictionary,_roster:Dictionary,_element:String,_owned:Array)->Dictionary:
	return {"compatible":true,"text":"已解锁"}

static func eligible(recipe:Dictionary,eligibility:Dictionary)->bool:
	return eligibility.phase=="shop" and recipe.target in eligibility.targets
static func rejected(target:String,reason:String,materials:Array=[])->Dictionary:
	return {"ok":false,"target":target,"reason":reason,"materials":materials.duplicate(),"consumed":[]}
# A selected recipe is exact. Automatic callers try matching base kinds in
# catalogue order and retain the first failure for useful missing-input feedback.
static func resolve_inputs(recipes:Array,target:String,base_uid:String,items:Array,stash:Array,definitions:Dictionary,space,recipe_id:String="")->Dictionary:
	var choices=BOOK.for_target(recipes,target,recipe_id)
	if choices.is_empty() or (not recipe_id.is_empty() and choices.size()!=1):
		var absent=rejected(target,"没有该配方");absent.recipe_id=recipe_id;return absent
	var bases=items.filter(func(v):return v.uid==base_uid)
	if bases.size()==1:
		var matching=BOOK.for_base(choices,bases[0].kind)
		if not matching.is_empty():choices=matching
	var first={}
	for recipe in choices:
		var selected=select_inputs(recipe,base_uid,items,stash,definitions,space)
		selected.recipe_id=recipe.id;selected.materials=recipe.materials.duplicate()
		if selected.ok:return selected
		if first.is_empty():first=selected
	return first
static func select_inputs(recipe:Dictionary,base_uid:String,items:Array,stash:Array,definitions:Dictionary,space)->Dictionary:
	var bases=items.filter(func(v):return v.uid==base_uid)
	if bases.size()!=1:return rejected(recipe.target,"基底未放入",recipe.materials)
	var base=bases[0]
	if not BOOK.accepts_base(recipe,base.kind):return rejected(recipe.target,"配方基底不符",recipe.materials)
	var consumed:Array=[base_uid]
	for kind in recipe.materials:
		var owned=items.filter(func(v):return v.kind==kind and v.uid not in consumed)
		var near=owned.filter(func(v):return space.adjacent(base,v))
		if near.is_empty():
			var reason="材料未相邻" if not owned.is_empty() or stash.any(func(v):return v.kind==kind) else "缺少材料：%s ×1"%definitions[kind].name
			return rejected(recipe.target,reason,recipe.materials)
		near.sort_custom(func(a,b):return a.uid<b.uid)
		consumed.append(near[0].uid)
	return {"ok":true,"base":base,"consumed":consumed}
static func relations(recipes:Array,eligibility:Dictionary,items:Array,stash:Array,extra:Array,space)->Array:
	var board_ids=items.map(func(v):return v.uid)
	var by_kind={};var seen={};var result:Array=[]
	for item in items+stash+extra:
		if not by_kind.has(item.kind):by_kind[item.kind]=[]
		by_kind[item.kind].append(item)
	for recipe in recipes:
		if recipe.materials.size()!=1 or not eligible(recipe,eligibility) or not by_kind.has(recipe.base) or not by_kind.has(recipe.materials[0]):continue
		for a in by_kind[recipe.base]:
			for b in by_kind[recipe.materials[0]]:
				if a.uid==b.uid:continue
				var pair=[str(a.uid),str(b.uid)];pair.sort()
				var key=JSON.stringify([recipe.id,recipe.target,pair])
				if seen.has(key):continue
				seen[key]=true
				result.append({"target":recipe.target,"recipe_id":recipe.id,"base_uid":a.uid,"material_uid":b.uid,"uids":pair,"adjacent":a.uid in board_ids and b.uid in board_ids and space.adjacent(a,b)})
	return result
