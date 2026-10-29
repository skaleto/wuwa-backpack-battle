extends SceneTree
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://tests/fixtures/recruitment_fixture_v113.gd")
const S=preload("res://scripts/storage/storage.gd")
var inv=I.new()
var checks=0
var failures=0
func ck(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:
 var store=S.new("/tmp/resonance-historical-v113-%d/"%OS.get_process_id())
 var baselines=[[S.pre_v43_hash,"resonance-v60","migrate_v43"],[S.pre_v53_hash,"resonance-v60","migrate_v53"],[S.pre_v70_hash,"resonance-v60","migrate_v70"],[S.v82_hash,"resonance-v75","migrate_v83"],[S.v85_hash,"resonance-v83","migrate_v86"]]
 for hash_value in S.recent_catalogues:
  baselines.append([hash_value,S.recent_catalogues[hash_value].versions[-1],"migrate_v88"])
 for baseline in baselines:
  var run=inv.new_run("aemeath",113);run.round=2;run.shop=[{},{},{},{},{},{}]
  run.catalogue_hash=baseline[0];run.simulation_version=baseline[1]
  var before=run.duplicate(true)
  ck(not store.call(baseline[2],run).is_empty() and run==before,"legal historical baseline migrates read-only "+baseline[0])
  var cross=C.roster.keys().filter(func(id):return C.roster[id].released and C.roster[id].element!=C.characters[run.leader].element)[0]
  var mixed=run.duplicate(true);mixed.roster=[cross];mixed.supports=[cross];mixed.recruited_round=2
  before=mixed.duplicate(true)
  ck(store.call(baseline[2],mixed).is_empty() and mixed==before,"historical cross-element crew rejected "+baseline[0])
  var ghost=inv.snapshot(mixed,"historical");ghost.catalogue_hash=baseline[0];ghost.simulation_version=baseline[1]
  ck(store.call(baseline[2],ghost,true).is_empty(),"historical cross-element ghost rejected "+baseline[0])
  var foreign=run.duplicate(true);foreign.shop[0]={"kind":"w_broadblade","locked":false}
  before=foreign.duplicate(true)
  ck(store.call(baseline[2],foreign).is_empty() and foreign==before,"historical off-type offer rejected "+baseline[0])
  var pending=run.duplicate(true);pending.pending_carrier_type="broadblade"
  ck(store.call(baseline[2],pending).is_empty(),"historical locked carrier metadata rejected "+baseline[0])
 # New preparation on a shared catalogue can still carry its prior fight version.
 for version in ["resonance-v112",C.SIMULATION_VERSION]:
  var run=inv.new_run("aemeath",113);run.round=2;run.simulation_version=version
  var cross=C.roster.keys().filter(func(id):return C.roster[id].released and C.roster[id].element!=C.characters[run.leader].element)[0]
  run.roster=[cross];run.supports=[cross];run.recruited_round=2;run.shop[0]={"kind":"w_broadblade","locked":false}
  ck(inv.validate_run(run),"current mixed preparation is legal even with old fight stamp "+version)
  store.save(run)
  ck(store.resume()==run,"current mixed preparation survives save/resume "+version)
  var unknown=run.duplicate(true);unknown.roster=["missing-role"];unknown.supports=[]
  ck(not inv.validate_run(unknown),"unknown role stays invalid "+version)
  var duplicate=run.duplicate(true);duplicate.round=3;duplicate.recruited_round=3;duplicate.roster=[cross,cross]
  ck(not inv.validate_run(duplicate),"duplicate role stays invalid "+version)
  var not_owned=run.duplicate(true);not_owned.supports=[C.characters[run.leader].roster_id]
  ck(not inv.validate_run(not_owned),"unowned support stays invalid "+version)
  var unreleased=C.roster.keys().filter(func(id):return not C.roster[id].released)
  for id in unreleased:
   var unavailable=run.duplicate(true);unavailable.roster=[id];unavailable.supports=[]
   ck(not inv.validate_run(unavailable),"unavailable role stays invalid "+id)
 print("HISTORICAL_QUALIFICATION_V113 ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
