extends RefCounted
## Within a rarity/category, alternatives share a functional family's old budget.
## No craft checks and no RNG here. V122 keeps its original ID distribution.
const C=preload("res://scripts/data/catalog.gd")
const FAMILIES={"echo_porcelain":"whiff","echo_anger":"zig","echo_sorrow":"echo_glacio","echo_gliding_sentry":"rocksteady","echo_moth":"echo_spectro","relic_diverter":"strategy","relic_lunchbox":"field_notes"}
static func family(kind:String)->String:
 if FAMILIES.has(kind):return family(FAMILIES[kind])
 var category="weapon" if C.is_tag(kind,"weapon") else "echo" if C.is_tag(kind,"echo") else "other"
 var caps=C.profile(kind).get("capabilities",[])
 for cap in ["stamina","healing","heal","shielding","shield","charge","haste","noise","frost","break_shield"]:
  if cap in caps:return category+":"+{"healing":"heal","shielding":"shield"}.get(cap,cap)
 return category+":attack"
static func shares(kinds:Array)->Dictionary:
 var groups={};var budgets={};var total=0.0;var out={}
 for kind in kinds:
  var key=family(kind)
  if not groups.has(key):groups[key]=[];budgets[key]=0.0
  groups[key].append(kind)
  if int(C.profile(kind).get("introduced_version",0))<125:budgets[key]+=1.0
 for key in groups:
  budgets[key]=maxf(1,budgets[key]);total+=budgets[key]
 for key in groups:
  for kind in groups[key]:out[kind]=budgets[key]/total/groups[key].size()
 return out
