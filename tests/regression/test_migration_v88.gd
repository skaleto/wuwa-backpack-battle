extends SceneTree
const S=preload("res://scripts/storage/storage.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const C=preload("res://scripts/data/catalog.gd")
var checks=0
var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
 var inv=I.new()
 for version in ["v86","v87-intermediate","v87"]:
  var text=preload("res://tests/fixtures/layout.gd").read("res://assets/catalog-"+version+".json")
  var frozen=JSON.parse_string(text)
  ck(int(frozen.design_version)==(86 if version=="v86" else 87),"frozen provenance "+version)
  var path="/tmp/resonance-v88-%s-%d/"%[version,OS.get_process_id()];var s=S.new(path)
  # Historical shelves must use the pre-V113 qualification pool.
  var old=S.HISTORICAL_I.new().new_run("aemeath",19);old.catalogue_hash=preload("res://scripts/compat/catalogue_fingerprints.gd").text(text);old.simulation_version="resonance-v86" if version=="v86" else "resonance-v87"
  old.gold=17;old.stash=[inv.make_piece("mat_43020011","saved-drop")]
  s.write_json(path+"run.json",old);var bytes=FileAccess.get_file_as_bytes(path+"run.json")
  var resumed=s.resume();ck(not resumed.is_empty(),"resumes "+version)
  if resumed.is_empty():continue
  for field in ["items","stash","bags","shop","gold","round","seed"]:ck(resumed[field]==old[field],"preserves "+version+" "+field)
  ck(resumed.catalogue_hash==C.catalogue_hash and resumed.simulation_version==C.SIMULATION_VERSION,"future fights use current rules")
  ck(s.resume()==resumed,"idempotent")
  ck(FileAccess.get_file_as_bytes(path+"run-before-v88-backup.json")==bytes,"byte-exact backup "+version)
  var unstamped=old.duplicate(true);unstamped.erase("simulation_version")
  s.write_json(path+"run.json",unstamped)
  ck(not s.resume().is_empty(),"fresh first-round save without simulation stamp migrates "+version)
  var finished=old.duplicate(true);finished.phase="result";finished.combat={"winner":1,"duration":23.3,"used":[[],[]],"totals":[{},{}],"frames":[]}
  var settled=s.migrate_v88(finished)
  ck(not settled.is_empty() and settled.combat.winner==1 and settled.combat.duration==23.3 and settled.simulation_version==old.simulation_version,"earned old result is preserved "+version)
  var ghost=inv.snapshot(old,"previous");ghost.catalogue_hash=old.catalogue_hash;ghost.simulation_version=old.simulation_version
  s.write_json(path+"import.json",ghost)
  var imported=s.import_ghost(path+"import.json")
  ck(not imported.is_empty() and imported.simulation_version==old.simulation_version,"old ghost cannot masquerade as current")
 print("MIGRATION_V88 ",checks," checks, ",failures," failures");quit(1 if failures else 0)
