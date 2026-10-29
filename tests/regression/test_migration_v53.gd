extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const C=preload("res://scripts/data/catalog.gd")
const S=preload("res://scripts/storage/storage.gd")
var checks=[]
func check(ok:bool,label:String):
	checks.append({"ok":ok,"label":label})
	if not ok:printerr("FAIL ",label)
func owned(run:Dictionary)->Array:
	var result=[]
	for key in I.OWNED_COLLECTIONS:
		for item in run.get(key,[]):
			var retained=item.duplicate(true)
			for field in ["x","y","rotation"]:retained.erase(field)
			result.append(retained)
	result.sort_custom(func(a,b):return a.uid<b.uid)
	return result
func _initialize():
	var inv=I.new();var store=S.new("user://qa-v53-migration/"+str(Time.get_ticks_usec()))
	var old=inv.new_run("yinlin",87);old.catalogue_hash=S.pre_v53_hash;old.simulation_version="resonance-v50"
	old.items=[];old.stash=[];old.pending_rearrange=[];old.primary="";old.shop=[{},{},{},{},{},{}];old.gold=37
	var echo=inv.make_piece("thundering","echo-old");echo.level=2;echo.tuning="strong";old.items=[echo]
	for n in 3:
		var filler=inv.make_piece("tea","fill-old-%d"%n);filler.x=1 if n==0 else 2;filler.y=1 if n==2 else 0;old.items.append(filler)
	for n in 6:old.stash.append(inv.make_piece("tea","stash-%d"%n))
	for n in 128:old.pending_rearrange.append(inv.make_piece("tea","pending-%d"%n))
	check(store.pre_v53_inventory.validate_run(old),"dense legacy shape source validates")
	var before=old.duplicate(true);var next=store.migrate_v53(old)
	check(not next.is_empty() and inv.validate_run(next),"V53 migration validates dense source with a full queue")
	check(old==before,"migration never mutates source")
	if not next.is_empty():
		check(owned(next)==owned(old),"all identities levels tuning and item kinds retained")
		check(next.gold==old.gold and next.serial==old.serial and next.seed==old.seed and next.round==old.round,"gold serial seed and round retained")
		check(next.pending_rearrange.size()>128,"safe overflow retained in pending queue")
		check(next.catalogue_hash==C.catalogue_hash and next.simulation_version==C.SIMULATION_VERSION,"catalogue and simulation metadata upgraded")
	store.write_json(store.root_path+"run.json",old)
	var bytes=FileAccess.get_file_as_bytes(store.root_path+"run.json")
	var raw=store.read_json(store.root_path+"run.json",{})
	var first=store.resume();var second=store.resume()
	check(not first.is_empty() and first==second,"resume migration is idempotent")
	check(FileAccess.get_file_as_bytes(store.root_path+"run-before-v53-backup.json")==bytes,"source backed up byte for byte")
	var ghost=inv.snapshot(old,"old-owner");ghost.catalogue_hash=S.pre_v53_hash
	ghost.stash=old.stash.duplicate(true);ghost.pending_rearrange=old.pending_rearrange.duplicate(true)
	var moved=store.migrate_v53(ghost,true)
	check(not moved.is_empty() and inv.validate_ghost(moved),"legacy ghost migrates")
	if not moved.is_empty():check(owned(moved)==owned(ghost),"ghost migration preserves ownership")
	store.write_json(store.root_path+"ghosts.json",[ghost]);check(store.pool().size()==1,"legacy pool remains readable")
	store.write_json(store.root_path+"import.json",ghost);var imported=store.import_ghost(store.root_path+"import.json")
	check(not imported.is_empty(),"legacy ghost imports and publishes")
	var bad=old.duplicate(true);bad.items.append(bad.items[0].duplicate(true))
	check(store.migrate_v53(bad).is_empty(),"duplicate ownership rejected before reflow")
	bad=old.duplicate(true);bad.catalogue_hash="unknown"
	check(store.migrate_v53(bad).is_empty(),"unknown catalogue rejected")
	old.opponent=ghost.duplicate(true)
	var with_enemy=store.migrate_v53(old)
	check(not with_enemy.is_empty() and not with_enemy.opponent.is_empty() and inv.validate_ghost(with_enemy.opponent) and with_enemy.opponent.catalogue_hash==C.catalogue_hash and with_enemy.opponent.simulation_version==C.SIMULATION_VERSION,"embedded legacy opponent upgrades to valid current shapes and simulation")
	if not with_enemy.is_empty():check(owned(with_enemy.opponent)==owned(ghost),"embedded opponent migration preserves every owned identity and field")
	old.phase="result";old.combat={"winner":1,"duration":9,"used":[[],[]]}
	var result=store.migrate_v53(old)
	check(not result.is_empty() and result.combat.winner==1 and result.phase=="result","earned result survives shape change")
	var failures=checks.filter(func(v):return not v.ok).size()
	var f=FileAccess.open("res://build/qa/ui-v53/checks/migration.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"));f.close()
	print("V53 MIGRATION ",checks.size()," checks ",failures," failures");quit(1 if failures else 0)
