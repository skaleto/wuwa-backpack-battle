extends SceneTree
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const S=preload("res://scripts/storage/storage.gd")
var checks=0;var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
 var inv=I.new();var text=FileAccess.get_file_as_string("res://data/compat/catalog-v88.json")
 var dir="/tmp/resonance-v92-migration-%d/"%OS.get_process_id();var store=S.new(dir)
 # Historical shelves must use the pre-V113 qualification pool.
 var old=S.HISTORICAL_I.new().new_run("aemeath",19);old.catalogue_hash=preload("res://scripts/compat/catalogue_fingerprints.gd").text(text);old.simulation_version="resonance-v88"
 old.gold=17;old.stash=[inv.make_piece("nutrition_dense","saved-legacy")]
 store.write_json(dir+"run.json",old);var bytes=FileAccess.get_file_as_bytes(dir+"run.json")
 var updated=store.resume();ck(not updated.is_empty(),"V88 save migrates")
 if not updated.is_empty():
  for key in ["items","stash","bags","shop","gold","round","seed"]:ck(updated[key]==old[key],"existing property preserved "+key)
  ck(updated.simulation_version==C.SIMULATION_VERSION and updated.catalogue_hash==C.catalogue_hash,"current rules stamped")
  ck(FileAccess.get_file_as_bytes(dir+"run-before-v92-backup.json")==bytes,"exact original bytes backed up")
  ck(store.resume()==updated,"idempotent resume")
 old.phase="battle";old.combat={"winner":1,"duration":12.5,"used":[["i2"],[]],"totals":[{},{}],"frames":[]}
 updated=store.migrate_v88(old)
 ck(not updated.is_empty() and updated.phase=="result" and updated.combat.winner==1 and updated.simulation_version=="resonance-v88","earned old outcome preserved")
 if not updated.is_empty():
  var pieces=updated.items.duplicate(true);inv.finish(updated,1)
  ck(updated.items==pieces and updated.stash==old.stash,"old pending activation cannot delete permanent supply")
  ck(updated.simulation_version==C.SIMULATION_VERSION and updated.gold==28,"only subsequent rounds switch rules")
 var ghost=inv.snapshot(old,"foreign");ghost.catalogue_hash=old.catalogue_hash;ghost.simulation_version="resonance-v88"
 updated=store.migrate_v88(ghost,true)
 ck(not updated.is_empty() and updated.simulation_version=="resonance-v88","old ghost never claims current combat")
 # V88 may already contain an earned V83 result or ghost migrated by that release.
 var prior=old.duplicate(true);prior.simulation_version="resonance-v83";prior.combat.legacy_result=true
 updated=store.migrate_v88(prior)
 ck(not updated.is_empty() and updated.simulation_version=="resonance-v83" and updated.combat.winner==1,"already-migrated historical result survives another update")
 var prior_ghost=ghost.duplicate(true);prior_ghost.simulation_version="resonance-v83"
 updated=store.migrate_v88(prior_ghost,true)
 ck(not updated.is_empty() and updated.simulation_version=="resonance-v83","already-migrated ghost retains historical provenance")
 ghost.simulation_version=C.SIMULATION_VERSION
 ck(store.migrate_v88(ghost,true).is_empty(),"forged version rejected")
 print("MIGRATION_V92 ",checks," checks, ",failures," failures");quit(1 if failures else 0)
