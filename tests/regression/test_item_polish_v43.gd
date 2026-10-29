extends SceneTree
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const S=preload("res://scripts/storage/storage.gd")
var inv=I.new()
var checks=0
var failures=0
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize() -> void:
	for kind in C.items:
		var def=C.items[kind]
		if not C.is_tag(kind,"weapon"):continue
		var expected=def.shape.size()
		if def.weapon_type in ["sword","broadblade"]:expected=[2,3,4,5,5][int(def.craft_tier)-1]
		if def.weapon_type in ["pistol","gauntlet","rectifier"]:
			var maximum=Vector2i.ZERO
			for cell in def.shape:maximum=maximum.max(Vector2i(cell[0],cell[1]))
			check(def.shape.size()==(maximum.x+1)*(maximum.y+1),"V53 body footprint is a complete rectangle "+kind)
		check(def.shape.size()==expected,"quality footprint "+kind)
		for turn in 4:
			var piece=inv.make_piece(kind,"p");piece.rotation=turn
			var cells=inv.cells(piece)
			check(cells.size()==expected,"rotation preserves capacity "+kind)
	for leader in C.characters:check(inv.validate_run(inv.new_run(leader,19)),"starter legal "+leader)
	var store=S.new("user://qa-polish-migration-v43/"+str(Time.get_ticks_usec()))
	var old=inv.new_run("jiyan",19);old.catalogue_hash=S.pre_v43_hash
	old.items=[];old.stash=[];old.primary="old-gun";old.gold=27
	# Fill six old cells; the old one-cell teaching pistol now needs two cells.
	for n in 6:
		var piece=inv.make_piece("weapon_21030011" if n==0 else "tea","old-gun" if n==0 else "tea-"+str(n))
		piece.x=n%3;piece.y=n/3;old.items.append(piece)
	check(store.pre_v43_inventory.validate_run(old),"valid dense pre-change save")
	check(not inv.validate_run(old),"old hash cannot bypass live validation")
	var snapshot=old.duplicate(true)
	var next=store.migrate_v43(old)
	check(old==snapshot,"migration preview never mutates original")
	check(not next.is_empty() and inv.validate_run(next),"dense save reflows legally")
	if not next.is_empty():
		var all_owned=next.items+next.stash+next.pending_rearrange
		check(all_owned.size()==6 and all_owned.any(func(v):return v.uid=="old-gun"),"expanded weapon and every owned item retained")
		check(next.gold==27 and next.round==old.round and next.wins==old.wins,"progress and money preserved")
	store.write_json(store.root_path+"run.json",old)
	var original_bytes=FileAccess.get_file_as_bytes(store.root_path+"run.json")
	var restored=store.resume()
	check(not restored.is_empty() and inv.validate_run(restored),"normal resume migrates exact prior hash")
	check(FileAccess.get_file_as_bytes(store.root_path+"run-before-v43-backup.json")==original_bytes,"original save backed up byte-for-byte before commit")
	var bad=old.duplicate(true);bad.items[1].x=0;bad.items[1].y=0
	check(store.migrate_v43(bad).is_empty(),"invalid old overlap rejected before reflow")
	bad=old.duplicate(true);bad.catalogue_hash="unknown"
	check(store.migrate_v43(bad).is_empty(),"unknown history rejected")
	var ghost=inv.snapshot(old,"old-owner");ghost.catalogue_hash=S.pre_v43_hash
	var moved_ghost=store.migrate_v43(ghost,true)
	check(not moved_ghost.is_empty() and inv.validate_ghost(moved_ghost),"previous ghost preserves displaced ownership")
	store.write_json(store.root_path+"ghosts.json",[ghost])
	check(store.pool().size()==1,"old asynchronous opponent remains available")
	old.phase="result";old.combat={"winner":1,"duration":12,"used":[[],[]]}
	var earned=store.migrate_v43(old)
	check(not earned.is_empty() and earned.phase=="result" and earned.combat.winner==1,"earned result survives migration")
	print("V43: ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
