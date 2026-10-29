extends RefCounted
const C=preload("res://scripts/data/catalog.gd")
const SUP=preload("res://scripts/party/supports.gd")
static func ancestors(target:String)->Array:
 var result=[target]
 for recipe in C.combinations:
  if recipe.target==target:
   for kind in [recipe.base,recipe.materials[0]]:
    for member in ancestors(kind):
     if member not in result:result.append(member)
 return result
static func make(inv,target:String,recursive:bool=false)->Dictionary:
 # Frozen-equivalence callers pass the historical qualifier to reproduce the
 # original leader, recruited types and seeded shelf; live callers stay open.
 var historical=inv.has_method("historical_types")
 var leaders=["aemeath","hsin","suisui","qingxiao","lu_hers","yangyang_xuanling"] if historical else C.selectable_leaders()
 for leader in leaders:
  var r=inv.new_run(leader,19);r.items=[];r.stash=[];r.bags=[];r.primary="";r.round=10;r.serial=100
  var required=ancestors(target) if recursive else [target]
  for kind in required:
   var d=C.items[kind]
   if historical and d.get("strict_signature",false):
    for owner in d.signature_owner_ids:
     if owner==C.characters[leader].roster_id or owner in r.roster:break
     if C.roster.has(owner) and C.roster[owner].element==C.characters[leader].element and C.roster[owner].released:r.roster.append(owner);break
   var types=inv.historical_types(r) if historical else SUP.unlocked_types(r)
   if C.is_tag(kind,"weapon") and d.weapon_type not in types:
    for role in SUP.candidates(r):
     if historical and C.roster[role].element!=C.characters[leader].element:continue
     if C.roster[role].weapon_type==d.weapon_type:r.roster.append(role);break
  r.recruited_round=10 if not r.roster.is_empty() else 0
  if not required.all(func(kind):return inv.craft_unlocked(r,kind)):continue
  for y in range(0,6,2):
   for x in range(0,8,2):
    var b=inv.make_piece("pouch","b%d-%d"%[x,y]);b.x=x;b.y=y;r.bags.append(b)
  return r
 return {}
