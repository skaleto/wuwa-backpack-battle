extends RefCounted
## Read-only build queries; no transactions, save access or battle execution.
const C=preload("res://scripts/data/catalog.gd")
const POCKETS=preload("res://scripts/inventory/pocket_rules_current.gd")
const SPACE=preload("res://scripts/inventory/item_space.gd")
const FILTERS=preload("res://scripts/battle/star_filters.gd")
var space
func _init(geometry=null):space=geometry if geometry!=null else SPACE.new(C.items)
func occupied(item:Dictionary)->Array:return space.occupied(item)
func stars(item:Dictionary)->Array:return space.stars(item)
func adjacent(a:Dictionary,b:Dictionary)->bool:return space.adjacent(a,b)

func element(item: Dictionary, build: Dictionary) -> String:
	if C.is_tag(item.get("kind",""),"weapon"):
		return C.characters.get(build.get("leader",""),{}).get("element","neutral")
	return C.items.get(item.get("kind",""),{}).get("element","neutral")

func star_eligible(source:Dictionary,item:Dictionary)->bool:
	if not C.items.has(source.get("kind","")) or not C.items.has(item.get("kind","")) or item.get("uid","")==source.get("uid","?"):return false
	return accepts_star(source.kind,C.items[source.kind],C.profile(source.kind),item.kind,C.items[item.kind],C.profile(item.kind))

# Pure semantic predicate: supply may pass its historical profiles without
# mutating the live catalogue or forking the battle/preparation star rules.
static func accepts_star(source_kind:String,source:Dictionary,source_profile:Dictionary,target_kind:String,target_def:Dictionary,n:Dictionary)->bool:
	var activity=preload("res://scripts/battle/item_activity.gd")
	if source_profile.get("star_requires_attack",false) and not activity.attacks_profile(target_def,n):return false
	var target=source.get("target","")
	var match_target=target in target_def.get("tags",[])
	if target in ["healing","shielding","noise","frost"] and target_def.has("v75"):
		match_target=(target=="healing" and (float(n.get("healAmount",0))>0 or float(n.get("emergency",0))>0)) or (target=="shielding" and (float(n.get("shieldAmount",0))>0 or float(n.get("openingShield",0))>0)) or (target=="noise" and float(n.get("noisePeriod",0))>0) or (target=="frost" and float(n.get("frostPeriod",0))>0)
	if source.has("v75"):
		match_target=false
		for filter in FILTERS.for_profile(source_kind,source_profile):
			if filter in ["weapon","echo","provision"] and filter in target_def.get("tags",[]):match_target=true
			if filter in ["heal","shield","noise"] and activity.functional_profile(target_kind,target_def,n,filter):match_target=true
			if n.is_empty() and filter in ["heal","shield","noise"] and (filter in target_def.get("tags",[]) or target_def.get("v60",{}).get("actions",[]).any(func(action):return action.get("type","")==filter and float(action.get("value",0))>0)):match_target=true
	var spec=source_profile.get("material_effect",{})
	if spec.get("trigger","")=="star_attack" and target_def.has("v75") and float(n.get("damage",0))<=0:return false
	return match_target

func star_links(source: Dictionary, items: Array, _build: Dictionary={}) -> Array:
	var result:Array=[]
	if not C.items.has(source.get("kind","")):return result
	var points=stars(source)
	var link=preload("res://scripts/party/recruitment.gd").valid_link(self,_build)
	var remote=""
	if not link.is_empty() and link.source==source.uid and items.any(func(p):return p.uid==source.uid):
		points.remove_at(int(link.star));remote=link.target
	for item in items:
		if star_eligible(source,item) and (item.uid==remote or occupied(item).any(func(v):return v in points)):result.append(item)
	return result

# Identical Echoes share a frequency: best tuned/leveled copy first, UID breaks ties.
# Damage, healing and root resource production use the same 100/50/25% budget.

func echo_weight(item: Dictionary, items: Array) -> float:
	if C.items[item.kind].get("v60",{}).get("active",false):return 1.0
	if not C.is_tag(item.kind,"echo"):return 1.0
	var copies=items.filter(func(v):return v.kind==item.kind)
	copies.sort_custom(func(a,b):
		var av=1.0+.15*int(a.get("level",0))+(.2 if a.get("tuning","")=="strong" else 0.0)
		var bv=1.0+.15*int(b.get("level",0))+(.2 if b.get("tuning","")=="strong" else 0.0)
		return str(a.uid)<str(b.uid) if is_equal_approx(av,bv) else av>bv)
	for n in range(copies.size()):
		if copies[n].uid==item.uid:return pow(.5,n)
	return 1.0

func pocket_bonus(item: Dictionary,build: Dictionary) -> Dictionary:
	return POCKETS.bonus(item,build,self)

func modifiers(item: Dictionary, items: Array, build: Dictionary={}) -> Dictionary:
	if C.items[item.kind].get("v60",{}).get("active",false):
		var pocket=pocket_bonus(item,build)
		return {"speed":float(pocket.speed),"damage":0.0,"energy":0.0,"shield":0.0,"crit":0.0,"multiplier":1.0+float(pocket.power)}
	var out={"speed":0.0,"damage":0.0,"energy":0.0,"shield":0.0,"crit":0.12,"multiplier":1.0}
	out.speed=.12 if item.get("tuning","")=="fast" else 0.0
	out.multiplier=1.0+.15*int(item.get("level",0))+(.2 if item.get("tuning","")=="strong" else 0.0)
	var sources: Array=[]
	for source in items:
		if source.kind in ["aero_coin","electro_coin"] and source.kind not in sources and star_links(source,items,build).any(func(v):return v.uid==item.uid):
			out.multiplier*=1.12;sources.append(source.kind)
	if C.is_tag(item.kind,"weapon") and items.any(func(v):return v.kind=="maocai"):out.crit+=.12
	if C.is_tag(item.kind,"echo"):
		out.multiplier*=echo_weight(item,items)
		for source in items:
			if source.kind!="captain_seal" or not adjacent(source,item):continue
			var elements: Array=[]
			for echo in items:
				if C.is_tag(echo.kind,"echo") and adjacent(source,echo):
					var elem=element(echo,build)
					if elem!="neutral" and elem not in elements:elements.append(elem)
			if elements.size()>=3:out.multiplier*=1.1;break
	var pocket=pocket_bonus(item,build)
	out.speed=minf(.5,float(out.speed)+float(pocket.speed))
	out.multiplier*=1.0+float(pocket.power)
	return out

func primary_weapon(build: Dictionary) -> Dictionary:
	var weapons=build.get("items",[]).filter(func(v):return C.is_tag(v.get("kind",""),"weapon"))
	for item in weapons:
		if item.uid==build.get("primary",""):return item
	if C.characters.has(build.get("leader","")):
		for item in weapons:
			if C.items[item.kind].weapon_type==C.characters[build.leader].weapon_type:return item
	return weapons[0] if not weapons.is_empty() else {}

func valid_relay(build: Dictionary,uids: Array) -> bool:
	if uids.is_empty():return true
	if uids.size()<2 or uids.size()>3:return false
	var path: Array=[]
	for uid in uids:
		if not uid is String or uids.count(uid)!=1:return false
		var matches=build.get("items",[]).filter(func(v):return v.uid==uid)
		if matches.size()!=1:return false
		path.append(matches[0])
	if not C.is_tag(path[0].kind,"weapon") or not C.is_tag(path[1].kind,"echo") or not adjacent(path[0],path[1]):return false
	return path.size()==2 or ((C.is_tag(path[2].kind,"relic") or C.is_tag(path[2].kind,"keepsake")) and adjacent(path[1],path[2]))

func relay_path(build: Dictionary) -> Array:
	var uids=build.get("relay",[])
	if not uids.is_empty() and valid_relay(build,uids):
		return uids.map(func(uid):return build.items.filter(func(v):return v.uid==uid)[0])
	var weapon=primary_weapon(build)
	var echoes=build.get("items",[]).filter(func(v):return C.is_tag(v.kind,"echo"))
	if weapon.is_empty():return []
	if not echoes.is_empty():return [weapon,echoes[0]]
	var outro=weapon.duplicate(true);outro.uid="leader-outro:"+str(build.get("leader",""));outro.leader_outro=true
	return [weapon,outro]
