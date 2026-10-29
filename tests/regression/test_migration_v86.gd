extends SceneTree
const S=preload("res://scripts/storage/storage.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const C=preload("res://scripts/data/catalog.gd")
var checks=0;var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
 var path="/tmp/resonance-v86-migration-%d/"%OS.get_process_id();var s=S.new(path);var inv=I.new()
 # Historical shelves must use the pre-V113 qualification pool.
 var old=S.HISTORICAL_I.new().new_run("aemeath",19);old.catalogue_hash=S.v85_hash;old.simulation_version="resonance-v83"
 old.gold=17;old.history=[{"round":1,"winner":1}]
 s.write_json(path+"run.json",old);var bytes=FileAccess.get_file_as_bytes(path+"run.json")
 var r=s.resume();ck(not r.is_empty(),"V85 save resumes")
 if not r.is_empty():
  for field in ["gold","round","seed","items","stash","bags","shop","history"]:ck(r[field]==(JSON.parse_string(JSON.stringify(old[field])) if field=="history" else old[field]),"migration preserves "+field)
  ck(r.simulation_version==C.SIMULATION_VERSION and r.catalogue_hash==C.catalogue_hash,"new rules applied only to future fights")
  ck(s.resume()==r,"migration idempotent")
  ck(FileAccess.get_file_as_bytes(path+"run-before-v86-backup.json")==bytes,"original save backed up byte for byte")
 old.phase="result";old.combat={"winner":1,"duration":23.3,"used":[[],[]],"totals":[{},{}],"frames":[]}
 var done=s.migrate_v86(old)
 ck(not done.is_empty() and done.combat.winner==1 and done.combat.duration==23.3 and done.simulation_version=="resonance-v83","already-earned fight never rerolled")
 var ghost=inv.snapshot(old,"old");ghost.catalogue_hash=S.v85_hash;ghost.simulation_version="resonance-v83"
 var migrated=s.migrate_v86(ghost,true);ck(not migrated.is_empty() and migrated.simulation_version=="resonance-v83","old opponent remains visibly old rules")
 ghost.simulation_version="resonance-v86";ck(s.migrate_v86(ghost,true).is_empty(),"old hash cannot impersonate new simulation")
 print("MIGRATION_V86 ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
