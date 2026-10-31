extends RefCounted
## Contact grants one full bonus per item and pocket type; shield stays per used cell.
const C=preload("res://scripts/data/catalog.gd")
const LEGACY=preload("res://scripts/inventory/pocket_rules.gd")
const PROFILES=LEGACY.PROFILES
const VERSION=143
const SPECIAL={
 "pocket_single":{"name":"单格口袋","short":"护盾","glyph":"shield","color":Color("c3b0d6"),"effect":"已用格 · 开场盾 +3","stat":"shield","amount":3.0},
 "pocket_double":{"name":"双格口袋","short":"加速","glyph":"speed","color":Color("c3b0d6"),"effect":"接触物品 · 冷却 −6%","stat":"speed","amount":.06},
 "pocket_long_l":{"name":"长折角口袋","short":"武器","glyph":"weapon","color":Color("c3b0d6"),"effect":"接触武器 · 伤害 +6%","stat":"weapon","amount":.06},
 "pocket_long_j":{"name":"反折角口袋","short":"声骸","glyph":"echo","color":Color("c3b0d6"),"effect":"接触声骸 · 伤害 +10%","stat":"echo","amount":.10}
}
static func profile(kind:String,build:Dictionary={"pocket_version":VERSION})->Dictionary:
 if int(build.get("pocket_version",0))==VERSION and SPECIAL.has(kind):return SPECIAL[kind]
 return PROFILES.get(kind,PROFILES.satchel)
static func covered_value(kind:String,covered:int,_total:int,build:Dictionary={"pocket_version":VERSION})->float:
 if covered<=0:return 0.0
 var p=profile(kind,build)
 return float(p.amount)*covered if p.stat=="shield" else float(p.amount)
static func applies(kind: String,item_kind:String,build:Dictionary={"pocket_version":VERSION})->bool:
 match str(profile(kind,build).stat):
  "speed":return float(C.items.get(item_kind,{}).get("cooldown",0))>0 and not C.is_tag(item_kind,"provision") and not C.is_tag(item_kind,"material")
  "echo":return C.is_tag(item_kind,"echo")
  "weapon":return C.is_tag(item_kind,"weapon")
  "shield":return not C.is_tag(item_kind,"bag")
 return false
static func bonus(item: Dictionary,build: Dictionary,inventory) -> Dictionary:
 if int(build.get("pocket_version",0))!=VERSION:return LEGACY.bonus(item,build,inventory)
 var out={"speed":0.0,"power":0.0,"sources":[]}
 var footprint=inventory.occupied(item)
 if footprint.is_empty():return out
 var best: Dictionary={}
 var shield_cells: Array=[]
 for bag in build.get("bags",[]):
  if not applies(bag.kind,item.kind,build):continue
  var p=profile(bag.kind,build)
  var covered=inventory.occupied(bag).filter(func(c):return c in footprint and (p.stat!="shield" or c not in shield_cells))
  if covered.is_empty():continue
  if p.stat=="shield":shield_cells.append_array(covered)

  var value=covered_value(bag.kind,covered.size(),footprint.size(),build)
  if p.stat!="shield":
   # Current small pockets must not mask a stronger touching pocket.
   if best.has(p.stat) and float(best[p.stat])>=value:continue
   var previous=float(best.get(p.stat,0.0));best[p.stat]=value
   out.sources=out.sources.filter(func(source):return source.stat!=p.stat)
   if p.stat=="speed":out.speed+=value-previous
   if p.stat in ["echo","weapon"]:out.power+=value-previous
  out.sources.append({"uid":bag.uid,"kind":bag.kind,"cells":covered,"value":value,"stat":p.stat})
 return out
static func shields(build: Dictionary,inventory) -> Array:
 var occupied: Array=[]
 for item in build.get("items",[]):
  for cell in inventory.occupied(item):
   if cell not in occupied:occupied.append(cell)
 var out: Array=[]
 for bag in build.get("bags",[]):
  if profile(bag.kind,build).stat!="shield":continue
  var count=inventory.occupied(bag).filter(func(c):return c in occupied).size()
  if count>0:out.append({"uid":bag.uid,"amount":covered_value(bag.kind,count,count,build)})
 return out
