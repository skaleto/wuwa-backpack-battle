extends RefCounted
## V60: explicit ordinary roots, non-recursive derived effects, simultaneous hit commit.
const C=preload("res://scripts/data/catalog.gd")
const BUILD=preload("res://scripts/battle/build_rules.gd")
const SUP=preload("res://scripts/party/supports.gd")
const POCKETS=preload("res://scripts/inventory/pocket_rules_current.gd")
const STEP=0.1
const EPS=0.000001
var inventory=BUILD.new()
var concerto_enabled=false
var event_order=0

func begin(a: Dictionary,b: Dictionary,seed_value: int=1) -> Dictionary:
	event_order=0
	var ctx={"builds":[a,b],"seed":seed_value,"time":0.0,"states":[],"queues":[],"progress":[{},{}],"timers":[{},{}],"bonuses":[{},{}],"waiting":[{},{}],"used":[[],[]],"events":[],"totals":[],"hits":[[],[]],"pending":[],"star_ready":[{},{}],"counter_ready":[{},{}]}
	for side in range(2):
		var build=ctx.builds[side]
		var queue=build.get("items",[]).filter(func(v):return C.items.get(v.get("kind",""),{}).get("v60",{}).get("active",false)).duplicate(true)
		var primary=inventory.primary_weapon(build).get("uid","")
		var carriers=[]
		for role in build.get("supports",[]):
			var uid=SUP.carrier(build,role).get("uid","")
			if not uid.is_empty() and uid!=primary:carriers.append(uid)
		queue.sort_custom(func(x,y):
			var xp=0 if x.uid==primary else 1 if x.uid in carriers else 2
			var yp=0 if y.uid==primary else 1 if y.uid in carriers else 2
			return xp<yp if xp!=yp else str(x.kind)+":"+str(x.uid)<str(y.kind)+":"+str(y.uid))
		ctx.queues.append(queue)
		var hp=90.0+float(build.get("round",1))*12.0
		ctx.states.append({"hp":hp,"max_hp":hp,"shield":0.0,"stamina":10.0,"energy":0.0,"concerto":0.0,"mark":0,"burn":0.0,"charge":0,"haste":0,"haste_until":0.0,"noise":0,"noise_until":0.0,"noise_next":0.0,"noise_source":{},"frost":0,"frost_until":0.0,"freeze_until":0.0,"frost_immune_until":0.0,"debuff_seen":false,"stamina_discount":0.0})
		ctx.totals.append({"damage":0.0,"heal":0.0,"shield":0.0,"bursts":0,"relays":0,"tired":0,"intros":0,"outros":0,"damage_by_uid":{},"energy_generated":0.0,"concerto_generated":0.0,"energy_wasted":0.0,"concerto_wasted":0.0,"resource_weighted":{"energy":0.0,"concerto":0.0},"resource_wasted":{"energy":0.0,"concerto":0.0},"first_burst":-1.0,"first_intro":-1.0,"stamina_wait_seconds":0.0,"stamina_wait_by_uid":{}})
		for item in queue:
			var pocket=inventory.pocket_bonus(item,build)
			ctx.bonuses[side][item.uid]={"speed":minf(.5,float(pocket.speed)),"multiplier":1.0+float(pocket.power)}
			ctx.waiting[side][item.uid]=false
			if model(item).get("activation","none")=="cooldown" and float(C.items[item.kind].get("cooldown",0))>0:
				ctx.progress[side][item.uid]=0.0
				ctx.timers[side][item.uid]=cooldown(ctx,side,item)
	for side in range(2):
		apply_character_opening(ctx,side)
		for item in ctx.queues[side]:
			if model(item).get("activation","")=="opening":use_supply(ctx,side,item,0)
		for shield in POCKETS.shields(ctx.builds[side],inventory):add_shield(ctx,side,shield.amount,0,shield.uid,"护盾匣")
	commit_pending(ctx,0)
	return ctx

# Character starts use the same bounded actions as items, with no passive hooks.
func apply_character_opening(ctx: Dictionary,side: int) -> void:
	var leader=str(ctx.builds[side].get("leader",""))
	var actions=C.characters.get(leader,{}).get("v60_opening",[])
	var item={"uid":"leader:"+leader,"kind":""}
	var bundle={"side":side,"actions":[]}
	ctx.pending.append(bundle)
	apply_actions(ctx,side,item,actions,0,false,bundle,"derived")

func model(item: Dictionary) -> Dictionary:
	return C.items.get(item.get("kind",""),{}).get("v60",{})

func cooldown(ctx: Dictionary,side: int,item: Dictionary) -> float:
	return float(C.items[item.kind].get("cooldown",0))*(1.0-float(ctx.bonuses[side].get(item.uid,{}).get("speed",0)))

func weapon_role_weight(ctx: Dictionary,side: int,item: Dictionary) -> float:
	if not C.is_tag(item.kind,"weapon"):return 0.0
	var build=ctx.builds[side]
	if inventory.primary_weapon(build).get("uid","")==item.uid:return 1.0
	for role in build.get("supports",[]):
		if SUP.carrier(build,role).get("uid","")==item.uid:return .5
	return .25

func weapon_damage_weight(ctx: Dictionary,side: int,item: Dictionary) -> float:
	var weight=weapon_role_weight(ctx,side,item)
	return 1.0 if weight==1.0 or weight==0.0 else .65 if weight==.5 else .5

func simulate(a: Dictionary,b: Dictionary,seed_value: int=1,capture_replay: bool=true) -> Dictionary:
	var ctx=begin(a,b,seed_value)
	var frames=[frame(0,ctx)]
	var winner=0
	var duration=45.0
	for tick in range(1,451):
		var time=float(tick)*STEP
		step(ctx,time)
		if capture_replay:frames.append(frame(time,ctx))
		if ctx.states[0].hp<=0 or ctx.states[1].hp<=0:
			winner=0 if ctx.states[0].hp<=0 and ctx.states[1].hp<=0 else 1 if ctx.states[1].hp<=0 else -1
			duration=time
			break
	if duration>=45:
		var difference=ctx.states[0].hp/ctx.states[0].max_hp-ctx.states[1].hp/ctx.states[1].max_hp
		winner=0 if absf(difference)<EPS else 1 if difference>0 else -1
	if not capture_replay:frames.append(frame(duration,ctx))
	return {"winner":winner,"duration":snappedf(duration,.1),"frames":frames,"events":ctx.events,"totals":ctx.totals,"used":ctx.used,"seed":seed_value}

# Progress is integrated over interval boundaries: a freeze ending at t does not
# accidentally grant progress for the preceding frozen 0.1 seconds.
func progression(ctx: Dictionary,side: int,item: Dictionary,start: float,end: float) -> float:
	var state=ctx.states[side]
	var weapon=C.is_tag(item.kind,"weapon")
	var active_start=maxf(start,float(state.freeze_until)) if weapon else start
	if active_start>=end-EPS:return 0
	var boundaries=[active_start,end]
	for boundary in [float(state.haste_until),float(state.frost_until) if weapon else end]:
		if boundary>active_start and boundary<end and boundary not in boundaries:boundaries.append(boundary)
	boundaries.sort()
	var progress=0.0
	for index in range(boundaries.size()-1):
		var midpoint=(float(boundaries[index])+float(boundaries[index+1]))*.5
		var rate=1.0+.04*int(state.haste) if midpoint<float(state.haste_until) else 1.0
		if weapon and midpoint<float(state.frost_until):rate*=1.0-.04*int(state.frost)
		progress+=(float(boundaries[index+1])-float(boundaries[index]))*rate
	return progress/maxf(EPS,cooldown(ctx,side,item))

func step(ctx: Dictionary,time: float) -> void:
	var previous=float(ctx.time)
	var delta=maxf(0,time-previous)
	if delta<=0:return
	ctx.time=time
	# Enemy-health conditionals read one shared pre-tick view, even when the
	# first actor plans an ordinary heal before the second actor plans damage.
	ctx.planning_vitals=ctx.states.map(func(state):return {"hp":state.hp,"max_hp":state.max_hp})
	# Both actors' cooldowns advance before either side's hostile statuses commit.
	for side in range(2):
		var state=ctx.states[side]
		state.stamina=minf(10,float(state.stamina)+2.0*delta)
		for item in ctx.queues[side]:
			if ctx.progress[side].has(item.uid):ctx.progress[side][item.uid]=minf(1,float(ctx.progress[side][item.uid])+progression(ctx,side,item,previous,time))
		if state.haste>0 and time+EPS>=float(state.haste_until):
			state.haste=0
			status_event(ctx,side,"haste",0,time,"",side,"迅捷消退")
		if state.frost>0 and time+EPS>=float(state.frost_until):
			state.frost=0;state.frost_until=0.0
			status_event(ctx,side,"frost",0,time,"",side,"霜渐消退")
		tick_noise(ctx,side,time)
	for side in range(2):
		var waiting=false
		for item in ctx.queues[side]:
			if not ctx.progress[side].has(item.uid) or float(ctx.progress[side][item.uid])+EPS<1:continue
			if C.is_tag(item.kind,"weapon") and time+EPS<float(ctx.states[side].freeze_until):continue
			var cost=stamina_cost(ctx,side,item)
			if float(ctx.states[side].stamina)+EPS<cost:
				waiting=true
				ctx.totals[side].stamina_wait_by_uid[item.uid]=float(ctx.totals[side].stamina_wait_by_uid.get(item.uid,0))+delta
				if not ctx.waiting[side][item.uid]:
					ctx.events.append(event(time,side,"tired",0,item.uid,"体力不足"));ctx.totals[side].tired+=1
				ctx.waiting[side][item.uid]=true
				continue
			ctx.waiting[side][item.uid]=false
			ctx.states[side].stamina=maxf(0,float(ctx.states[side].stamina)-cost)
			use_threshold_provisions(ctx,side,time,"stamina3")
			ctx.progress[side][item.uid]=0.0
			activate(ctx,side,item,time,true,"attack")
		if waiting:ctx.totals[side].stamina_wait_seconds+=delta
		use_threshold_provisions(ctx,side,time)
	ctx.erase("planning_vitals")
	commit_pending(ctx,time)
	for side in range(2):
		if time>=22:
			ctx.states[side].hp-=(1.0+(time-22.0)*1.5)*delta
		use_threshold_provisions(ctx,side,time)
		ctx.states[side].hp=maxf(0,float(ctx.states[side].hp))
		for item in ctx.queues[side]:
			if not ctx.progress[side].has(item.uid):continue
			var rate=1.0+.04*int(ctx.states[side].haste)
			if C.is_tag(item.kind,"weapon"):rate*=1.0-.04*int(ctx.states[side].frost)
			ctx.timers[side][item.uid]=time+(1.0-float(ctx.progress[side][item.uid]))*cooldown(ctx,side,item)/rate
	# A consumption triggered by damage may itself carry a derived star effect.
	commit_pending(ctx,time)

func stamina_cost(ctx: Dictionary,side: int,item: Dictionary) -> float:
	var cost=float(C.items[item.kind].get("stamina",0))
	if C.is_tag(item.kind,"weapon"):
		cost*=1.0-clampf(float(ctx.states[side].stamina_discount),0,1)
		var special=model(item).get("special",{}).get("haste_stamina",{})
		if not special.is_empty() and int(ctx.states[side].haste)>=int(special.get("min_stacks",4)):cost*=float(special.get("multiplier",.8))
	return cost

func activate(ctx: Dictionary,side: int,item: Dictionary,time: float,ordinary: bool=true,kind: String="attack",_scale: float=1.0,_relay_bonus: float=0.0) -> void:
	if not model(item).get("active",false):return
	var def=C.items[item.kind]
	var rules=model(item)
	var state=ctx.states[side]
	var special=rules.get("special",{})
	var actions=rules.get("actions",[]).duplicate(true)
	var attacking=actions.any(func(action):return action.get("type","")=="damage" and float(action.get("value",0))>0)
	var charged=ordinary and attacking and weapon_role_weight(ctx,side,item)==1.0 and int(state.charge)>=6
	var flat_bonus=0.0
	var bundle={"side":side,"actions":[]}
	ctx.pending.append(bundle)
	var trigger=event(time,side,"trigger",0,item.uid,def.get("name",item.kind));trigger.ordinary=ordinary
	ctx.events.append(trigger)
	if charged:
		state.charge-=6
		flat_bonus+=float(def.get("damage",0))*.8
		status_event(ctx,side,"charge",-6,time,item.uid,side,"充能消耗")
		var heavy=event(time,side,"heavy",float(def.get("damage",0))*.8,item.uid,"充能攻击");heavy.cue_only=true;heavy.ordinary=true
		ctx.events.append(heavy)
	if ordinary and attacking:
		var haste_damage=special.get("haste_damage",{})
		if not haste_damage.is_empty() and int(state.haste)>=int(haste_damage.get("min_stacks",6)):flat_bonus+=float(haste_damage.get("value",2))
		var low=special.get("low_hp_damage",{})
		var enemy=ctx.get("planning_vitals",ctx.states)[1-side]
		if not low.is_empty() and enemy.hp<enemy.max_hp*float(low.get("threshold",.35)):flat_bonus+=float(low.get("value",6))
		var strike=special.get("shield_strike",{})
		if not strike.is_empty():
			var spent=remove_shield(ctx,side,float(strike.get("consume",8)))
			flat_bonus+=spent*float(strike.get("multiplier",1.5))
			if spent>0:ctx.events.append(event(time,side,"shield_spend",spent,item.uid,"盾击消耗"))
	var applied=apply_actions(ctx,side,item,actions,time,ordinary,bundle,kind,flat_bonus)
	if ordinary and attacking:
		var eat=special.get("noise_consume",{})
		if not eat.is_empty() and (charged or not bool(eat.get("requires_charge",true))):
			bundle.actions.append({"type":"noise_consume","value":0,"item":item,"ordinary":false,"kind":"derived","rules":eat})
	if ordinary:
		var self_star=rules.get("star",{})
		if self_star.get("event","")=="self" or special.has("matched_healer_shield"):
			var matches=inventory.star_links(item,ctx.queues[side],ctx.builds[side])
			if not matches.is_empty() and (self_star.is_empty() or star_ready(ctx,side,item,time)):
				var self_actions=self_star.get("actions",[]).duplicate(true)
				var matched=special.get("matched_healer_shield",{})
				if not matched.is_empty():self_actions.append({"type":"shield","value":mini(matches.size(),int(matched.get("max_items",2)))*float(matched.get("per_item",1))})
				emit_star(ctx,side,item,item,time)
				var extra=apply_actions(ctx,side,item,self_actions,time,false,bundle,"derived")
				applied.shield+=extra.shield
		var conditional=special.get("haste_derived",{})
		if not conditional.is_empty() and int(state.haste)>=int(conditional.get("min_stacks",4)):
			apply_actions(ctx,side,item,[{"type":"damage","value":float(conditional.get("value",3))}],time,false,bundle,"derived")
		var roots=["activate"]
		if attacking:roots.append("attack")
		if float(applied.heal)>EPS:roots.append("heal")
		if float(applied.shield)>EPS:roots.append("shield")
		if C.is_tag(item.kind,"provision"):roots.append("supply")
		notify_stars(ctx,side,item,roots,time,bundle)

# Own state changes are visible during planning; opposing damage/statuses wait
# for commit, so simultaneous lethal activations do not favor side zero.
func apply_actions(ctx: Dictionary,side: int,item: Dictionary,actions: Array,time: float,ordinary: bool,bundle: Dictionary,kind: String="derived",flat_bonus: float=0.0) -> Dictionary:
	var applied={"heal":0.0,"shield":0.0}
	for action in actions:
		var type=str(action.get("type",""))
		var value=float(action.get("value",0))
		var scale=float(ctx.bonuses[side].get(item.uid,{}).get("multiplier",1))
		if type=="damage" and ordinary:
			value=value*scale*weapon_damage_weight(ctx,side,item)+flat_bonus
			flat_bonus=0
		elif ordinary and type in ["heal","shield"] and C.is_tag(item.kind,"echo"):value*=scale
		match type:
			"damage","break_shield","noise","frost":
				bundle.actions.append({"type":type,"value":value,"item":item,"ordinary":ordinary,"kind":kind})
			"heal":applied.heal+=heal(ctx,side,item,value,time,ordinary)
			"shield":applied.shield+=add_shield(ctx,side,value,time,item.uid,C.items.get(item.kind,{}).get("name",item.kind))
			"charge":
				var prior=int(ctx.states[side].charge)
				ctx.states[side].charge=clampi(prior+int(value),0,6)
				if prior!=ctx.states[side].charge:status_event(ctx,side,"charge",int(ctx.states[side].charge)-prior,time,item.uid,side,"充能")
			"haste":
				var prior=int(ctx.states[side].haste)
				ctx.states[side].haste=clampi(prior+int(value),0,6)
				if value>0:ctx.states[side].haste_until=time+6
				status_event(ctx,side,"haste",int(ctx.states[side].haste)-prior,time,item.uid,side,"迅捷")
			"cleanse":cleanse(ctx,side,int(value),time,item.uid)
			"stamina":
				var actual=maxf(0,minf(value,float(ctx.states[side].get("stamina_max",10.0))-float(ctx.states[side].stamina)))
				ctx.states[side].stamina+=actual
				if actual>0:ctx.events.append(event(time,side,"stamina",actual,item.uid,"体力回复"))
			"max_hp":
				ctx.states[side].max_hp+=value;ctx.states[side].hp+=value
				ctx.events.append(event(time,side,"max_hp",value,item.uid,"生命上限"))
			"stamina_discount":ctx.states[side].stamina_discount=maxf(float(ctx.states[side].stamina_discount),value)
	return applied

func star_ready(ctx: Dictionary,side: int,source: Dictionary,time: float) -> bool:
	var star=model(source).get("star",{})
	var family=str(star.get("family",source.kind))
	if time+EPS<float(ctx.star_ready[side].get(family,-1)):return false
	ctx.star_ready[side][family]=time+maxf(EPS,float(star.get("interval",0)))
	return true

func emit_star(ctx: Dictionary,side: int,source: Dictionary,trigger: Dictionary,time: float) -> void:
	var ev=event(time,side,"star_trigger",0,source.uid,C.items[source.kind].get("name",source.kind))
	ev.source_uid=source.uid;ev.trigger_uid=trigger.uid;ev.target_uid=trigger.uid;ev.ordinary=false
	ctx.events.append(ev)

func notify_stars(ctx: Dictionary,side: int,trigger: Dictionary,roots: Array,time: float,bundle: Dictionary) -> void:
	for source in ctx.queues[side]:
		var star=model(source).get("star",{})
		if star.is_empty() or star.get("event","") not in roots:continue
		var links=inventory.star_links(source,ctx.queues[side],ctx.builds[side])
		if not links.any(func(link):return link.uid==trigger.uid):continue
		if not star_ready(ctx,side,source,time):continue
		emit_star(ctx,side,source,trigger,time)
		apply_actions(ctx,side,source,star.get("actions",[]),time,false,bundle,"derived")

func use_supply(ctx: Dictionary,side: int,item: Dictionary,time: float) -> void:
	if item.uid in ctx.used[side]:return
	ctx.used[side].append(item.uid)
	ctx.events.append(event(time,side,"supply",0,item.uid,C.items.get(item.kind,{}).get("name",item.kind)))
	activate(ctx,side,item,time,true,"supply")

func use_threshold_provisions(ctx: Dictionary,side: int,time: float,activation_filter: String="") -> void:
	var state=ctx.states[side]
	if state.hp<=0:return
	for item in ctx.queues[side]:
		if item.uid in ctx.used[side]:continue
		var activation=str(model(item).get("activation","none"))
		if not activation_filter.is_empty() and activation!=activation_filter:continue
		var ready=(activation=="hp50" and state.hp<state.max_hp*.5) or (activation=="hp60" and state.hp<state.max_hp*.6) or (activation=="stamina3" and state.stamina<3) or (activation=="first_debuff" and bool(state.debuff_seen)) or (activation=="time6" and time+EPS>=6)
		if ready:use_supply(ctx,side,item,time)

func add_shield(ctx: Dictionary,side: int,amount: float,time: float,uid: String,label: String="护盾") -> float:
	var state=ctx.states[side]
	var actual=maxf(0,minf(amount,float(state.max_hp)*.4-float(state.shield)))
	if actual<=EPS:return 0
	state.shield+=actual;ctx.totals[side].shield+=actual
	ctx.events.append(event(time,side,"shield",actual,uid,label))
	return actual

func remove_shield(ctx:Dictionary,side:int,amount:float)->float:
	var removed=minf(float(ctx.states[side].shield),maxf(0,amount))
	ctx.states[side].shield-=removed
	return removed

func heal(ctx: Dictionary,side: int,item: Dictionary,amount: float,time: float,ordinary: bool=false) -> float:
	var state=ctx.states[side]
	var actual=maxf(0,minf(float(state.max_hp)-float(state.hp),amount))
	if actual<=EPS:return 0
	state.hp+=actual;ctx.totals[side].heal+=actual
	var ev=event(time,side,"heal",actual,item.uid,"实际回复");ev.ordinary_heal=ordinary;ev.ordinary=ordinary
	ctx.events.append(ev)
	return actual

func record_damage(ctx: Dictionary,side: int,uid: String,value: float) -> void:
	ctx.totals[side].damage+=value
	ctx.totals[side].damage_by_uid[uid]=float(ctx.totals[side].damage_by_uid.get(uid,0))+value

func deal_damage(ctx: Dictionary,side: int,item: Dictionary,amount: float,time: float,ordinary: bool,kind: String,counters: Array,check_thresholds: bool=true) -> void:
	if amount<=0:return
	var target=ctx.states[1-side]
	var blocked=minf(float(target.shield),amount)
	target.shield-=blocked;target.hp-=amount-blocked
	record_damage(ctx,side,item.get("uid",""),amount)
	var ev=event(time,side,kind,amount,item.get("uid",""),C.items.get(item.get("kind",""),{}).get("name",kind))
	ev.ordinary=ordinary;ev.absorbed=blocked;ev.hp_damage=amount-blocked;ev.element=C.items.get(item.get("kind",""),{}).get("element","neutral")
	ctx.events.append(ev)
	if ordinary and kind=="attack" and blocked>EPS:
		for source in ctx.queues[1-side]:
			var rule=model(source).get("special",{}).get("shield_counter",{})
			if rule.is_empty():continue
			var family=str(rule.get("family",source.kind))
			if time+EPS<float(ctx.counter_ready[1-side].get(family,-1)):continue
			ctx.counter_ready[1-side][family]=time+float(rule.get("interval",1.5))
			counters.append({"side":1-side,"item":source,"damage":float(rule.get("damage",3))})
	if check_thresholds:use_threshold_provisions(ctx,1-side,time)

func commit_pending(ctx: Dictionary,time: float) -> void:
	while not ctx.pending.is_empty():
		var pending=ctx.pending
		ctx.pending=[]
		var counters=[]
		for bundle in pending:
			var side=int(bundle.side)
			# All extra shield removal attached to this root precedes regular damage.
			for action in bundle.actions:
				if action.type!="break_shield":continue
				var removed=remove_shield(ctx,1-side,float(action.value))
				if removed>0:
					var ev=event(time,side,"break_shield",removed,action.item.uid,"额外削盾");ev.target_side=1-side
					ctx.events.append(ev)
			for action in bundle.actions:
				match str(action.type):
					"damage":deal_damage(ctx,side,action.item,float(action.value),time,bool(action.ordinary),str(action.kind),counters)
					"noise":apply_noise(ctx,side,action.item,int(action.value),time)
					"frost":apply_frost(ctx,side,action.item,int(action.value),time)
					"noise_consume":
						var layers=mini(int(ctx.states[1-side].noise),int(action.rules.get("max_layers",2)))
						if layers>0:
							ctx.states[1-side].noise-=layers
							status_event(ctx,side,"noise",-layers,time,action.item.uid,1-side,"光噪消耗")
							deal_damage(ctx,side,action.item,layers*float(action.rules.get("damage_per_layer",6)),time,false,"derived",counters)
		for counter in counters:deal_damage(ctx,int(counter.side),counter.item,float(counter.damage),time,false,"counter",[])

func apply_noise(ctx: Dictionary,side: int,item: Dictionary,layers: int,time: float) -> void:
	if layers<=0:return
	var target=ctx.states[1-side]
	var before=int(target.noise)
	if before==0:target.noise_next=time+2
	target.noise=mini(6,before+layers);target.noise_until=time+12;target.noise_source={"side":side,"item":item}
	target.debuff_seen=true
	status_event(ctx,side,"noise",int(target.noise)-before,time,item.uid,1-side,"光噪")
	use_threshold_provisions(ctx,1-side,time)

func tick_noise(ctx: Dictionary,side: int,time: float) -> void:
	var state=ctx.states[side]
	if int(state.noise)<=0:return
	while float(state.noise_next)<=time+EPS and float(state.noise_next)<=float(state.noise_until)+EPS:
		var source=state.noise_source
		if not source.is_empty():
			var bundle={"side":int(source.side),"actions":[{"type":"damage","value":int(state.noise),"item":source.item,"ordinary":false,"kind":"noise_tick"}]}
			ctx.pending.append(bundle)
		state.noise_next+=2
	if time+EPS>=float(state.noise_until):
		state.noise=0
		status_event(ctx,side,"noise",0,time,"",side,"光噪消退")

func apply_frost(ctx: Dictionary,side: int,item: Dictionary,layers: int,time: float) -> void:
	var target=ctx.states[1-side]
	for _layer in range(maxi(0,layers)):
		if time+EPS<float(target.frost_immune_until) or time+EPS<float(target.freeze_until):return
		target.frost+=1;target.frost_until=time+8;target.debuff_seen=true
		status_event(ctx,side,"frost",1,time,item.uid,1-side,"霜渐")
		deal_damage(ctx,side,item,1,time,false,"frost_hit",[],false)
		if int(target.frost)>=5:
			target.frost=0;target.frost_until=0.0;target.freeze_until=time+.6;target.frost_immune_until=time+3.6
			status_event(ctx,side,"freeze",.6,time,item.uid,1-side,"冻结")
		use_threshold_provisions(ctx,1-side,time)

func cleanse(ctx: Dictionary,side: int,layers: int,time: float,uid: String) -> void:
	var state=ctx.states[side]
	for _layer in range(maxi(0,layers)):
		var key="frost" if int(state.frost)>=int(state.noise) else "noise"
		if int(state[key])<=0:break
		state[key]-=1
		if key=="frost" and int(state.frost)==0:state.frost_until=0.0
		var ev=event(time,side,"cleanse",1,uid,"净化");ev.status=key;ev.stacks=int(state[key]);ev.target_side=side
		ctx.events.append(ev)

func status_event(ctx: Dictionary,side: int,status: String,value: float,time: float,uid: String,target_side: int,label: String) -> void:
	var ev=event(time,side,status,value,uid,label)
	ev.status=status;ev.target_side=target_side
	ev.stacks=1 if status=="freeze" and time<float(ctx.states[target_side].freeze_until) else int(ctx.states[target_side].get(status,0))
	ev.remaining=maxf(0,float(ctx.states[target_side].get(status+"_until",0))-time)
	ctx.events.append(ev)

func event(time: float,side: int,kind: String,value: float,uid: String,label: String) -> Dictionary:
	event_order+=1
	return {"order":event_order,"time":snappedf(time,.01),"side":side,"kind":kind,"value":snappedf(value,.1),"uid":uid,"label":label,"resources":false}

func frame(time: float,ctx: Dictionary) -> Dictionary:
	var sides=[]
	for side in range(2):
		var state=ctx.states[side]
		var visible={}
		for key in ["hp","max_hp","shield","stamina","energy","concerto","mark","burn","charge","haste","noise","frost"]:visible[key]=snappedf(float(state[key]),.001)
		visible.stamina_max=float(state.get("stamina_max",10.0))
		visible.freeze=maxf(0,float(state.freeze_until)-time)
		visible.frost_immunity=maxf(0,float(state.frost_immune_until)-maxf(time,float(state.freeze_until)))
		visible.statuses=[]
		for key in ["charge","haste","noise","frost"]:
			if int(state[key])>0:
				visible.statuses.append({"id":key,"label":{"charge":"充能","haste":"迅捷","noise":"光噪","frost":"霜渐"}[key],"stacks":int(state[key]),"remaining":maxf(0,float(state.get(key+"_until",0))-time)})
		if visible.freeze>EPS:visible.statuses.append({"id":"freeze","label":"冻结","stacks":1,"remaining":visible.freeze})
		sides.append(visible)
	return {"time":snappedf(time,.1),"sides":sides,"progress":ctx.progress.duplicate(true),"cooldown_fractions":ctx.progress.duplicate(true),"weapon_marks":[{},{}],"waiting":ctx.waiting.duplicate(true)}
