extends RefCounted

## Structured demo facts; canonical lore is retained in the source catalogue.
const V75=preload("res://scripts/ui/items/item_presentation_v75.gd")
const C=preload("res://scripts/data/catalog.gd")
const F=preload("res://scripts/crafting/craft.gd")
const P=preload("res://scripts/inventory/pocket_rules.gd")
const FEATURES=preload("res://scripts/run/demo_features.gd")
const TYPES={"sword":"迅刀","broadblade":"长刃","pistol":"佩枪","gauntlet":"臂铠","rectifier":"音感仪"}
const ELEMENTS={"aero":"气动","electro":"导电","spectro":"衍射","fusion":"热熔","glacio":"冷凝","havoc":"湮灭","neutral":"无属性"}
const FACTS={
	"tea":[["开战 · 生命上限","+15"]],
	"soup":[["触发","体力 < 3"],["恢复体力","+4"]],
	"nutrition":[["触发","生命 < 50%"],["恢复生命","+18"]],
	"revive":[["触发","首次致命伤"],["保留生命","1"],["恢复生命","+12"],["携带上限","1 件"]],
	"tube":[["使用对象","声骸"],["每级效果","+15%"],["升级上限","2 级"]],
	"tuner":[["使用对象","声骸"],["迅捷 · 冷却","−12%"],["强效 · 效果","+20%"]],
	"contract":[["星位声骸攻击 → 追击","伤害 ×35%"],["追击间隔","6 秒"],["追击回能","0"]],
	"aero_coin":[["星位气动物品","伤害 +12%"],["同类加成","不叠加"]],
	"electro_coin":[["星位导电物品","伤害 +12%"],["同类加成","不叠加"]],
	"sail":[["解放 → 接力终点","下一击 +50%"]],
	"feilian":[["连击","8 + 10"],["星位重击武器","下一击 +4"]],
	"thundering":[["相邻角色信物","下次解放 +6"]],
	"bellborne":[["钟盾减伤","3 × 3 次"],["星位有效治疗 → 钟盾","+1 · 上限 +3"]],
	"heron":[],
	"inferno":[["连击","5 + 5 + 8"],["星位武器","下两击各 +2"]],
	"violet":[["下次受击减伤","4"],["格挡反击","7"]],
	"whiff":[["连击","3 + 3"]],
	"turtle":[["满血回能","0"]],
	"rocksteady":[["每次护盾","+8"]],
	"strategy":[["接力终点","伤害 +2"]],
	"puppet":[["下次普通声骸协同","+2"],["强化窗口","6 秒"]],
	"flower":[["星位有效治疗 → 下次技能","护盾 +2"],["触发间隔","3 秒"]],
	"dreamless":[["连击段数","6"],["解放后首击","+6"]],
	"cyan_heron":[["敌方最早就绪重击","延迟 0.6 秒"],["全队触发间隔","8 秒"]],
	"zig":[["敌方最早就绪武器","延迟 0.3 秒"],["全队触发间隔","1 秒"]],
	"wuka":[["连击","3 + 3"],["共振削弱","5 秒"]],
	"judgment":[["变奏 / 接力 → 暴击率","+12%"],["下次暴击","+6"]],
	"captain_seal":[["相邻声骸属性","≥ 3 种"],["相邻声骸伤害","+10%"],["同类加成","不叠加"]],
	"starfall":[["声骸普通触发","累计 4 次"],["本场武器 / 声骸伤害","+12%"]],
	"answer":[["目标有共振削弱","20% 伤害穿盾"]],
	"elegance":[["热熔声骸普通触发","每 4 次"],["追加热熔伤害","8"],["全队触发间隔","6 秒"]],
	"lamp":[["获得护盾 → 蓄力","+1 层"],["相邻重击下一击","每层 +2"],["蓄力上限","3 层"],["全队叠层间隔","1 秒"]],
	"medical":[["相邻恢复 / 复苏药品生效","护盾 +5"],["本场上限","2 次"]],
	"city_photo":[["触发","生命 < 30%"],["下次普通重击","+5"],["本场上限","1 次"]],
	"cheongsam":[["锁定商品价格","−1 · 最低 1"]],
	"magnifier":[["普通武器触发悬丝强化","追加伤害 2"],["触发间隔","3 秒"]],
	"glasses":[["触发","生命 < 40%"],["相邻治疗声骸","立即就绪"],["本场上限","1 次"]],
	"field_notes":[["购买扩容返还","1 贝币"],["每轮上限","1 次"],["替换扩容返还","0"]],
	"maocai":[["本场武器暴击率","+12%"]],
	"rations":[["本场武器体力消耗","−15%"]],
	"spectro_coin":[["条件","相邻衍射武器"],["施加光噪","1 层"],["每层伤害","1 / 2 秒"],["持续 / 层数上限","6 秒 / 6 层"]]
}

static func effects(kind:String) -> Array:
	if V75.has_profile(kind):return V75.effect_rows(kind)
	if C.items[kind].get("v60",{}).get("active",false) and not C.is_tag(kind,"bag"):return live_effects(kind)
	var d=C.items[kind]
	if not FEATURES.item_enabled(kind):return [["当前 Demo","效果暂停"]]
	if C.is_tag(kind,"weapon"):
		# Numbers are the base mechanic, before bag multipliers.
		var power=float(d.get("route_power",1.0)) if int(d.get("craft_tier",0))<5 else 1.65
		match str(d.get("mechanic","")):
			"heavy":return [["蓄力","每 3 次普攻"],["蓄力后下一击","+%.2f"%(3.85*power)],["解放后 5 秒内下一击","+%.2f"%(2*power)]]
			"coordinated":
				var result=[["武器普攻 → 印记","+1 · 上限 3"],["相邻声骸普攻 → 追击","4 + 单层 %.2f"%(float(d.damage)*.2)],["印记持续 / 追击间隔","6 秒 / 3 秒"]]
				if kind=="weapon_21050044":result.append(["耗印追击 → 声骸下次行动","提前 0.5 秒"])
				return result
			"wind":return [["武器普攻 → 风蚀","+1 层"],["每层伤害","%.2f / 2 秒"%(float(d.damage)*.15)],["持续 / 层数上限","6 秒 / 6 层"]]
			"noise":return [["武器普攻 → 光噪","+1 层"],["每层伤害","%.2f / 2 秒"%(float(d.damage)*.12)],["每 3 次普攻 → 引爆","最多 3 层 ×115%"],["持续 / 层数上限","6 秒 / 6 层"]]
			"photo":return [["武器每 3 次普攻","治疗 %.2f"%(3*power)],["治疗触发间隔","3 秒"],["2 次有效治疗 → 下击","+%.2f / 护盾 +3"%(float(d.damage)*.25)]]
			"burst":return [["解放后 10 秒内","3 次强化普攻"],["强化普攻","+%.2f"%(float(d.damage)*.4)]]
	if C.is_tag(kind,"bag"):
		var p=P.profile(kind)
		match p.stat:
			"shield":return [["开场护盾 / 已用格","+2"]]
			"speed":return [["接触物品冷却","−"+number(float(p.amount)*100)+"%"],["叠加","同类不叠加"]]
			"echo":return [["接触声骸出手伤害","+"+number(float(p.amount)*100)+"%"],["叠加","同类不叠加"]]
			"weapon":return [["接触武器伤害","+"+number(float(p.amount)*100)+"%"],["叠加","同类不叠加"]]
		return [["类型","基础扩容"]]
	if C.is_tag(kind,"craft_material"):return [["用途","合成材料"],["使用数量","见配方"]]
	return FACTS.get(kind,[]).duplicate(true)

static func rows(item:Dictionary) -> Array:
	if V75.has_profile(item.kind):return V75.rows(item)
	var kind=str(item.kind);var d=C.items[kind];var out:Array=[]
	if d.get("v60",{}).get("active",false):
		out.append(["占格 / 价格",str(d.shape.size())+" 格 / "+str(int(d.price))+" 贝币"])
		var cd=float(d.get("cooldown",0))
		if float(d.get("damage",0))>0:out.append(["伤害"+(" / 间隔" if cd>0 else ""),String.num(d.damage,2)+(" / "+String.num(cd,1)+" 秒" if cd>0 else "")])
		elif cd>0:out.append(["间隔",String.num(cd,1)+" 秒"])
		if float(d.get("heal",0))>0:out.append(["治疗",String.num(d.heal,1)])
		if float(d.get("stamina",0))>0:out.append(["体力消耗",String.num(d.stamina,1)])
		out.append_array(effects(kind))
		if C.is_tag(kind,"provision"):out.append(["使用次数","每场一次"])
		return out
	if C.is_tag(kind,"weapon"):out.append(["类型",TYPES.get(d.weapon_type,"")])
	else:out.append(["类型","扩容" if C.is_tag(kind,"bag") else "声骸" if C.is_tag(kind,"echo") else "补给" if C.is_tag(kind,"provision") else "材料" if C.is_tag(kind,"material") else "信物" if C.is_tag(kind,"keepsake") else "遗物"])
	out.append(["占格",str(d.shape.size())])
	if C.is_tag(kind,"echo"):out.append(["COST",str(int(d.get("echo_cost",1)))+"C"])
	var caps=[]
	for pair in [["attack","攻击"],["healing","治疗"],["shielding","护盾"]]:
		if C.is_tag(kind,pair[0]):caps.append(pair[1])
	if not caps.is_empty():out.append(["能力"," / ".join(caps)])
	for stat in [["damage","基础伤害"],["heal","基础治疗"],["cooldown","间隔 · 秒"],["stamina","体力消耗"],["energy","基础回能"]]:
		if float(d.get(stat[0],0))>0:out.append([stat[1],String.num(float(d[stat[0]]),2)])
	if C.is_tag(kind,"echo") and not d.get("v60",{}).get("active",false):
		out.append(["强化等级",str(int(item.get("level",0)))+" / 2"])
		out.append(["调谐",{"fast":"迅捷","strong":"强效","":"无"}.get(item.get("tuning",""),"无")])
	out.append_array(effects(kind))
	if C.is_tag(kind,"weapon") and d.get("strict_signature",false):
		out.append(["专武关联"," / ".join(d.signature_owner_ids.map(func(id):return C.roster.get(id,{}).get("name",id)))])
	if C.is_tag(kind,"provision"):out.append(["使用次数","每场一次"])
	
	out.append(["价格",str(int(d.price))+" 贝币"])
	return out

static func recipes(kind:String)->Array:
	var d=C.items[kind]
	return C.combinations.filter(func(r):return r.target==kind or kind in r.materials or F.accepts_base(r,kind))

static func bases(recipe:Dictionary)->Array:
	return C.items.keys().filter(func(k):return F.accepts_base(recipe,k))

## Tags define gameplay identity; material weapon_type is recipe metadata only.
static func type_chips(kind:String)->Array:
	var d=C.items[kind];var result=[]
	if C.is_tag(kind,"material") or C.is_tag(kind,"craft_material"):result.append(["material","材料"])
	elif C.is_tag(kind,"bag"):result.append(["bag","口袋"])
	elif C.is_tag(kind,"weapon"):result.append(["weapon",TYPES.get(d.get("weapon_type",""),"武器")])
	elif C.is_tag(kind,"echo"):result.append(["echo","声骸 · %dC"%int(d.get("echo_cost",1))])
	elif C.is_tag(kind,"provision"):result.append(["provision","补给"])
	else:result.append(["relic","遗物"])
	if V75.has_profile(kind):
		result.append_array(V75.chips(kind));return result
	for pair in [["attack","攻击"],["healing","治疗"],["shielding","护盾"],["charge","充能"],["haste","迅捷"],["noise","光噪"],["frost","霜渐"],["cleanse","净化"],["breaker","削盾"],["max_hp","生命上限"],["stamina","体力"],["counter","反击"]]:
		if C.is_tag(kind,pair[0]):result.append(["break_shield" if pair[0]=="breaker" else pair[0],pair[1]])
	return result

static func number(value)->String:
	return str(int(value)) if is_equal_approx(float(value),roundf(float(value))) else String.num(float(value),2)

static func action_phrase(action:Dictionary)->String:
	var type=str(action.type);var value=number(action.get("value",0))
	match type:
		"damage":return "敌方[attack]伤害 "+value
		"heal":return "我方[healing]+"+value
		"shield","charge","haste":return "我方["+type+"]+"+value
		"noise","frost":return "敌方["+type+"]+"+value
		"break_shield":return "敌方[break_shield]−"+value
		"cleanse":return "我方[cleanse]减益 −"+value
		"max_hp":return "我方生命及上限 +"+value
		"stamina":return "我方体力 +"+value
		"stamina_discount":return "本场体力消耗 −"+number(float(action.value)*100)+"%"
	return type+" "+value

static func star_rows(kind:String)->Array:
	if V75.has_profile(kind):return V75.star_rows(kind)
	var d=C.items[kind];var model=d.get("v60",{});var star=model.get("star",{});var out=[]
	var target=str(d.get("target",""));var icon="["+target+"]"
	if not star.is_empty():
		var event=str(star.get("event",""))
		var trigger={"attack":"攻击时","heal":"有效治疗时","shield":"获盾时","supply":"发动时","activate":"发动时","self":"本件发动时"}.get(event,event)
		if target=="weapon":trigger="武器"+trigger
		elif target=="echo":trigger="声骸"+trigger
		elif target=="provision":trigger="补给"+trigger
		for a in star.get("actions",[]):out.append(["[star]"+icon+trigger+" →",action_phrase(a)])
		if float(star.get("interval",0))>0:out.append(["[star]同族间隔","最多每 "+number(star.interval)+" 秒一次"])
	var matched=model.get("special",{}).get("matched_healer_shield",{})
	if not matched.is_empty():
		out.append(["本件发动 · [star][healing]每件","我方[shield]+"+number(matched.per_item)])
		out.append(["[star]计件上限",str(int(matched.max_items))+" 件 · 同件只计一次"])
	return out

static func live_effects(kind:String)->Array:
	if V75.has_profile(kind):return V75.effect_rows(kind)
	var d=C.items[kind];var model=d.get("v60",{});var out=[]
	var activation=str(model.get("activation","none"))
	if activation not in ["cooldown","none"]:out.append(["发动",{"opening":"开场","stamina3":"体力 < 3","hp50":"生命 < 50%","hp60":"生命 < 60%","time6":"第 6 秒","first_debuff":"首次受到减益"}.get(activation,activation)])
	var hits=[]
	for action in model.get("actions",[]):
		if action.type=="damage":hits.append(number(action.value))
		elif action.type!="heal":out.append(["本件发动 →",action_phrase(action)])
	if hits.size()>1:out.append(["连击伤害"," + ".join(hits)])
	out.append_array(star_rows(kind))
	for key in model.get("special",{}):
		var rule=model.special[key]
		match str(key):
			"haste_damage":out.append(["我方[haste] ≥ "+number(rule.min_stacks),"本件普攻 +"+number(rule.value)+" 伤害"])
			"low_hp_damage":out.append(["敌方生命 < "+number(float(rule.threshold)*100)+"%","本件普攻 +"+number(rule.value)+" 伤害"])
			"haste_stamina":out.append(["我方[haste] ≥ "+number(rule.min_stacks),"本件体力 −"+number((1-float(rule.multiplier))*100)+"%"])
			"haste_derived":out.append(["本件发动 · [haste] ≥ "+number(rule.min_stacks),"追加[attack]伤害 "+number(rule.value)])
			"noise_consume":out.append(["充能攻击 · 消耗敌方[noise]" if rule.get("requires_charge",true) else "本件普攻 · 消耗敌方[noise]","最多 "+number(rule.max_layers)+" 层 × "+number(rule.damage_per_layer)+" 伤"])
			"shield_strike":out.append(["本件普攻 · 消耗我方[shield]","最多 "+number(rule.consume)+" 点 × "+number(rule.multiplier)+" 伤"])
			"shield_counter":
				out.append(["我方[shield]挡下普攻 →","反击[attack]伤害 "+number(rule.damage)])
				out.append(["反击同族间隔","最多每 "+number(rule.interval)+" 秒一次"])
	return out

## Include losses as well as gains; compare live semantics, never cached prose.
static func recipe_changes(base:String,target:String)->Array:
	if V75.has_profile(target):return V75.changes(base,target).map(func(line):return ["变化",line])
	var before=C.items[base];var after=C.items[target];var result=[]
	for stat in [["damage","伤害"],["heal","治疗"],["cooldown","间隔 · 秒"],["stamina","体力消耗"]]:
		if not is_equal_approx(float(before.get(stat[0],0)),float(after.get(stat[0],0))):result.append([stat[1],number(before.get(stat[0],0))+" → "+number(after.get(stat[0],0))])
	if before.shape.size()!=after.shape.size():result.append(["占格",str(before.shape.size())+" → "+str(after.shape.size())])
	var old=effects(base);var current=effects(target)
	for row in old:
		if row not in current:result.append(["移除",str(row[0])+" "+str(row[1])])
	for row in current:
		if row not in old:result.append(["获得",str(row[0])+" "+str(row[1])])
	return result
