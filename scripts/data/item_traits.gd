extends RefCounted
## Bounded mechanics for the additional researched non-weapon items.
const C=preload("res://scripts/data/catalog.gd")

static func initialise(ctx: Dictionary) -> void:
	ctx.content_delays=[]
	for state in ctx.states:
		state.content={"until":{},"exposed_until":0.0,"dreamless_ready":{},"judgment_ready":false,"tide_count":0,"tide_active":false,"fusion_count":0,"lamp_stacks":0,"medical_uses":0,"photo_used":false,"photo_ready":false,"glasses_used":false}

static func find(ctx: Dictionary,side: int,kind: String) -> Dictionary:
	for item in ctx.queues[side]:
		if item.kind==kind:return item
	return {}

static func allowed(state: Dictionary,key: String,time: float,interval: float) -> bool:
	if time+.00001<float(state.content.until.get(key,0)):return false
	state.content.until[key]=time+interval
	return true

static func before_attack(engine,ctx: Dictionary,side: int,item: Dictionary,time: float,ordinary: bool) -> Dictionary:
	var result={"bonus":0.0,"pierce":0.0,"critical_bonus":0.0,"crit_chance":0.0,"multiplier":1.0}
	var state=ctx.states[side]
	if state.content.tide_active and (C.is_tag(item.kind,"weapon") or C.is_tag(item.kind,"echo")):result.multiplier=1.12
	if not ordinary:return result
	if item.kind=="dreamless" and state.content.dreamless_ready.get(item.uid,false):
		result.bonus+=6;state.content.dreamless_ready[item.uid]=false
	if C.is_tag(item.kind,"weapon"):
		if state.content.judgment_ready:result.critical_bonus=6;result.crit_chance=.12
		if C.is_tag(item.kind,"heavy"):
			if state.content.photo_ready:
				result.bonus+=5;state.content.photo_ready=false
				ctx.events.append(engine.event(time,side,"content_buff",5,item.uid,"今州一角 · 重击 +5"))
			var lamp=find(ctx,side,"lamp")
			if not lamp.is_empty() and state.content.lamp_stacks>0 and engine.inventory.adjacent(lamp,item):
				var bonus=2*int(state.content.lamp_stacks);result.bonus+=bonus;state.content.lamp_stacks=0
				ctx.events.append(engine.event(time,side,"content_buff",bonus,lamp.uid,"燃灯 · 重击奖励"))
		var magnifier=find(ctx,side,"magnifier")
		if not magnifier.is_empty() and state.puppet_pending and allowed(state,"magnifier",time,3):
			engine.add_hit(ctx,side,magnifier,2,time,false,"extra")
	if (C.is_tag(item.kind,"weapon") or C.is_tag(item.kind,"echo")) and ctx.states[1-side].content.exposed_until>time and not find(ctx,side,"answer").is_empty():result.pierce=.2
	return result

static func consume_critical(engine,ctx: Dictionary,side: int,item: Dictionary,time: float) -> void:
	ctx.states[side].content.judgment_ready=false
	ctx.events.append(engine.event(time,side,"content_buff",6,item.uid,"审判令旗 · 暴击 +6"))

static func after_attack(engine,ctx: Dictionary,side: int,item: Dictionary,time: float,ordinary: bool) -> void:
	if not ordinary:return
	var state=ctx.states[side]
	if item.kind=="wuka":
		ctx.states[1-side].content.exposed_until=maxf(float(ctx.states[1-side].content.exposed_until),time+5*ctx.bonuses[side][item.uid].multiplier)
		ctx.events.append(engine.event(time,side,"weaken",5,item.uid,"呜咔咔 · 共振削弱"))
	if item.kind=="cyan_heron" and allowed(state,"cyan_interrupt",time,8):ctx.content_delays.append({"side":side,"uid":item.uid,"heavy":true,"amount":.6*ctx.bonuses[side][item.uid].multiplier})
	if item.kind=="zig" and allowed(state,"zig_stasis",time,1):ctx.content_delays.append({"side":side,"uid":item.uid,"heavy":false,"amount":.3*ctx.bonuses[side][item.uid].multiplier})
	if not C.is_tag(item.kind,"echo"):return
	var starfall=find(ctx,side,"starfall")
	if not starfall.is_empty() and not state.content.tide_active:
		state.content.tide_count+=1
		if state.content.tide_count>=4:
			state.content.tide_active=true
			ctx.events.append(engine.event(time,side,"tide",12,starfall.uid,"坠星 · 焚潮"))
	var elegance=find(ctx,side,"elegance")
	if not elegance.is_empty() and engine.inventory.element(item,ctx.builds[side])=="fusion":
		state.content.fusion_count+=1
		if int(state.content.fusion_count)%4==0 and allowed(state,"elegance",time,6):engine.add_hit(ctx,side,elegance,8,time,false,"extra")

static func resolve_delays(engine,ctx: Dictionary,time: float) -> void:
	# Apply after both sides have planned their normal actions, preserving symmetry.
	for delay in ctx.content_delays:
		var side=1-int(delay.side)
		var targets=ctx.queues[side].filter(func(v):return C.is_tag(v.kind,"weapon") and (not delay.heavy or C.is_tag(v.kind,"heavy")) and ctx.timers[side].has(v.uid))
		targets.sort_custom(func(a,b):return a.uid<b.uid if is_equal_approx(float(ctx.timers[side][a.uid]),float(ctx.timers[side][b.uid])) else ctx.timers[side][a.uid]<ctx.timers[side][b.uid])
		if targets.is_empty():continue
		ctx.timers[side][targets[0].uid]+=float(delay.amount)
		ctx.events.append(engine.event(time,int(delay.side),"delay",delay.amount,delay.uid,"声骸 · 延迟出手"))
	ctx.content_delays=[]

static func on_relay(engine,ctx: Dictionary,side: int,time: float) -> void:
	var source=find(ctx,side,"judgment")
	if not source.is_empty() and allowed(ctx.states[side],"judgment",time,6):ctx.states[side].content.judgment_ready=true

static func on_burst(ctx: Dictionary,side: int) -> void:
	for item in ctx.queues[side]:
		if item.kind=="dreamless":ctx.states[side].content.dreamless_ready[item.uid]=true

static func on_shield(ctx: Dictionary,side: int,time: float) -> void:
	if not find(ctx,side,"lamp").is_empty() and allowed(ctx.states[side],"lamp",time,1):ctx.states[side].content.lamp_stacks=mini(3,int(ctx.states[side].content.lamp_stacks)+1)

static func on_consume(engine,ctx: Dictionary,side: int,item: Dictionary,time: float) -> void:
	if item.kind not in ["nutrition","revive"]:return
	var source=find(ctx,side,"medical")
	if source.is_empty() or ctx.states[side].content.medical_uses>=2 or not engine.inventory.adjacent(source,item):return
	ctx.states[side].content.medical_uses+=1
	engine.add_shield(ctx,side,5,time,source.uid,"悬壶仁心 · 药品救急")

static func on_threshold(engine,ctx: Dictionary,side: int,time: float) -> void:
	var state=ctx.states[side]
	if state.hp<=0:return
	if not state.content.photo_used and state.hp<state.max_hp*.3 and not find(ctx,side,"city_photo").is_empty():
		state.content.photo_used=true;state.content.photo_ready=true
	var glasses=find(ctx,side,"glasses")
	if not state.content.glasses_used and state.hp<state.max_hp*.4 and not glasses.is_empty():
		state.content.glasses_used=true
		for echo in ctx.queues[side]:
			if C.is_tag(echo.kind,"echo") and float(C.items[echo.kind].get("heal",0))>0 and engine.inventory.adjacent(glasses,echo) and ctx.timers[side].has(echo.uid):
				ctx.timers[side][echo.uid]=minf(float(ctx.timers[side][echo.uid]),time)
				ctx.events.append(engine.event(time,side,"content_buff",1,glasses.uid,"监测眼镜 · 治疗声骸就绪"))
