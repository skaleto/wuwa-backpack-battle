extends RefCounted
## Facts are recorded at their source and consumed after both teams have acted.
## Crew gains never become new natural-attack or spending facts.
const A=preload('res://scripts/party/crew_abilities_v115.gd')
const C=preload('res://scripts/data/catalog.gd')
const EPS=.00001
const CONTINUOUS=['spent_stamina','full_stamina','full_guard']
static func counter()->Dictionary:
 return {'count':0.0,'weapon':false,'echo':false,'next':0.0,'tick':4.0}
static func setup(ctx:Dictionary)->void:
 ctx.crew115=[]
 for side in 2:
  var state={'roles':{},'pieces':{},'facts':[],'attack_times':{},'full':A.full_team(ctx.builds[side]),'bond':counter()}
  if A.enabled(ctx.builds[side]):
   for p in ctx.builds[side].get('items',[]):state.pieces[p.uid]=p
   for role in ctx.builds[side].get('supports',[]):
    if not A.profile(role).is_empty():state.roles[role]=counter()
  ctx.crew115.append(state)
static func active(ctx:Dictionary,side:int)->bool:
 return ctx.has('crew115') and not ctx.crew115[side].roles.is_empty()
static func record_attack(ctx:Dictionary,side:int,item:Dictionary,t:float,data:Dictionary)->void:
 if not active(ctx,side) or str(item.get('uid','')).begins_with('crew:'):return
 var state=ctx.crew115[side]
 if not state.pieces.has(item.get('uid','')):return
 if is_equal_approx(float(state.attack_times.get(item.uid,-100)),t):return
 state.attack_times[item.uid]=t
 var target=ctx.get('planning_vitals',ctx.states)[1-side]
 state.facts.append({'type':'attack','uid':item.uid,'weapon':C.is_tag(item.kind,'weapon'),'echo':C.is_tag(item.kind,'echo'),'charged':data.get('charged',false),'afflicted':int(target.noise)>0 or int(target.frost)>0})
static func record_spent(ctx:Dictionary,side:int,amount:float,_t:float,uid:String)->void:
 if active(ctx,side) and amount>EPS and not uid.begins_with('crew:'):
  ctx.crew115[side].facts.append({'type':'spent','uid':uid,'amount':amount})
static func record_blocked(ctx:Dictionary,side:int,amount:float,_t:float,uid:String)->void:
 if active(ctx,side) and amount>EPS and not uid.begins_with('crew:'):
  ctx.crew115[side].facts.append({'type':'blocked','uid':uid,'amount':amount})
static func signal_event(b,ctx:Dictionary,side:int,spec:Dictionary,t:float,actual:float,uid:String='',trigger_side:int=-1)->void:
 if actual<=EPS:return
 var ev=b.event(t,side,'crew_trigger',actual,'crew:'+spec.role_id,spec.ability_name)
 ev.actual_value=actual;ev.role_id=spec.role_id;ev.ability=spec.ability_id;ev.trigger_uid=uid;ev.trigger_side=side if trigger_side<0 else trigger_side
 ctx.events.append(ev)
static func process(b,ctx:Dictionary,t:float)->void:
 if not ctx.has('crew115'):return
 for side in 2:
  var state=ctx.crew115[side];var facts=state.facts;state.facts=[]
  if ctx.states[side].hp<=0:continue
  for role in state.roles:
   var spec=A.profile(role);var s=state.roles[role]
   if spec.ability_id not in ['timed_stamina','timed_heal'] or t+EPS<float(s.tick):continue
   # Full resources do not bank unused periodic pulses.
   s.tick=(floor(t/float(spec.period))+1)*float(spec.period)
   signal_event(b,ctx,side,spec,t,apply_base(b,ctx,side,spec,t))
  for fact in facts:
   for role in state.roles:
    var spec=A.profile(role);var s=state.roles[role]
    if not accumulate(s,spec.ability_id,float(spec.threshold),fact):continue
    if t+EPS<float(s.next):continue
    var actual=apply_base(b,ctx,side,spec,t)
    if actual>EPS:
     consume(s,t,spec);signal_event(b,ctx,side,spec,t,actual,str(fact.uid))
   var full=state.full
   if full.is_empty() or not accumulate(state.bond,full.ability_id,float(full.threshold),fact):continue
   if t+EPS<float(state.bond.next):continue
   var actual=apply_full(b,ctx,side,full,t)
   if actual>EPS:
    consume(state.bond,t,full);signal_event(b,ctx,side,full,t,actual,str(fact.uid),1-side if fact.type=='blocked' else side)
static func consume(state:Dictionary,t:float,spec:Dictionary)->void:
 # Actual paid/blocked amounts are conserved across thresholds. One fact can
 # trigger at most once; a backlog needs another real input after the interval.
 state.count=maxf(0,float(state.count)-float(spec.threshold)) if spec.ability_id in CONTINUOUS else 0.0
 state.weapon=false;state.echo=false;state.next=t+float(spec.period)
static func accumulate(state:Dictionary,id:String,threshold:float,fact:Dictionary)->bool:
 var gain=0.0
 var attack=fact.type=='attack'
 match id:
  'dual_charge','full_relay':
   if not attack:return false
   state.weapon=bool(state.weapon) or bool(fact.weapon);state.echo=bool(state.echo) or bool(fact.echo)
   return state.weapon and state.echo
  'triple_charge','echo_relay','weapon_noise','weapon_frost':
   if attack and fact.weapon:gain=1.0
  'weapon_relay','echo_heal':
   if attack and fact.echo:gain=1.0
  'spent_stamina','full_stamina':
   if fact.type=='spent':gain=float(fact.amount)
  'full_guard':
   if fact.type=='blocked':gain=float(fact.amount)
  'full_charge':
   if attack and fact.weapon and fact.charged:gain=1.0
  'full_affliction':
   if attack and fact.weapon and fact.afflicted:gain=1.0
 if gain<=0:return false
 state.count=float(state.count)+gain if id in CONTINUOUS else minf(threshold,float(state.count)+gain)
 return float(state.count)+EPS>=threshold
static func source(spec:Dictionary)->Dictionary:return {'kind':'','uid':'crew:'+str(spec.role_id)}
static func resource_gain(b,ctx:Dictionary,side:int,spec:Dictionary,key:String,t:float)->float:
 var before=float(ctx.states[side].get(key,0))
 b.resource(ctx,side,source(spec),key,float(spec.value),t)
 return float(ctx.states[side].get(key,0))-before
static func advance(b,ctx:Dictionary,side:int,spec:Dictionary,category:String,t:float)->float:
 var candidates=ctx.queues[side].filter(func(p):return C.is_tag(p.kind,category) and ctx.progress[side].has(p.uid) and float(ctx.progress[side][p.uid])<1-EPS)
 candidates.sort_custom(func(a,bp):
  var av=(1-float(ctx.progress[side][a.uid]))*b.cooldown(ctx,side,a);var bv=(1-float(ctx.progress[side][bp.uid]))*b.cooldown(ctx,side,bp)
  return str(a.uid)<str(bp.uid) if is_equal_approx(av,bv) else av>bv)
 if candidates.is_empty():return 0.0
 return b.advance_item(ctx,side,candidates[0],float(spec.value),t,source(spec),false)
static func heal_with_overflow(b,ctx:Dictionary,side:int,spec:Dictionary,t:float)->float:
 var actual=b.heal(ctx,side,source(spec),float(spec.value),t,false)
 var overflow=maxf(0,float(spec.value)-actual)*.5
 var shield=b.add_shield(ctx,side,overflow,t,source(spec).uid,spec.ability_name) if overflow>EPS else 0.0
 return actual+shield
static func apply_base(b,ctx:Dictionary,side:int,spec:Dictionary,t:float)->float:
 match spec.ability_id:
  'dual_charge','triple_charge':return resource_gain(b,ctx,side,spec,'charge',t)
  'echo_relay':return advance(b,ctx,side,spec,'echo',t)
  'weapon_relay':return advance(b,ctx,side,spec,'weapon',t)
  'timed_stamina','spent_stamina':return resource_gain(b,ctx,side,spec,'stamina',t)
  'timed_heal','echo_heal':return heal_with_overflow(b,ctx,side,spec,t)
  'weapon_noise':
   if ctx.states[1-side].hp>0:return float(b.apply_noise_internal(ctx,side,source(spec),int(spec.value),t,false))
  'weapon_frost':
   if ctx.states[1-side].hp>0:return float(b.apply_frost_internal(ctx,side,source(spec),int(spec.value),t,false))
 return 0.0
static func apply_full(b,ctx:Dictionary,side:int,spec:Dictionary,t:float)->float:
 match spec.family:
  'charge','guard','affliction':
   if ctx.states[1-side].hp<=0:return 0.0
   b.queue_hit(ctx,side,source(spec),float(spec.value),t,'counter' if spec.family=='guard' else 'derived')
   return float(spec.value)
  'relay':return advance(b,ctx,side,spec,'weapon',t)
  'stamina':return b.add_shield(ctx,side,float(spec.value),t,source(spec).uid,spec.ability_name)
 return 0.0
