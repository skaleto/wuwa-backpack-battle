extends RefCounted
## Display-only pocket names, capacity and uniform colors. Combat keeps frozen rules.
const OLD=preload('res://scripts/inventory/pocket_rules.gd')
const POCKETS=preload('res://scripts/data/pocket_catalog_v129.gd')
static var PROFILES:Dictionary=_profiles()
static func _profiles()->Dictionary:
 var out=OLD.PROFILES.duplicate(true)
 for kind in POCKETS.spec:
  var d=POCKETS.spec[kind]
  out[kind]={'name':d.name,'short':'扩容','glyph':'base','color':Color(d.color),'effect':str(d.shape.size())+' 格','stat':'capacity','amount':0.0}
 return out
static func profile(kind:String)->Dictionary:return PROFILES.get(kind,OLD.PROFILES.satchel)
