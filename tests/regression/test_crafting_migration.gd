extends SceneTree
const I = preload("res://scripts/inventory/inventory.gd")
const OLD = preload("res://scripts/compat/v4/inventory.gd")
const S = preload("res://scripts/storage/storage.gd")
var failures=0
func check(ok: bool,label: String) -> void:
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize() -> void:
	var s=S.new("user://v15-migration-test-"+str(Time.get_ticks_msec()))
	check(s.has_method("migrate_v4_crafting"),"explicit non-additive migration")
	if not s.has_method("migrate_v4_crafting"):quit(1);return
	var old=OLD.new().new_run("jiyan",9)
	var before=old.duplicate(true)
	s.write_json(s.root_path+"run.json",old)
	var result=s.resume()
	check(not result.is_empty() and result.version==5,"known V4 migrated to V5")
	check(old==before,"migration preview does not mutate original")
	check(FileAccess.file_exists(s.root_path+"run-v4-before-crafting-backup.json"),"original bytes backed up")
	check(result.gold==old.gold and result.round==old.round,"progress and money preserved")
	var all_owned=result.get("items",[])+result.get("stash",[])+result.get("pending_rearrange",[])
	check(old.items.all(func(p):return all_owned.any(func(v):return v.uid==p.uid and v.kind==p.kind)),"owned UIDs preserved")
	var bad=old.duplicate(true);bad.items.append(bad.items[0].duplicate(true))
	check(s.migrate_v4_crafting(bad).is_empty(),"corrupt legacy overlap rejected before reflow")
	bad=old.duplicate(true);bad.catalogue_hash="unknown"
	check(s.migrate_v4_crafting(bad).is_empty(),"unknown catalogue rejected")
	edges(s)
	print("MIGRATION failures ",failures);quit(1 if failures else 0)

func crowded() -> Dictionary:
	var inv=OLD.new();var r=inv.new_run("jiyan",7);r.items=[];r.bags=[];r.stash=[];r.round=4;r.shop=[{},{},{},{},{},{}]
	for n in range(5):r.bags.append(inv.first_fit(inv.make_piece("satchel","b"+str(n)),[],r.bags))
	for n in range(15):r.items.append(inv.first_fit(inv.make_piece("w_sword","weapon"+str(n)),r.items,r.bags))
	r.primary=r.items[0].uid
	for n in range(6):r.stash.append(inv.make_piece("tea","stash"+str(n)))
	for n in range(64):r.pending_rearrange.append(inv.make_piece("whiff","pending"+str(n)))
	return r
func edges(s) -> void:
	var r=crowded();check(OLD.new().validate_run(r),"maximum legacy queue fixture legal")
	var migrated=s.migrate_v4_crafting(r)
	check(not migrated.is_empty() and migrated.pending_rearrange.size()==69,"crowded valid old queue reflows without rejection/loss")
	check(migrated.items.size()+migrated.stash.size()+migrated.pending_rearrange.size()==85,"all old equipment retained across queues")
	var ghost=OLD.new().snapshot(r,"old-crowded")
	var newghost=s.migrate_v4_crafting(ghost,true)
	check(not newghost.is_empty() and newghost.items.size()+newghost.stash.size()==15,"ghost displaced equipment retained")
	var bad=newghost.duplicate(true);bad.stash.append(bad.items[0].duplicate(true))
	check(not I.new().validate_ghost(bad),"pool and publish reject duplicate ownership in migration metadata")
	var tiny=OLD.new().new_run("jiyan",2);tiny.round=4;tiny.items=[OLD.new().make_piece("discord","discord-old")];tiny.primary="discord-old";tiny.shop=[{},{},{},{},{},{}]
	check(OLD.new().validate_run(tiny),"all-displaced old item fixture is valid")
	ghost=OLD.new().snapshot(tiny,"old-tiny")
	newghost=s.migrate_v4_crafting(ghost,true)
	check(not newghost.is_empty() and newghost.inactive and newghost.stash.size()==1,"all-displaced ghost archived with ownership")
	s.write_json(s.root_path+"ghosts.json",[ghost])
	check(s.publish(I.new().snapshot(I.new().new_run("jiyan",8),"other")),"publishing after migration succeeds")
	check(s.pool().any(func(v):return v.owner=="old-tiny" and v.inactive and v.stash[0].uid=="discord-old"),"publishing does not silently erase all-displaced legacy ghost")
	# Fill the old board with weapons followed by two teas in the last weapon's
	# exact old cells. Weapon growth fills the new board before the teas are
	# visited, while the already-full stash forces real pending rearrangement.
	var ending=crowded();var old_inv=OLD.new();var removed=ending.items.pop_back()
	var freed=old_inv.occupied(removed)
	for n in range(freed.size()):
		var tea=old_inv.make_piece("tea","used-tea"+str(n));tea.x=freed[n].x;tea.y=freed[n].y;ending.items.append(tea)
	var used_uid=ending.items[-1].uid
	ending.phase="result";ending.combat={"winner":1,"duration":25.0,"totals":[{"damage":200},{}],"used":[[used_uid],[]]}
	check(old_inv.validate_run(ending),"result fixture equips a used consumable on a completely occupied valid legacy board")
	var result=s.migrate_v4_crafting(ending)
	check(not result.is_empty() and result.phase=="result" and result.combat.winner==1,"earned pending victory survives migration")
	check(not result.is_empty() and result.pending_rearrange.any(func(v):return v.uid==used_uid) and not result.items.any(func(v):return v.uid==used_uid),"used equipped consumable actually reflows into pending rearrangement")
	var gold=int(result.gold);I.new().finish(result,1)
	check(result.wins==1 and result.round==ending.round+1 and result.gold==gold+9,"preserved victory settles exactly once")
	check(not(result.items+result.stash+result.pending_rearrange+result.pending_gifts).any(func(v):return v.uid==used_uid),"already used item removed even after reflow")
