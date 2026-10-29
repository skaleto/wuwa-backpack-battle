extends RefCounted
## Frozen evidence + a presentation clock. Never simulates, settles, or saves.
const C=preload("res://scripts/data/catalog.gd")
const FEEDBACK=preload("res://scripts/ui/battle/battle_feedback.gd")
const LABELS={
	"attack":"攻击","derived":"追加伤害","counter":"反击","noise_tick":"光噪伤害","frost_hit":"霜渐伤害",
	"guard":"招架减伤","heal":"治疗","intro_heal":"治疗","shield":"获得护盾","break_shield":"削盾","fatigue":"疲劳",
	"trigger":"发动","star_trigger":"星位联动","cooldown_advance":"冷却推进","delay":"冷却延迟",
	"charge":"充能","haste":"迅捷","noise":"光噪","frost":"霜渐","freeze":"冻结","cleanse":"净化",
	"max_hp":"生命上限","stamina":"体力","combo_ready":"强化就绪","supply":"补给发动",
	"content_buff":"强化","burst":"共鸣","intro":"变奏","outro":"延奏","extra":"追加伤害",
	"coordinated":"协同","noise_consume":"光噪引爆","heavy_hit":"重击","buff":"强化","expire":"消退","crew_trigger":"队友支援",
	"relay_attack":"接力攻击","intro_attack":"变奏攻击","copy":"复刻","weaken":"削弱"
}
var active=false
var playing=false
var time=0.0
var duration=0.0
var speed=1.0
var cursor=0
var record:Dictionary={}
var builds:Array=[]
func open(evidence:Dictionary,participants:Array)->bool:
	close()
	if not available(evidence):return false
	record=evidence.duplicate(true);builds=participants.duplicate(true)
	duration=float(record.duration);speed=1.0;active=true;seek(duration)
	return true
static func available(evidence:Dictionary)->bool:
	return not evidence.get("legacy_result",false) and not evidence.get("frames",[]).is_empty() and evidence.has("events")
func close()->void:
	active=false;playing=false;record={};builds=[];cursor=0;time=0
func seek(at:float)->void:
	playing=false;time=clampf(at,0,duration);cursor=0
	while cursor<record.get("events",[]).size() and float(record.events[cursor].time)<=time+.00001:cursor+=1
func play()->void:
	if not active:return
	if time>=duration:seek(0);cursor=0
	playing=true
func advance(delta:float)->Array:
	var due=[]
	if not active or not playing:return due
	time=minf(duration,time+maxf(0,delta)*speed)
	while cursor<record.events.size() and float(record.events[cursor].time)<=time+.00001:
		due.append(record.events[cursor].duplicate(true));cursor+=1
	if time>=duration:playing=false
	return due
func step(direction:int)->void:
	if not active:return
	var next=duration if direction>0 else 0.0
	for event in record.events:
		var at=float(event.time)
		if direction>0 and at>time+.00001:next=at;break
		if direction<0 and at<time-.00001:next=at
	seek(next)
static func frame_at(evidence:Dictionary,at:float)->Dictionary:
	var frames=evidence.get("frames",[])
	if frames.is_empty():return {}
	var lo=0;var hi=frames.size()-1
	while lo<hi:
		var middle=(lo+hi+1)/2
		if float(frames[middle].time)<=at+.00001:lo=middle
		else:hi=middle-1
	return frames[lo].duplicate(true)
static func identities(participants:Array,side:int)->Dictionary:
	var out={}
	if side<0 or side>=participants.size():return out
	var build:Dictionary=participants[side]
	var pieces:Array=build.get("items",[])+build.get("bags",[]);var counts={};var copies={}
	for item in pieces:counts[item.kind]=int(counts.get(item.kind,0))+1
	for item in pieces:
		copies[item.kind]=int(copies.get(item.kind,0))+1
		var title=str(C.items.get(item.kind,{}).get("name",item.kind))
		if counts[item.kind]>1:title+=" · "+str(copies[item.kind])
		out[str(item.uid)]={"uid":str(item.uid),"kind":str(item.kind),"name":title,"position_label":"%d列 %d行"%[int(item.get("x",0))+1,int(item.get("y",0))+1]}
	var leader=str(build.get("leader",""))
	out["leader:"+leader]={"uid":"leader:"+leader,"kind":"","name":str(C.characters.get(leader,{}).get("name","角色"))}
	for role in build.get("supports",[]):
		var spec=preload("res://scripts/party/crew_abilities.gd").profile(role)
		out["crew:"+role]={"uid":"crew:"+role,"kind":"","role_id":role,"ability_icon":spec.get("icon","charge"),"name":str(C.roster.get(role,{}).get("name","队友")),"position_label":spec.get("name","支援")}
		if preload("res://scripts/party/recruitment.gd").enabled(build):
			var current=preload("res://scripts/party/recruitment.gd").profile(role,build)
			out["crew:"+role].crew_ability=current.get("icon_id",current.get("ability_id",""))
			out["crew:"+role].position_label=current.get("ability_name","队友")
	return out
static func source_uid(event:Dictionary)->String:
	return str(event.get("source_uid",event.get("uid",""))) if event.get("kind","") in ["cooldown_advance","star_trigger","delay"] else str(event.get("uid",""))
static func identity(index:Dictionary,uid:String,event:Dictionary={})->Dictionary:
	if index.has(uid):return index[uid]
	return {"uid":uid,"kind":"","name":"疲劳" if uid=="fatigue" else str(event.get("label","队伍效果")) if not str(event.get("label","")).is_empty() else "队伍效果"}
static func empty_row(who:Dictionary)->Dictionary:
	var row=who.duplicate()
	for key in ["damage","hp_damage","shield_damage","heal","shield","advance","break_shield","charge","haste","noise","frost","fatigue","stamina","guard"]:row[key]=0.0
	for key in ["activations","charged","prepared","enhanced","stars"]:row[key]=0
	return row
static func damage(event:Dictionary)->float:
	# Precision fields are authoritative; value is a rounded presentation label.
	if event.has("hp_damage"):return float(event.hp_damage)+float(event.get("absorbed",0))
	return float(event.get("value",0)) if str(event.get("kind","")) in ["attack","derived","counter","noise_tick","frost_hit","extra","copy","relay_attack","intro_attack","heavy_hit","noise_consume","coordinated"] else 0.0
static func rows(evidence:Dictionary,participants:Array,side:int,until:float)->Array:
	var index=identities(participants,side);var by_uid={}
	for item in participants[side].get("items",[])+participants[side].get("bags",[]):by_uid[str(item.uid)]=empty_row(index[str(item.uid)])
	for role in participants[side].get("supports",[]):by_uid["crew:"+role]=empty_row(index["crew:"+role])
	for event in evidence.get("events",[]):
		if int(event.get("side",-1))!=side or float(event.get("time",0))>until+.00001:continue
		var uid=source_uid(event)
		if not by_uid.has(uid):by_uid[uid]=empty_row(identity(index,uid,event))
		var row:Dictionary=by_uid[uid];var kind=str(event.get("kind",""))
		if kind=="fatigue":row.fatigue+=float(event.get("actual_value",event.get("value",0)));continue
		var dealt=damage(event);row.damage+=dealt
		row.hp_damage+=float(event.get("hp_damage",dealt));row.shield_damage+=float(event.get("absorbed",0))
		if kind in ["heal","intro_heal"]:row.heal+=float(event.get("actual_value",event.get("value",0)))
		elif kind=="shield":row.shield+=float(event.get("actual_value",event.get("value",0)))
		elif kind=="cooldown_advance":row.advance+=float(event.get("actual_value",event.get("value",0)))
		elif kind in ["break_shield","charge","haste","noise","frost","stamina","guard"]:row[kind]+=maxf(0,float(event.get("actual_value",event.get("value",0))))
		elif kind=="crew_trigger":row.activations+=1
		elif kind=="trigger":
			row.activations+=1
			if event.get("charged",false):row.charged+=1
			if event.get("prepared",false):row.prepared+=1
			if event.get("charged",false) or event.get("prepared",false):row.enhanced+=1
	for row in by_uid.values():row.stars=FEEDBACK.stars(evidence.get("events",[]),side,row.uid,until)
	return by_uid.values()
static func timeline(evidence:Dictionary,participants:Array,side:int=-1,uid:String="")->Array:
	var indices=[identities(participants,0),identities(participants,1)]
	var out=[];var ordinal=0
	for event in evidence.get("events",[]):
		var id=ordinal;ordinal+=1
		var team=int(event.get("side",-1))
		if team<0 or team>1 or event.get("cue_only",false):continue
		var source=source_uid(event);var partner=str(event.get("trigger_uid",event.get("target_uid","")))
		var partner_side=int(event.get("trigger_side",team)) if event.has("trigger_uid") else int(event.get("target_side",team))
		if uid.is_empty():
			if side>=0 and side!=team:continue
		else:
			var from_source=source==uid and (side<0 or side==team)
			var from_partner=partner==uid and (side<0 or side==partner_side)
			var from_beneficiary=str(event.get("beneficiary_uid",""))==uid and (side<0 or side==int(event.get("beneficiary_side",team)))
			if not (from_source or from_partner or from_beneficiary):continue
		var who=identity(indices[team],source,event)
		var target=identity(indices[clampi(partner_side,0,1)],partner)
		var kind=str(event.get("kind",""));var text=str(LABELS.get(kind,event.get("label",kind)))
		var value=float(event.get("actual_value",event.get("value",0)))
		if kind=="crew_trigger":text+=" · "+str(event.get("label",""))
		if damage(event)>0:
			text=("强化攻击" if event.get("charged",false) or event.get("prepared",false) else text)+"  %.1f"%damage(event)
			if float(event.get("absorbed",0))>0:text+="  · 挡 %.1f"%float(event.absorbed)
		elif kind in ["cooldown_advance","delay"]:
			text+="  %.2f 秒"%value
			if not partner.is_empty():text+="  → "+("对方·" if partner_side!=team else "")+target.name
		elif kind=="star_trigger" and not partner.is_empty():
			var recipient=str(event.get("beneficiary_uid",""))
			text+="  → "+identity(indices[team],recipient).name if partner==source and not recipient.is_empty() else "  ← "+target.name
		elif kind not in ["trigger","supply","combo_ready","star_trigger","crew_trigger"] and not is_zero_approx(value):text+="  %+.1f"%value
		if kind in ["noise","frost","freeze"] and int(event.get("target_side",team))!=team:text+="  → 对方"
		out.append({"id":id,"time":float(event.get("time",0)),"side":team,"source_uid":source,"partner_uid":partner,
			"partner_side":partner_side,"kind":who.kind,"name":who.name,"event_kind":kind,"text":text})
	# Stable original order is the tie-breaker for simultaneous facts.
	out.sort_custom(func(a,b):return a.time<b.time if not is_equal_approx(a.time,b.time) else a.id<b.id)
	return out
