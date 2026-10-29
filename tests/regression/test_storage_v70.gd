extends SceneTree
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const S=preload("res://scripts/storage/storage.gd")
const B=preload("res://scripts/battle/battle.gd")
var checks=0;var failures=[]
func ck(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize():call_deferred("test")
func test():
	var old_hash=FileAccess.get_file_as_string("res://tests/fixtures/data/ui-v70/before/catalog.sha256").strip_edges().split(" ")[0]
	var inv=I.new()
	# Historical shelves must use the pre-V113 qualification pool.
	var run=S.HISTORICAL_I.new().new_run("aemeath",15)
	var enemy=inv.practice(1,4)
	run.phase="result";run.combat=B.new().simulate(run,enemy,22,false)
	run.opponent=enemy.duplicate(true);run.opponent.catalogue_hash=old_hash
	run.catalogue_hash=old_hash
	var real_hash=C.catalogue_hash
	# Also exercise migration before the expanded catalogue lands.
	if C.catalogue_hash==old_hash:C.catalogue_hash="qa-v70-future-catalogue"
	var s=S.new("/tmp/resonance-v70-storage-%d"%OS.get_process_id())
	s.write_json(s.root_path+"run.json",run)
	var original=FileAccess.get_file_as_bytes(s.root_path+"run.json")
	var resumed=s.resume()
	ck(not resumed.is_empty(),"known preceding catalogue resumes")
	ck(FileAccess.get_file_as_bytes(s.root_path+"run-before-v70-backup.json")==original,"exact pre-migration bytes backed up")
	if not resumed.is_empty():
		var expected=JSON.parse_string(original.get_string_from_utf8());expected.catalogue_hash=C.catalogue_hash;expected.opponent.catalogue_hash=C.catalogue_hash
		ck(JSON.parse_string(JSON.stringify(resumed))==expected,"inventory cash phase replay and all fields preserved except catalogue hashes")
		ck(inv.validate_run(resumed),"migrated save validates")
		ck(s.resume()==resumed,"second resume is idempotent")
		ck(FileAccess.get_file_as_bytes(s.root_path+"run-before-v70-backup.json")==original,"second resume preserves original backup")
	s.write_json(s.root_path+"ghosts.json",[run.opponent])
	var ghosts=s.pool()
	ck(ghosts.size()==1,"preceding ghost remains available")
	if ghosts.size()==1:ck(ghosts[0].catalogue_hash==C.catalogue_hash,"ghost migrated in memory")
	s.write_json(s.root_path+"import.json",run.opponent)
	ck(not s.import_ghost(s.root_path+"import.json").is_empty(),"preceding external ghost imports")
	var corrupt=run.duplicate(true);corrupt.gold=-1
	s.write_json(s.root_path+"run.json",corrupt)
	ck(s.resume().is_empty(),"invalid money cannot be blessed by migration")
	ck(FileAccess.get_file_as_bytes(s.root_path+"run-before-v70-backup.json")==original,"rejected save cannot replace backup")
	corrupt=run.duplicate(true);corrupt.catalogue_hash="unknown-catalogue"
	s.write_json(s.root_path+"run.json",corrupt)
	ck(s.resume().is_empty(),"unknown catalogue stays rejected")
	C.catalogue_hash=real_hash
	print("STORAGE_V70 ",checks," checks, ",failures.size()," failures")
	quit(1 if not failures.is_empty() else 0)
