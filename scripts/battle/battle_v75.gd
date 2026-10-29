extends "res://scripts/battle/battle_v60.gd"
## V75 source-scoped clocks and explicit handlers. V60 remains only for unspecced saves.
const STAMINA=preload("res://scripts/battle/stamina_rules.gd")
const CREW114=preload("res://scripts/party/crew_battle_v114.gd")
const CREW115=preload("res://scripts/party/crew_battle_v115.gd")
const CREW=preload("res://scripts/party/crew_combat.gd")
const ACTIVITY=preload("res://scripts/battle/item_activity.gd")
const COMBOS=preload("res://scripts/battle/combo_effects.gd")
const MATERIALS=preload("res://scripts/battle/material_effects.gd")
const RULES=preload("res://scripts/battle/battle_v75_rules.gd")
func profile(item:Dictionary)->Dictionary:return C.items.get(item.get("kind",""),{}).get("v75",{})
func rule(item:Dictionary)->String:return RULES.NAMES.get(item.get("kind",""),"")
func model(item:Dictionary)->Dictionary:
	return {"active":false} if not profile(item).is_empty() else super.model(item)
func own(ctx:Dictionary,side:int,item:Dictionary)->Dictionary:
	if not ctx.local[side].has(item.uid):ctx.local[side][item.uid]={"count":0,"stack":0,"until":0.0,"seen":{},"buffs":{},"clocks":{},"last_hit":-100.0}
	return ctx.local[side][item.uid]
func gate(ctx:Dictionary,side:int,item:Dictionary,key:String,t:float,period:float)->bool:
	var id=str(item.kind)+":"+key
	if t+EPS<float(ctx.icd[side].get(id,-100)):return false
	ctx.icd[side][id]=t+period
	return true
func remove_shield(ctx:Dictionary,side:int,amount:float)->float:
	var removed=super.remove_shield(ctx,side,amount)
	CREW114.shield_removed(ctx,side,removed)
	return removed
func resource(ctx:Dictionary,side:int,item:Dictionary,key:String,value:float,t:float)->void:
	var bundle={"side":side,"actions":[]}
	var before=float(ctx.states[side].get(key,0));var start=ctx.events.size()
	super.apply_actions(ctx,side,item,[{"type":key,"value":value}],t,false,bundle)
	if key=="stamina" and ctx.events.size()>start:ctx.events.back().actual_value=float(ctx.states[side].stamina)-before
func queue_hit(ctx:Dictionary,side:int,item:Dictionary,damage:float,t:float,kind:String="derived",extra:Dictionary={})->void:
	var action={"type":"damage","value":damage,"item":item,"ordinary":kind=="attack","kind":kind}
	action.merge(extra,true)
	ctx.pending.append({"side":side,"actions":[action]})
func begin(a:Dictionary,b:Dictionary,seed_value:int=1)->Dictionary:
	# V75 model suppresses all old opening/action handlers during base allocation.
	var ctx=super.begin(a,b,seed_value)
	ctx.local=[{},{}];ctx.icd=[{},{}];ctx.origins=[{},{}];ctx.noise_parts=[[],[]];ctx.team=[{},{}]
	for side in range(2):
		ctx.totals[side].fatigue=0.0
		ctx.states[side].stamina_max=STAMINA.MAXIMUM
		ctx.states[side].stamina=STAMINA.MAXIMUM
		ctx.queues[side]=ctx.builds[side].get("items",[]).filter(func(i):return not profile(i).is_empty() or super_active(i)).duplicate(true)
		# Equal-status weapons: deterministic order only breaks simultaneous readiness ties.
		ctx.queues[side].sort_custom(func(x,y):return str(x.kind)+":"+str(x.uid)<str(y.kind)+":"+str(y.uid))
		for item in ctx.queues[side]:
			var n=profile(item)
			if n.is_empty():continue
			var s=own(ctx,side,item)
			var pocket=inventory.pocket_bonus(item,ctx.builds[side])
			ctx.bonuses[side][item.uid]={"speed":minf(.5,float(pocket.speed)),"multiplier":1.0+float(pocket.power)}
			ctx.waiting[side][item.uid]=false
			if ACTIVITY.has_clock(item):
				ctx.progress[side][item.uid]=0.0;ctx.timers[side][item.uid]=cooldown(ctx,side,item)
			else:ctx.progress[side].erase(item.uid);ctx.timers[side].erase(item.uid)
			for clock_key in ["heal","shield","noise","frost"]:
				var p=float(n.get(clock_key+"Period",0))
				if p>0:s.clocks[clock_key]=p
			if item.kind in ["glasses","echo_butterfly"]:s.clocks.cleanse=8.0
			if item.kind=="violet":s.clocks.stance=5.0
			if item.kind=="bellborne":s.clocks.ward=6.0
			if rule(item)=="穿击枪-26型":s.clocks.aim=5.0
			var hp=float(n.hp)
			if hp>float(ctx.origins[side].get("hp",0)):
				resource(ctx,side,item,"max_hp",hp-float(ctx.origins[side].get("hp",0)),0);ctx.origins[side].hp=hp
		for item in ctx.queues[side]:
			if profile(item).is_empty():continue
			opening(ctx,side,item)
	commit_pending(ctx,0)
	CREW.setup(ctx)
	CREW114.setup(ctx)
	CREW115.setup(ctx)
	return ctx
func super_active(item:Dictionary)->bool:return super.model(item).get("active",false)
func opening(ctx:Dictionary,side:int,item:Dictionary)->void:
	MATERIALS.opening(self,ctx,side,item)
	var n=profile(item);var name=rule(item)
	if float(n.openingShield)>=12:
		var actual=add_shield(ctx,side,12,0,item.uid,"开场护盾")
		if actual>0:natural(ctx,side,item,"shield",0,{"amount":actual})
	if item.kind=="tea" or item.kind=="maocai" or name=="龙抬头":supply_event(ctx,side,item,0)
	if item.kind=="rations":resource(ctx,side,item,"stamina_discount",.15,0);supply_event(ctx,side,item,0)
	if item.kind=="daily_tea" or name=="西升":resource(ctx,side,item,"haste",2 if item.kind=="daily_tea" else 3,0)
	if item.kind=="daily_tea":supply_event(ctx,side,item,0)
	if (item.kind=="spicy_meat" and not n.get("cyclic_supply",false)) or name in ["金穹","翼锋","永远的启明星","阳焰","悲喜剧"]:
		resource(ctx,side,item,"charge",3,0)
		if item.kind=="spicy_meat":supply_event(ctx,side,item,0)
	if name=="狂欢者—船长印章":
		var targets=linked(ctx,side,item,"weapon");sort_damage(targets)
		if not targets.is_empty():buff(ctx,side,targets[0],item,"flat",3,0,999,2)
func cooldown(ctx:Dictionary,side:int,item:Dictionary)->float:
	var n=profile(item)
	return super.cooldown(ctx,side,item) if n.is_empty() else float(n.cd)*(1.0-float(ctx.bonuses[side].get(item.uid,{}).get("speed",0)))
func weapon_role_weight(_ctx:Dictionary,_side:int,item:Dictionary)->float:
	return 1.0 if C.is_tag(item.kind,"weapon") else 0.0
func weapon_damage_weight(_ctx:Dictionary,_side:int,_item:Dictionary)->float:return 1.0
func stamina_cost(ctx:Dictionary,side:int,item:Dictionary)->float:
	return super.stamina_cost(ctx,side,item) if profile(item).is_empty() else float(profile(item).stamina)*(1.0-float(ctx.states[side].stamina_discount))
func progression(ctx:Dictionary,side:int,item:Dictionary,start:float,end:float)->float:
	var v=super.progression(ctx,side,item,start,end)
	if not profile(item).is_empty() and rule(item) in ["暗夜迅刀·黑闪","暗夜佩枪·暗星"] and own(ctx,side,item).count<2:v*=1.25
	return v
func step(ctx:Dictionary,time:float)->void:
	if not ctx.has("local"):return
	var previous=float(ctx.time);var delta=time-previous
	if delta<=0:return
	ctx.time=time
	ctx.planning_vitals=ctx.states.map(func(st):return {"hp":st.hp,"max_hp":st.max_hp,"shield":st.shield,"noise":st.noise,"frost":st.frost})
	for side in range(2):
		var state=ctx.states[side]
		state.stamina=minf(STAMINA.MAXIMUM,state.stamina+STAMINA.RECOVERY_PER_SECOND*delta)
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
			if CREW114.volley(self,ctx,side,item,time,delta):continue
			if C.is_tag(item.kind,"weapon") and time+EPS<ctx.states[side].freeze_until:continue
			var cost=stamina_cost(ctx,side,item)
			if ctx.states[side].stamina+EPS<cost:
				waiting=true
				ctx.totals[side].stamina_wait_by_uid[item.uid]=float(ctx.totals[side].stamina_wait_by_uid.get(item.uid,0))+delta
				if not ctx.waiting[side][item.uid]:ctx.events.append(event(time,side,"tired",0,item.uid,"体力不足"));ctx.totals[side].tired+=1
				ctx.waiting[side][item.uid]=true
				continue
			ctx.waiting[side][item.uid]=false;ctx.states[side].stamina=maxf(0,ctx.states[side].stamina-cost)
			CREW115.record_spent(ctx,side,cost,time,item.uid)
			use_threshold_provisions(ctx,side,time,"stamina3")
			ctx.progress[side][item.uid]=0.0
			activate(ctx,side,item,time)
		# Components act after natural cooldowns roll over, so readiness is never wasted.
		for item in ctx.queues[side]:
			MATERIALS.tick(self,ctx,side,item,time)
			CREW114.specialty_tick(self,ctx,side,item,time)
		if waiting or is_equal_approx(float(ctx.crew114[side].stamina_wait_at),time):ctx.totals[side].stamina_wait_seconds+=delta
	commit_pending(ctx,time)
	CREW.process(self,ctx,time)
	CREW115.process(self,ctx,time)
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
func fatigue_rate(time:float)->float:return 1+(time-22)*1.5 if time>=22 else 0.0

func tick_source(ctx:Dictionary,side:int,item:Dictionary,t:float)->void:
	var s=own(ctx,side,item);var n=profile(item)
	if rule(item)=="云琅" and s.has("layer_times"):
		s.layer_times=s.layer_times.filter(func(deadline):return deadline>t+EPS);s.stack=s.layer_times.size()
	if rule(item)!="云琅" and float(s.until)>0 and t+EPS>=s.until:s.stack=0;s.until=0.0
	if s.get("window",0.0)>0 and t+EPS>=s.window:
		s.locked=s.window+float(s.get("lock_period",4));s.window=0.0
	if s.get("dance_active",false) and t+EPS>=s.get("dance_until",0):s.dance_active=false;s.dance_lock=float(s.dance_until)+5
	if s.get("stance_end",0.0)>0 and t+EPS>=s.stance_end:end_stance(ctx,side,item,t)
	for key in s.clocks.keys():
		if t+EPS<float(s.clocks[key]):continue
		var period=float(n.get(key+"Period",0))
		match key:
			"heal":support_heal(ctx,side,item,float(n.healAmount),t)
			"shield":
				var amount=float(n.shieldAmount)+float(s.get("next_shield",0));s.next_shield=0
				var actual=add_shield(ctx,side,amount,t,item.uid)
				if actual>0:natural(ctx,side,item,"shield",t,{"amount":actual})
			"noise","frost":ctx.pending.append({"side":side,"actions":[{"type":key,"value":1,"item":item,"ordinary":true,"kind":"support"}]})
			"cleanse":period=8;cleanse(ctx,side,1,t,item.uid)
			"ward":period=6;ctx.team[side].ward=3;ctx.team[side].ward_until=t+6
			"stance":period=5;s.stance_end=t+2+float(s.get("extension",0));s.extension=0;s.caught=false
			"aim":
				period=5
				if t-float(ctx.team[side].get("last_hp_hit",0))+EPS>=5:s.stack=mini(2,int(s.stack)+1)
			"store":
				period=2
				if t<=float(s.get("store_until",0))+EPS:s.stack=mini(4,int(s.stack)+1);s.until=float(s.store_until)
				else:s.clocks.erase(key);continue
		s.clocks[key]=float(s.clocks[key])+maxf(EPS,period)
func support_heal(ctx:Dictionary,side:int,item:Dictionary,amount:float,t:float)->float:
	var s=own(ctx,side,item);var name=rule(item);var before=ctx.states[side].hp/ctx.states[side].max_hp
	if name in ["源能长刃·测壹","源能迅刀·测贰","源能佩枪·测叁","源能臂铠·测肆","重破刃-41型"] and before<.4:amount+=1
	amount+=float(s.get("next_heal",0));s.next_heal=0
	# 异度 consumes one prepared addition, selected deterministically, without a recursive heal root.
	for source in ctx.queues[side]:
		if rule(source)!="异度":continue
		var ss=own(ctx,side,source)
		if ss.get("heal_ready",false) and (source.uid==item.uid or has_link(ctx,side,source,item)) and gate(ctx,side,source,"heal",t,5):amount+=2;ss.heal_ready=false;break
	var actual=heal(ctx,side,item,amount,t,true)
	if actual>0:
		natural(ctx,side,item,"heal",t,{"amount":actual,"before":before,"after":ctx.states[side].hp/ctx.states[side].max_hp})
		if name=="栖霞饮露" and t-float(ctx.team[side].get("last_frost",-100))<=6 and gate(ctx,side,item,"heal_chain",t,6):s.next_heal=3
	return actual
func supply_event(ctx:Dictionary,side:int,item:Dictionary,t:float)->void:
	if item.uid in ctx.used[side]:return
	ctx.used[side].append(item.uid);ctx.events.append(event(t,side,"supply",0,item.uid,rule(item)))
	natural(ctx,side,item,"supply",t)
func use_threshold_provisions(ctx:Dictionary,side:int,t:float,activation_filter:String="")->void:
	if not ctx.has("local"):super.use_threshold_provisions(ctx,side,t,activation_filter);return
	var state=ctx.states[side]
	if state.hp<=0:return
	for item in ctx.queues[side]:
		var n=profile(item)
		if n.is_empty():continue
		var s=own(ctx,side,item);var name=rule(item)
		if float(n.emergency)>0 and state.hp<state.max_hp*.5 and not ctx.origins[side].get("emergency",false):
			ctx.origins[side].emergency=true
			var before=state.hp/state.max_hp
			var actual=heal(ctx,side,item,float(n.emergency),t,true)
			if actual>0:natural(ctx,side,item,"heal",t,{"amount":actual,"before":before,"after":state.hp/state.max_hp})
			if C.is_tag(item.kind,"provision"):supply_event(ctx,side,item,t)
		if float(n.openingShield)==8 and state.hp<state.max_hp*.6 and not s.get("threshold_shield",false):
			s.threshold_shield=true;var actual=add_shield(ctx,side,8,t,item.uid)
			if actual>0:natural(ctx,side,item,"shield",t,{"amount":actual})
			if C.is_tag(item.kind,"provision"):supply_event(ctx,side,item,t)
		if ((item.kind=="soup" and not n.get("cyclic_supply",false)) or name=="龙抬头") and state.stamina<3 and not s.get("stamina_used",false):
			s.stamina_used=true;resource(ctx,side,item,"stamina",4,t);supply_event(ctx,side,item,t)
		if item.kind=="revive" and state.debuff_seen and not s.get("cleanse_used",false):
			s.cleanse_used=true;cleanse(ctx,side,1,t,item.uid);supply_event(ctx,side,item,t)
		if name=="舒云秘制凉茶" and (state.debuff_seen or t+EPS>=6) and not s.get("cleanse_used",false):
			s.cleanse_used=true;cleanse(ctx,side,2,t,item.uid);resource(ctx,side,item,"haste",2,t);supply_event(ctx,side,item,t)
	# Original fourteen legacy supply rules remain authoritative for missing profiles.
	for item in ctx.queues[side]:
		if not profile(item).is_empty() or item.uid in ctx.used[side]:continue
		var activation=model(item).get("activation","")
		if (activation=="hp50" and state.hp<state.max_hp*.5) or (activation=="hp60" and state.hp<state.max_hp*.6) or (activation=="stamina3" and state.stamina<3) or (activation=="first_debuff" and state.debuff_seen) or (activation=="time6" and t>=6):super.use_supply(ctx,side,item,t)
# Feedback only: direct partner grants and existing natural-event notifications
# can meet at the same timestamp. Emit one source/target pair without changing effects.
func emit_star(ctx:Dictionary,side:int,source:Dictionary,trigger:Dictionary,time:float)->void:
	if not ctx.has("star_feedback"):ctx.star_feedback={}
	var key=str(side)+":"+str(source.uid)+":"+str(trigger.uid)+":"+str(time)
	if ctx.star_feedback.has(key):return
	ctx.star_feedback[key]=true
	super.emit_star(ctx,side,source,trigger,time)
	CREW114.link_trigger(self,ctx,side,source,trigger,time)
func effect_feedback(ctx:Dictionary,side:int,source:Dictionary,trigger:Dictionary,beneficiary:Dictionary,t:float,linked_partner:Dictionary={})->void:
	var before=ctx.events.size()
	emit_star(ctx,side,source,trigger if linked_partner.is_empty() else linked_partner,t)
	# emit_star may append a separate crew event; annotate the actual star event.
	for i in range(before,ctx.events.size()):
		var ev=ctx.events[i]
		if ev.kind=="star_trigger" and ev.get("source_uid","")==source.uid:
			ev.trigger_uid=trigger.uid
			ev.beneficiary_uid=beneficiary.get("uid",source.uid)
			break
func partner_feedback(ctx:Dictionary,side:int,source:Dictionary,target:Dictionary,t:float)->void:
	if not source.is_empty() and not target.is_empty() and source.uid!=target.uid and has_link(ctx,side,source,target):emit_star(ctx,side,source,target,t)
func buff(ctx:Dictionary,side:int,target:Dictionary,source:Dictionary,type:String,value:float,t:float,duration:float=6,count:int=1,feedback:bool=true)->void:
	if target.is_empty():return
	own(ctx,side,target).buffs[str(source.kind)+":"+type]={"type":type,"value":value,"until":t+duration,"count":count}
	if feedback and value!=0 and count>0:partner_feedback(ctx,side,source,target,t)
func take_buffs(ctx:Dictionary,side:int,item:Dictionary,t:float,charged:bool)->Dictionary:
	var s=own(ctx,side,item);var out={"flat":0.0,"percent":0.0,"base_percent":0.0,"pierce":0.0,"break":0.0,"last_percent":0.0}
	for id in s.buffs.keys():
		var b=s.buffs[id]
		if t>b.until+EPS:s.buffs.erase(id);continue
		if b.type=="charged" and not charged:continue
		if b.type=="ordinary" and charged:continue
		if b.type=="break_charged" and not charged:continue
		var key="flat" if b.type in ["charged","ordinary","flat"] else "break" if b.type=="break_charged" else b.type
		out[key]=float(out.get(key,0))+float(b.value);b.count-=1
		if b.count<=0:s.buffs.erase(id)
	return out
func stack(s:Dictionary,maximum:int,t:float,duration:float,amount:int=1)->void:
	s.stack=mini(maximum,int(s.stack)+amount);s.until=t+duration
func open_window(s:Dictionary,t:float,duration:float,lock_period:float)->void:
	if t+EPS<float(s.get("locked",0)) or t<float(s.get("window",0)):return
	s.window=t+duration;s.lock_period=lock_period;s.extended=0;s.window_count=0
func activate(ctx:Dictionary,side:int,item:Dictionary,t:float,ordinary:bool=true,kind:String="attack",scale:float=1.0,relay_bonus:float=0.0)->void:
	var n=profile(item)
	if n.is_empty():
		before_attack(ctx,side,item,t,false)
		var start=ctx.pending.size()
		var crew_start=ctx.get("crew_attacks",[]).size()
		var is_charged=ordinary and weapon_role_weight(ctx,side,item)==1 and ctx.states[side].charge>=6
		super.activate(ctx,side,item,t,ordinary,kind,scale,relay_bonus)
		for index in range(crew_start,ctx.get("crew_attacks",[]).size()):ctx.crew_attacks[index].charged=is_charged
		if ordinary and ctx.pending.size()>start:ctx.pending[start].root_item=item;ctx.pending[start].charged=is_charged
		return
	if float(n.cd)<=0 or item.kind=="violet":return
	if not ordinary:queue_hit(ctx,side,item,float(n.damage)*scale,t,kind if kind!="attack" else "derived");return
	var s=own(ctx,side,item);var state=ctx.states[side];var enemy=ctx.get("planning_vitals",ctx.states)[1-side];var name=rule(item)
	if float(s.until)>0 and t>s.until+EPS:s.stack=0;s.until=0.0
	var charged=C.is_tag(item.kind,"weapon") and weapon_role_weight(ctx,side,item)==1 and int(state.charge)>=6
	var base=float(n.damage);var extra=0.0;var breaking=0.0;var pierce=0.0;var pierce_cap=999.0;var multiplier=1.0
	var burst=false;var segments=[1.0];var fixed_segments=[];var last_extra=0.0
	if charged:
		resource(ctx,side,item,"charge",-6,t);extra+=base*.8
		var ev=event(t,side,"heavy",base*.8,item.uid,"充能攻击");ev.cue_only=true;ev.ordinary=true;ctx.events.append(ev)
	before_attack(ctx,side,item,t,charged)
	var additions=take_buffs(ctx,side,item,t,charged)
	extra+=additions.flat;breaking+=additions["break"];multiplier+=additions.percent
	var prepared:Dictionary=s.get("card_prepared",{})
	s.erase("card_prepared")
	extra+=float(prepared.get("value",0));breaking+=float(prepared.get("breaking",0))
	var old_stack=int(s.stack)
	match name:
		"暗夜长刃·玄明":
			if s.count==0:extra+=8
		"暗夜臂铠·夜芒","暗夜矩阵·暝光":
			if s.count<2:extra+=4
		"永夜长明":breaking+=2
		"重破刃-41型":
			if state.hp>=state.max_hp*.8:extra+=3
		"东落":
			if charged:extra+=old_stack*2;s.stack=0
		"纹秋":extra+=old_stack*.6
		"容赦的沉思录":
			if charged:extra+=old_stack*2;s.stack=0
		"浩境粼光":
			if charged:extra+=old_stack*3;s.stack=0
		"源能机锋":
			if charged:breaking+=8
		"苍鳞千嶂":
			if charged:extra+=old_stack*4;s.stack=0
		"时和岁稔":
			if charged and s.get("ready",false):s.ready=false;fixed_segments=[4.0,4.0]
		"焰痕","凌空","诸方玄枢","清音":
			if t<float(s.get("window",0)):multiplier+=.25 if name=="诸方玄枢" else .2
		"驭冕铸雷之权","万物持存的注释":
			if charged:extra+=old_stack*(2 if name=="驭冕铸雷之权" else 1);breaking+=old_stack*(3 if name=="驭冕铸雷之权" else 4);s.stack=0
		"昙切":
			if charged and s.get("ready",false):extra+=8;s.ready=false
		"瞬斩刀-18型":
			if charged and state.hp<state.max_hp*.4 and gate(ctx,side,item,"low",t,5):extra+=5
		"心之锚":
			if old_stack>=5:extra+=7;s.stack=0;burst=true
		"飞景","镭射切变":
			if s.get("ready",false):extra+=3;s.ready=false;burst=true;breaking+=5 if name=="镭射切变" else 0
		"风流的寓言诗","叙别的罗曼史","酩酊的英雄志","虚饰的华尔兹":extra+=old_stack*.5
		"千古洑流":extra+=old_stack
		"赫奕流明":
			if s.get("burst",0)>0:extra+=4;s.burst-=1;burst=true
		"裁春":
			if s.get("ready",false) and state.haste>=3:
				resource(ctx,side,item,"haste",-3,t);extra+=8;fixed_segments=[3.0,3.0];s.ready=false;s.prep=0;burst=true
		"不灭航路":multiplier+=old_stack*.1
		"不屈命定之冠":
			if enemy.noise>0:pierce=.15;pierce_cap=4
		"裁竹":
			if s.get("ready",false):
				var echoes=s.get("echoes",{})
				extra+=10 if echoes.size()>=2 else 4;s.ready=false;s.prep=0;burst=true
				if echoes.size()>=2:
					for echo in echoes.values():buff(ctx,side,echo,item,"flat",3,t)
				s.echoes={}
		"永远的启明星":
			if charged:pierce=.3 if enemy.noise>0 else .2;pierce_cap=8
		"天之苍苍":
			if charged and enemy.noise>=3 and gate(ctx,side,item,"charged",t,5):extra+=6;breaking+=5
		"云琅":multiplier+=old_stack*.05
		"穿击枪-26型":extra+=old_stack*2
		"无眠烈火","奔雷","阳焰","相位涟漪","蜃影","碎骨":
			if s.get("ready",false):
				extra+=6 if name in ["无眠烈火","相位涟漪","蜃影"] else 5
				breaking+=6 if name in ["相位涟漪","碎骨"] else 0
				if name=="蜃影" and enemy.noise>0:pierce=.2;pierce_cap=6
				s.ready=false;s.prep=0;burst=true
		"飞逝","停驻之烟":
			if state.haste>=3 and (s.count+1)%3==0:extra+=4;burst=true
		"溢彩荧辉":
			if not charged and t<=float(s.get("ordinary_until",-1)):multiplier+=.2;s.ordinary_until=-1.0
		"金掌":
			if charged:extra+=old_stack*2;s.stack=0
		"擎渊怒涛","悲喜剧":pass
		"焰光裁定":
			if s.get("ready",false):breaking+=6;s.ready=false;s.prep=0;burst=true
		"白昼之脊":
			if s.get("ready",false):pierce=.2;pierce_cap=4;s.ready=false
		"鸣动仪-25型":
			if state.hp>=state.max_hp*.6:extra+=2
		"大海的馈赠":extra+=old_stack*.6
		"曜光":
			if s.get("burst",0)>0:extra+=3;s.burst-=1;burst=true
		"漪澜浮录":extra+=old_stack*.7
		"玻色星仪":
			if (s.count+1)%3==0:breaking+=4
		"坚岩斗士":
			breaking+=3
			if state.shield>0 and not linked(ctx,side,item,"shield").is_empty():extra+=2
		"解形煞":breaking+=6
		"飞廉之猩":segments=[.5,.5]
		"云闪之鳞":segments=[.25,.25,.5]
		"燎照之骑":breaking+=9
		"无妄者":
			segments=[.1,.1,.1,.1,.1,.5]
			if enemy.hp<enemy.max_hp*.35:last_extra+=6
		"万囮牢·朽躯":
			breaking+=10
			var spent=remove_shield(ctx,side,6);extra+=spent*1.5
			if spent>0:ctx.events.append(event(t,side,"shield_spend",spent,item.uid,"盾击消耗"))
		"和光回唱":
			if old_stack>=3:
				s.stack-=3;extra+=4;ctx.team[side].noise_boost=.25;ctx.team[side].noise_boost_until=t+6
	if item.kind in ["wuka","echo_vanguard"]:breaking+=3
	if not prepared.is_empty():
		pierce=maxf(pierce,float(prepared.get("pierce",0)));pierce_cap=minf(pierce_cap,float(prepared.get("pierce_cap",999)))
	# Stored recipient rewards are attached to this root, then cleared exactly once.
	var damage=(base+extra+minf(base*additions.base_percent,6))*multiplier*float(ctx.bonuses[side].get(item.uid,{}).get("multiplier",1))*weapon_damage_weight(ctx,side,item)
	damage+=float(s.get("crew_volley_bonus",0));s.erase("crew_volley_bonus")
	var fractions=segments
	var actions=[]
	if breaking>0:actions.append({"type":"break_shield","value":breaking,"item":item,"ordinary":false,"kind":"derived"})
	for idx in range(fractions.size()):
		var value=damage*float(fractions[idx])
		if idx==fractions.size()-1:value+=(last_extra+minf(base*float(fractions[idx])*additions.last_percent,6))*multiplier*float(ctx.bonuses[side].get(item.uid,{}).get("multiplier",1))*weapon_damage_weight(ctx,side,item)
		actions.append({"type":"damage","value":value,"item":item,"ordinary":true,"kind":"attack","charged":charged,"pierce":pierce,"pierce_cap":pierce_cap})
		if not prepared.is_empty():actions[-1].prepared=true
	for fixed in fixed_segments:actions.append({"type":"damage","value":float(fixed)*multiplier*float(ctx.bonuses[side].get(item.uid,{}).get("multiplier",1))*weapon_damage_weight(ctx,side,item),"item":item,"ordinary":true,"kind":"attack","charged":charged})
	ctx.pending.append({"side":side,"actions":actions,"root_item":item,"charged":charged,"burst":burst})
	var trigger=event(t,side,"trigger",0,item.uid,name);trigger.ordinary=true;trigger.charged=charged;ctx.events.append(trigger)
	if not prepared.is_empty():trigger.prepared=true
	s.count+=1;s.last_hit=t
	post_attack(ctx,side,item,t,charged,burst,enemy)
	if int(n.charge)>0:resource(ctx,side,item,"charge",n.charge,t)
	if int(n.hasteEvery)>0 and s.count%int(n.hasteEvery)==0:resource(ctx,side,item,"haste",1,t)
	natural(ctx,side,item,"attack",t,{"charged":charged,"damage":damage,"base":base,"burst":burst})
	if charged:natural(ctx,side,item,"charged",t,{"damage":damage,"base":base})
func post_attack(ctx:Dictionary,side:int,item:Dictionary,t:float,charged:bool,burst:bool,enemy:Dictionary)->void:
	var s=own(ctx,side,item);var name=rule(item)
	if s.get("punch_heal",false):heal(ctx,side,item,2,t,false);s.punch_heal=false
	if name=="沉冥" and s.count%2==0:resource(ctx,side,item,"haste",1,t)
	match name:
		"东落":
			if charged:s.store_until=t+8;s.clocks.store=t+2;s.until=t+8
		"纹秋":stack(s,5,t,6)
		"容赦的沉思录":
			if enemy.noise>0:stack(s,3,t,999)
		"浩境粼光":stack(s,3,t,999)
		"苍鳞千嶂":
			if charged:stack(s,2,t,999)
		"时和岁稔":
			if not charged:s.ordinary_seen=true
		"金穹","翼锋":
			if charged:buff(ctx,side,item,item,"ordinary",2,t,999,2)
		"凋亡频移","永续坍缩","悖论喷流","尘云旋臂","核熔星盘","玉阙玄华","赝作的矮星":
			if s.count%3==0:resource(ctx,side,item,"charge",1,t)
		"焰痕","凌空","诸方玄枢","清音":
			if charged:
				if name=="焰痕" and t<float(s.get("window",0)) and s.get("extended",0)==0:s.window+=2;s.extended=1
				else:open_window(s,t,5 if name=="清音" else 4,6 if name=="诸方玄枢" else 5 if name=="清音" else 4)
			elif name=="凌空" and t<float(s.get("window",0)):
				s.window_count=int(s.get("window_count",0))+1
				if s.window_count>=2 and s.get("extended",0)==0:s.window+=2;s.extended=1
		"心之锚":
			if not burst:stack(s,5,t,6)
		"飞景","镭射切变":
			if burst and name=="飞景":
				advance_item(ctx,side,item,.2,t);advance_longest(ctx,side,item,.2,t)
			if s.count%3==0:s.ready=true
		"风流的寓言诗","叙别的罗曼史","酩酊的英雄志":
			if enemy.noise>0:stack(s,4,t,6)
		"大海的馈赠":
			if enemy.noise>0:stack(s,4,t,6)
		"虚饰的华尔兹":
			if enemy.frost>0:stack(s,4,t,6)
		"千古洑流":
			if s.count%2==0:stack(s,2,t,6)
		"赫奕流明":
			if not burst:
				s.stack+=1
				if s.stack>=6:s.burst=3;s.stack=0
		"裁春":
			if not burst:s.prep=mini(3,int(s.get("prep",0))+1);s.ready=s.prep>=3
		"不灭航路":stack(s,3,t,4)
		"裁竹":
			if not burst:s.prep=int(s.get("prep",0))+1;s.ready=s.prep>=3
		"华彩乐段":
			if s.count%3==0 and gate(ctx,side,item,"relay",t,4):
				var target=advance_longest(ctx,side,item,.4,t)
				if not target.is_empty():s.relay_uid=target.uid
		"无眠烈火","奔雷","阳焰","相位涟漪","蜃影","碎骨":
			if not burst and (not charged or name=="无眠烈火"):
				s.prep=int(s.get("prep",0))+1;s.ready=s.prep>=3
			if burst and name=="阳焰":buff(ctx,side,strongest_link(ctx,side,item),item,"charged",4,t)
		"停驻之烟":
			if burst and gate(ctx,side,item,"partner",t,4):buff_first(ctx,side,item,"weapon","flat",3,t)
		"林间的咏叹调":pass
		"溢彩荧辉":
			s.ordinary_until=t+4
			if enemy.noise>=6 and gate(ctx,side,item,"partner",t,5):buff_first(ctx,side,item,"weapon","flat",3,t)
		"袍泽之固":
			if charged:buff(ctx,side,item,item,"flat",5,t)
		"骇行":
			if charged:s.armor=maxi(int(s.get("armor",0)),3)
		"金掌":
			if not charged:stack(s,3,t,999)
		"擎渊怒涛","悲喜剧":
			if charged:buff(ctx,side,item,item,"ordinary",2,t,999,2)
			else:buff(ctx,side,item,item,"charged",8 if name=="悲喜剧" else 4,t,3 if name=="悲喜剧" else 999)
		"焰光裁定":
			if not charged and not burst:s.prep=int(s.get("prep",0))+1;s.ready=s.prep>=3
		"白昼之脊":
			if enemy.noise>=3 and s.count%3==0:s.ready=true
		"异度":
			if s.count%2==0:s.heal_ready=true
		"曜光":
			if not burst:
				s.prep=int(s.get("prep",0))+1
				if s.prep>=3:s.burst=2;s.prep=0
		"漪澜浮录":stack(s,5,t,6)
		"琼枝冰绡":
			if s.count%3==0:s.transfer=true
		"和光回唱":
			if enemy.noise>0:stack(s,3,t,999)
		"飞廉之猩":
			var targets=linked(ctx,side,item,"weapon");sort_damage(targets)
			if not targets.is_empty():buff(ctx,side,targets[0],item,"charged",5,t,8)
		"无常凶鹭":
			if gate(ctx,side,item,"main",t,6):buff(ctx,side,strongest_link(ctx,side,item),item,"flat",5,t)
		"青羽鹭":
			if s.get("delay",false):
				s.delay=false;delay_shortest(ctx,1-side,.3,t,item);advance_longest(ctx,side,item,.3,t)
func linked(ctx:Dictionary,side:int,source:Dictionary,category:String="")->Array:
	var links=inventory.star_links(source,ctx.queues[side],ctx.builds[side])
	if category=="":return links
	return links.filter(func(i):return capability(i,category))
func capability(item:Dictionary,category:String)->bool:
	var n=profile(item)
	var action=n.get("material_effect",{}).get("action","")
	if category in ["heal","shield","noise","stamina"] and not n.is_empty():return ACTIVITY.functional(item.kind,category)
	match category:
		"weapon","echo","provision":return C.is_tag(item.kind,category)
		"heal":return float(n.get("healAmount",0))>0 or float(n.get("emergency",0))>0 if not n.is_empty() else legacy_capability(item,"heal")
		"shield":return float(n.get("shieldAmount",0))>0 or float(n.get("openingShield",0))>0 if not n.is_empty() else legacy_capability(item,"shield")
		"noise":return float(n.get("noisePeriod",0))>0
	return false
func legacy_capability(item:Dictionary,key:String)->bool:
	return C.is_tag(item.kind,key) or super.model(item).get("actions",[]).any(func(action):return action.get("type","")==key and float(action.get("value",0))>0)
func has_link(ctx:Dictionary,side:int,source:Dictionary,target:Dictionary)->bool:
	return linked(ctx,side,source).any(func(i):return i.uid==target.uid)
func sort_damage(items:Array)->void:items.sort_custom(func(a,b):return float(profile(a).get("damage",C.items[a.kind].get("damage",0)))>float(profile(b).get("damage",C.items[b.kind].get("damage",0))))
func strongest_link(ctx:Dictionary,side:int,source:Dictionary)->Dictionary:
	var targets=linked(ctx,side,source,"weapon");sort_damage(targets)
	return targets[0] if not targets.is_empty() else {}
func buff_first(ctx:Dictionary,side:int,source:Dictionary,category:String,type:String,value:float,t:float,count:int=1,duration:float=6,limit:int=1)->void:
	var targets=linked(ctx,side,source,category)
	for index in range(mini(limit,targets.size())):buff(ctx,side,targets[index],source,type,value,t,duration,count)
func advance_item(ctx:Dictionary,side:int,item:Dictionary,seconds:float,t:float,origin:Dictionary={},feedback:bool=true)->float:
	if item.is_empty() or not ctx.progress[side].has(item.uid):return 0.0
	var before=float(ctx.progress[side][item.uid])
	ctx.progress[side][item.uid]=minf(1,before+seconds/maxf(EPS,cooldown(ctx,side,item)))
	var actual=(ctx.progress[side][item.uid]-before)*cooldown(ctx,side,item)
	var ev=event(t,side,"cooldown_advance",actual,item.uid,"冷却推进");ev.actual_value=actual;ev.target_uid=item.uid;ev.source_uid=origin.get("uid",item.uid);ctx.events.append(ev)
	if feedback and float(ctx.progress[side][item.uid])>before+EPS:partner_feedback(ctx,side,origin,item,t)
	return actual
func advance_longest(ctx:Dictionary,side:int,source:Dictionary,seconds:float,t:float)->Dictionary:
	var targets=linked(ctx,side,source,"weapon").filter(func(i):return ctx.progress[side].has(i.uid))
	targets.sort_custom(func(a,b):return (1-ctx.progress[side][a.uid])*cooldown(ctx,side,a)>(1-ctx.progress[side][b.uid])*cooldown(ctx,side,b))
	if targets.is_empty():return {}
	advance_item(ctx,side,targets[0],seconds,t,source);return targets[0]
func delay_shortest(ctx:Dictionary,side:int,seconds:float,t:float,origin:Dictionary={})->void:
	# Hostile clock changes resolve only after both sides have planned this tick.
	# Select against the shared post-planning clocks, then delay the next cycle
	# when an already-ready target has committed its attack.
	ctx.pending.append({"side":1-side,"actions":[{"type":"cooldown_delay","target_side":side,"value":seconds,"item":origin}]})
func commit_delay_shortest(ctx:Dictionary,side:int,seconds:float,t:float,origin:Dictionary)->void:
	var targets=ctx.queues[side].filter(func(i):return C.is_tag(i.kind,"weapon") and ctx.progress[side].has(i.uid))
	targets.sort_custom(func(a,b):return (1-ctx.progress[side][a.uid])*cooldown(ctx,side,a)<(1-ctx.progress[side][b.uid])*cooldown(ctx,side,b))
	if targets.is_empty():return
	var target=targets[0];ctx.progress[side][target.uid]-=seconds/maxf(EPS,cooldown(ctx,side,target))
	var ev=event(t,1-side,"delay",seconds,origin.get("uid",target.uid),"冷却延迟");ev.target_uid=target.uid;ev.target_side=side;ev.source_uid=origin.get("uid","");ctx.events.append(ev)
func two_kinds(s:Dictionary,item:Dictionary,key:String="seen")->bool:
	if not s.has(key):s[key]={}
	s[key][item.kind]=item
	return s[key].size()>=2
func alternating(s:Dictionary,item:Dictionary)->bool:
	var prior=str(s.get("last_kind",""));s.last_kind=item.kind
	return not prior.is_empty() and prior!=item.kind
func before_attack(ctx:Dictionary,side:int,item:Dictionary,t:float,charged:bool)->void:
	for source in ctx.queues[side]:
		if profile(source).is_empty() or not has_link(ctx,side,source,item):continue
		var s=own(ctx,side,source);var echo=C.is_tag(item.kind,"echo");var weapon=C.is_tag(item.kind,"weapon")
		if echo and s.has("next_echo"):
			var b=s.next_echo
			if t<=b.until+EPS:buff(ctx,side,item,source,b.type,b.value,t,b.until-t)
			s.erase("next_echo")
		if weapon and s.get("marks",0)>0:buff(ctx,side,item,source,"flat",s.marks*3,t);s.marks=0
		if weapon and s.get("snapshot",false):
			buff(ctx,side,item,source,"flat",minf(6,float(profile(item).get("damage",0))*.3),t);s.snapshot=false
func next_echo(s:Dictionary,type:String,value:float,t:float,duration:float=6)->void:s.next_echo={"type":type,"value":value,"until":t+duration}
func natural(ctx:Dictionary,side:int,trigger:Dictionary,event_kind:String,t:float,data:Dictionary={})->void:
	if not ctx.has("local"):return
	if event_kind=="attack" and ACTIVITY.attacks(trigger):
		CREW.record_attack(ctx,side,trigger,t,data)
		CREW115.record_attack(ctx,side,trigger,t,data)
	if event_kind=="attack":COMBOS.event(self,ctx,side,trigger,"self_attack",t)
	MATERIALS.star_event(self,ctx,side,trigger,event_kind,t,data)
	if not profile(trigger).is_empty():
		var legacy_roots=[event_kind]
		if event_kind=="attack":legacy_roots.append("activate")
		if event_kind=="supply":legacy_roots=["activate","supply"]
		var legacy_bundle={"side":side,"actions":[]}
		super.notify_stars(ctx,side,trigger,legacy_roots,t,legacy_bundle)
		if not legacy_bundle.actions.is_empty():ctx.pending.append(legacy_bundle)
	var own_s=own(ctx,side,trigger);var own_name=rule(trigger)
	if event_kind=="heal":
		if own_name=="血誓盟约" and gate(ctx,side,trigger,"heal",t,5):buff(ctx,side,trigger,trigger,"flat",4,t)
		if own_name=="宙算仪轨" and gate(ctx,side,trigger,"heal",t,5):
			var targets=linked(ctx,side,trigger,"weapon");sort_damage(targets)
			if not targets.is_empty():buff(ctx,side,targets[0],trigger,"charged",5,t)
		if own_name=="星序协响" and gate(ctx,side,trigger,"heal",t,5):buff_first(ctx,side,trigger,"weapon","flat",3,t,1,6,2)
	if event_kind=="shield" and own_name=="千般渡" and gate(ctx,side,trigger,"carry",t,2):stack(own_s,3,t,999)
	if event_kind=="noise" and own_name=="昙切":count_noise(ctx,side,trigger,t)
	for source in ctx.queues[side]:
		if profile(source).is_empty():continue
		var s=own(ctx,side,source);var name=rule(source)
		var is_link=source.uid!=trigger.uid and has_link(ctx,side,source,trigger)
		var weapon=C.is_tag(trigger.kind,"weapon");var echo=C.is_tag(trigger.kind,"echo")
		var attack=event_kind=="attack";var charged=event_kind=="charged"
		# These clauses explicitly listen to the team's weapon charge events, independently of stars.
		if charged and weapon:
			match name:
				"凋亡频移","永续坍缩","悖论喷流","尘云旋臂","核熔星盘":
					if gate(ctx,side,source,"weapon_charge",t,4):buff(ctx,side,source,source,"flat",3,t,999)
				"玉阙玄华":
					if gate(ctx,side,source,"weapon_charge",t,5):buff(ctx,side,source,source,"break",4,t,999,2)
				"死与舞":
					if t>=float(s.get("dance_lock",0)) and not s.get("dance_active",false):
						buff(ctx,side,source,source,"flat",7,t,5,2);s.dance_active=true;s.dance_until=t+5;s.dance_shots=2
				"那前赴后继的风帆":
					if gate(ctx,side,source,"weapon_charge",t,4):
						var targets=linked(ctx,side,source,"weapon").filter(func(i):return i.uid!=trigger.uid)
						if not targets.is_empty():buff(ctx,side,targets[0],source,"flat",4,t)
				"那撕裂命运的坠星":
					if t>=float(s.get("locked",0)):
						if t-float(s.get("first_charge",-100))<=8 and gate(ctx,side,source,"starfall",t,8):
							buff_first(ctx,side,source,"weapon","flat",3,t,2,8,2);s.locked=t+8;s.first_charge=-100.0
						else:s.first_charge=t
				"审判-遗落令旗":
					if gate(ctx,side,source,"weapon_charge",t,5):next_echo(s,"last_percent",.4,t)
		if source.uid==trigger.uid and attack and name=="死与舞" and s.get("dance_active",false):
			s.dance_shots-=1
			if s.dance_shots<=0:s.dance_active=false;s.dance_lock=t+5
		if not is_link:continue
		var fired=false
		match name:
			"远行者长刃·辟路","远行者迅刀·旅迹","远行者佩枪·洞察","远行者臂铠·破障","远行者矩阵·探幽":
				if attack and echo and gate(ctx,side,source,"star",t,4):resource(ctx,side,source,"charge",1,t);fired=true
			"钧天正音","呼啸重音":
				if attack:
					if weapon and name=="钧天正音":s.weapon_seen=true
					if echo:s.echo_seen=true
					if s.get("weapon_seen",false) and s.get("echo_seen",false) and gate(ctx,side,source,"star",t,3):
						advance_longest(ctx,side,source,.4 if name=="钧天正音" else .5,t);s.weapon_seen=false;s.echo_seen=false;fired=true
			"永夜长明","今州守望":
				if attack and echo and gate(ctx,side,source,"star",t,3):buff(ctx,side,source,source,"flat",2,t,999);fired=true
			"异响空灵":
				if attack and echo:
					s.echo_count=int(s.get("echo_count",0))+1
					if s.echo_count>=2 and gate(ctx,side,source,"star",t,3):
						var target=strongest_link(ctx,side,source);advance_item(ctx,side,source if target.is_empty() else target,.25 if target.is_empty() else .5,t,source);s.echo_count=0;fired=true
			"重破刃-41型","鸣动仪-25型":
				var threshold=.8 if name=="重破刃-41型" else .6
				if event_kind=="heal" and float(data.get("before",1))<threshold and float(data.get("after",0))>=threshold and gate(ctx,side,source,"star",t,5):buff(ctx,side,source,source,"flat",2 if threshold==.8 else 3,t,999);fired=true
			"浩境粼光","苍鳞千嶂":
				if attack and echo and gate(ctx,side,source,"star",t,3):stack(s,3 if name=="浩境粼光" else 2,t,999);fired=true
			"时和岁稔":
				if attack and echo:s.echo_seen=true
				if s.get("ordinary_seen",false) and s.get("echo_seen",false) and gate(ctx,side,source,"star",t,4):s.ready=true;s.ordinary_seen=false;s.echo_seen=false;fired=true
			"驭冕铸雷之权","万物持存的注释":
				if event_kind=="shield" and gate(ctx,side,source,"star",t,2):stack(s,3,t,999);fired=true
			"昙切":
				if event_kind=="noise":count_noise(ctx,side,source,t);fired=true
			"千般渡":
				if event_kind=="shield" and gate(ctx,side,source,"carry",t,2):stack(s,3,t,999);fired=true
			"行进序曲":
				if attack and echo and gate(ctx,side,source,"star",t,3):advance_item(ctx,side,source,.3,t);fired=true
			"西升","飞逝","停驻之烟","林间的咏叹调","溢彩荧辉":
				if event_kind=="supply" and not s.seen.has(trigger.uid):s.seen[trigger.uid]=true;resource(ctx,side,source,"haste",1 if name=="西升" else 2,t);fired=true
			"千古洑流":
				if attack and echo and gate(ctx,side,source,"star",t,3):stack(s,2,t,6);fired=true
			"沉冥":
				if attack and (weapon or echo):
					var category="weapon" if weapon else "echo"
					if s.get("last_category","")!=category:s.switches=int(s.get("switches",0))+1;s.last_category=category
					if s.get("switches",0)>=4:
						s.switches=0;s.mode=1-int(s.get("mode",0))
						if s.mode==1:buff(ctx,side,source,source,"flat",3,t,999,2)
						else:buff_first(ctx,side,source,"weapon","flat",2,t,1,999,2)
						fired=true
			"裁春":
				if attack and weapon and not s.get("ready",false):s.prep=mini(3,int(s.get("prep",0))+1);s.ready=s.prep>=3;fired=true
			"裁竹":
				if attack and echo and s.get("echoes",{}).size()<2:two_kinds(s,trigger,"echoes")
			"云琅":
				if attack and echo and alternating(s,trigger) and s.stack<4:
					if not s.has("layer_times"):s.layer_times=[]
					s.layer_times.append(t+6);s.stack=s.layer_times.size()
					if s.stack==4:s.layer_times=[t+10,t+10,t+10,t+10]
					fired=true
			"华彩乐段":
				if attack and trigger.uid==s.get("relay_uid",""):advance_item(ctx,side,source,.2,t);s.relay_uid="";fired=true
			"无眠烈火":
				if charged and weapon and gate(ctx,side,source,"star",t,4):s.prep=int(s.get("prep",0))+1;s.ready=s.prep>=3;fired=true
			"光影双生":
				if attack and echo and s.get("last_direction","")!="echo" and gate(ctx,side,source,"echo_direction",t,4):
					buff(ctx,side,source,source,"charged",4,t,999);s.last_direction="echo";fired=true
			"脉冲协臂","白昼之脊":
				if attack and echo and alternating(s,trigger) and gate(ctx,side,source,"star",t,3):resource(ctx,side,source,"haste",1,t);fired=true
			"诸方玄枢":
				if attack and echo and t<float(s.get("window",0)) and s.get("extended",0)<3:s.window+=1;s.extended=int(s.get("extended",0))+1;fired=true
			"昭日译注":
				if attack and echo and alternating(s,trigger) and gate(ctx,side,source,"star",t,4):next_echo(s,"base_percent",.35,t,999);fired=true
			"奇幻变奏":
				if attack and echo and alternating(s,trigger):
					s.alternations=int(s.get("alternations",0))+1
					if s.alternations>=2 and gate(ctx,side,source,"star",t,4):advance_item(ctx,side,strongest_link(ctx,side,source),.6,t,source);s.alternations=0;fired=true
			"渊海回声":
				if charged and weapon and gate(ctx,side,source,"star",t,5):s.next_heal=2;fired=true
			"曜光":
				if attack and weapon and s.get("burst",0)==0 and gate(ctx,side,source,"star",t,4):
					s.prep=int(s.get("prep",0))+1
					if s.prep>=3:s.burst=2;s.prep=0
					fired=true
			"掣傀之手","海的呢喃","幽冥的忘忧章":
				if attack and echo and two_kinds(s,trigger) and gate(ctx,side,source,"star",t,4 if name=="掣傀之手" else 5):
					s.seen={}
					if name=="掣傀之手":s.marks=2
					elif name=="海的呢喃":buff(ctx,side,source,source,"flat",9,t,999)
					else:buff(ctx,side,source,source,"flat",5,t);next_echo(s,"flat",5,t)
					fired=true
			"琼枝冰绡":pass # The pending reward is assigned after its own third attack below.
			"赝作的矮星":
				if charged and weapon and gate(ctx,side,source,"star",t,5):next_echo(s,"flat",6,t,999);fired=true
			"青羽鹭","绝息魄","云闪之鳞":
				if attack and weapon:
					s.weapon_count=int(s.get("weapon_count",0))+1
					if s.weapon_count>=4 and gate(ctx,side,source,"star",t,4):
						s.weapon_count=0
						if name=="青羽鹭":s.delay=true
						elif name=="绝息魄":buff(ctx,side,source,source,"flat",4,t,999)
						else:advance_item(ctx,side,source,.4,t)
						fired=true
			"紫羽鹭":
				if event_kind=="shield" and gate(ctx,side,source,"star",t,5):s.extension=minf(1,float(s.get("extension",0))+.5);fired=true
			"霁息兽尊","千傀重楼":
				if event_kind=="heal" and gate(ctx,side,source,"cleanse",t,6):cleanse(ctx,side,1,t,source.uid);fired=true
				if name=="千傀重楼" and attack and weapon and two_kinds(s,trigger) and gate(ctx,side,source,"shield_clock",t,4):
					if s.clocks.has("shield"):s.clocks.shield=maxf(t,s.clocks.shield-.5)
					s.seen={};fired=true
			"共鸣回响·天演溯心":
				if event_kind=="shield" and gate(ctx,side,source,"star",t,4):ctx.pending.append({"side":side,"actions":[{"type":"noise","value":1,"item":source,"ordinary":false,"kind":"derived"}]});fired=true
			"天傀劫煞":
				if attack and echo and two_kinds(s,trigger) and gate(ctx,side,source,"star",t,5):
					var targets=linked(ctx,side,source,"weapon")
					for idx in range(mini(2,targets.size())):advance_item(ctx,side,targets[idx],.4,t,source)
					s.seen={};fired=true
			"盛放的永恒":
				if event_kind=="heal" and gate(ctx,side,source,"star",t,3):s.next_shield=mini(2,int(s.get("next_shield",0))+1);fired=true
			"那映照虚幻的燃灯":
				if attack and weapon and gate(ctx,side,source,"charge",t,3):resource(ctx,side,source,"charge",1,t);fired=true
				if event_kind=="shield" and gate(ctx,side,source,"shield",t,4):buff(ctx,side,strongest_link(ctx,side,source),source,"charged",3,t,999);fired=true
			"那万变无常的解答":
				if attack and weapon and (ctx.get("planning_vitals",ctx.states)[1-side].noise>0 or ctx.get("planning_vitals",ctx.states)[1-side].frost>0) and gate(ctx,side,source,"star",t,3):
					ctx.pending.append({"side":side,"actions":[{"type":"break_shield","value":4,"item":source,"ordinary":false,"kind":"derived"}]});fired=true
			"那奢靡优雅的归宿":
				if attack and echo and alternating(s,trigger) and gate(ctx,side,source,"star",t,5):queue_hit(ctx,side,source,minf(6,float(data.get("base",0))*.4),t);fired=true
		if source.kind=="contract" and attack and echo and gate(ctx,side,source,"star",t,3):resource(ctx,side,source,"haste",1,t);fired=true
		if source.kind=="electro_coin" and attack and weapon and gate(ctx,side,source,"star",t,3):resource(ctx,side,source,"charge",1,t);fired=true
		if source.kind=="aero_coin" and event_kind=="supply" and not s.seen.has(trigger.uid) and gate(ctx,side,source,"star",t,1):s.seen[trigger.uid]=true;resource(ctx,side,source,"haste",2,t);fired=true
		if source.kind=="glasses" and event_kind=="supply" and not s.seen.has(trigger.uid) and gate(ctx,side,source,"star",t,3):s.seen[trigger.uid]=true;cleanse(ctx,side,1,t,source.uid);fired=true
		if source.kind=="spectro_coin" and attack and weapon and gate(ctx,side,source,"star",t,3):s.clocks.noise=maxf(t,float(s.clocks.noise)-1);fired=true
		if source.kind=="echo_vanguard" and attack and weapon and gate(ctx,side,source,"star",t,4):resource(ctx,side,source,"charge",1,t);fired=true
		if fired:emit_star(ctx,side,source,trigger,t)
	# Own-root clauses needing previously collected partner records.
	if event_kind=="attack":
		if own_name=="呼啸重音":
			own_s.weapon_seen=true
			if own_s.get("echo_seen",false) and gate(ctx,side,trigger,"star",t,3):advance_longest(ctx,side,trigger,.5,t);own_s.weapon_seen=false;own_s.echo_seen=false
		if own_name=="时和岁稔" and own_s.get("ordinary_seen",false) and own_s.get("echo_seen",false) and gate(ctx,side,trigger,"star",t,4):own_s.ready=true;own_s.ordinary_seen=false;own_s.echo_seen=false
		if own_name=="琼枝冰绡" and own_s.get("transfer",false) and gate(ctx,side,trigger,"star",t,5):next_echo(own_s,"flat",6,t,999);own_s.transfer=false
	if event_kind=="charged" and own_name=="光影双生" and own_s.get("last_direction","")!="charged" and gate(ctx,side,trigger,"charge_direction",t,4):next_echo(own_s,"flat",4,t,999);own_s.last_direction="charged"
func count_noise(ctx:Dictionary,side:int,item:Dictionary,t:float)->void:
	if not gate(ctx,side,item,"count_noise",t,.5):return
	var s=own(ctx,side,item);s.noise_count=int(s.get("noise_count",0))+1
	if s.noise_count>=3:s.ready=true;s.noise_count=0
func finish_pending_action(ctx:Dictionary,side:int,action:Dictionary,t:float,applied:bool)->void:
	MATERIALS.finish_star_action(self,ctx,side,action,t,applied)
func commit_pending(ctx:Dictionary,t:float)->void:
	if not ctx.has("local"):super.commit_pending(ctx,t);return
	while not ctx.pending.is_empty():
		var pending=ctx.pending;ctx.pending=[];var counters=[]
		for bundle in pending:
			var side=int(bundle.side);var target=ctx.states[1-side]
			var root=bundle.get("root_item",{})
			var shield_before=float(target.shield);var hp_before=float(target.hp)
			var reduction=0.0;var armor=0.0;var blocker={}
			if not root.is_empty() and C.is_tag(root.kind,"weapon"):
				if int(ctx.team[1-side].get("ward",0))>0 and t<=float(ctx.team[1-side].get("ward_until",0))+EPS:
					reduction=.25;ctx.team[1-side].ward-=1
				for guard in ctx.queues[1-side]:
					if profile(guard).is_empty():continue
					var gs=own(ctx,1-side,guard)
					if guard.kind=="violet" and float(gs.get("stance_end",0))>t-EPS and not gs.get("caught",false):
						reduction=maxf(reduction,.3);gs.caught=true;blocker=guard;break
				for guard in ctx.queues[1-side]:
					if rule(guard)=="骇行":
						var gs=own(ctx,1-side,guard)
						if gs.get("armor",0)>0:armor=maxf(armor,1);gs.armor-=1
			for action in bundle.actions:
				if action.type!="break_shield":continue
				var removed=remove_shield(ctx,1-side,float(action.value))
				if removed>0:
					var ev=event(t,side,"break_shield",removed,action.item.uid,"额外削盾");ev.target_side=1-side;ctx.events.append(ev)
				finish_pending_action(ctx,side,action,t,removed>0)
			var amounts={}
			for action_index in bundle.actions.size():
				var action=bundle.actions[action_index]
				if action.type!="damage":continue
				var amount=float(action.value)*(1-reduction)
				var absorbed_armor=minf(armor,amount);amount-=absorbed_armor;armor-=absorbed_armor
				amounts[action_index]=mitigate_hit(ctx,side,action.item,amount,t,bool(action.ordinary),str(action.kind))
			var pierce_override=whole_attack_pierce(ctx,bundle,amounts,t)
			for action_index in bundle.actions.size():
				var action=bundle.actions[action_index]
				match str(action.type):
					"damage":
						var amount=float(amounts[action_index])
						var bypass=float(pierce_override.get(action_index,minf(amount*float(action.get("pierce",0)),float(action.get("pierce_cap",999)))))
						deal_v75_damage(ctx,side,action.item,amount,t,bool(action.ordinary),str(action.kind),bypass,bool(action.get("charged",bundle.get("charged",false))) and bool(action.ordinary),bool(action.get("prepared",false)))
					"cooldown_delay":commit_delay_shortest(ctx,int(action.target_side),float(action.value),t,action.item)
					"noise":
						var applied=apply_noise_internal(ctx,side,action.item,int(action.value),t,bool(action.get("ordinary",false)))
						finish_pending_action(ctx,side,action,t,applied>0)
					"frost":
						var applied=apply_frost_internal(ctx,side,action.item,int(action.value),t,bool(action.get("ordinary",false)))
						finish_pending_action(ctx,side,action,t,applied>0)
					"noise_consume":
						var layers=mini(target.noise,int(action.rules.get("max_layers",2)))
						if layers>0:
							target.noise-=layers
							for _i in range(mini(layers,ctx.noise_parts[1-side].size())):ctx.noise_parts[1-side].pop_back()
							deal_v75_damage(ctx,side,action.item,layers*float(action.rules.get("damage_per_layer",6)),t,false,"derived")
			if not root.is_empty():
				if shield_before>EPS and target.shield<=EPS:after_break(ctx,side,root,t)
				if target.hp>0 and C.is_tag(root.kind,"weapon"):
					if not blocker.is_empty():counters.append({"side":1-side,"item":blocker,"damage":8});end_stance(ctx,1-side,blocker,t)
					after_weapon_hit(ctx,1-side,root,t,bool(bundle.get("charged",false)),counters)
				
			use_threshold_provisions(ctx,1-side,t)
		for counter in counters:deal_v75_damage(ctx,int(counter.side),counter.item,float(counter.damage),t,false,"counter")
func mitigate_hit(_ctx:Dictionary,_side:int,_item:Dictionary,amount:float,_t:float,_ordinary:bool,_kind:String)->float:
	return amount
func whole_attack_pierce(_ctx:Dictionary,_bundle:Dictionary,_amounts:Dictionary,_t:float)->Dictionary:
	return {}
func deal_v75_damage(ctx:Dictionary,side:int,item:Dictionary,amount:float,t:float,ordinary:bool,kind:String,pierce:float=0,charged:bool=false,prepared:bool=false)->void:
	if amount<=0:return
	var target=ctx.states[1-side]
	var blocked=minf(float(target.shield),maxf(0,amount-pierce))
	CREW114.absorb(ctx,1-side,blocked,float(target.shield))
	CREW115.record_blocked(ctx,1-side,blocked,t,str(item.get("uid","")))
	target.shield-=blocked;target.hp-=amount-blocked
	if blocked>EPS and ordinary and kind=="attack":COMBOS.blocked(self,ctx,1-side,t)
	record_damage(ctx,side,item.get("uid",""),amount)
	var ev=event(t,side,kind,amount,item.get("uid",""),C.items.get(item.get("kind",""),{}).get("name",kind))
	ev.ordinary=ordinary;ev.charged=charged;ev.absorbed=blocked;ev.hp_damage=amount-blocked;ev.element=C.items.get(item.get("kind",""),{}).get("element","neutral");ctx.events.append(ev)
	if prepared:ev.prepared=true
	if amount-blocked>EPS:
		ctx.team[1-side].last_hp_hit=t
		for defender in ctx.queues[1-side]:
			if rule(defender)=="穿击枪-26型":own(ctx,1-side,defender).clocks.aim=t+5
		after_hp_hit(ctx,1-side,t)
	use_threshold_provisions(ctx,1-side,t)
func after_break(ctx:Dictionary,side:int,item:Dictionary,t:float)->void:
	var name=rule(item)
	match name:
		"源能机锋":
			if gate(ctx,side,item,"break",t,6):buff(ctx,side,item,item,"charged",6,t,999)
		"镭射切变":
			if gate(ctx,side,item,"break",t,4):advance_item(ctx,side,item,.5,t)
		"相位涟漪","蜃影":
			if gate(ctx,side,item,"break",t,6):buff_first(ctx,side,item,"weapon","flat",3,t,1,6,2)
		"碎骨","玻色星仪":
			if gate(ctx,side,item,"break",t,6):buff(ctx,side,item,item,"ordinary",2 if name=="碎骨" else 3,t,999,3)
		"解形煞":
			if gate(ctx,side,item,"break",t,5):resource(ctx,side,item,"charge",2,t)
		"燎照之骑":
			if gate(ctx,side,item,"break",t,6):buff(ctx,side,item,item,"flat",5,t,999)
func after_weapon_hit(ctx:Dictionary,side:int,attacker:Dictionary,t:float,charged:bool,counters:Array)->void:
	for item in ctx.queues[side]:
		var name=rule(item);var s=own(ctx,side,item)
		if name=="钢影拳-21丁型" and gate(ctx,side,item,"hit",t,5):
			buff(ctx,side,item,item,"flat",5,t,999);s.punch_heal=true
		if name=="千般渡" and charged and s.stack>0 and gate(ctx,side,item,"counter",t,5):counters.append({"side":side,"item":item,"damage":s.stack*4*weapon_damage_weight(ctx,side,item)});s.stack=0
func after_hp_hit(ctx:Dictionary,side:int,t:float)->void:
	for item in ctx.queues[side]:
		if rule(item)!="穿击枪-26型":continue
		var s=own(ctx,side,item)
		if s.stack>0 and ctx.states[side].hp>0 and gate(ctx,side,item,"hit",t,3):s.stack-=1;heal(ctx,side,item,3,t,false)
func end_stance(ctx:Dictionary,side:int,item:Dictionary,t:float)->void:
	var s=own(ctx,side,item)
	if float(s.get("stance_end",0))<=0:return
	if not s.get("caught",false):
		before_attack(ctx,side,item,t,false)
		var additions=take_buffs(ctx,side,item,t,false)
		queue_hit(ctx,side,item,(6+additions.flat+minf(6*additions.base_percent,6)+minf(6*additions.last_percent,6))*(1+additions.percent),t,"attack")
	s.stance_end=0.0
	resource(ctx,side,item,"charge",1,t)
	ctx.pending.append({"side":side,"actions":[{"type":"break_shield","value":3,"item":item,"ordinary":false,"kind":"derived"}]})
	# One stance resolution is one natural Echo activation; counter damage itself remains derived.
	natural(ctx,side,item,"attack",t,{"base":6.0,"damage":8.0 if s.get("caught",false) else 6.0})
func apply_noise(ctx:Dictionary,side:int,item:Dictionary,layers:int,t:float)->void:apply_noise_internal(ctx,side,item,layers,t,true)
func apply_noise_internal(ctx:Dictionary,side:int,item:Dictionary,layers:int,t:float,ordinary:bool)->int:
	if not ctx.has("local"):super.apply_noise(ctx,side,item,layers,t);return 0
	if layers<=0:return 0
	var target=ctx.states[1-side];var before=int(target.noise)
	if before==0:target.noise_next=t+2;ctx.noise_parts[1-side]=[]
	var actual=mini(layers,6-before)
	for i in range(actual):ctx.noise_parts[1-side].append({"side":side,"item":item.duplicate()})
	target.noise=mini(6,before+layers);target.noise_until=t+12;target.debuff_seen=true
	status_event(ctx,side,"noise",actual,t,item.uid,1-side,"光噪")
	if ordinary and actual>0:natural(ctx,side,item,"noise",t,{"amount":actual})
	if target.noise>=6:
		for source in ctx.queues[side]:
			if rule(source)=="林间的咏叹调" and gate(ctx,side,source,"noise",t,8):ctx.team[side].forest_until=t+6
	use_threshold_provisions(ctx,1-side,t)
	return actual
func tick_noise(ctx:Dictionary,side:int,t:float)->void:
	if not ctx.has("local"):super.tick_noise(ctx,side,t);return
	var state=ctx.states[side]
	if state.noise<=0:return
	while state.noise_next<=t+EPS and state.noise_next<=state.noise_until+EPS:
		for contribution in ctx.noise_parts[side]:
			var owner=int(contribution.side);var item=contribution.item;var global=0.0
			if state.noise_next<=float(ctx.team[owner].get("noise_boost_until",-1))+EPS:global=.25
			if state.noise_next<=float(ctx.team[owner].get("forest_until",-1))+EPS:global=maxf(global,.2)
			queue_hit(ctx,owner,item,(1+global)*(1.25 if rule(item)=="焰光裁定" else 1.0),t,"noise_tick")
		state.noise_next+=2
	if t+EPS>=state.noise_until:state.noise=0;ctx.noise_parts[side]=[];status_event(ctx,side,"noise",0,t,"",side,"光噪消退")
func apply_frost(ctx:Dictionary,side:int,item:Dictionary,layers:int,t:float)->void:apply_frost_internal(ctx,side,item,layers,t,true)
func apply_frost_internal(ctx:Dictionary,side:int,item:Dictionary,layers:int,t:float,ordinary:bool)->int:
	if not ctx.has("local"):super.apply_frost(ctx,side,item,layers,t);return 0
	var target=ctx.states[1-side];var applied=0
	for index in range(maxi(0,layers)):
		if t+EPS<target.frost_immune_until:return applied
		target.frost+=1;target.frost_until=t+8;target.debuff_seen=true;ctx.team[side].last_frost=t
		applied+=1
		status_event(ctx,side,"frost",1,t,item.uid,1-side,"霜渐")
		if target.frost>=5:
			target.frost=0;target.frost_until=0.0;target.freeze_until=t+.6;target.frost_immune_until=t+3.6
			status_event(ctx,side,"freeze",.6,t,item.uid,1-side,"冻结")
			for source in ctx.queues[side]:
				if rule(source)=="灼霜" and gate(ctx,side,source,"freeze",t,5):buff(ctx,side,source,source,"flat",7,t,999)
				if rule(source)=="存帧" and gate(ctx,side,source,"freeze",t,6):own(ctx,side,source).snapshot=true
		use_threshold_provisions(ctx,1-side,t)
	return applied
func cleanse(ctx:Dictionary,side:int,layers:int,t:float,uid:String)->void:
	var before=int(ctx.states[side].noise)
	super.cleanse(ctx,side,layers,t,uid)
	if ctx.has("noise_parts"):
		for i in range(mini(before-int(ctx.states[side].noise),ctx.noise_parts[side].size())):ctx.noise_parts[side].pop_back()
func notify_stars(ctx:Dictionary,side:int,trigger:Dictionary,roots:Array,t:float,bundle:Dictionary)->void:
	super.notify_stars(ctx,side,trigger,roots,t,bundle)
	if ctx.has("local"):
		for root in roots:
			if root in ["attack","heal","shield"]:
				var data={"base":float(C.items.get(trigger.kind,{}).get("damage",0))}
				if root=="heal":data.merge(own(ctx,side,trigger).get("last_heal",{}),true)
				natural(ctx,side,trigger,root,t,data)
		if "activate" in roots and "attack" not in roots and C.is_tag(trigger.kind,"echo"):natural(ctx,side,trigger,"attack",t,{"base":0.0})
		if "supply" in roots:natural(ctx,side,trigger,"supply",t)
func frame(t:float,ctx:Dictionary)->Dictionary:
	var out=super.frame(t,ctx)
	if not ctx.has("local"):return out
	out.combo_meters=[{},{}]
	out.fatigue_rate=fatigue_rate(t)
	for side in range(2):
		out.sides[side].fatigue=float(ctx.totals[side].get("fatigue",0))
		for item in ctx.queues[side]:
			if profile(item).is_empty():continue
			var s=own(ctx,side,item)
			var meter=COMBOS.meter(self,ctx,side,item)
			if not meter.is_empty():out.combo_meters[side][item.uid]=meter
			out.weapon_marks[side][item.uid]=mini(6,maxi(int(s.stack),int(s.get("prep",0))))
			if not out.cooldown_fractions[side].has(item.uid):
				var fraction=0.0
				var has_clock=false
				var material=profile(item).get("material_effect",{})
				if material.get("trigger","")=="clock":
					has_clock=true
					fraction=clampf(1-(float(s.get("material_next",material.period))-t)/float(material.period),0,1)
				for key in s.clocks:
					var period=5.0 if key=="stance" else float(profile(item).get(key+"Period",0))
					if period>0:
						has_clock=true;fraction=maxf(fraction,clampf(1-(float(s.clocks[key])-t)/period,0,1))
				# Opening/threshold provisions have no repeating cooldown. A fabricated
				# zero progress would leave them permanently dark even before activation.
				if has_clock:
					out.cooldown_fractions[side][item.uid]=fraction
					out.progress[side][item.uid]=fraction
	return out

func apply_actions(ctx:Dictionary,side:int,item:Dictionary,actions:Array,t:float,ordinary:bool,bundle:Dictionary,kind:String="derived",flat_bonus:float=0.0)->Dictionary:
	var actual_actions=actions
	if ctx.has("local") and ordinary and profile(item).is_empty():
		var extras=take_buffs(ctx,side,item,t,false)
		flat_bonus+=float(extras.flat)*weapon_damage_weight(ctx,side,item)
		actual_actions=actions.duplicate(true)
		var indices=[];var total=0.0
		for index in range(actual_actions.size()):
			if actual_actions[index].type=="damage":indices.append(index);total+=float(actual_actions[index].value)
		if not indices.is_empty() and total>0:
			var base_bonus=minf(6,total*float(extras.base_percent))
			for index in indices:
				var original=float(actual_actions[index].value)
				actual_actions[index].value=(original+base_bonus*original/total)*(1+float(extras.percent))
			var last=indices[-1]
			actual_actions[last].value+=minf(6,float(actions[last].value)*float(extras.last_percent))
	return super.apply_actions(ctx,side,item,actual_actions,t,ordinary,bundle,kind,flat_bonus)

func add_shield(ctx:Dictionary,side:int,amount:float,t:float,uid:String,label:String="护盾")->float:
	var actual=super.add_shield(ctx,side,amount,t,uid,label)
	if actual>EPS:ctx.events[-1].actual_value=actual
	return actual

func heal(ctx:Dictionary,side:int,item:Dictionary,amount:float,t:float,ordinary:bool=false)->float:
	var before=float(ctx.states[side].hp)/float(ctx.states[side].max_hp)
	var actual=super.heal(ctx,side,item,amount,t,ordinary)
	if actual>EPS:ctx.events[-1].actual_value=actual
	CREW114.specialty_overflow(self,ctx,side,item,amount,actual,t)
	CREW114.overflow(self,ctx,side,item,amount,actual,t)
	if ctx.has("local") and ordinary and actual>0:own(ctx,side,item).last_heal={"before":before,"after":float(ctx.states[side].hp)/float(ctx.states[side].max_hp),"amount":actual}
	return actual

func material_cycle(_ctx:Dictionary,_side:int,_item:Dictionary,_t:float,_actual:bool)->void:
	pass
