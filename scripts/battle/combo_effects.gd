extends RefCounted
## Small data-driven counters. Derived hits never publish natural attack roots.
## Defensive counters listen to actual shield absorption, never raw incoming hits.
static func event(b,ctx:Dictionary,side:int,item:Dictionary,root:String,t:float)->void:
 var specs:Array=b.profile(item).get("combo_effects",[])
 var state=b.own(ctx,side,item)
 for index in specs.size():
  var spec=specs[index]
  if spec.trigger!=root:continue
  var key="combo_"+str(index);var threshold=int(spec.get("threshold",1))
  state[key]=mini(threshold,int(state.get(key,0))+1)
  if int(state[key])<threshold or not b.gate(ctx,side,item,key,t,float(spec.get("period",0))):continue
  state[key]=0
  b.queue_hit(ctx,side,item,float(spec.value),t,"counter" if spec.action=="counter" else "derived")
  var ev=b.event(t,side,"combo_ready",threshold,item.uid,"");ev.effect=spec.action;ctx.events.append(ev)
static func blocked(b,ctx:Dictionary,side:int,t:float)->void:
 for item in ctx.queues[side]:event(b,ctx,side,item,"blocked",t)
static func meter(b,ctx:Dictionary,side:int,item:Dictionary)->Dictionary:
 var s=b.own(ctx,side,item);var specs:Array=b.profile(item).get("combo_effects",[])
 if not specs.is_empty():return {"count":int(s.get("combo_0",0)),"total":int(specs[0].get("threshold",1)),"kind":specs[0].action}
 var star=b.profile(item).get("material_effect",{})
 if int(star.get("threshold",1))>1:return {"count":mini(int(s.get("card_count",0)),int(star.threshold)),"total":int(star.threshold),"kind":star.action}
 return {}
