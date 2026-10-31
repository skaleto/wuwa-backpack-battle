extends RefCounted
## Display palette plus versioned rules; no simulation writes.
const OLD=preload('res://scripts/inventory/pocket_rules_current.gd')
const POCKETS=preload('res://scripts/data/pocket_catalog_v129.gd')
static var PROFILES:Dictionary=_profiles()
static func _profiles()->Dictionary:
 var out=OLD.PROFILES.duplicate(true)
 for kind in POCKETS.spec:
  var d=POCKETS.spec[kind]
  out[kind]={'name':d.name,'short':'扩容','glyph':'base','color':Color(d.color),'effect':str(d.shape.size())+' 格','stat':'capacity','amount':0.0}
 return out
static func profile(kind:String,build:Dictionary={"pocket_version":143})->Dictionary:
 var result=PROFILES.get(kind,OLD.PROFILES.satchel).duplicate(true)
 var rule=OLD.profile(kind,build)
 for key in ["short","glyph","effect","stat","amount"]:result[key]=rule[key]
 if rule.stat=="capacity" and POCKETS.spec.has(kind):result.effect=str(POCKETS.spec[kind].shape.size())+" 格"
 return result
