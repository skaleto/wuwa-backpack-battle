extends RefCounted
## New-run procurement only. Owned recipes and combat never consult this policy.
const C=preload('res://scripts/data/catalog.gd')
const VERSION=122
const MISSING_BOOST=6.0
const PARTNER_BOOST=2.0
## The two direct terminal catalysts, plus answer/lamp and their roots. None is an
## input to any of the five starters' first tier-2 upgrades (see audit/tests).
const EARLY_CATALYSTS=['contract','mat_42300050','mat_42500030','electro_coin','answer','lamp']
const CATALYST_WEIGHT=[.08,.12,.30,.65,1.0]
const TARGET_PROGRESS={
 2:[1.0,1.0,1.0,1.0,1.0,1.0],
 3:[.15,.35,.7,1.0,1.0,1.0],
 4:[.03,.08,.25,.5,1.0,1.0],
 5:[.01,.025,.08,.2,.55,1.0],
}
static func enabled(data:Dictionary)->bool:return int(data.get('supply_version',0))in [VERSION,125,127,128,129]
static func commodity_weight(kind:String,round_number:int)->float:
 return float(CATALYST_WEIGHT[clampi(round_number-1,0,CATALYST_WEIGHT.size()-1)]) if kind in EARLY_CATALYSTS else 1.0
static func commodities(ordinary:Dictionary,round_number:int)->Dictionary:
 var result=ordinary.duplicate();var total=0.0
 for kind in result:
  result[kind]*=commodity_weight(kind,round_number);total+=float(result[kind])
 # Renormalize the whole shelf, not each tier: a sole eligible catalyst must
 # not recover the entire tier's probability after its weight is reduced.
 if total>0:
  for kind in result:result[kind]/=total
 return result
static func target_weight(kind:String,round_number:int)->float:
 var tier=int(C.profile(kind).get('tier',1))
 var curve=TARGET_PROGRESS.get(tier,[1.0,1.0,1.0,1.0,1.0,1.0])
 return float(curve[clampi(round_number-1,0,curve.size()-1)])
static func missing_weights(data:Dictionary)->Dictionary:
 var result={}
 for recipe in C.supply_recipes(int(data.get('supply_version',0))):
  if str(recipe.id).begins_with("E125-") and int(data.get("supply_version",0))<125:continue
  if not data.unlocked.has(recipe.target):continue
  for pair in [[recipe.base,recipe.materials[0]],[recipe.materials[0],recipe.base]]:
   if data.owned.has(pair[0]) and not data.owned.has(pair[1]) and data.eligible.has(pair[1]):
    result[pair[1]]=maxf(float(result.get(pair[1],0)),target_weight(recipe.target,int(data.round)))
 return result
static func weighted(ordinary:Dictionary,data:Dictionary,slot:int)->Dictionary:
 var result=ordinary.duplicate();var total=0.0
 var missing=missing_weights(data) if slot==4 else {}
 for kind in result:
  var boost=MISSING_BOOST*float(missing.get(kind,0)) if slot==4 else PARTNER_BOOST if slot==3 and kind in data.get('partners',[]) else 0.0
  result[kind]*=1.0+boost
  total+=float(result[kind])
 if total>0:
  for kind in result:result[kind]/=total
 return result
