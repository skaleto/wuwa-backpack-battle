extends "res://scripts/battle/battle_v125.gd"
## Family parts reuse the existing clocks/resources. Only natural roots may feed
## these bounded reactions; their queued damage never publishes another root.
func step(ctx:Dictionary,time:float)->void:
	ctx.erase("family_plan")
	super.step(ctx,time)
	ctx.erase("family_plan")

func tick_source(ctx:Dictionary,side:int,item:Dictionary,t:float)->void:
	# V75 expires both sides' statuses and captures planning_vitals before the
	# first source tick. Capture contribution values at that same boundary,
	# before either side can cleanse, add a layer or activate a new bonus.
	if ctx.has("planning_vitals") and not ctx.has("family_plan"):
		ctx.family_plan={"noise_ticks":[super.noise_tick_value(ctx,0,t),super.noise_tick_value(ctx,1,t)],"freeze_until":ctx.states.map(func(s):return s.freeze_until)}
	super.tick_source(ctx,side,item,t)

func noise_tick_value(ctx:Dictionary,side:int,t:float)->float:
	return float(ctx.family_plan.noise_ticks[side]) if ctx.has("family_plan") else super.noise_tick_value(ctx,side,t)

func opening(ctx:Dictionary,side:int,item:Dictionary)->void:
	if not ctx.has("family_sources"):ctx.family_sources=[[],[]]
	ctx.family_sources[side]=ctx.queues[side].filter(func(i):return profile(i).has("family_effect"))
	super.opening(ctx,side,item)
	var small_shield=float(profile(item).get("openingShield",0))
	if small_shield>0 and small_shield<8 and core_gate_ready(ctx,side,item,"family_opening_shield",0):
		var actual=add_shield(ctx,side,small_shield,0,item.uid,"开场护盾")
		if actual>EPS:
			gate(ctx,side,item,"family_opening_shield",0,999)
			natural(ctx,side,item,"shield",0,{"amount":actual})
	var discount=float(profile(item).get("opening_stamina_discount",0))
	if discount>0:resource(ctx,side,item,"stamina_discount",discount,0)

func buff(ctx:Dictionary,side:int,target:Dictionary,source:Dictionary,type:String,value:float,t:float,duration:float=6,count:int=1,feedback:bool=true)->void:
	# A still-unused permanent preparation has no new benefit to announce.
	var definition=C.items.get(source.get("kind",""),{})
	if not target.is_empty() and (definition.has("v127") or definition.has("v128")) and duration>=999:
		var old=own(ctx,side,target).buffs.get(str(source.kind)+":"+type,{})
		if float(old.get("until",0))>t and float(old.get("value",0))>=value and int(old.get("count",0))>=count:return
	super.buff(ctx,side,target,source,type,value,t,duration,count,feedback)

func natural(ctx:Dictionary,side:int,trigger:Dictionary,event_kind:String,t:float,data:Dictionary={})->void:
	super.natural(ctx,side,trigger,event_kind,t,data)
	if event_kind not in ["attack","charged"] or not ACTIVITY.attacks(trigger):return
	for source in ctx.get("family_sources",[[],[]])[side]:
		var spec=profile(source).family_effect
		if str(spec.trigger)!="star_"+event_kind or source.uid==trigger.uid or not has_link(ctx,side,source,trigger):continue
		if not capability(trigger,str(spec.get("category","weapon"))):continue
		var state=own(ctx,side,source)
		if not family_root(state,trigger,event_kind,t):continue
		# Observe every natural echo, including those during the reward interval.
		var prior=str(state.get("family_last_kind",""))
		if spec.action=="alternate_advance":state.family_last_kind=trigger.kind
		if not core_gate_ready(ctx,side,source,"family",t):continue
		var enemy=ctx.get("planning_vitals",ctx.states)[1-side]
		var value=float(spec.get("value",0));var paid=false;var beneficiary=source
		match str(spec.action):
			"conditional_damage":
				var frozen_until=float(ctx.family_plan.freeze_until[1-side]) if ctx.has("family_plan") else float(ctx.states[1-side].freeze_until)
				var eligible=float(enemy.shield)<=EPS if spec.condition=="unshielded" else int(enemy.frost)>=int(spec.get("frost_min",2)) or frozen_until>t+EPS
				if eligible and value>EPS:
					queue_hit(ctx,side,source,value,t);paid=true
			"noise_tick":
				if int(enemy.noise)>0:
					value=minf(value,noise_tick_value(ctx,side,t))
					if value>EPS:queue_hit(ctx,side,source,value,t);paid=true
			"alternate_advance":
				if prior.is_empty() or prior==trigger.kind:continue
				var targets=linked(ctx,side,source,"echo").filter(func(i):return i.uid!=trigger.uid and MATERIALS.remaining(self,ctx,side,i,t)>EPS)
				targets.sort_custom(func(a,b):return MATERIALS.remaining(self,ctx,side,a,t)>MATERIALS.remaining(self,ctx,side,b,t))
				if targets.is_empty():continue
				beneficiary=targets[0]
				if ACTIVITY.has_clock(beneficiary):paid=advance_item(ctx,side,beneficiary,value,t,source,false)>EPS
				else:
					var clocks=own(ctx,side,beneficiary).clocks;var key=MATERIALS.clock_key(self,ctx,side,beneficiary)
					var actual=minf(value,maxf(0,float(clocks[key])-t))
					if actual>EPS:clocks[key]-=actual;advance_event(ctx,side,source,beneficiary,actual,t);paid=true
		if paid:
			gate(ctx,side,source,"family",t,float(spec.period))
			effect_feedback(ctx,side,source,trigger,beneficiary,t)

func family_root(state:Dictionary,trigger:Dictionary,kind:String,t:float)->bool:
	if not state.has("family_roots"):state.family_roots={}
	var key=str(trigger.uid)+":"+kind
	if is_equal_approx(float(state.family_roots.get(key,-100)),t):return false
	state.family_roots[key]=t
	return true

func deal_v75_damage(ctx:Dictionary,side:int,item:Dictionary,amount:float,t:float,ordinary:bool,kind:String,pierce:float=0,charged:bool=false,prepared:bool=false)->void:
	var blocked=minf(float(ctx.states[1-side].shield),maxf(0,amount-pierce))
	super.deal_v75_damage(ctx,side,item,amount,t,ordinary,kind,pierce,charged,prepared)
	if not ordinary or kind!="attack" or blocked<=EPS:return
	var defending=1-side
	for source in ctx.get("family_sources",[[],[]])[defending]:
		var spec=profile(source).family_effect
		if str(spec.trigger)!="blocked":continue
		var state=own(ctx,defending,source)
		if not family_root(state,item,"blocked",t):continue
		var threshold=int(spec.get("threshold",1))
		state.family_count=mini(threshold,int(state.get("family_count",0))+1)
		if state.family_count<threshold or not core_gate_ready(ctx,defending,source,"family",t) or ctx.states[defending].shield<=EPS:continue
		var spent=remove_shield(ctx,defending,float(spec.spend))
		if spent<=EPS:continue
		state.family_count=0;gate(ctx,defending,source,"family",t,float(spec.period))
		var ev=event(t,defending,"shield_spend",spent,source.uid,"护盾转化")
		ev.actual_value=spent;ev.trigger_uid=item.uid;ev.trigger_side=side;ctx.events.append(ev)
		queue_hit(ctx,defending,source,spent*float(spec.value),t,"counter")

func frame(t:float,ctx:Dictionary)->Dictionary:
	var out=super.frame(t,ctx)
	for side in 2:
		for source in ctx.get("family_sources",[[],[]])[side]:
			var spec=profile(source).family_effect
			if spec.trigger=="blocked":out.combo_meters[side][source.uid]={"count":int(own(ctx,side,source).get("family_count",0)),"total":int(spec.threshold),"kind":"counter"}
	return out
