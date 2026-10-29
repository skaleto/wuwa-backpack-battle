extends "res://scripts/battle/battle_v124.gd"
## Eight small ecosystem rules on natural roots. Derived attacks never publish roots.
func rule(item:Dictionary)->String:
 return "" if profile(item).has("ecosystem_rule") else super.rule(item)
func opening(ctx:Dictionary,side:int,item:Dictionary)->void:
 if not ctx.has("eco_sources"):ctx.eco_sources=[[],[]]
 ctx.eco_sources[side]=ctx.queues[side].filter(func(i):return profile(i).has("ecosystem_rule"))
 super.opening(ctx,side,item)
 var n=profile(item)
 if float(n.get("opening_haste",0))>0:resource(ctx,side,item,"haste",n.opening_haste,0)
func material_cycle(ctx:Dictionary,side:int,item:Dictionary,t:float,actual:bool)->void:
 if not actual or not profile(item).get("cyclic_supply",false):return
 cycle_event(ctx,side,item,t)
func cycle_event(ctx:Dictionary,side:int,item:Dictionary,t:float)->void:
 var s=own(ctx,side,item)
 if is_equal_approx(float(s.get("eco_supply_time",-100)),t):return
 s.eco_supply_time=t
 var ev=event(t,side,"supply",0,item.uid,C.items[item.kind].name);ev.cyclic=true;ctx.events.append(ev)
 if item.uid not in ctx.used[side]:
  ctx.used[side].append(item.uid);natural(ctx,side,item,"supply",t)
 natural(ctx,side,item,"supply_cycle",t)
func support_heal(ctx:Dictionary,side:int,item:Dictionary,amount:float,t:float)->float:
 var actual=super.support_heal(ctx,side,item,amount,t)
 if actual>EPS and profile(item).get("cyclic_supply",false):cycle_event(ctx,side,item,t)
 return actual
func before_attack(ctx:Dictionary,side:int,item:Dictionary,t:float,charged:bool)->void:
 super.before_attack(ctx,side,item,t,charged)
 if not ctx.has("local") or profile(item).is_empty():return
 var n=profile(item);var s=own(ctx,side,item)
 s.erase("eco_pierce_source")
 s.eco_attack_ready=s.get("eco_ready",false)
 if n.get("ecosystem_rule","")=="anger" and s.eco_attack_ready:
  s.eco_ready=false;buff(ctx,side,item,item,"flat",n.prepare_flat,t,999,1,false)
 if not C.is_tag(item.kind,"weapon"):return
 for source in ctx.get("eco_sources",[[],[]])[side]:
  if not has_link(ctx,side,source,item):continue
  var sn=profile(source);var key=sn.ecosystem_rule
  if key=="diverter" and not charged and ctx.states[side].charge>=1 and ctx.states[side].charge<6 and gate(ctx,side,source,"eco_spend",t,sn.star_period):
   resource(ctx,side,source,"charge",-1,t);buff(ctx,side,item,source,"flat",sn.prepare_flat,t,999,1,false)
   effect_feedback(ctx,side,source,item,item,t)
  elif key=="answer":
   var enemy=ctx.get("planning_vitals",ctx.states)[1-side]
   if s.has("eco_pierce_source") or enemy.shield<=EPS or (enemy.noise<=0 and enemy.frost<=0) or not core_gate_ready(ctx,side,source,"eco_pierce",t):continue
   s.eco_pierce_source=source
func activate(ctx:Dictionary,side:int,item:Dictionary,t:float,ordinary:bool=true,kind:String="attack",scale:float=1.0,relay_bonus:float=0.0)->void:
 var first=ctx.pending.size()
 super.activate(ctx,side,item,t,ordinary,kind,scale,relay_bonus)
 if not ordinary or not ctx.has("local") or profile(item).is_empty():return
 var n=profile(item);var s=own(ctx,side,item);var key=n.get("ecosystem_rule","")
 # The shared activation calculated all whole-attack additions once. Only then split.
 for index in range(first,ctx.pending.size()):
  var bundle=ctx.pending[index]
  if bundle.get("root_item",{}).get("uid","")!=item.uid:continue
  if s.has("eco_pierce_source"):bundle.eco_pierce_source=s.eco_pierce_source
  if n.has("segments"):
   var damage_actions=bundle.actions.filter(func(a):return a.type=="damage" and a.get("ordinary",false))
   if damage_actions.size()==1:
    var original=damage_actions[0];bundle.actions.erase(original)
    for i in n.segments.size():
     var a=original.duplicate(true);a.value=float(original.value)*float(n.segments[i])
     if key=="singilum" and s.get("eco_attack_ready",false) and i==n.segments.size()-1:
      a.value+=float(n.prepare_flat);a.prepared=true;s.eco_ready=false;s.eco_count=0
     bundle.actions.append(a)
  # One pierce budget for an entire multi-hit root, not one cap per segment.
  var hits=bundle.actions.filter(func(a):return a.type=="damage" and a.get("ordinary",false) and float(a.get("pierce",0))>0)
  var total=0.0
  for a in hits:total+=float(a.value)
  for a in hits:
   if float(a.get("pierce_cap",999))<999:a.pierce_cap=float(a.pierce_cap)*float(a.value)/maxf(EPS,total)
  if key=="moth":
   if s.get("eco_attack_ready",false):
    var layers=int(ctx.get("planning_vitals",ctx.states)[1-side].noise)
    if layers>0:
     bundle.actions.append({"type":"damage","value":noise_tick_value(ctx,side,t),"item":item,"ordinary":false,"kind":"derived"})
     s.eco_ready=false
   bundle.actions.append({"type":"noise","value":1,"item":item,"ordinary":true,"kind":"support"})
  elif key=="sorrow" and s.get("eco_attack_ready",false):
   bundle.actions.append({"type":"frost","value":1,"item":item,"ordinary":false,"eco_consume_ready":true})
func whole_attack_pierce(ctx:Dictionary,bundle:Dictionary,resolved_amounts:Dictionary,t:float)->Dictionary:
 var source=bundle.get("eco_pierce_source",{})
 if source.is_empty():return {}
 var side=int(bundle.side);var enemy=ctx.states[1-side];var n=profile(source)
 if enemy.shield<=EPS or (enemy.noise<=0 and enemy.frost<=0) or not core_gate_ready(ctx,side,source,"eco_pierce",t):return {}
 # Resolve the whole root after mitigation; a helper cannot cap innate piercing.
 # Fixed extra segments are natural hits too and receive their share of the gain.
 var amounts={};var total=0.0;var innate=0.0
 for i in bundle.actions.size():
  var a=bundle.actions[i]
  if a.type!="damage":continue
  var damage=float(resolved_amounts[i])
  if not a.get("ordinary",false):continue
  amounts[i]=damage;total+=damage
  innate+=minf(damage*float(a.get("pierce",0)),float(a.get("pierce_cap",999)))
 var desired=minf(total*float(n.pierce),float(n.pierce_cap))
 if total<=EPS or desired<=maxf(innate,total-float(enemy.shield))+EPS:return {}
 if not gate(ctx,side,source,"eco_pierce",t,n.star_period):return {}
 effect_feedback(ctx,side,source,bundle.root_item,bundle.root_item,t)
 var out={}
 for i in amounts:out[i]=desired*float(amounts[i])/total
 return out
func finish_pending_action(ctx:Dictionary,side:int,action:Dictionary,t:float,applied:bool)->void:
 super.finish_pending_action(ctx,side,action,t,applied)
 if applied and action.get("eco_consume_ready",false):own(ctx,side,action.item).eco_ready=false
func natural(ctx:Dictionary,side:int,trigger:Dictionary,event_kind:String,t:float,data:Dictionary={})->void:
 super.natural(ctx,side,trigger,event_kind,t,data)
 if not ctx.has("eco_sources"):return
 var n=profile(trigger);var s=own(ctx,side,trigger)
 if n.get("ecosystem_rule","")=="porcelain" and event_kind=="attack" and new_root(s,trigger,event_kind,t):
  s.eco_count=mini(int(n.threshold),int(s.get("eco_count",0))+1)
  if s.eco_count>=n.threshold:
   var targets=linked(ctx,side,trigger,"echo").filter(func(i):return MATERIALS.remaining(self,ctx,side,i,t)>EPS)
   targets.sort_custom(func(a,b):return MATERIALS.remaining(self,ctx,side,a,t)>MATERIALS.remaining(self,ctx,side,b,t))
   if not targets.is_empty():
    var target=targets[0];var actual=0.0
    if ACTIVITY.has_clock(target):actual=advance_item(ctx,side,target,n.advance,t,trigger)
    else:
     var clock=MATERIALS.clock_key(self,ctx,side,target);var clocks=own(ctx,side,target).clocks
     actual=minf(float(n.advance),maxf(0,float(clocks[clock])-t));clocks[clock]-=actual
     if actual>EPS:advance_event(ctx,side,trigger,target,actual,t);partner_feedback(ctx,side,trigger,target,t)
    if actual>EPS:s.eco_count=0
 for source in ctx.eco_sources[side]:
  if source.uid==trigger.uid or not has_link(ctx,side,source,trigger):continue
  var sn=profile(source);var ss=own(ctx,side,source)
  if not new_root(ss,trigger,event_kind,t):continue
  var attack=event_kind=="attack" and ACTIVITY.attacks(trigger)
  var paid=false
  match sn.ecosystem_rule:
   "puppet":
    if attack and C.is_tag(trigger.kind,"echo"):
     ss.eco_count=mini(int(sn.threshold),int(ss.get("eco_count",0))+1)
     var value=minf(sn.copy_cap,float(profile(trigger).damage)*float(sn.copy_ratio))
     if ss.eco_count>=sn.threshold and value>EPS and gate(ctx,side,source,"eco_copy",t,sn.star_period):
      ss.eco_count=0;queue_hit(ctx,side,source,value,t);paid=true
   "anger","moth","singilum":
    if event_kind=="charged" and C.is_tag(trigger.kind,"weapon") and not ss.get("eco_ready",false):
     ss.eco_count=mini(int(sn.get("threshold",1)),int(ss.get("eco_count",0))+1)
     if ss.eco_count>=int(sn.get("threshold",1)) and gate(ctx,side,source,"eco_prepare",t,float(sn.get("star_period",0))):
      ss.eco_ready=true;paid=true
   "sorrow","sentry":
    if event_kind=="shield" and float(data.get("amount",0))>EPS and not ss.get("eco_ready",false) and core_gate_ready(ctx,side,source,"eco_prepare",t):
     ss.eco_ready=true;paid=true
     if sn.ecosystem_rule=="sorrow":gate(ctx,side,source,"eco_prepare",t,sn.star_period)
   "glacio":
    if attack and C.is_tag(trigger.kind,"weapon"):
     ss.eco_count=mini(int(sn.threshold),int(ss.get("eco_count",0))+1)
     var remain=float(ss.clocks.get("frost",t))-t
     if ss.eco_count>=sn.threshold and remain>EPS and gate(ctx,side,source,"eco_frost",t,sn.star_period):
      var actual=minf(float(sn.advance),remain);ss.clocks.frost-=actual;ss.eco_count=0
      advance_event(ctx,side,source,source,actual,t);paid=true
   "lunchbox":
    if event_kind=="supply_cycle" and C.is_tag(trigger.kind,"provision"):
     if not ss.has("eco_foods"):ss.eco_foods={}
     ss.eco_foods[trigger.kind]=true
     var remain=float(ss.get("material_next",t))-t
     if ss.eco_foods.size()>=2 and remain>EPS and gate(ctx,side,source,"eco_lunch",t,sn.star_period):
      var actual=minf(float(sn.advance),remain);ss.material_next-=actual;ss.eco_foods.clear()
      var clock_key=str(source.kind)+":material_clock"
      if ctx.icd[side].has(clock_key):ctx.icd[side][clock_key]=maxf(t,float(ctx.icd[side][clock_key])-actual)
      advance_event(ctx,side,source,source,actual,t);paid=true
  if paid:effect_feedback(ctx,side,source,trigger,source,t)
func new_root(state:Dictionary,trigger:Dictionary,kind:String,t:float)->bool:
 if not state.has("eco_roots"):state.eco_roots={}
 var key=str(trigger.uid)+":"+kind
 if is_equal_approx(float(state.eco_roots.get(key,-100)),t):return false
 state.eco_roots[key]=t;return true
func advance_event(ctx:Dictionary,side:int,source:Dictionary,target:Dictionary,actual:float,t:float)->void:
 var ev=event(t,side,"cooldown_advance",actual,target.uid,"冷却推进")
 ev.actual_value=actual;ev.source_uid=source.uid;ev.target_uid=target.uid;ctx.events.append(ev)
func mitigate_hit(ctx:Dictionary,side:int,item:Dictionary,amount:float,t:float,ordinary:bool,kind:String)->float:
 if ordinary and kind=="attack" and C.is_tag(item.get("kind",""),"weapon") and amount>EPS:
  var defending=1-side;var key=str(item.uid)+":"+str(t)
  for source in ctx.get("eco_sources",[[],[]])[defending]:
   var n=profile(source)
   if n.ecosystem_rule!="sentry":continue
   var s=own(ctx,defending,source)
   if s.get("eco_guard_root","")!=key:
    if not s.get("eco_ready",false) or not gate(ctx,defending,source,"eco_prepare",t,n.star_period):continue
    s.eco_ready=false;s.eco_guard_root=key;s.eco_guard_left=float(n.guard)
    queue_hit(ctx,defending,source,n.counter_damage,t,"counter")
    ctx.pending.append({"side":defending,"actions":[{"type":"frost","value":1,"item":source,"ordinary":false}]})
   var prevented=minf(amount,float(s.eco_guard_left))
   if prevented<=EPS:continue
   s.eco_guard_left-=prevented;amount-=prevented
   var ev=event(t,defending,"guard",prevented,source.uid,"招架")
   ev.actual_value=prevented;ev.prevented=prevented;ev.trigger_uid=item.uid;ev.trigger_side=side;ctx.events.append(ev)
   # Same-kind guards share the interval and cannot stack on this root.
   break
 return amount
func frame(t:float,ctx:Dictionary)->Dictionary:
 var out=super.frame(t,ctx)
 for side in 2:
  for item in ctx.get("eco_sources",[[],[]])[side]:
   var n=profile(item);var s=own(ctx,side,item)
   if n.ecosystem_rule in ["porcelain","puppet","glacio","singilum"]:
    out.combo_meters[side][item.uid]={"kind":"derived","count":int(n.threshold) if s.get("eco_ready",false) else int(s.get("eco_count",0)),"total":int(n.threshold)}
   elif n.ecosystem_rule in ["anger","sorrow","sentry","moth"]:
    out.combo_meters[side][item.uid]={"kind":"counter" if n.ecosystem_rule=="sentry" else "derived","count":1 if s.get("eco_ready",false) else 0,"total":1}
 return out

func noise_tick_value(ctx:Dictionary,side:int,t:float)->float:
 var value=0.0
 for contribution in ctx.noise_parts[1-side]:
  var owner=int(contribution.side);var bonus=0.0
  if t<=float(ctx.team[owner].get("noise_boost_until",-1))+EPS:bonus=.25
  if t<=float(ctx.team[owner].get("forest_until",-1))+EPS:bonus=maxf(bonus,.2)
  value+=(1+bonus)*(1.25 if rule(contribution.item)=="焰光裁定" else 1.0)
 return value
