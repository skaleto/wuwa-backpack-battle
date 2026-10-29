extends RefCounted
const C=preload("res://scripts/compat/v4/catalog.gd")
const MAX_ROSTER=12
const MAX_SUPPORTS=2

static func price(role: Dictionary) -> int:
	return 4 if int(role.get("rarity",5))==4 else 5

static func valid_team(build: Dictionary) -> bool:
	if not C.characters.has(build.get("leader","")) or not build.get("roster",[]) is Array or not build.get("supports",[]) is Array:return false
	var crew=build.get("roster",[]);var team=build.get("supports",[])
	if crew.size()>MAX_ROSTER or team.size()>MAX_SUPPORTS:return false
	var round_number=build.get("round",1)
	if not (round_number is int or round_number is float) or not is_finite(float(round_number)) or int(round_number)!=round_number or round_number<1 or round_number>10:return false
	if crew.size()>int(round_number)-1:return false
	var leader=C.characters[build.leader]
	for id in crew:
		if not id is String or not C.roster.has(id) or crew.count(id)!=1:return false
		if not C.roster[id].released or C.roster[id].element!=leader.element or id==leader.roster_id:return false
	for id in team:
		if not id is String or id not in crew or team.count(id)!=1:return false
	return true

static func candidates(run: Dictionary) -> Array[String]:
	var result: Array[String]=[]
	if not valid_team(run) or int(run.get("round",1))<2 or run.get("roster",[]).size()>=MAX_ROSTER:return result
	var leader=C.characters[run.leader]
	var pool: Array[String]=[]
	for id in C.roster:
		var role=C.roster[id]
		if role.released and role.element==leader.element and id!=leader.roster_id and id not in run.get("roster",[]):pool.append(id)
	# Local hash ranking keeps candidates stable, with no mutation of the shop RNG.
	var owned=run.get("roster",[]).duplicate();owned.sort()
	var key=str(run.get("seed",0))+":"+str(run.get("round",1))+":"+",".join(owned)
	pool.sort_custom(func(a,b):
		var ha=(key+":"+a).sha256_text();var hb=(key+":"+b).sha256_text()
		return a<b if ha==hb else ha<hb)
	for id in pool.slice(0,3):result.append(id)
	return result

static func unlocked_types(build: Dictionary) -> Array[String]:
	var result: Array[String]=[]
	if not C.characters.has(build.get("leader","")):return result
	result.append(C.characters[build.leader].weapon_type)
	for id in build.get("roster",[]):
		if C.roster.has(id) and C.roster[id].weapon_type not in result:result.append(C.roster[id].weapon_type)
	return result

# Geometry here is pure so Supports does not preload Inventory and create a cycle.
static func footprint(item: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i]=[]
	if not C.items.has(item.get("kind","")):return result
	var low=Vector2i(100,100)
	for p in C.items[item.kind].shape:
		var v=Vector2i(int(p[0]),int(p[1]))
		for n in range(posmod(int(item.get("rotation",0)),4)):v=Vector2i(-v.y,v.x)
		low.x=mini(low.x,v.x);low.y=mini(low.y,v.y);result.append(v)
	for n in range(result.size()):result[n]=result[n]-low+Vector2i(int(item.get("x",0)),int(item.get("y",0)))
	return result

static func adjacent(a: Dictionary,b: Dictionary) -> bool:
	return footprint(a).any(func(v):return footprint(b).any(func(w):return absi(v.x-w.x)+absi(v.y-w.y)==1))

static func sorted_items(build: Dictionary) -> Array:
	var items=build.get("items",[]).filter(func(v):return v is Dictionary and C.items.has(v.get("kind","")))
	items.sort_custom(func(a,b):return str(a.kind)+":"+str(a.uid)<str(b.kind)+":"+str(b.uid))
	return items

static func manual_path(build: Dictionary) -> Array:
	var ids=build.get("relay",[]);var result: Array=[]
	if not ids is Array or ids.size()<2 or ids.size()>3:return []
	for uid in ids:
		if not uid is String or ids.count(uid)!=1:return []
		var matches=sorted_items(build).filter(func(v):return v.uid==uid)
		if matches.size()!=1:return []
		result.append(matches[0])
	if not C.is_tag(result[0].kind,"weapon") or not C.is_tag(result[1].kind,"echo") or not adjacent(result[0],result[1]):return []
	if result.size()==3 and (not(C.is_tag(result[2].kind,"relic") or C.is_tag(result[2].kind,"keepsake")) or not adjacent(result[1],result[2])):return []
	return result

static func carrier(build: Dictionary,role_id: String) -> Dictionary:
	if not C.roster.has(role_id):return {}
	var weapon_type=C.roster[role_id].weapon_type
	var manual=manual_path(build)
	if not manual.is_empty() and C.items[manual[0].kind].weapon_type==weapon_type:return manual[0]
	var matching=sorted_items(build).filter(func(v):return C.is_tag(v.kind,"weapon") and C.items[v.kind].weapon_type==weapon_type)
	for item in matching:
		if item.uid==build.get("primary",""):return item
	return matching[0] if not matching.is_empty() else {}

static func path(build: Dictionary,role_id: String) -> Array:
	var weapon=carrier(build,role_id)
	if weapon.is_empty():return []
	var manual=manual_path(build)
	if not manual.is_empty() and manual[0].uid==weapon.uid:return manual
	var items=sorted_items(build)
	var echoes=items.filter(func(v):return C.is_tag(v.kind,"echo") and adjacent(weapon,v))
	if echoes.is_empty():return [weapon]
	var echo=echoes[0]
	var ends=items.filter(func(v):return (C.is_tag(v.kind,"relic") or C.is_tag(v.kind,"keepsake")) and adjacent(echo,v))
	return [weapon,echo,ends[0]] if not ends.is_empty() else [weapon,echo]

static func next(build: Dictionary,cursor: int) -> Dictionary:
	if not valid_team(build) or build.get("supports",[]).is_empty():return {}
	var team=build.supports
	for offset in range(team.size()):
		var index=posmod(cursor+offset,team.size());var id=team[index];var chain=path(build,id)
		if not chain.is_empty():return {"role_id":id,"carrier_uid":chain[0].uid,"path":chain,"next_cursor":posmod(index+1,team.size())}
	return {}
