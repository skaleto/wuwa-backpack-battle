extends RefCounted
## Consumes committed facts once. Crew outputs never feed back into crew inputs.
const A=preload("res://scripts/party/crew_abilities.gd")
const C=preload("res://scripts/data/catalog.gd")
const EPS=.00001
static func setup(ctx:Dictionary)->void:
 ctx.crew_cursor=0;ctx.crew_state=[{},{}];ctx.crew_pieces=[{},{}];ctx.crew_attacks=[];ctx.crew_attack_times=[{},{}]
 for side in 2:
  for piece in ctx.builds[side].get("items",[]):ctx.crew_pieces[side][piece.uid]=piece
  if preload("res://scripts/party/recruitment.gd").enabled(ctx.builds[side]):continue
  for role in ctx.builds[side].get("supports",[]):
   if not A.profile(role).is_empty():ctx.crew_state[side][role]={"count":0.0,"next":0.0,"last":""}
static func record_attack(ctx:Dictionary,side:int,item:Dictionary,time:float,data:Dictionary)->void:
 if not ctx.has("crew_attacks"):return
 if is_equal_approx(float(ctx.crew_attack_times[side].get(item.uid,-100)),time):return
 ctx.crew_attack_times[side][item.uid]=time
 ctx.crew_attacks.append({"kind":"natural_attack","side":side,"uid":item.uid,"charged":data.get("charged",false)})
static func process(engine,ctx:Dictionary,time:float)->void:
 if not ctx.has("crew_state"):return
 var end=ctx.events.size()
 var facts=ctx.events.slice(int(ctx.crew_cursor),end)+ctx.crew_attacks
 ctx.crew_attacks=[]
 for e in facts:
  var side=int(e.get("side",-1))
  if side<0 or side>1 or str(e.get("uid","")).begins_with("crew:") or str(e.get("source_uid","")).begins_with("crew:"):continue
  var kind=str(e.get("kind",""));var piece=ctx.crew_pieces[side].get(e.get("uid",""),{})
  for team in 2:
   if ctx.states[team].hp<=0:continue
   for role in ctx.crew_state[team]:
    var spec=A.profile(role);var state=ctx.crew_state[team][role];var gain=0.0
    var natural=kind=="natural_attack" and not piece.is_empty()
    match spec.id:
     "stamina_relay":
      if team==side and natural and C.is_tag(piece.kind,"weapon") and str(piece.uid)!=state.last:
       state.last=str(piece.uid);gain=1
     "weapon_echo":
      if team==side and natural and C.is_tag(piece.kind,"weapon"):gain=1
     "charged_guard":
      if team==side and natural and C.is_tag(piece.kind,"weapon") and e.get("charged",false):gain=1
     "shield_counter":
      if team!=side and kind=="attack" and e.get("ordinary",false):gain=maxf(0,float(e.get("absorbed",0)))
     "heal_charge":
      if team==side and kind=="heal" and not piece.is_empty():gain=maxf(0,float(e.get("actual_value",e.get("value",0))))
     "frost_hunt":
      if team==side and kind=="freeze" and int(e.get("target_side",side))!=side and not piece.is_empty():gain=1
     "noise_break":
      if team==side and kind=="noise" and int(e.get("target_side",side))!=side and float(e.get("value",0))>0 and not piece.is_empty():gain=1
     "echo_heal":
      if team==side and natural and C.is_tag(piece.kind,"echo"):gain=1
    if gain<=0:continue
    state.count=minf(float(spec.threshold),float(state.count)+gain)
    if state.count+EPS<float(spec.threshold) or time+EPS<float(state.next):continue
    var actual=apply(engine,ctx,team,role,spec,time)
    if actual<=EPS:continue
    state.count=0.0;state.next=time+float(spec.period)
    var ev=engine.event(time,team,"crew_trigger",actual,"crew:"+role,spec.name)
    ev.actual_value=actual;ev.role_id=role;ev.ability=spec.id;ev.trigger_uid=e.get("uid","");ev.trigger_side=side
    ctx.events.append(ev)
 ctx.crew_cursor=end
static func apply(engine,ctx:Dictionary,side:int,role:String,spec:Dictionary,t:float)->float:
 var source={"kind":"","uid":"crew:"+role};var state=ctx.states[side];var target=ctx.states[1-side]
 match spec.id:
  "stamina_relay","frost_hunt":
   var before=float(state.stamina);engine.resource(ctx,side,source,"stamina",float(spec.value),t)
   return float(state.stamina)-before
  "weapon_echo":
   var candidates=ctx.queues[side].filter(func(p):return C.is_tag(p.kind,"echo") and ctx.progress[side].has(p.uid) and float(ctx.progress[side][p.uid])<1-EPS)
   candidates.sort_custom(func(a,b):
    var av=(1-float(ctx.progress[side][a.uid]))*engine.cooldown(ctx,side,a);var bv=(1-float(ctx.progress[side][b.uid]))*engine.cooldown(ctx,side,b)
    return str(a.uid)<str(b.uid) if is_equal_approx(av,bv) else av>bv)
   if candidates.is_empty():return 0.0
   return engine.advance_item(ctx,side,candidates[0],float(spec.value),t,source,false)
  "charged_guard":return engine.add_shield(ctx,side,float(spec.value),t,source.uid,spec.name)
  "shield_counter":
   if target.hp<=0:return 0.0
   engine.queue_hit(ctx,side,source,float(spec.value),t,"counter");return float(spec.value)
  "heal_charge":
   var before=int(state.charge);engine.resource(ctx,side,source,"charge",float(spec.value),t);return float(state.charge)-before
  "noise_break":
   if target.hp<=0:return 0.0
   if target.shield>EPS:
    var amount=engine.remove_shield(ctx,1-side,float(spec.value))
    var ev=engine.event(t,side,"break_shield",amount,source.uid,spec.name);ev.actual_value=amount;ev.target_side=1-side;ctx.events.append(ev);return amount
   engine.queue_hit(ctx,side,source,float(spec.fallback),t);return float(spec.fallback)
  "echo_heal":return engine.heal(ctx,side,source,float(spec.value),t,false)
 return 0.0
