extends SceneTree
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const S=preload("res://scripts/storage/storage.gd")
var checks=0;var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
 var inv=I.new();var hash=preload("res://scripts/compat/catalogue_fingerprints.gd").text(FileAccess.get_file_as_string("res://data/compat/catalog-v92.json"))
 var dir="/tmp/resonance-v93-migration-%d/"%OS.get_process_id();var store=S.new(dir)
 # Historical shelves must use the pre-V113 qualification pool.
 var old=S.HISTORICAL_I.new().new_run("aemeath",19,"focused");old.catalogue_hash=hash;old.simulation_version="resonance-v92"
 old.gold=17;old.round=3;old.wins=1;old.losses=1;old.refreshes=2;old.shop[0].locked=true
 store.write_json(dir+"run.json",old);var bytes=FileAccess.get_file_as_bytes(dir+"run.json")
 var updated=store.resume();ck(not updated.is_empty(),"V92 save migrates")
 if not updated.is_empty():
  for key in ["items","stash","bags","shop","gold","round","seed","wins","losses","refreshes"]:ck(updated[key]==old[key],"preserves "+key)
  ck(updated.simulation_version==C.SIMULATION_VERSION,"new preparation uses new rules")
  ck(FileAccess.get_file_as_bytes(dir+"run-before-v93-backup.json")==bytes,"exact original bytes backup")
  ck(store.resume()==updated,"idempotent resume")
 old.phase="result";old.combat={"winner":1,"duration":12.5,"used":[["i2"],[]],"totals":[{},{}],"frames":[]}
 updated=store.migrate_v88(old)
 ck(not updated.is_empty() and updated.combat.winner==1 and updated.simulation_version=="resonance-v92","earned result remains historical")
 if not updated.is_empty():
  inv.finish(updated,1)
  ck(updated.round==4 and updated.gold==30 and updated.items==old.items,"next round uses current grant once without consuming supplies")
  var same=updated.duplicate(true);inv.finish(updated,1);ck(updated==same,"no repeated award")
 old.phase="ending";old.wins=6;old.losses=0;old.round=6
 updated=store.migrate_v88(old)
 ck(not updated.is_empty() and updated.phase=="ending" and updated.wins==6 and updated.gold==17,"old terminal remains terminal")
 ck(not updated.is_empty() and updated.simulation_version=="resonance-v92" and I.PROGRESSION.cleared(updated),"old completed victory retains its historical meaning")
 var current=old.duplicate(true);current.simulation_version=C.SIMULATION_VERSION
 ck(not I.PROGRESSION.cleared(current),"six wins cannot clear a new rules run")
 for baseline in [[S.v82_hash,"resonance-v75","migrate_v83"],[S.v85_hash,"resonance-v83","migrate_v86"]]:
  var prior=old.duplicate(true);prior.catalogue_hash=baseline[0];prior.simulation_version=baseline[1]
  var terminal=store.call(baseline[2],prior)
  ck(not terminal.is_empty() and terminal.simulation_version==baseline[1] and I.PROGRESSION.cleared(terminal),"older terminal also retains completed victory "+baseline[1])
 var ghost=inv.snapshot(old,"historical");ghost.catalogue_hash=hash;ghost.simulation_version="resonance-v92"
 updated=store.migrate_v88(ghost,true)
 ck(not updated.is_empty() and updated.simulation_version=="resonance-v92","old ghost does not masquerade as V93")
 ghost.simulation_version="resonance-v83"
 ck(not store.migrate_v88(ghost,true).is_empty(),"previously carried historical ghost stays readable")
 ghost.simulation_version=C.SIMULATION_VERSION
 ck(store.migrate_v88(ghost,true).is_empty(),"forged current version rejected")
 var fresh=inv.new_run("aemeath",19,"focused");fresh.round=11;fresh.wins=7;fresh.losses=3
 store.save(fresh);ck(store.resume()==fresh,"eleventh round save survives restart")
 print("MIGRATION_V93 ",checks," checks, ",failures," failures");quit(1 if failures else 0)
