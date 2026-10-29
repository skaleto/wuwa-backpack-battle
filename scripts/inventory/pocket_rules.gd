extends RefCounted
## Contact grants one full bonus per item and pocket type; shield stays per used cell.
const C=preload("res://scripts/data/catalog.gd")
const PROFILES={
	"satchel":{"name":"基础匣","short":"基础","glyph":"base","color":Color("aebbc4"),"effect":"6 格","stat":"capacity","amount":0.0},
	"pouch":{"name":"护盾匣","short":"护盾","glyph":"shield","color":Color("b9abd6"),"effect":"每个已用格 · 开场盾 +2","stat":"shield","amount":2.0},
	"strip":{"name":"加速匣","short":"加速","glyph":"speed","color":Color("9dcfdf"),"effect":"接触物品 · 冷却 −10%","stat":"speed","amount":.10},
	"corner":{"name":"声骸匣","short":"声骸","glyph":"echo","color":Color("9cd3bc"),"effect":"接触声骸 · 出手伤害 +15%","stat":"echo","amount":.15},
	"travel":{"name":"武器匣","short":"武器","glyph":"weapon","color":Color("d9c595"),"effect":"接触武器 · 出手伤害 +8%","stat":"weapon","amount":.08}
}
static func profile(kind: String) -> Dictionary:return PROFILES.get(kind,PROFILES.satchel)
static func covered_value(kind:String,covered:int,_total:int)->float:
	if covered<=0:return 0.0
	var p=profile(kind)
	return float(p.amount)*covered if p.stat=="shield" else float(p.amount)
static func applies(kind: String,item_kind: String) -> bool:
	match str(profile(kind).stat):
		"speed":return float(C.items.get(item_kind,{}).get("cooldown",0))>0 and not C.is_tag(item_kind,"provision") and not C.is_tag(item_kind,"material")
		"echo":return C.is_tag(item_kind,"echo")
		"weapon":return C.is_tag(item_kind,"weapon")
		"shield":return not C.is_tag(item_kind,"bag")
	return false
static func bonus(item: Dictionary,build: Dictionary,inventory) -> Dictionary:
	var out={"speed":0.0,"power":0.0,"sources":[]}
	var footprint=inventory.occupied(item)
	if footprint.is_empty():return out
	var counted_types: Array=[]
	var shield_cells: Array=[]
	for bag in build.get("bags",[]):
		if not applies(bag.kind,item.kind):continue
		var p=profile(bag.kind)
		if p.stat!="shield" and p.stat in counted_types:continue
		var covered=inventory.occupied(bag).filter(func(c):return c in footprint and (p.stat!="shield" or c not in shield_cells))
		if covered.is_empty():continue
		if p.stat=="shield":shield_cells.append_array(covered)
		else:counted_types.append(p.stat)
		var value=covered_value(bag.kind,covered.size(),footprint.size())
		if p.stat=="speed":out.speed+=value
		if p.stat in ["echo","weapon"]:out.power+=value
		out.sources.append({"uid":bag.uid,"kind":bag.kind,"cells":covered,"value":value,"stat":p.stat})
	return out
static func shields(build: Dictionary,inventory) -> Array:
	var occupied: Array=[]
	for item in build.get("items",[]):
		for cell in inventory.occupied(item):
			if cell not in occupied:occupied.append(cell)
	var out: Array=[]
	for bag in build.get("bags",[]):
		if profile(bag.kind).stat!="shield":continue
		var count=inventory.occupied(bag).filter(func(c):return c in occupied).size()
		if count>0:out.append({"uid":bag.uid,"amount":covered_value(bag.kind,count,count)})
	return out
