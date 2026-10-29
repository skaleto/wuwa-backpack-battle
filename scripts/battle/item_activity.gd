extends RefCounted
## Shared facts about existing natural activations, including retained equipment.
const C=preload("res://scripts/data/catalog.gd")
static func attacks(item:Dictionary)->bool:
 var d=C.items.get(item.get("kind",""),{});var n=C.profile(item.get("kind",""))
 return attacks_profile(d,n)
static func attacks_profile(d:Dictionary,n:Dictionary)->bool:
 if not n.is_empty():return float(n.get("damage",0))>0 and float(n.get("cd",0))>0
 var old=d.get("v60",{})
 return old.get("active",false) and old.get("actions",[]).any(func(a):return a.get("type","")=="damage" and float(a.get("value",0))>0)
static func has_clock(item:Dictionary)->bool:
 var d=C.items.get(item.get("kind",""),{});var n=C.profile(item.get("kind",""))
 if not n.is_empty():return attacks(item) and item.get("kind","")!="violet"
 var old=d.get("v60",{})
 return old.get("active",false) and old.get("activation","")=="cooldown" and float(d.get("cooldown",0))>0

static func functional(kind:String,type:String)->bool:
 return functional_profile(kind,C.items.get(kind,{}),C.profile(kind),type)
static func functional_profile(kind:String,d:Dictionary,n:Dictionary,type:String)->bool:
 var action=n.get("material_effect",{}).get("action","");var specialty=d.get("v114",{}).get("action","")
 if type==action and type in ["heal","shield","noise","stamina"]:return true
 match type:
  "heal":return float(n.get("healAmount",0))>0 or float(n.get("emergency",0))>0
  "shield":return float(n.get("shieldAmount",0))>0 or float(n.get("openingShield",0))>0 or specialty=="overflow_shield"
  "noise":return float(n.get("noisePeriod",0))>0 or n.get("ecosystem_rule","")=="moth"
  "stamina":return specialty=="stamina" or kind in ["soup","dragon_food"]
 return false
