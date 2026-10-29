extends "res://scripts/battle/battle_v75.gd"
## Twelve explicit cores, on the existing natural-input / derived-output boundary.
func profile(item:Dictionary)->Dictionary:return C.profile(str(item.get("kind","")))
func rule(item:Dictionary)->String:
	return "" if C.items.get(item.get("kind",""),{}).has("v124") else super.rule(item)
func begin(a:Dictionary,b:Dictionary,seed_value:int=1)->Dictionary:
	var ctx=super.begin(a,b,seed_value)
	ctx.core_sources=[[],[]]
	for side in 2:ctx.core_sources[side]=ctx.queues[side].filter(func(i):return profile(i).has("rule"))
	return ctx
func opening(ctx:Dictionary,side:int,item:Dictionary)->void:
	if not ctx.has("core_sources"):ctx.core_sources=[[],[]]
	ctx.core_sources[side]=ctx.queues[side].filter(func(i):return profile(i).has("rule"))
	super.opening(ctx,side,item)
	var n=profile(item)
	if float(n.get("opening_charge",0))>0:resource(ctx,side,item,"charge",n.opening_charge,0)
func before_attack(ctx:Dictionary,side:int,item:Dictionary,t:float,charged:bool)->void:
	super.before_attack(ctx,side,item,t,charged)
	var n=profile(item)
	if not n.has("rule"):return
	var s=own(ctx,side,item);s.core_burst=false
	if s.get("core_ready",false):
		s.core_ready=false;s.core_burst=true
		core_prepare(s,n.prepare_flat,n.get("break_amount",0) if n.rule=="laser" else 0)
		if n.rule=="steel":support_heal(ctx,side,item,n.punch_heal,t)
	if n.rule in ["rock","verdant"]:buff(ctx,side,item,item,"break",n.break_amount,t)
	if n.rule=="frost" and (int(s.get("core_attacks",0))+1)%int(n.prepare_every)==0 and ctx.states[1-side].frost>=n.frost_min:
		core_prepare(s,n.prepare_flat);s.core_burst=true
	if not charged:return
	match n.rule:
		"morning":buff(ctx,side,item,item,"flat",n.charged_flat,t)
		"east":
			buff(ctx,side,item,item,"flat",float(s.get("core_stack",0))*n.stack_flat,t);s.core_stack=0
		"verdant":
			var spent=remove_shield(ctx,side,float(n.shield_spend))
			if spent>EPS:
				buff(ctx,side,item,item,"flat",spent*n.shield_ratio,t)
				var ev=event(t,side,"shield_spend",spent,item.uid,"护盾转化");ev.actual_value=spent;ctx.events.append(ev)
func core_prepare(s:Dictionary,value:float,breaking:float=0)->void:
	var prepared:Dictionary=s.get("card_prepared",{}).duplicate(true)
	prepared.value=float(prepared.get("value",0))+value
	prepared.breaking=float(prepared.get("breaking",0))+breaking
	s.card_prepared=prepared
func natural(ctx:Dictionary,side:int,trigger:Dictionary,event_kind:String,t:float,data:Dictionary={})->void:
	if ctx.has("local") and profile(trigger).has("rule") and event_kind=="attack":
		data=data.duplicate(true);data.burst=own(ctx,side,trigger).get("core_burst",false)
	super.natural(ctx,side,trigger,event_kind,t,data)
	if not ctx.has("core_sources"):return
	var n=profile(trigger);var s=own(ctx,side,trigger)
	if n.has("rule") and event_kind=="attack":
		s.core_attacks=int(s.get("core_attacks",0))+1
		if int(n.get("charge_every",0))>0 and s.core_attacks%int(n.charge_every)==0:resource(ctx,side,trigger,"charge",n.charge_gain,t)
		if n.rule in ["feijing","laser","yunlang"]:
			if s.get("core_burst",false):
				if n.rule!="yunlang":
					advance_item(ctx,side,trigger,n.self_advance,t)
					advance_longest(ctx,side,trigger,n.partner_advance,t)
			if s.core_attacks%int(n.prepare_every)==0:
				s.core_ready=true
				ctx.events.append(event(t,side,"combo_ready",n.prepare_flat,trigger.uid,"强化准备"))
	if n.get("rule","")=="morning" and event_kind=="charged":
		for partner in linked(ctx,side,trigger,"weapon"):buff(ctx,side,partner,trigger,"flat",n.partner_flat,t,8)
	for source in ctx.core_sources[side]:
		if source.uid==trigger.uid or not has_link(ctx,side,source,trigger):continue
		core_star(ctx,side,source,trigger,event_kind,t,data)
func core_star(ctx:Dictionary,side:int,source:Dictionary,trigger:Dictionary,event_kind:String,t:float,data:Dictionary)->void:
	var n=profile(source);var s=own(ctx,side,source)
	var attack=event_kind=="attack" and ACTIVITY.attacks(trigger)
	var weapon=C.is_tag(trigger.kind,"weapon");var echo=C.is_tag(trigger.kind,"echo")
	var paid=false
	match n.rule:
		"wing","morning":
			if attack and echo and core_threshold(s,"echo",int(n.star_threshold)) and core_gate_ready(ctx,side,source,"core_echo",t) and ctx.states[side].charge<6:
				s.core_echo=0;resource(ctx,side,source,"charge",n.star_charge,t);gate(ctx,side,source,"core_echo",t,n.star_period);paid=true
		"east":
			if attack and weapon:
				var old=int(s.get("core_stack",0));s.core_stack=mini(n.stack_cap,old+1);paid=s.core_stack>old
		"verdant":
			if event_kind=="shield" and float(data.get("amount",0))>EPS and ctx.states[side].charge<6 and gate(ctx,side,source,"core_shield",t,n.star_period):resource(ctx,side,source,"charge",n.star_charge,t);paid=true
		"frost":
			var pending_key=source.kind+":core_frost_pending"
			if attack and weapon and core_threshold(s,"weapon",int(n.star_threshold)) and core_gate_ready(ctx,side,source,"core_frost",t) and not ctx.team[side].get(pending_key,false):
				ctx.team[side][pending_key]=true
				ctx.pending.append({"side":side,"actions":[{"type":"frost","value":1,"item":source,"ordinary":false,"core_star_trigger":trigger}]})
		"yunlang":
			if attack and echo:
				var prior=str(s.get("core_last_echo",""));s.core_last_echo=trigger.kind
				if not prior.is_empty() and prior!=trigger.kind and gate(ctx,side,source,"core_alternate",t,n.star_period):
					resource(ctx,side,source,"haste",1,t);advance_item(ctx,side,source,n.self_advance,t);paid=true
		"haixing","qianban":
			if event_kind=="shield" and float(data.get("amount",0))>EPS and gate(ctx,side,source,"core_prepare",t,n.star_period):buff(ctx,side,source,source,"flat",n.partner_flat,t,8);paid=true
		"steel":
			if event_kind=="heal" and float(data.get("amount",0))>EPS and core_gate_ready(ctx,side,source,"core_shield",t):
				paid=add_shield(ctx,side,n.star_shield,t,source.uid,"治疗转盾")>EPS
				if paid:gate(ctx,side,source,"core_shield",t,n.star_period)
		"rock":
			if attack and weapon and core_threshold(s,"weapon",int(n.star_threshold)):
				s.core_weapon=0;paid=float(s.get("next_shield",0))<float(n.shield_bonus);s.next_shield=n.shield_bonus
	if paid:effect_feedback(ctx,side,source,trigger,source,t)
func finish_pending_action(ctx:Dictionary,side:int,action:Dictionary,t:float,applied:bool)->void:
	super.finish_pending_action(ctx,side,action,t,applied)
	if not action.has("core_star_trigger"):return
	var source=action.item
	ctx.team[side].erase(source.kind+":core_frost_pending")
	if applied:
		own(ctx,side,source).core_weapon=0
		gate(ctx,side,source,"core_frost",t,profile(source).star_period)
		effect_feedback(ctx,side,source,action.core_star_trigger,source,t)
func core_threshold(s:Dictionary,key:String,threshold:int)->bool:
	key="core_"+key;s[key]=mini(threshold,int(s.get(key,0))+1)
	return int(s[key])>=threshold
func core_gate_ready(ctx:Dictionary,side:int,item:Dictionary,key:String,t:float)->bool:
	return t+EPS>=float(ctx.icd[side].get(str(item.kind)+":"+key,-100))
func deal_v75_damage(ctx:Dictionary,side:int,item:Dictionary,amount:float,t:float,ordinary:bool,kind:String,pierce:float=0,charged:bool=false,prepared:bool=false)->void:
	var blocked=minf(float(ctx.states[1-side].shield),maxf(0,amount-pierce))
	super.deal_v75_damage(ctx,side,item,amount,t,ordinary,kind,pierce,charged,prepared)
	if blocked<=EPS or not ordinary or kind!="attack" or not ctx.has("core_sources"):return
	for source in ctx.core_sources[1-side]:
		var n=profile(source);var s=own(ctx,1-side,source)
		if n.rule in ["haixing","qianban"]:
			var root_key=str(item.uid)+":"+str(t)
			if s.get("core_block_root","")==root_key:continue
			s.core_block_root=root_key
			if core_threshold(s,"blocks",int(n.block_threshold)) and gate(ctx,1-side,source,"core_counter",t,n.counter_period):
				s.core_blocks=0;queue_hit(ctx,1-side,source,n.counter_damage,t,"counter")
		elif n.rule=="steel":
			s.core_block_amount=minf(float(n.block_amount),float(s.get("core_block_amount",0))+blocked)
			if s.core_block_amount>=n.block_amount and not s.get("core_ready",false) and gate(ctx,1-side,source,"core_counter",t,n.counter_period):
				s.core_block_amount=0.0;s.core_ready=true
				ctx.events.append(event(t,1-side,"combo_ready",n.prepare_flat,source.uid,"反击准备"))
func frame(t:float,ctx:Dictionary)->Dictionary:
	var out=super.frame(t,ctx)
	if not ctx.has("core_sources"):return out
	for side in 2:
		for item in ctx.core_sources[side]:
			var n=profile(item);var s=own(ctx,side,item);var meter={}
			if n.rule in ["feijing","laser","yunlang"]:meter={"kind":"derived","count":int(n.prepare_every) if s.get("core_ready",false) else int(s.get("core_attacks",0))%int(n.prepare_every),"total":int(n.prepare_every)}
			elif n.rule=="east":meter={"kind":"charge","count":int(s.get("core_stack",0)),"total":int(n.stack_cap)}
			elif n.rule in ["haixing","qianban"]:meter={"kind":"counter","count":int(s.get("core_blocks",0)),"total":int(n.block_threshold)}
			elif n.rule=="steel":meter={"kind":"counter","count":int(n.block_amount) if s.get("core_ready",false) else int(s.get("core_block_amount",0)),"total":int(n.block_amount)}
			if not meter.is_empty():out.combo_meters[side][item.uid]=meter
	return out
