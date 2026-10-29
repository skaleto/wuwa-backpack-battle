extends "res://scripts/battle/battle_v75.gd"
var test_max=6.0
var test_regen=1.0
func begin(a:Dictionary,b:Dictionary,seed_value:int=1)->Dictionary:
	var ctx=super.begin(a,b,seed_value)
	for state in ctx.states:state.stamina=test_max
	return ctx
func step(ctx:Dictionary,time:float)->void:
	if not ctx.has("local"):return
	var previous=float(ctx.time);var delta=time-previous
	if delta<=0:return
	ctx.time=time
	ctx.planning_vitals=ctx.states.map(func(st):return {"hp":st.hp,"max_hp":st.max_hp,"shield":st.shield,"noise":st.noise,"frost":st.frost})
	for side in range(2):
		var state=ctx.states[side]
		state.stamina=minf(test_max,state.stamina+test_regen*delta)
		for item in ctx.queues[side]:
			if ctx.progress[side].has(item.uid):ctx.progress[side][item.uid]=minf(1,ctx.progress[side][item.uid]+progression(ctx,side,item,previous,time))
		if time+EPS>=state.haste_until:state.haste=0
		if time+EPS>=state.frost_until:state.frost=0
		tick_noise(ctx,side,time)
	ctx.planning_vitals=ctx.states.map(func(st):return {"hp":st.hp,"max_hp":st.max_hp,"shield":st.shield,"noise":st.noise,"frost":st.frost})
	for side in range(2):
		for item in ctx.queues[side]:
			if not profile(item).is_empty():tick_source(ctx,side,item,time)
		use_threshold_provisions(ctx,side,time)
		var waiting=false
		for item in ctx.queues[side]:
			if not ctx.progress[side].has(item.uid) or ctx.progress[side][item.uid]+EPS<1:continue
			if C.is_tag(item.kind,"weapon") and time+EPS<ctx.states[side].freeze_until:continue
			var cost=stamina_cost(ctx,side,item)
			if ctx.states[side].stamina+EPS<cost:
				waiting=true
				ctx.totals[side].stamina_wait_by_uid[item.uid]=float(ctx.totals[side].stamina_wait_by_uid.get(item.uid,0))+delta
				if not ctx.waiting[side][item.uid]:ctx.events.append(event(time,side,"tired",0,item.uid,"体力不足"));ctx.totals[side].tired+=1
				ctx.waiting[side][item.uid]=true
				continue
			ctx.waiting[side][item.uid]=false;ctx.states[side].stamina=maxf(0,ctx.states[side].stamina-cost)
			use_threshold_provisions(ctx,side,time,"stamina3")
			ctx.progress[side][item.uid]=0.0
			activate(ctx,side,item,time)
		# Components act after natural cooldowns roll over, so readiness is never wasted.
		for item in ctx.queues[side]:MATERIALS.tick(self,ctx,side,item,time)
		if waiting:ctx.totals[side].stamina_wait_seconds+=delta
	commit_pending(ctx,time)
	ctx.erase("planning_vitals")
	for side in range(2):
		var rate=fatigue_rate(time)
		var loss=minf(maxf(0,float(ctx.states[side].hp)),rate*delta)
		if loss>0:
			ctx.states[side].hp-=loss;ctx.totals[side].fatigue+=loss
			var ev=event(time,side,"fatigue",loss,"fatigue","疲劳")
			ev.value=loss;ev.hp_damage=loss;ev.target_side=side;ev.source="overtime";ev.rate=rate
			ctx.events.append(ev)
		use_threshold_provisions(ctx,side,time)
		ctx.states[side].hp=maxf(0,ctx.states[side].hp)
		for item in ctx.queues[side]:
			if ctx.progress[side].has(item.uid):ctx.timers[side][item.uid]=time+(1-ctx.progress[side][item.uid])*cooldown(ctx,side,item)
	commit_pending(ctx,time)
