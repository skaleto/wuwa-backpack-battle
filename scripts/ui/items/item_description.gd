extends RefCounted
## Readable clauses are derived from executable rules, never legacy v60.rows.
const V75=preload("res://scripts/ui/items/item_presentation_v75.gd")
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/ui/items/item_info.gd")
const P=preload("res://scripts/inventory/pocket_rules.gd")
const TAGS={"attack":"攻击物品","provision":"补给","healing":"治疗物品","shielding":"护盾物品","weapon":"武器","echo":"声骸"}

static func outcome(a:Dictionary)->String:
	var n=I.number(a.get("value",0))
	match str(a.type):
		"damage":return "对敌方造成"+n+"点伤害"
		"heal":return "我方恢复"+n+"点生命"
		"shield":return "我方获得"+n+"点[shield]护盾"
		"charge":return "我方获得"+n+"层[charge]充能"
		"haste":return "我方获得"+n+"层[haste]迅捷"
		"noise":return "对敌方施加"+n+"层[noise]光噪"
		"frost":return "对敌方施加"+n+"层[frost]霜渐"
		"break_shield":return "额外削去敌方"+n+"点护盾"
		"cleanse":return "移除我方"+n+"层减益"
		"max_hp":return "我方生命及上限增加"+n+"点"
		"stamina":return "我方恢复"+n+"点体力"
		"stamina_discount":return "本场物品体力消耗降低"+I.number(float(a.value)*100)+"%"
	return I.action_phrase(a)

static func stats(kind:String,base:String="")->Array:
	if V75.has_profile(kind):return V75.stats(kind,base)
	var d=C.items[kind];var result=[]
	for spec in [["damage","伤害","attack"],["heal","治疗","healing"],["cooldown","间隔",""],["stamina","体力消耗","stamina"]]:
		var value=float(d.get(spec[0],0));var old=float(C.items.get(base,{}).get(spec[0],0))
		if value<=0 and (base.is_empty() or old<=0):continue
		var text=I.number(value)+("秒" if spec[0]=="cooldown" else "")
		if not base.is_empty() and not is_equal_approx(value,old):text=I.number(old)+" → "+text
		result.append([spec[1],text,spec[2]])
	if not base.is_empty():
		var before=C.items[base].shape.size();var after=d.shape.size()
		result.append(["占格",str(after) if before==after else str(before)+" → "+str(after),"bag"])
	return result

static func effects(kind:String)->Array:
	if V75.has_profile(kind):return V75.effects(kind)
	var d=C.items[kind];var model=d.get("v60",{});var out=[]
	if C.is_tag(kind,"bag"):
		var profile=P.profile(kind);var percent=I.number(float(profile.amount)*100)+"%"
		match str(profile.stat):
			"shield":return ["开战时，每个已使用的口袋格提供"+I.number(profile.amount)+"点护盾。"]
			"speed":return ["接触此口袋的物品冷却缩短"+percent+"；同类不叠加。"]
			"echo":return ["接触此口袋的声骸出手伤害提高"+percent+"；同类不叠加。"]
			"weapon":return ["接触此口袋的武器伤害提高"+percent+"；同类不叠加。"]
		return ["扩展物品可放置的区域。"]
	if C.is_tag(kind,"material") or C.is_tag(kind,"craft_material"):return ["用于合成配方。"]
	var activation=str(model.get("activation","none"))
	var prefix={"opening":"开战时，","stamina3":"我方体力低于3时，","hp50":"我方生命低于50%时，","hp60":"我方生命低于60%时，","time6":"战斗第6秒，","first_debuff":"我方首次受到减益时，","cooldown":"每次发动后，","none":""}.get(activation,"")
	var normal=[];var hits=[]
	for a in model.get("actions",[]):
		if a.type=="damage":hits.append(I.number(a.value))
		elif a.type!="heal" or activation!="cooldown":normal.append(outcome(a))
	if not normal.is_empty():out.append(prefix+"；".join(normal)+"。")
	if hits.size()>1:out.append("每次发动连续造成"+"、".join(hits)+"点伤害。")
	var star=model.get("star",{})
	if not star.is_empty():
		var target=str(d.get("target",""));var event=str(star.get("event",""));var lead=""
		if event=="self":lead="本物品发动且[star]格上有["+target+"]"+TAGS.get(target,target)+"时，"
		else:
			lead="[star]格上的["+target+"]"+TAGS.get(target,target)+{"attack":"攻击时，","heal":"有效治疗时，","shield":"提供护盾时，","supply":"发动时，","activate":"发动时，"}.get(event,"发动时，")
		var actions=[]
		for a in star.get("actions",[]):actions.append(outcome(a))
		if not actions.is_empty():out.append(lead+"；".join(actions)+"。")
		if float(star.get("interval",0))>0:out.append("星位同族触发间隔："+I.number(star.interval)+"秒。")
	for key in model.get("special",{}):
		var r=model.special[key]
		match str(key):
			"matched_healer_shield":out.append("每次发动时，[star]格上每件[healing]治疗物品提供"+I.number(r.per_item)+"点护盾，最多计"+str(int(r.max_items))+"件，同件只计一次。")
			"haste_damage":out.append("我方迅捷达到"+I.number(r.min_stacks)+"层时，本物品普攻伤害增加"+I.number(r.value)+"。")
			"low_hp_damage":out.append("敌方生命低于"+I.number(float(r.threshold)*100)+"%时，本物品普攻伤害增加"+I.number(r.value)+"。")
			"haste_stamina":out.append("我方迅捷达到"+I.number(r.min_stacks)+"层时，本物品体力消耗降低"+I.number((1-float(r.multiplier))*100)+"%。")
			"haste_derived":out.append("我方迅捷达到"+I.number(r.min_stacks)+"层时，本物品每次发动追加"+I.number(r.value)+"点伤害。")
			"noise_consume":out.append(("充能攻击时，" if r.get("requires_charge",true) else "本物品普攻时，")+"消耗敌方最多"+I.number(r.max_layers)+"层光噪，每层造成"+I.number(r.damage_per_layer)+"点伤害。")
			"shield_strike":out.append("本物品普攻消耗我方最多"+I.number(r.consume)+"点护盾，每点增加"+I.number(r.multiplier)+"点伤害。")
			"shield_counter":out.append("我方护盾挡下普攻时，反击造成"+I.number(r.damage)+"点伤害；同族间隔"+I.number(r.interval)+"秒。")
	if C.is_tag(kind,"provision"):out.append("每场一次。")
	if out.is_empty():
		if activation=="cooldown":out.append("冷却结束后自动发动。")
		else:out.append("无主动效果。")
	return out

static func compact(actions:Array,omit_stats:bool=true)->String:
	var result=[]
	for action in actions:
		if omit_stats and action.type in ["damage","heal"]:continue
		var key={"damage":"伤害","heal":"治疗","shield":"护盾","charge":"充能","haste":"迅捷","noise":"光噪","frost":"霜渐","break_shield":"削盾","cleanse":"净化","max_hp":"生命上限","stamina":"体力","stamina_discount":"体力减耗"}.get(action.type,action.type)
		result.append(key+I.number(float(action.value)*100 if action.type=="stamina_discount" else action.value)+("%" if action.type=="stamina_discount" else "层" if action.type in ["charge","haste","noise","frost","cleanse"] else "点"))
	return "、".join(result) if not result.is_empty() else "无"

static func changes(base:String,target:String,recipe_id:String="")->Array:
	if V75.has_profile(target):return V75.changes(base,target,recipe_id)
	var before=C.items[base].get("v60",{});var after=C.items[target].get("v60",{});var out=[]
	var old=compact(before.get("actions",[]));var now=compact(after.get("actions",[]))
	if old!=now:out.append("发动效果："+old+" → "+now)
	var a=before.get("star",{});var b=after.get("star",{})
	var trigger_a=TAGS.get(C.items[base].get("target",""),"")+{"supply":"发动","attack":"攻击","heal":"治疗","shield":"获盾","activate":"发动","self":"本件发动"}.get(a.get("event",""),"")
	var trigger_b=TAGS.get(C.items[target].get("target",""),"")+{"supply":"发动","attack":"攻击","heal":"治疗","shield":"获盾","activate":"发动","self":"本件发动"}.get(b.get("event",""),"")
	if a.is_empty():trigger_a="无"
	if b.is_empty():trigger_b="无"
	if trigger_a!=trigger_b:out.append("星位触发："+trigger_a+" → "+trigger_b)
	if compact(a.get("actions",[]),false)!=compact(b.get("actions",[]),false):out.append("星位效果："+compact(a.get("actions",[]),false)+" → "+compact(b.get("actions",[]),false))
	if not is_equal_approx(float(a.get("interval",0)),float(b.get("interval",0))):out.append("星位同族间隔："+I.number(a.get("interval",0))+" → "+I.number(b.get("interval",0))+"秒")
	# For special-rule changes retain the complete source and destination clauses.
	if before.get("special",{})!=after.get("special",{}) or before.get("activation","")!=after.get("activation",""):
		var previous=effects(base);var current=effects(target)
		for line in previous:
			if line not in current:out.append("移除："+line)
		for line in current:
			if line not in previous:out.append("获得："+line)
	return out
