extends RefCounted
## Shared display adapter. Numeric clocks come from the executable V75 profile;
## approved own/star clauses describe the explicit handlers in battle_v75.gd.
const C=preload("res://scripts/data/catalog.gd")
const RULES=preload("res://scripts/battle/battle_v75_rules.gd")
const ALIASES={"heal":"healing","emergency":"healing","shield":"shielding","once_shield":"shielding","hp":"max_hp"}
const LABELS={"attack":"攻击","healing":"治疗","shielding":"护盾","charge":"充能","haste":"迅捷","noise":"光噪","frost":"霜渐","cleanse":"净化","break_shield":"削盾","max_hp":"生命上限","stamina":"体力","counter":"反击"}
# These capabilities are conditional handlers, not unconditional numeric supplies.
const BREAKERS=["inferno","wuka","echo_vanguard","echo_formrender","echo_wankui","rocksteady","violet","weapon_21010044","weapon_21010045","weapon_21010046","weapon_21020045","weapon_21020096","weapon_21030045","weapon_21030066","weapon_21040036","weapon_21040046","weapon_21050045","weapon_21050116","answer"]
const COUNTERS=["violet","weapon_21010076"]
static func has_profile(kind:String)->bool:return not C.profile(kind).is_empty()
static func number(value)->String:return str(int(value)) if is_equal_approx(float(value),roundf(float(value))) else String.num(float(value),2)
static func clauses(text:String)->Array:
	var out=[]
	for sentence in text.replace("★","[star]").replace("耐力","体力").replace("CD","冷却").split("。",false):
		if sentence.contains("预算") or sentence.contains("上版") or sentence.contains("无额外机制") or sentence.contains("无额外星位规则"):continue
		out.append(sentence+"。")
	return out
static func specialty_own_text(kind:String)->String:
	# Specialty prose is a projection of the same fields consumed by combat.
	# Keep the frozen catalogue untouched: its source participates in save hashes.
	var spec:Dictionary=C.items[kind].get("v114",{})
	match str(spec.get("action","")):
		"stamina":return "每"+number(spec.period)+"秒，我方回复"+number(spec.value)+"点体力。"
		"overflow_shield":return "自身溢出治疗的"+number(float(spec.value)*100)+"%转为护盾；每"+number(spec.period)+"秒最多"+number(spec.cap)+"点。"
	return ""
static func specialty_star_text(kind:String)->String:
	var spec:Dictionary=C.profile(kind).get("material_effect",{})
	if spec.is_empty():return ""
	var category={"weapon":"武器","echo":"声骸"}.get(str(spec.get("category","")),"")
	var timing="每"+number(spec.period)+"秒，"
	match str(spec.action):
		"advance":return timing+"使[star]星位上剩余冷却最长的一件"+category+"冷却提前"+number(spec.value)+"秒。"
		"flat":return timing+"使[star]星位上基础伤害最高的一件"+category+"下一击伤害增加"+number(spec.value)+"点。"
		"stamina":return timing+"[star]星位上有"+category+"时，我方回复"+number(spec.value)+"点体力。"
	return ""
static func own_text(kind:String)->String:
	if C.items[kind].has("crew_supply"):return specialty_own_text(kind)
	# Migration/design commentary does not belong in a live effect card.
	var text=str(C.profile(kind).ownExtra)
	var removals=["移除浩境爆发计数。","移除暗夜首击奖励。","；不保留异度额外治疗强化计数","，已整合输入治疗，不再叠旧强化计数","；不保留曜光另一段强化"]
	for phrase in removals:text=text.replace(phrase,"")
	if kind=="weapon_21050066":text=""
	if kind in ["cheongsam","magnifier"] and not C.items[kind].has("v127"):text="仅供收藏，不参与战斗。"
	elif text.begins_with("组件或收藏") or text.begins_with("合成材料"):text="用于合成配方，不参与战斗。"
	return text
static func support_effects(kind:String)->Array:
	var n=C.profile(kind);var result=[]
	for spec in [["heal","治疗","healing"],["shield","护盾","shield"],["noise","光噪","noise"],["frost","霜渐","frost"]]:
		var period=float(n.get(spec[0]+"Period",0));var amount=float(n.get(spec[0]+"Amount",1))
		if period>0:result.append("独立每"+number(period)+"秒"+spec[1]+number(amount)+("层" if spec[0] in ["noise","frost"] else "点")+"。")
	if float(n.hp)>0:result.append("开战时生命及上限+"+number(n.hp)+"；同类生命加成取最高。")
	if float(n.emergency)>0:result.append("首次存活且生命低于50%时立即治疗"+number(n.emergency)+"；同类急救全队每场共一次。")
	if float(n.openingShield)>0:result.append(("开战时" if float(n.openingShield)>=12 or ((C.items[kind].has("v127") or C.items[kind].has("v128")) and float(n.openingShield)<8) else "首次存活且生命低于60%时")+"护盾+"+number(n.openingShield)+"；每场一次。")
	return result
static func star_effects(kind:String)->Array:
	if C.items[kind].has("crew_supply"):return clauses(specialty_star_text(kind))
	return clauses(str(C.profile(kind).starText))
static func mechanics(kind:String)->Array:
	var n=C.profile(kind);var text=own_text(kind)
	# Remove duplicated baseline fragments only. Conditions, caps and exceptions stay.
	var redundant=["每次自然攻击后充能1。","每次自然攻击后充能+1。","保留每次自然攻击后充能+1。","保留每次本体自然攻击后充能1。","每次自然发动后充能1。","每次发动后充能2。","每次自然发动迅捷1。","每2次自然攻击获得迅捷1。","每2次自然攻击获得迅捷1；","保留每2击迅捷1。","基础附噪每6秒1层。","每6秒6盾；","每5秒5盾；","保留每5秒4治疗。","保留基础盾与生命15。","保留基础真实供盾和生命；","保留独立治疗与霜渐。","基础附噪独立供给。","基础治疗独立时钟；","基础治疗使用独立5秒时钟；","每5秒治疗4；","每5秒治疗12，生命15；","每5秒治疗12，生命15。","基础每5秒治疗11。","独立治疗每5秒6；","每6秒治疗3，无攻击和额外星位收益。"]
	for fragment in redundant:text=text.replace(fragment,"")
	text=text.replace("每次自然攻击后充能1，其他收益给伙伴。","")
	if float(n.hp)>0:text=text.replace("开战生命上限与当前生命+15；茶及继承者全队同源取最高。","")
	if float(n.openingShield)>=12:text=text.replace("开战护盾12，每场一次。","")
	if kind=="nutrition":return [] # Shared emergency clause includes the full living/threshold gate.
	if kind=="weapon_21040066":return [] # Its attack value already includes the approved tradeoff.
	return clauses(text)

static func effects(kind:String)->Array:
	var n=C.profile(kind);var result=[]
	result.append_array(support_effects(kind))
	if int(n.charge)>0:result.append("每次自然攻击后充能+"+number(n.charge)+"。")
	if int(n.hasteEvery)>0:result.append("每"+number(n.hasteEvery)+"次自然攻击获得迅捷1。")
	for line in mechanics(kind):
		if line not in result:result.append(line)
	for line in star_effects(kind):
		if line not in result:result.append(line)
	if result.is_empty():result.append("按攻击间隔自动攻击。" if float(n.damage)>0 else "无战斗效果。")
	return result
static func stats(kind:String,base:String="")->Array:
	var n=C.profile(kind);var old=C.profile(base);var result=[]
	for spec in [["damage","基础伤害","attack"],["cd","攻击间隔",""],["stamina","体力消耗","stamina"]]:
		if spec[0]=="cd" and (float(n.damage)<=0 or kind=="violet"):continue
		if spec[0]=="damage" and kind=="violet":continue
		var value=float(n.get(spec[0],0));var previous=float(old.get(spec[0],0))
		if value<=0 and (base.is_empty() or previous<=0):continue
		var value_text=number(value)+("秒" if spec[0]=="cd" else "")
		if not base.is_empty() and not is_equal_approx(value,previous):value_text=number(previous)+" → "+value_text
		result.append([spec[1],value_text,spec[2]])
	if not base.is_empty():result.append(["占格",str(C.items[base].shape.size())+" → "+str(C.items[kind].shape.size()),"bag"])
	return result
static func cost_label(item:Dictionary)->String:
	return {"legacy_estimate":"旧值估算","mixed":"成本含估算","known_free":"免费获得"}.get(item.get("cost_basis","actual"),"支付成本")

static func rows(item:Dictionary)->Array:
	var result=[["占格 / 标价",str(C.items[item.kind].shape.size())+" 格 / "+number(C.items[item.kind].price)+" 贝币"]]
	for row in stats(item.kind):result.append([row[0],row[1]])
	if item.has("paid_cost"):
		result.append([cost_label(item),number(item.paid_cost)+" 贝币"])
		result.append(["卖出返还",str(int(item.paid_cost)/2)+" 贝币"])
	result.append_array(effect_rows(item.kind));return result
static func effect_rows(kind:String)->Array:return effects(kind).map(func(line):return ["效果",line])
static func star_rows(kind:String)->Array:return star_effects(kind).map(func(line):return ["[star]星位",line])
static func choice_summary(kind:String)->String:
	var n=C.profile(kind)
	match str(n.get("rule","")):
		"wing":return "声骸助充能；开场充能+%s，每%d击再获得%s。"%[number(n.opening_charge),n.charge_every,number(n.charge_gain)]
		"morning":return "充能击额外+%s伤害，并给★武器下一击+%s。"%[number(n.charged_flat),number(n.partner_flat)]
		"east":return "★武器帮助蓄力；充能击消耗最多%d层，每层+%s伤害。"%[n.stack_cap,number(n.stack_flat)]
		"verdant":return "每击削盾%s；充能攻击消耗自身护盾换伤害。"%number(n.break_amount)
		"feijing","laser":return "强化击伤害+%s，推进一件★武器%s秒。"%[number(n.prepare_flat),number(n.partner_advance)]
		"frost":return "★武器%d击附霜；有%d层霜时每第%d击+%s伤害。"%[n.star_threshold,n.frost_min,n.prepare_every,number(n.prepare_flat)]
		"yunlang":return "不同★声骸交替攻击：迅捷+1，自身冷却提前%s秒。"%number(n.self_advance)
		"haixing","qianban":return "实际挡住%d次自然攻击，反击%s伤害；需要持续供盾。"%[n.block_threshold,number(n.counter_damage)]
		"steel":return "实际挡伤%s点后，下一拳+%s伤害并治疗%s。"%[number(n.block_amount),number(n.prepare_flat),number(n.punch_heal)]
		"rock":return "★武器%d击强化下次护盾；本体攻击削盾%s。"%[n.star_threshold,number(n.break_amount)]
	return ""
static func chips(kind:String)->Array:
	var tags=C.items[kind].tags.duplicate();tags.append_array(C.profile(kind).capabilities)
	if C.items[kind].has("v124") or C.items[kind].has("v125") or C.items[kind].has("v127"):tags=C.profile(kind).capabilities.duplicate()
	if kind in BREAKERS:tags.append("break_shield")
	if kind in COUNTERS:tags.append("counter")
	if kind=="daily_tea":tags.append("haste")
	if kind=="spicy_meat":tags.append("charge")
	if kind in ["soup","dragon_food"]:tags.append("stamina")
	var out=[];var used=[]
	for tag in tags:
		var key=ALIASES.get(tag,tag)
		if LABELS.has(key) and key not in used:
			var label="穿盾" if kind=="answer" and C.items[kind].has("v125") and key=="break_shield" else LABELS[key]
			out.append([key,label]);used.append(key)
	return out
static func recipe_inputs(base:String,target:String,recipe_id:String="")->Array:
	for recipe in C.combinations:
		if recipe.base==base and recipe.target==target and (recipe_id.is_empty() or str(recipe.id)==recipe_id):return [base]+recipe.materials
	return [base]
static func resource_description(key:String,value:float)->String:
	return "每"+number(value)+"次攻击获得1层" if key=="hasteEvery" else number(value)

static func changes(base:String,target:String,recipe_id:String="")->Array:
	var inputs=recipe_inputs(base,target,recipe_id);var out=[];var n=C.profile(target)
	# Compare both consumed inputs by mechanical field, independently of prose spelling.
	for spec in [["heal","治疗供给"],["shield","护盾供给"],["noise","光噪供给"],["frost","霜渐供给"]]:
		var before=[]
		for input in inputs:
			var p=C.profile(input)
			if float(p.get(spec[0]+"Period",0))>0:before.append(C.items[input].name+" 每"+number(p[spec[0]+"Period"])+"秒"+number(p.get(spec[0]+"Amount",1)))
		var period=float(n.get(spec[0]+"Period",0))
		if before.is_empty() and period<=0:continue
		var after="每"+number(period)+"秒"+number(n.get(spec[0]+"Amount",1)) if period>0 else "无"
		out.append(("失去" if period<=0 else "保留并整合" if not before.is_empty() else "获得")+spec[1]+"："+("、".join(before) if not before.is_empty() else "无")+" → "+after+"。")
	for spec in [["hp","开战生命加成"],["emergency","一次急救"],["openingShield","一次护盾"],["charge","每次攻击充能"],["hasteEvery","迅捷"]]:
		var before=[]
		for input in inputs:
			var value=float(C.profile(input).get(spec[0],0))
			if value>0:before.append(C.items[input].name+" "+resource_description(spec[0],value))
		var value=float(n.get(spec[0],0))
		if before.is_empty() and value<=0:continue
		out.append(("失去" if value<=0 else "保留并整合" if not before.is_empty() else "获得")+spec[1]+"："+("、".join(before) if not before.is_empty() else "无")+" → "+(resource_description(spec[0],value) if value>0 else "无")+"。")
	var current_caps=chips(target).map(func(chip):return chip[0])
	for input in inputs:
		if not has_profile(input):continue
		for chip in chips(input):
			if chip[0] in ["counter","break_shield","cleanse"] and chip[0] not in current_caps:out.append("失去"+chip[1]+"能力（输入："+C.items[input].name+"）。")
	var after=mechanics(target)+star_effects(target);var previous=[]
	for input in inputs:
		if not has_profile(input):continue
		for line in mechanics(input)+star_effects(input):
			if line in ["用于合成配方，不参与战斗。","仅供收藏，不参与战斗。"]:continue
			previous.append(line)
			out.append(("保留" if line in after else "输入机制")+" · "+C.items[input].name+"："+line)
	for line in after:
		if line not in previous:out.append("成品机制："+line)
	return out
