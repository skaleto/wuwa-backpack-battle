extends SceneTree
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const S=preload("res://scripts/storage/storage.gd")
var inv=I.new()
var failures=0
var checks=0
func ck(ok,label):
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
	var s=S.new("user://qa-v124-migration/%s"%Time.get_ticks_usec())
	ck(s.has_method("migrate_v124"),"exact previous-version migration exists")
	if not s.has_method("migrate_v124"):quit(1);return
	var old=inv.new_run_supply("aemeath",32,"full",0);old.catalogue_hash=C.v116_hash;old.simulation_version="resonance-v116"
	var before=old.duplicate(true);var n=s.migrate_v124(old)
	ck(not n.is_empty() and old==before,"preparation migration is read-only")
	ck(n.get("simulation_version","")==C.SIMULATION_VERSION,"future combat uses current rules")
	for key in ["items","stash","bags","seed","gold","shop","recruitment"]:ck(n.get(key)==old.get(key),"keep "+key)
	s.write_json(s.root_path+"run.json",old)
	var bytes=FileAccess.get_file_as_bytes(s.root_path+"run.json")
	ck(not s.resume().is_empty(),"real resume path migrates")
	ck(FileAccess.get_file_as_bytes(s.root_path+"run-before-v124-backup.json")==bytes,"original saved byte-for-byte")
	var combat={"winner":-1,"duration":2.1,"events":[{"kind":"attack","value":7.123}],"frames":[{"time":0,"sides":[]}],"totals":[{},{}]}
	old.phase="result";old.combat=combat.duplicate(true);old.opponent=inv.snapshot(before,"old");old.opponent.catalogue_hash=C.v116_hash
	n=s.migrate_v124(old)
	ck(n.get("combat",{})==combat and n.get("simulation_version","")=="resonance-v116","completed result and rule provenance frozen")
	ck(n.get("opponent",{}).get("simulation_version","")=="resonance-v116","old opponent retains version")
	old.catalogue_hash="unknown";ck(s.migrate_v124(old).is_empty(),"reject unknown catalogue")
	old.catalogue_hash=C.v116_hash;old.simulation_version="resonance-v999";ck(s.migrate_v124(old).is_empty(),"reject unknown simulator")
	print("MIGRATION_V124 ",checks," checks, ",failures," failures");quit(1 if failures else 0)
