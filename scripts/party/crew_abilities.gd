extends RefCounted
## One shared source for roster cards, matching hints and battle coefficients.
const C=preload("res://scripts/data/catalog.gd")
const ACTIVITY=preload("res://scripts/battle/item_activity.gd")
const BUILD=preload("res://scripts/battle/build_rules.gd")
const POCKETS=preload("res://scripts/inventory/pocket_rules.gd")
const NAMES=preload("res://scripts/battle/battle_v75_rules.gd")
const SPECS={
 "stamina_relay":{"name":"交替接应","icon":"stamina","trigger":"不同武器交替出手累计 4 次","effect":"恢复 1 点体力","threshold":4.0,"period":4.0,"value":1.0},
 "weapon_echo":{"name":"声骸接力","icon":"echo","trigger":"武器自然攻击累计 3 次","effect":"剩余冷却最长的声骸提前 1 秒","threshold":3.0,"period":4.0,"value":1.0},
 "charged_guard":{"name":"蓄力掩护","icon":"shield","trigger":"武器消耗充能发动攻击","effect":"获得 4 点护盾","threshold":1.0,"period":4.0,"value":4.0},
 "shield_counter":{"name":"挡伤回击","icon":"counter","trigger":"实际挡伤累计 10 点","effect":"反击造成 4 点伤害","threshold":10.0,"period":4.0,"value":4.0},
 "heal_charge":{"name":"疗愈蓄能","icon":"charge","trigger":"物品实际治疗累计 8 点","effect":"获得 2 层充能","threshold":8.0,"period":4.0,"value":2.0},
 "frost_hunt":{"name":"霜锋接应","icon":"frost","trigger":"物品使对方冻结","effect":"恢复 1.2 点体力","threshold":1.0,"period":5.0,"value":1.2},
 "noise_break":{"name":"噪声破防","icon":"noise","trigger":"物品成功施加光噪累计 3 次","effect":"额外削盾 5 点；无盾时造成 3 点伤害","threshold":3.0,"period":5.0,"value":5.0,"fallback":3.0},
 "echo_heal":{"name":"声骸回护","icon":"healing","trigger":"声骸自然攻击累计 3 次","effect":"恢复 4 点生命","threshold":3.0,"period":4.0,"value":4.0},
}
const GROUPS={
 "stamina_relay":["role_1102","role_1104","role_1202","role_1204","role_1402","role_1403","role_1510","role_1511","role_1602","role_1603","role_1604","role_1610"],
 "weapon_echo":["role_1105","role_1109","role_1302","role_1303","role_1304","role_1312","role_1411","role_1504","role_1606"],
 "charged_guard":["role_1203","role_1205","role_1207","role_1208","role_1210","role_1211","role_1301","role_1305","role_1306","role_1308","role_1309","role_1404","role_1412","role_1509"],
 "shield_counter":["role_1209","role_1212","role_1405","role_1507","role_1508","role_1601"],
 "heal_charge":["role_1103","role_1106","role_1206","role_1307","role_1503","role_1505","role_1607"],
 "frost_hunt":["role_1107","role_1108"],
 "noise_break":["role_1110","role_1311","role_1406","role_1407","role_1409","role_1501","role_1506"],
 "echo_heal":["role_1410","role_1413","role_1608"],
}
static func profile(role_id:String)->Dictionary:
 for key in GROUPS:
  if role_id in GROUPS[key]:
   var spec=SPECS[key].duplicate(true);spec.id=key;return spec
 return {}
static func supplies(item:Dictionary,key:String,build:Dictionary)->bool:
 var d=C.items.get(item.get("kind",""),{});var n=d.get("v75",{});var geometry=BUILD.new()
 if item.kind=="pouch":return key=="shield" and POCKETS.shields(build,geometry).any(func(p):return p.uid==item.uid)
 if n.is_empty():
  var old=d.get("v60",{})
  return old.get("active",false) and old.get("actions",[]).any(func(a):return a.get("type","")==key and float(a.get("value",0))>0)
 match key:
  "heal":
   if float(n.get("healAmount",0))>0 or float(n.get("emergency",0))>0:return true
  "shield":
   if float(n.get("shieldAmount",0))>0 or float(n.get("openingShield",0))>0:return true
  "frost","noise":
   if float(n.get(key+"Period",0))>0:return true
  "charge":
   if float(n.get("charge",0))>0 or item.kind in ["spicy_meat","violet"] or NAMES.NAMES.get(item.kind,"") in ["金穹","翼锋","永远的启明星","阳焰","悲喜剧"]:return true
 var material=n.get("material_effect",{})
 if material.get("action","")==key:
  if material.get("category","").is_empty():return true
  return not geometry.star_links(item,build.get("items",[]),build).is_empty()
 # Capability tags describe build themes too (e.g. charged-hit damage);
 # they are not evidence that this item actually supplies a resource.
 if key=="charge":
  var name=NAMES.NAMES.get(item.kind,"")
  if name in ["凋亡频移","永续坍缩","悖论喷流","尘云旋臂","核熔星盘","玉阙玄华","赝作的矮星"]:return true
  if item.kind in ["electro_coin","echo_vanguard"] or name.begins_with("远行者") or name=="那映照虚幻的燃灯":
   return not geometry.star_links(item,build.get("items",[]),build).is_empty()
 return false
static func matches(role_id:String,items:Array,build:Dictionary={})->Array:
 var spec=profile(role_id);var result=[]
 if spec.is_empty():return result
 if build.is_empty():build={"items":items.filter(func(p):return not C.is_tag(p.kind,"bag")),"bags":items.filter(func(p):return C.is_tag(p.kind,"bag"))}
 for item in items:
  var tags=C.items.get(item.get("kind",""),{}).get("tags",[]);var yes=false
  match spec.id:
   "stamina_relay":yes="weapon" in tags and ACTIVITY.attacks(item)
   "weapon_echo":yes=("weapon" in tags and ACTIVITY.attacks(item)) or ("echo" in tags and ACTIVITY.has_clock(item))
   "charged_guard":yes=supplies(item,"charge",build)
   "shield_counter":yes=supplies(item,"shield",build)
   "heal_charge":yes=supplies(item,"heal",build)
   "frost_hunt":yes=supplies(item,"frost",build)
   "noise_break":yes=supplies(item,"noise",build)
   "echo_heal":yes="echo" in tags and ACTIVITY.attacks(item)
  if yes:result.append(item)
 return result
static func ready(role_id:String,build:Dictionary)->bool:
 var spec=profile(role_id)
 if spec.is_empty():return false
 var pieces=build.get("items",[]);var linked=matches(role_id,pieces+build.get("bags",[]),build)
 match spec.id:
  "stamina_relay":return linked.size()>=2
  "weapon_echo":return linked.any(func(p):return C.is_tag(p.kind,"weapon")) and linked.any(func(p):return C.is_tag(p.kind,"echo"))
  "charged_guard":
   var opening=C.characters.get(build.get("leader",""),{}).get("v60_opening",[])
   return pieces.any(func(p):return C.is_tag(p.kind,"weapon")) and (not linked.is_empty() or opening.any(func(a):return a.type=="charge" and a.value>0))
 return not linked.is_empty()
static func ordered(ids:Array,build:Dictionary)->Array:
 var result=ids.duplicate()
 result.sort_custom(func(a,b):
  var ar=ready(a,build);var br=ready(b,build)
  return ar if ar!=br else C.roster[a].name<C.roster[b].name)
 return result
