extends RefCounted
## Six routes share bounded cadence, layers, marks, windows, healing and owner charges.
## The controller is passed in: this module never preloads Battle or Inventory.
const C=preload("res://scripts/data/catalog.gd")
const SUP=preload("res://scripts/party/supports.gd")
const EPS=.00001

static func initialise(ctx: Dictionary) -> void:
	for state in ctx.states:
		state.resonance={"weapons":{},"layers":{"wind":[],"noise":[]},"coord_until":0.0,"yinlin_until":0.0,"coord_icd":0.0,"coord_bonus":0.0,"coord_bonus_until":0.0,"photo_count":0,"photo_ready":false,"verina_count":0,"verina_ready":false,"jiyan_count":0,"jiyan_ready":false,"entry_count":0,"entry_ready":false,"encore_charges":0,"owner_until":{},"owner_charges":{}}
	for side in range(2):
		for item in ctx.queues[side]:
			if not C.is_tag(item.kind,"weapon"):continue
			ctx.states[side].resonance.weapons[item.uid]={"count":0,"heavy_ready":false,"heavy_until":0.0,"heavy_charge":false,"marks":0,"mark_until":0.0,"burst_charges":0,"burst_until":0.0,"heal_until":0.0}

static func power(item: Dictionary) -> float:return float(C.items[item.kind].get("route_power",1.0))
static func tier(item: Dictionary) -> int:return int(C.items[item.kind].get("craft_tier",2))
static func route(item: Dictionary) -> String:return str(C.items[item.kind].get("mechanic",""))
static func terminal(item: Dictionary) -> bool:return tier(item)>=5
static func empowered(engine,ctx: Dictionary,side: int,item: Dictionary) -> bool:return terminal(item) and signature_active(engine,ctx.builds[side],item)
static func mechanic_power(engine,ctx: Dictionary,side: int,item: Dictionary) -> float:return power(item) if not terminal(item) or empowered(engine,ctx,side,item) else 1.65
static func main(engine,ctx: Dictionary,side: int,item: Dictionary) -> bool:return engine.inventory.primary_weapon(ctx.builds[side]).get("uid","")==item.uid
static func signature_active(engine,build: Dictionary,item: Dictionary) -> bool:
	var def=C.items[item.kind]
	if not def.get("strict_signature",false):return false
	var owners=def.get("signature_owner_ids",[])
	var leader=C.characters.get(build.get("leader",""),{}).get("roster_id","")
	if leader in owners:return true
	for id in build.get("supports",[]):
		if id in owners and SUP.carrier(build,id).get("uid","")==item.uid:return true
	return false
static func owner(engine,ctx: Dictionary,side: int,item: Dictionary,id: String) -> bool:
	return id in C.items[item.kind].get("signature_owner_ids",[]) and signature_active(engine,ctx.builds[side],item)

static func add_layer(engine,ctx: Dictionary,side: int,item: Dictionary,id: String,time: float,damage: float) -> void:
	var layers=ctx.states[1-side].resonance.layers[id]
	if layers.size()>=6:return
	layers.append({"created":time,"expires":time+6.0,"next":time+2.0,"side":side,"uid":item.uid,"kind":item.kind,"damage":damage})
	var ev=engine.event(time,side,"mark",layers.size(),item.uid,"风蚀" if id=="wind" else "光噪")
	ev.status=id;ev.resources=false;ctx.events.append(ev)

static func maintain(ctx: Dictionary,victim: int,id: String,time: float) -> void:
	for layer in ctx.states[victim].resonance.layers[id]:
		if float(layer.expires)>time+EPS:layer.expires=minf(float(layer.created)+8.0,maxf(float(layer.expires),time+2.0))

static func consume_layers(engine,ctx: Dictionary,side: int,item: Dictionary,id: String,time: float,limit: int=3) -> float:
	var layers=ctx.states[1-side].resonance.layers[id];var damage=0.0;var consumed=0
	for layer in layers.duplicate():
		if consumed>=limit:break
		if layer.expires<=time+EPS:continue
		var next_tick=float(layer.next);var remaining=0
		while next_tick<float(layer.expires)-EPS:remaining+=1;next_tick+=2
		damage+=float(layer.damage)*remaining;layers.erase(layer);consumed+=1
	if damage>0:engine.add_hit(ctx,side,item,damage*1.15,time,false,"noise_consume" if id=="noise" else "heavy_hit")
	return damage

static func tick(engine,ctx: Dictionary,time: float) -> void:
	for victim in range(2):
		var r=ctx.states[victim].resonance
		for id in ["wind","noise"]:
			var layers=r.layers[id]
			for layer in layers.duplicate():
				# Expiration wins at t+6/t+8: there is never a final expiration jump.
				if time+EPS>=float(layer.expires):layers.erase(layer);continue
				while time+EPS>=float(layer.next) and float(layer.next)<float(layer.expires)-EPS:
					engine.add_hit(ctx,int(layer.side),{"kind":layer.kind,"uid":layer.uid},float(layer.damage),float(layer.next),false,"dot")
					layer.next+=2.0
		for w in r.weapons.values():
			if time+EPS>=float(w.mark_until):w.marks=0
			if time+EPS>=float(w.burst_until):w.burst_charges=0
		if time+EPS>=float(r.yinlin_until):r.yinlin_until=0
		if time+EPS>=float(r.coord_bonus_until):r.coord_bonus=0
		if time+EPS>=float(ctx.states[victim].puppet_until):ctx.states[victim].puppet_pending=false

static func before_attack(engine,ctx: Dictionary,side: int,item: Dictionary,time: float,ordinary: bool) -> Dictionary:
	var result={"bonus":0.0,"heavy":false,"pierce":0.0}
	if not ordinary or not C.is_tag(item.kind,"weapon"):return result
	var state=ctx.states[side];var r=state.resonance;var w=r.weapons[item.uid]
	var is_main=main(engine,ctx,side,item);var weight=1.0 if is_main else engine.weapon_role_weight(ctx,side,item)
	var scaled=mechanic_power(engine,ctx,side,item)*weight
	var final=empowered(engine,ctx,side,item)
	if route(item)=="heavy":
		if w.heavy_ready:result.bonus+=(4.2 if final else 3.85)*scaled;w.heavy_ready=false;result.heavy=true
		if w.heavy_charge and time<float(w.heavy_until):result.bonus+=2.0*scaled;w.heavy_charge=false;result.heavy=true
	if route(item)=="burst" and w.burst_charges>0 and time<float(w.burst_until):
		result.bonus+=float(C.items[item.kind].get("damage",0))*(.55 if final else .40)*weight;w.burst_charges-=1
	if not is_main:return result
	if r.jiyan_ready:result.bonus+=5;r.jiyan_ready=false;result.heavy=true
	if r.entry_ready:result.bonus+=3;r.entry_ready=false;result.heavy=true
	if int(r.encore_charges)>0:result.bonus+=2;r.encore_charges-=1
	if r.verina_ready:result.bonus+=3;r.verina_ready=false;engine.add_shield(ctx,side,3,time,item.uid,"维里奈 · 光合")
	if route(item)=="photo" and r.photo_ready:
		result.bonus+=float(C.items[item.kind].get("damage",0))*(.40 if final else .25)
		r.photo_ready=false;engine.add_shield(ctx,side,5 if final else 3,time,item.uid,"光合 · 转化")
	return result

static func after_attack(engine,ctx: Dictionary,side: int,item: Dictionary,time: float,ordinary: bool,attacking: bool=false) -> void:
	if not ordinary:return
	var state=ctx.states[side];var r=state.resonance
	if item.kind=="spectro_coin":
		var weapon=engine.inventory.primary_weapon(ctx.builds[side])
		if not weapon.is_empty() and engine.inventory.element(weapon,ctx.builds[side])=="spectro" and engine.inventory.adjacent(item,weapon):
			add_layer(engine,ctx,side,item,"noise",time,1.0)
		return
	if item.kind=="puppet":
		state.puppet_pending=true;state.puppet_until=time+6
		var ev=engine.event(time,side,"mark",1,item.uid,"悬丝 · 协同强化");ev.resources=false;ctx.events.append(ev)
		return
	if C.is_tag(item.kind,"echo"):
		if attacking:coordinate(engine,ctx,side,item,time)
		return
	if not C.is_tag(item.kind,"weapon"):return
	var w=r.weapons[item.uid];w.count+=1
	var is_main=main(engine,ctx,side,item);var active=signature_active(engine,ctx.builds[side],item)
	var weight=1.0 if is_main else engine.weapon_role_weight(ctx,side,item)
	if route(item)=="heavy" and int(w.count)%3==0:w.heavy_ready=true
	if not is_main:
		# Secondary weapons retain a small ordinary-only passive, without feeding
		# main cadence/marks/layers. Its additive budget uses its resource weight.
		if int(w.count)%3==0 and route(item) in ["wind","noise","coordinated"]:
			engine.add_hit(ctx,side,item,2.0*mechanic_power(engine,ctx,side,item)*weight,time,false,"coordinated" if route(item)=="coordinated" else "extra")
		if route(item)=="photo" and int(w.count)%3==0:engine.heal(ctx,side,item,3.0*mechanic_power(engine,ctx,side,item)*weight,time,true)
		carrier_owner(engine,ctx,side,item,time,active)
		return
	if ctx.builds[side].leader=="jiyan":
		r.jiyan_count+=1
		if r.jiyan_count>=3:r.jiyan_count=0;r.jiyan_ready=true
	if ctx.builds[side].leader in ["sanhua","camellya"]:
		r.entry_count+=1
		if r.entry_count>=3:r.entry_count=0;r.entry_ready=true
	if ctx.builds[side].leader=="yinlin":r.yinlin_until=time+4
	match route(item):
		"wind":
			var amount=2 if terminal(item) and active else 1
			for _n in range(amount):add_layer(engine,ctx,side,item,"wind",time,float(C.items[item.kind].damage)*.15)
			if owner(engine,ctx,side,item,"role_1409") and int(w.count)%3==0:consume_layers(engine,ctx,side,item,"wind",time,3)
		"noise":
			add_layer(engine,ctx,side,item,"noise",time,float(C.items[item.kind].damage)*(.18 if empowered(engine,ctx,side,item) else .12))
			if owner(engine,ctx,side,item,"role_1506"):maintain(ctx,1-side,"noise",time)
			elif int(w.count)%3==0 and time+EPS>=float(r.owner_until.get("noise_consume",0)):
				r.owner_until.noise_consume=time+(3 if owner(engine,ctx,side,item,"role_1507") else 4)
				consume_layers(engine,ctx,side,item,"noise",time,3)
		"coordinated":
			w.marks=mini(3,int(w.marks)+1);w.mark_until=time+6
			var mark=engine.event(time,side,"weapon_mark",w.marks,item.uid,"印记")
			mark.source_uid=item.uid;mark.expires=w.mark_until;ctx.events.append(mark)
		"photo":
			# This is a timed ordinary root heal budget; no heal-on-heal feedback.
			if int(w.count)%3==0 and time+EPS>=float(w.heal_until):
				w.heal_until=time+3;engine.heal(ctx,side,item,3.0*mechanic_power(engine,ctx,side,item),time,true)
	carrier_owner(engine,ctx,side,item,time,active)

static func carrier_owner(engine,ctx: Dictionary,side: int,item: Dictionary,time: float,active: bool) -> void:
	if not active:return
	var r=ctx.states[side].resonance
	# Owner bonuses use an explicit ordinary activation of their selected UID.
	if owner(engine,ctx,side,item,"role_1506"):
		maintain(ctx,1-side,"wind",time);maintain(ctx,1-side,"noise",time)
	if owner(engine,ctx,side,item,"role_1407"):maintain(ctx,1-side,"wind",time)
	if not main(engine,ctx,side,item) and owner(engine,ctx,side,item,"role_1507") and time+EPS>=float(r.owner_until.get("zani",0)):
		r.owner_until.zani=time+3;consume_layers(engine,ctx,side,item,"noise",time,3)
	if not main(engine,ctx,side,item) and owner(engine,ctx,side,item,"role_1409") and time+EPS>=float(r.owner_until.get("cartethyia",0)):
		r.owner_until.cartethyia=time+4;consume_layers(engine,ctx,side,item,"wind",time,3)

static func coordinate(engine,ctx: Dictionary,side: int,echo: Dictionary,time: float) -> void:
	var state=ctx.states[side];var r=state.resonance
	if time+EPS<float(r.coord_icd):return
	var weapon=engine.inventory.primary_weapon(ctx.builds[side])
	if weapon.is_empty() or not engine.inventory.adjacent(weapon,echo):return
	var w=r.weapons[weapon.uid];var marked=int(w.marks) if time<float(w.mark_until) else 0
	var yinlin=time<float(r.yinlin_until)
	if marked==0 and not yinlin:return
	var damage=0.0;var contributions={}
	if marked>0:
		damage=float(C.items[weapon.kind].damage)*(.30 if empowered(engine,ctx,side,weapon) else .20)*marked+(7.0 if empowered(engine,ctx,side,weapon) else 4.0)
		contributions["weapon:"+weapon.uid]=damage
		if owner(engine,ctx,side,weapon,"role_1302"):
			var bonus=2.0*power(weapon);damage+=bonus;contributions["signature:"+weapon.uid]=bonus
	if yinlin:damage+=4;contributions["leader:yinlin"]=4.0
	if state.puppet_pending:damage+=2;contributions["puppet"]=2.0;state.puppet_pending=false
	if time<float(r.coord_bonus_until):
		damage+=float(r.coord_bonus);contributions["support"]=float(r.coord_bonus);r.coord_bonus=0
	w.marks=0;r.yinlin_until=0;r.coord_icd=time+3
	var source_uid=weapon.uid if marked>0 else "leader:yinlin"
	engine.add_hit(ctx,side,weapon,damage,time,false,"coordinated",false,0.0,{"uid":source_uid,"source_uid":source_uid,"carrier_uid":weapon.uid,"trigger_uid":echo.uid,"consumed_marks":marked,"contributions":contributions})
	# Only consumed weapon marks purchase this candidate advance. The simulator
	# schedules the next root before activating it, so the new timer survives.
	if weapon.kind=="weapon_21050044" and marked>0 and ctx.timers[side].has(echo.uid):
		var old_ready=float(ctx.timers[side][echo.uid])
		var new_ready=maxf(time+engine.STEP,old_ready-.5)
		ctx.timers[side][echo.uid]=new_ready
		var advance=engine.event(time,side,"cooldown_advance",old_ready-new_ready,weapon.uid,"今州守望")
		advance.source_uid=weapon.uid;advance.trigger_uid=echo.uid;advance.target_uid=echo.uid
		advance.consumed_marks=marked;advance.old_ready_time=old_ready;advance.new_ready_time=new_ready
		ctx.events.append(advance)

static func on_heal(engine,ctx: Dictionary,side: int,item: Dictionary,actual: float,time: float,ordinary: bool) -> void:
	if not ordinary or actual<=EPS:return
	var r=ctx.states[side].resonance
	if ctx.builds[side].leader=="verina":
		r.verina_count+=1
		if r.verina_count>=2:r.verina_count=0;r.verina_ready=true
	var weapon=engine.inventory.primary_weapon(ctx.builds[side])
	if not weapon.is_empty() and route(weapon)=="photo":
		r.photo_count+=1
		if r.photo_count>=2:r.photo_count=0;r.photo_ready=true
	# Ordinary healing provides a bounded owner guard, never another heal.
	if not weapon.is_empty() and owner(engine,ctx,side,weapon,"role_1505") and time+EPS>=float(r.owner_until.get("shorekeeper_heal",0)):
		r.owner_until.shorekeeper_heal=time+6;engine.add_shield(ctx,side,2,time,weapon.uid,"守岸人 · 观测")

static func on_burst(engine,ctx: Dictionary,side: int,time: float) -> void:
	var r=ctx.states[side].resonance
	if ctx.builds[side].leader=="encore":r.encore_charges=2
	for item in ctx.queues[side]:
		if not C.is_tag(item.kind,"weapon"):continue
		var w=r.weapons[item.uid]
		if route(item)=="burst":w.burst_charges=4 if empowered(engine,ctx,side,item) else 3;w.burst_until=time+10
		if route(item)=="heavy":w.heavy_charge=true;w.heavy_until=time+5

static func on_relay(engine,ctx: Dictionary,side: int,time: float) -> void:
	for item in ctx.queues[side]:
		if C.is_tag(item.kind,"weapon") and route(item)=="heavy":
			var w=ctx.states[side].resonance.weapons[item.uid];w.heavy_charge=true;w.heavy_until=time+5

static func on_outro(engine,ctx: Dictionary,side: int,selected: Dictionary,time: float) -> void:
	var r=ctx.states[side].resonance;var id=selected.role_id
	match id:
		"role_1402","role_1407":maintain(ctx,1-side,"wind",time)
		"role_1506":maintain(ctx,1-side,"noise",time);maintain(ctx,1-side,"wind",time)
		"role_1303","role_1307","role_1304":r.coord_bonus=maxf(float(r.coord_bonus),2.0 if id=="role_1303" else 3.0);r.coord_bonus_until=time+6
		"role_1305":
			var carrier=selected.path[0]
			if route(carrier)=="burst":r.weapons[carrier.uid].burst_charges=mini(4,int(r.weapons[carrier.uid].burst_charges)+1);r.weapons[carrier.uid].burst_until=time+8
		"role_1505":
			# Root guard outro is already 8 shield; it never counts as photo healing.
			r.owner_until.shorekeeper_guard=time+6

static func statuses(ctx: Dictionary,side: int,time: float) -> Array:
	var state=ctx.states[side];var r=state.resonance;var result: Array=[]
	for id in ["wind","noise"]:
		var layers=r.layers[id]
		if not layers.is_empty():
			var remaining=0.0
			for layer in layers:remaining=maxf(remaining,float(layer.expires)-time)
			result.append({"id":id,"label":"风蚀" if id=="wind" else "光噪","stacks":layers.size(),"remaining":maxf(0,remaining)})
	var marks=1 if time<float(r.yinlin_until) else 0;var coord_remaining=maxf(0,float(r.yinlin_until)-time);var heavy=(1 if r.jiyan_ready else 0)+(1 if r.entry_ready else 0);var burst=int(r.encore_charges);var burst_remaining=0.0
	for w in r.weapons.values():
		marks+=int(w.marks);coord_remaining=maxf(coord_remaining,float(w.mark_until)-time)
		if w.heavy_ready or (w.heavy_charge and time<float(w.heavy_until)):heavy+=1
		burst+=int(w.burst_charges);burst_remaining=maxf(burst_remaining,float(w.burst_until)-time)
	if marks>0:result.append({"id":"coord","label":"协同","stacks":marks,"remaining":maxf(0,coord_remaining)})
	if heavy>0:result.append({"id":"heavy","label":"破阵","stacks":heavy,"remaining":0.0})
	if burst>0:result.append({"id":"burst","label":"爆发","stacks":burst,"remaining":maxf(0,burst_remaining)})
	if r.photo_ready or r.verina_ready or r.photo_count>0 or r.verina_count>0:result.append({"id":"photo","label":"光合","stacks":2 if r.photo_ready or r.verina_ready else 1,"remaining":0.0})
	return result
