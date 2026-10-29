extends RefCounted
## Small reusable component effects. Same-kind copies share one clock/opening.
## All combat changes go through battle actions; this module cannot edit a run.
const CATALOG=preload("res://scripts/data/catalog.gd")
static func definition(b,item:Dictionary)->Dictionary:return b.profile(item).get("material_effect",{})
static func opening(b,ctx:Dictionary,side:int,item:Dictionary)->void:
 var spec=definition(b,item)
 if spec.is_empty():return
 if spec.trigger=="clock":
  b.own(ctx,side,item).material_next=float(spec.period)
 elif spec.trigger=="opening" and eligible(b,ctx,side,item,spec,0) and b.gate(ctx,side,item,"material_opening",0,999):
  apply(b,ctx,side,item,spec,0)
  if bool(spec.get("notifies_supply",false)):b.supply_event(ctx,side,item,0)
static func tick(b,ctx:Dictionary,side:int,item:Dictionary,t:float)->void:
 var spec=definition(b,item)
 if spec.is_empty() or spec.trigger!="clock":return
 var state=b.own(ctx,side,item)
 if t+b.EPS<float(state.material_next):return
 state.material_next=float(state.material_next)+float(spec.period)
 if eligible(b,ctx,side,item,spec,t) and b.gate(ctx,side,item,"material_clock",t,float(spec.period)):
  var before=float(ctx.states[side].get(spec.action,0))
  var prepared=apply(b,ctx,side,item,spec,t)
  b.material_cycle(ctx,side,item,t,prepared or float(ctx.states[side].get(spec.action,0))>before+b.EPS)
static func clock_key(b,ctx:Dictionary,side:int,item:Dictionary)->String:
 var clocks=b.own(ctx,side,item).clocks;var key=""
 for k in clocks:
  if key.is_empty() or float(clocks[k])<float(clocks[key]):key=k
 return key
static func remaining(b,ctx:Dictionary,side:int,item:Dictionary,t:float)->float:
 if ctx.progress[side].has(item.uid) and float(b.profile(item).get("damage",0))>0:return (1-float(ctx.progress[side][item.uid]))*b.cooldown(ctx,side,item)
 var key=clock_key(b,ctx,side,item)
 return maxf(0,float(b.own(ctx,side,item).clocks[key])-t) if not key.is_empty() else -1.0
static func targets(b,ctx:Dictionary,side:int,item:Dictionary,spec:Dictionary,t:float)->Array:
 var found=b.linked(ctx,side,item,spec.category)
 if spec.action=="advance":found=found.filter(func(p):return remaining(b,ctx,side,p,t)>b.EPS)
 return found
static func eligible(b,ctx:Dictionary,side:int,item:Dictionary,spec:Dictionary,t:float)->bool:
 return spec.category.is_empty() or not targets(b,ctx,side,item,spec,t).is_empty()
static func apply(b,ctx:Dictionary,side:int,item:Dictionary,spec:Dictionary,t:float)->bool:
 var amount=float(spec.value)
 match spec.action:
  "advance","flat","charged","break":
   var found=targets(b,ctx,side,item,spec,t)
   if found.is_empty():return false
   if spec.action=="advance":
    found.sort_custom(func(a,c):return remaining(b,ctx,side,a,t)>remaining(b,ctx,side,c,t))
    var target=found[0]
    if ctx.progress[side].has(target.uid) and float(b.profile(target).get("damage",0))>0:b.advance_item(ctx,side,target,amount,t,item)
    else:
     var key=clock_key(b,ctx,side,target);var clocks=b.own(ctx,side,target).clocks
     var actual=minf(amount,maxf(0,float(clocks[key])-t));clocks[key]=float(clocks[key])-actual
     var event=b.event(t,side,"cooldown_advance",actual,target.uid,"冷却推进");event.source_uid=item.uid;event.target_uid=target.uid;ctx.events.append(event)
     b.partner_feedback(ctx,side,item,target,t)
   else:
    b.sort_damage(found)
    var key=str(item.kind)+':'+str(spec.action)
    var prior=b.own(ctx,side,found[0]).buffs.get(key,{}).duplicate(true)
    b.buff(ctx,side,found[0],item,spec.action,amount,t,999,int(spec.count))
    return b.own(ctx,side,found[0]).buffs.get(key,{})!=prior
  "heal":b.support_heal(ctx,side,item,amount,t)
  "shield":
   var actual=b.add_shield(ctx,side,amount,t,item.uid)
   if actual>0:b.natural(ctx,side,item,"shield",t,{"amount":actual})
  "damage":b.queue_hit(ctx,side,item,amount,t,"derived")
  "noise","frost","break_shield":ctx.pending.append({"side":side,"actions":[{"type":spec.action,"value":amount,"item":item,"ordinary":true,"kind":"support"}]})
  _:b.resource(ctx,side,item,spec.action,amount,t)
 return false

## Card star triggers: the effect fires when an item standing on this card's
## star cells publishes a battle event. Trigger names are "star_"+event root
## (attack/heal/shield/supply/noise); category limits the lighting tag, period
## is the same-kind interval, target picks self (default)/trigger/strongest_weapon.
## Actions reuse the vocabulary above plus resource keys (haste/charge/...).
static func star_event(b,ctx:Dictionary,side:int,trigger:Dictionary,root:String,t:float,data:Dictionary={})->void:
 if root!="attack" and root!="heal" and root!="shield" and root!="supply" and root!="noise":return
 for item in ctx.queues[side]:
  var spec=definition(b,item)
  var own_burst=spec.get("trigger","")=="self_burst" and root=="attack" and bool(data.get("burst",false)) and item.uid==trigger.uid
  if not own_burst and str(spec.get("trigger",""))!="star_"+root:continue
  if not own_burst and (item.uid==trigger.uid or not b.has_link(ctx,side,item,trigger)):continue
  var category=str(spec.get("category",""))
  if not own_burst and not category.is_empty() and not b.capability(trigger,category):continue
  var state=b.own(ctx,side,item);var threshold=int(spec.get("threshold",1))
  # A repeated publication of one natural root is still one activation, and a
  # stored attack occupies one local slot until this weapon actually attacks.
  var root_key=str(trigger.uid)+":"+root
  if not state.has("card_roots"):state.card_roots={}
  if is_equal_approx(float(state.card_roots.get(root_key,-100)),t):continue
  state.card_roots[root_key]=t
  if spec.get("action","")=="prepare_attack" and not state.get("card_prepared",{}).is_empty():continue
  state.card_count=mini(threshold,int(state.get("card_count",0))+1)
  if int(state.card_count)<threshold:continue
  var gate_key=str(item.kind)+":card_star"
  if t+b.EPS<float(ctx.icd[side].get(gate_key,-100)):continue
  if ctx.team[side].get("card_pending",{}).has(gate_key):continue
  var target=item
  if str(spec.get("target","self"))=="trigger":target=trigger
  elif str(spec.get("target","self"))=="strongest_weapon":
   var found=b.linked(ctx,side,item,"weapon");b.sort_damage(found)
   if found.is_empty():continue
   target=found[0]
  elif str(spec.get("target","self"))=="longest_weapon":
   var found=targets(b,ctx,side,item,spec,t)
   found.sort_custom(func(a,c):return remaining(b,ctx,side,a,t)>remaining(b,ctx,side,c,t))
   if found.is_empty():continue
   target=found[0]
  if star_apply(b,ctx,side,item,spec,target,trigger,t):
   # A reservation prevents duplicate queued actions without spending the
   # counter or interval. Both are consumed only by a successful resolution.
   if spec.action in ["noise","frost","break_shield"]:
    if not ctx.team[side].has("card_pending"):ctx.team[side].card_pending={}
    ctx.team[side].card_pending[gate_key]=item.uid
   else:
    state.card_count=0
    ctx.icd[side][gate_key]=t+float(spec.get("period",0))
    b.effect_feedback(ctx,side,item,trigger,target,t,target if own_burst else {})

static func finish_star_action(b,ctx:Dictionary,side:int,action:Dictionary,t:float,applied:bool)->void:
 if not action.has("star_trigger"):return
 var item=action.item;var key=str(item.kind)+":card_star"
 ctx.team[side].get("card_pending",{}).erase(key)
 if not applied:return
 b.own(ctx,side,item).card_count=0
 ctx.icd[side][key]=t+float(action.star_period)
 b.effect_feedback(ctx,side,item,action.star_trigger,action.star_beneficiary,t)

static func star_apply(b,ctx:Dictionary,side:int,item:Dictionary,spec:Dictionary,target:Dictionary,trigger:Dictionary,t:float)->bool:
 var amount=float(spec.get("value",0))
 if amount<=0 and str(spec.get("action",""))!="advance":return false
 match str(spec.get("action","")):
  "prepare_attack":
   var state=b.own(ctx,side,target)
   if not state.get("card_prepared",{}).is_empty():return false
   state.card_prepared={"value":amount,"pierce":float(spec.get("pierce",0)),"pierce_cap":float(spec.get("pierce_cap",999)),"breaking":float(spec.get("breaking",0))}
   var ready=b.event(t,side,"combo_ready",1,target.uid,"准备强化攻击")
   ready.effect="prepare_attack";ready.source_uid=item.uid;ready.trigger_uid=trigger.uid;ready.beneficiary_uid=target.uid;ctx.events.append(ready)
  "advance":
   if target.is_empty():return false
   if ctx.progress[side].has(target.uid) and float(b.profile(target).get("damage",0))>0:
    if b.advance_item(ctx,side,target,amount,t,item,false)<=b.EPS:return false
   else:
    var clocks=b.own(ctx,side,target).clocks
    if clocks.is_empty():return false
    var key=clock_key(b,ctx,side,target)
    var actual=minf(amount,maxf(0,float(clocks[key])-t));clocks[key]=float(clocks[key])-actual
    if actual<=b.EPS:return false
    var event=b.event(t,side,"cooldown_advance",actual,target.uid,"冷却推进");event.source_uid=item.uid;event.target_uid=target.uid;ctx.events.append(event)
  "flat","charged":
   if target.is_empty():return false
   var key=str(item.kind)+":"+str(spec.action)
   var prior=b.own(ctx,side,target).buffs.get(key,{})
   if float(prior.get("until",0))>t and float(prior.get("value",0))>=amount and int(prior.get("count",0))>=int(spec.get("count",1)):return false
   b.buff(ctx,side,target,item,str(spec.get("action","flat")),amount,t,999,int(spec.get("count",1)),false)
  "heal":
   return b.support_heal(ctx,side,item,amount,t)>b.EPS
  "shield":
   var actual2=b.add_shield(ctx,side,amount,t,item.uid)
   if actual2<=b.EPS:return false
   b.natural(ctx,side,item,"shield",t,{"amount":actual2})
  "damage":b.queue_hit(ctx,side,item,amount,t,"derived")
  "noise","frost","break_shield":
   var enemy=ctx.states[1-side]
   if spec.action=="frost" and t+b.EPS<float(enemy.frost_immune_until):return false
   if spec.action=="noise" and int(enemy.noise)>=6:return false
   if spec.action=="break_shield" and float(enemy.shield)<=b.EPS:return false
   ctx.pending.append({"side":side,"actions":[{"type":spec.action,"value":amount,"item":item,"ordinary":false,"kind":"derived","star_trigger":trigger,"star_beneficiary":target,"star_period":float(spec.get("period",0))}]})
  _:
   var action=str(spec.get("action",""));var before=float(ctx.states[side].get(action,0));var expiry=float(ctx.states[side].get(action+"_until",0))
   b.resource(ctx,side,item,action,amount,t)
   return float(ctx.states[side].get(action,0))>before or float(ctx.states[side].get(action+"_until",0))>expiry
 return true
