extends RefCounted
## Expanded parts share their functional family's budget, not a new extra slot.
## Pure weighting: no rolls, recipe locks or inventory mutation here.
const C=preload('res://scripts/data/catalog.gd')
const PREVIOUS=preload('res://scripts/shop/supply_policy_v125.gd')
static func family(kind:String)->String:
 var anchor=str(C.profile(kind).get('supply_anchor',''))
 return PREVIOUS.family(anchor) if not anchor.is_empty() else PREVIOUS.family(kind)
static func shares(kinds:Array)->Dictionary:
 var groups={};var budgets={};var total=0.0;var out={}
 for kind in kinds:
  var key=family(kind)
  if not groups.has(key):groups[key]=[];budgets[key]=0.0
  groups[key].append(kind)
  if int(C.profile(kind).get('introduced_version',0))<125:budgets[key]+=1.0
 for key in groups:
  budgets[key]=maxf(1,budgets[key]);total+=budgets[key]
 for key in groups:
  for kind in groups[key]:out[kind]=budgets[key]/total/groups[key].size()
 return out
