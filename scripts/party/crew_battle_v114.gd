extends RefCounted
## Selected crew rules use actual item readiness, payment, overflow and absorption.
const R=preload('res://scripts/party/recruitment_v114.gd')
const C=preload('res://scripts/data/catalog.gd')
static func setup(ctx:Dictionary)->void:
 ctx.crew114=[{'guard_shield':0.0,'guard_used':0.0,'guard_until':0.0,'counter':0.0,'volley_at':-1.0,'stamina_wait_at':-1.0},{'guard_shield':0.0,'guard_used':0.0,'guard_until':0.0,'counter':0.0,'volley_at':-1.0,'stamina_wait_at':-1.0}]
static func signal_event(b,ctx:Dictionary,side:int,ability:String,t:float,value:float,uid:String='')->void:
 var role=''
 for r in ctx.builds[side].get('supports',[]):
  if R.ROLES.get(r,'')==ability:role=r;break
 if role.is_empty() or value<=b.EPS:return
 var ev=b.event(t,side,'crew_trigger',value,'crew:'+role,R.NAMES[ability]);ev.role_id=role;ev.ability=ability;ev.actual_value=value;ev.trigger_uid=uid;ctx.events.append(ev)
static func volley(b,ctx:Dictionary,side:int,item:Dictionary,t:float,delta:float)->bool:
 var pair=R.valid_pair(b.inventory,ctx.builds[side],'volley')
 if pair.is_empty() or not pair.any(func(p):return p.uid==item.uid):return false
 var s=ctx.crew114[side]
 if is_equal_approx(float(s.volley_at),t):return true
 if pair.any(func(p):return not ctx.progress[side].has(p.uid) or float(ctx.progress[side][p.uid])+b.EPS<1):return true
 if t+b.EPS<float(ctx.states[side].freeze_until):return true
 var total=pair.reduce(func(sum,p):return sum+b.stamina_cost(ctx,side,p),0.0)
 if float(ctx.states[side].stamina)+b.EPS<total:
  for p in pair:
   ctx.totals[side].stamina_wait_by_uid[p.uid]=float(ctx.totals[side].stamina_wait_by_uid.get(p.uid,0))+delta
   if not ctx.waiting[side][p.uid]:ctx.events.append(b.event(t,side,'tired',0,p.uid,'合击等待耐力'));ctx.totals[side].tired+=1
   ctx.waiting[side][p.uid]=true
  s.volley_at=t
  s.stamina_wait_at=t
  return true
 s.volley_at=t
 ctx.states[side].stamina=maxf(0,float(ctx.states[side].stamina)-total)
 var counter=minf(6,float(s.counter)*.25);s.counter=0.0
 for p in pair:
  ctx.waiting[side][p.uid]=false;ctx.progress[side][p.uid]=0.0
  b.own(ctx,side,p).crew_volley_bonus=float(b.profile(p).get('damage',C.items[p.kind].get('damage',0)))*.2+counter
  b.activate(ctx,side,p,t)
 b.use_threshold_provisions(ctx,side,t,'stamina3')
 signal_event(b,ctx,side,'volley',t,pair.reduce(func(sum,p):return sum+float(b.profile(p).get('damage',0))*.2+counter,0.0),pair[0].uid)
 return true
static func overflow(b,ctx:Dictionary,side:int,item:Dictionary,amount:float,actual:float,t:float)->void:
 if not ctx.has('crew114') or float(ctx.states[side].hp)<=0 or amount<=actual+b.EPS:return
 var pair=R.valid_pair(b.inventory,ctx.builds[side],'guard')
 if pair.is_empty() or pair[0].uid!=item.get('uid',''):return
 var s=ctx.crew114[side]
 if t+b.EPS>=float(s.guard_until):s.guard_used=0.0;s.guard_until=t+4.0
 var requested=minf((amount-actual)*.5,maxf(0,6.0-float(s.guard_used)))
 if requested<=b.EPS:return
 var gained=b.add_shield(ctx,side,requested,t,'crew:role_1505','溢出守护')
 if gained<=b.EPS:return
 s.guard_used+=gained;s.guard_shield+=gained
 signal_event(b,ctx,side,'guard',t,gained,item.uid)
static func absorb(ctx:Dictionary,side:int,blocked:float,shield_before:float)->void:
 if not ctx.has('crew114'):return
 var s=ctx.crew114[side];s.guard_shield=minf(float(s.guard_shield),shield_before)
 var used=minf(float(s.guard_shield),blocked);s.guard_shield-=used
 if R.bond_id(ctx.builds[side])=='guard+volley':s.counter=minf(24,float(s.counter)+used)
static func shield_removed(ctx:Dictionary,side:int,removed:float)->void:
 if ctx.has('crew114'):ctx.crew114[side].guard_shield=maxf(0,float(ctx.crew114[side].guard_shield)-removed)
static func specialty_tick(b,ctx:Dictionary,side:int,item:Dictionary,t:float)->void:
 var spec=C.items[item.kind].get('v114',{})
 if spec.is_empty() or spec.action!='stamina':return
 if t+b.EPS>=float(spec.period) and b.gate(ctx,side,item,'specialty',t,float(spec.period)):b.resource(ctx,side,item,spec.action,float(spec.value),t)

static func specialty_overflow(b,ctx:Dictionary,side:int,item:Dictionary,amount:float,actual:float,t:float)->void:
 if not ctx.has('local') or float(ctx.states[side].hp)<=0:return
 var spec=C.items.get(item.get('kind',''),{}).get('v114',{})
 if spec.get('action','')!='overflow_shield' or amount<=actual+b.EPS:return
 var state=b.own(ctx,side,item)
 if t+b.EPS>=float(state.get('overflow_until',0)):state.overflow_used=0.0;state.overflow_until=t+float(spec.period)
 var request=minf((amount-actual)*float(spec.value),maxf(0,float(spec.cap)-float(state.get('overflow_used',0))))
 if request<=b.EPS:return
 var gained=b.add_shield(ctx,side,request,t,item.uid,'晨露溢出')
 state.overflow_used=float(state.get('overflow_used',0))+gained

static func link_trigger(b,ctx:Dictionary,side:int,source:Dictionary,target:Dictionary,t:float)->void:
 if not ctx.has('crew114'):return
 var link=R.valid_link(b.inventory,ctx.builds[side])
 if not link.is_empty() and source.uid==link.source and target.uid==link.target:signal_event(b,ctx,side,'link',t,1.0,target.uid)
