extends RefCounted
## Stable geometry shared by painting and tooltips; no battle state mutations.
const LABELS={"charge":"充能","haste":"迅捷","noise":"光噪","frost":"霜渐","freeze":"冻结"}
const DETAILS={"charge":"积满 6 层，下一次武器自然攻击消耗并强化。","haste":"加快物品冷却。","noise":"持续造成伤害。","frost":"减慢武器冷却；积满可造成冻结。","freeze":"武器暂时停止冷却。"}
static func origin(side:int)->Vector2:return Vector2(128 if side==0 else 808,400)
static func health(side:int)->Rect2:return Rect2(origin(side)+Vector2(109,-17),Vector2(282,14))
static func stamina(side:int)->Rect2:return Rect2(origin(side)+Vector2(109,13),Vector2(282,9))
static func chips(side:int,statuses:Array)->Array:
 var out=[]
 for n in mini(5,statuses.size()):
  var s=statuses[n];var key=str(s.get("id",""))
  out.append({"rect":Rect2(origin(side)+Vector2(n*103,31),Vector2(99,27)),"id":key,"label":LABELS.get(key,str(s.get("label",key))),"stacks":int(s.get("stacks",1)),"remaining":float(s.get("remaining",0)),"negative":key in ["noise","frost","freeze"],"detail":DETAILS.get(key,"")})
 return out
