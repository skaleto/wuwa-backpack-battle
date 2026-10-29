extends RefCounted
## Read-only projection; all consumers agree on side and one effective source/partner event.
static func advance_seconds(event:Dictionary)->float:
 return maxf(0.0,float(event.get("actual_value",event.get("value",0.0))))
static func stars(events:Array,side:int,uid:String="",until:float=INF)->int:
 var seen={}
 for e in events:
  if e.get("kind","")!="star_trigger" or int(e.get("side",-1))!=side or float(e.get("time",0))>until:continue
  var source=str(e.get("source_uid",""))
  if not uid.is_empty() and source!=uid:continue
  seen[source+":"+str(e.get("trigger_uid",""))+":"+str(e.get("time",0))]=true
 return seen.size()
static func contribution(events:Array,side:int,uid:String,until:float)->Dictionary:
 var out={"stars":stars(events,side,uid,until),"damage":0.0,"heal":0.0,"shield":0.0,"advance":0.0}
 for e in events:
  if int(e.get("side",-1))!=side or float(e.get("time",0))>until:continue
  if e.get("kind","")=="cooldown_advance" and str(e.get("source_uid",""))==uid:out.advance+=advance_seconds(e)
  if str(e.get("uid",""))!=uid:continue
  if e.kind in ["attack","derived","counter","noise_tick","frost_hit"]:out.damage+=float(e.hp_damage)+float(e.get("absorbed",0)) if e.has("hp_damage") else float(e.value)
  elif e.kind in ["heal","shield"]:out[e.kind]+=float(e.get("actual_value",e.value))
 return out

## Damage events already carry effective absorption. The shared shield pool
## has no item ownership, so this number is intentionally a team statistic.
static func absorption(events:Array,side:int,until:float=INF)->float:
 var total=0.0
 for e in events:
  if float(e.get("time",0))>until:continue
  if int(e.get("side",-1))==1-side:total+=float(e.get("absorbed",0))
  elif int(e.get("side",-1))==side and e.get("kind","")=="guard":total+=float(e.get("actual_value",e.get("value",0)))
 return total

static func result_contributions(events:Array,side:int,items:Array)->Array:
 var rows=[]
 for item in items:
  var stats=contribution(events,side,str(item.uid),INF)
  var score=float(stats.damage)+float(stats.heal)+float(stats.shield)
  if score<=0:continue
  stats.uid=str(item.uid);stats.kind=str(item.kind);stats.score=score
  rows.append(stats)
 rows.sort_custom(func(a,b):return a.score>b.score if not is_equal_approx(a.score,b.score) else a.uid<b.uid)
 return rows.slice(0,3)
