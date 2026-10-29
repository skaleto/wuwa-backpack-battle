extends SceneTree
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const S=preload("res://scripts/storage/storage.gd")
var checks=0;var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
 var inv=I.new();var hash=preload("res://scripts/compat/catalogue_fingerprints.gd").text(FileAccess.get_file_as_string("res://data/compat/catalog-v93.json"))
 var dir="/tmp/resonance-v101-migration-%d/"%OS.get_process_id();var store=S.new(dir)
 # Historical shelves must use the pre-V113 qualification pool.
 var old=S.HISTORICAL_I.new().new_run("aemeath",19,"focused");old.catalogue_hash=hash;old.simulation_version="resonance-v93"
 old.gold=23;old.round=3;old.wins=1;old.losses=1;old.refreshes=2;old.shop[0].locked=true
 store.write_json(dir+"run.json",old);var bytes=FileAccess.get_file_as_bytes(dir+"run.json")
 var updated=store.resume();ck(not updated.is_empty(),"V93 save migrates")
 ck(C.SIMULATION_VERSION=="resonance-v128","new simulator version is explicit")
 if not updated.is_empty():
  for key in ["items","stash","bags","shop","gold","round","seed","wins","losses","refreshes","history","serial"]:
   ck(updated.get(key)==old.get(key),"preserves "+key)
  ck(updated.simulation_version==C.SIMULATION_VERSION,"preparation opts into new rules")
  ck(FileAccess.get_file_as_bytes(dir+"run-before-v101-backup.json")==bytes,"backs up exact V93 bytes")
  ck(store.resume()==updated,"resume is idempotent")
 old.phase="result";old.combat={"winner":0,"duration":12.5,"used":[[],[]],"totals":[{},{}],"frames":[]}
 updated=store.migrate_v88(old)
 ck(not updated.is_empty() and updated.combat.winner==0 and updated.simulation_version=="resonance-v93","earned result stays historical")
 if not updated.is_empty():
  ck(updated.gold==23 and updated.wins==1 and updated.losses==1,"migration cannot re-award result")
  var history=updated.get("history",[]).duplicate(true);inv.finish(updated,0);var once=updated.duplicate(true)
  inv.finish(updated,0);ck(updated==once,"historical result settles at most once")
  ck(updated.get("history",[]).size()>=history.size(),"history is retained")
 old.phase="ending";old.wins=8;old.losses=2;old.round=10
 updated=store.migrate_v88(old)
 ck(not updated.is_empty() and updated.phase=="ending" and updated.simulation_version=="resonance-v93","terminal V93 stays terminal")
 var ghost=inv.snapshot(old,"historical");ghost.catalogue_hash=hash
 for version in ["resonance-v60","resonance-v75","resonance-v83","resonance-v86","resonance-v87","resonance-v88","resonance-v92","resonance-v93"]:
  ghost.simulation_version=version;updated=store.migrate_v88(ghost,true)
  ck(not updated.is_empty() and updated.simulation_version==version,"carried historical ghost "+version)
 ghost.simulation_version="resonance-v101"
 ck(store.migrate_v88(ghost,true).is_empty(),"old hash cannot forge current simulation")
 print("MIGRATION_V101 ",checks," checks, ",failures," failures");quit(1 if failures else 0)
