extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const C=preload("res://scripts/data/catalog.gd")
const S=preload("res://scripts/storage/storage.gd")
var inv=I.new()
var checks=0
var failures=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func isolated(prefix: String) -> String:
	return "user://qa-v6/"+prefix+"-"+str(Time.get_ticks_usec())+"/"
func json_equal(a: Variant,b: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(a))==JSON.parse_string(JSON.stringify(b))
func write_bytes(path: String,value: PackedByteArray) -> void:
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(value);file.close()
func rejects(storage: RefCounted,old: Dictionary,label: String) -> void:
	storage.write_json(storage.root_path+"run.json",old)
	var original=FileAccess.get_file_as_bytes(storage.root_path+"run.json")
	check(storage.resume().is_empty() and FileAccess.get_file_as_bytes(storage.root_path+"run.json")==original and not FileAccess.file_exists(storage.root_path+"run-v3-backup.json"),label)
func _initialize() -> void:
	var path=isolated("v3-fixture");var storage=S.new(path)
	var owner=storage.owner;var profile=FileAccess.get_file_as_bytes(path+"profile.json")
	var fixture_bytes=FileAccess.get_file_as_bytes("res://tests/fixtures/v3-run.json")
	var file=FileAccess.open(path+"run.json",FileAccess.WRITE);file.store_buffer(fixture_bytes);file.close()
	var old=JSON.parse_string(fixture_bytes.get_string_from_utf8())
	var run=storage.resume()
	check(not run.is_empty() and run.version==5 and run.ruleset==C.RULESET and run.catalogue_hash==C.catalogue_hash and inv.validate_run(run),"actual V3 fixture passes frozen V4 validation then migrates to current V5")
	if run.is_empty():finish();return
	check(run.gold==old.gold and run.round==old.round and run.wins==old.wins and run.losses==old.losses and run.seed==old.seed and run.serial==old.serial,"authoritative fixture currency, progression and serial are unchanged")
	var expected_items=old.items.duplicate(true)
	# The expanded revive footprint overlaps whiff; V53 keeps the legal pieces
	# and relocates only that displaced item into the remaining right pocket.
	for item in expected_items:
		if item.uid=="i8":item.x=5;item.y=0
	var actual_items=run.items.duplicate(true)
	expected_items.sort_custom(func(a,b):return a.uid<b.uid);actual_items.sort_custom(func(a,b):return a.uid<b.uid)
	check(json_equal(actual_items,expected_items) and json_equal(run.bags,old.bags) and json_equal(run.stash,old.stash) and run.pending_rearrange.is_empty() and run.relay==old.relay and run.primary==old.primary,"fixture preserves all identity fields and legal geometry while reflowing only expanded revive")
	check(run.roster.is_empty() and run.supports.is_empty() and run.recruited_round==0 and run.migrated_from==4 and run.free_rearrange==1,"migration adds empty crew, V4 reflow marker and one rearrangement allowance")
	check(FileAccess.get_file_as_bytes(path+"run-v3-backup.json")==fixture_bytes,"V3 backup preserves original file bytes before replacing run")
	check(storage.owner==owner and FileAccess.get_file_as_bytes(path+"profile.json")==profile,"migration preserves profile owner bytes")
	check(json_equal(storage.resume(),run),"migrated run resumes without a second migration or reset")
	var identical=S.new(isolated("identical-backup"))
	write_bytes(identical.root_path+"run.json",fixture_bytes);write_bytes(identical.root_path+"run-v3-backup.json",fixture_bytes)
	check(not identical.resume().is_empty() and FileAccess.get_file_as_bytes(identical.root_path+"run-v3-backup.json")==fixture_bytes,"already byte-identical backup is accepted and retained")
	var stale="unrelated original".to_utf8_buffer();var collision=S.new(isolated("stale-backup"))
	write_bytes(collision.root_path+"run.json",fixture_bytes);write_bytes(collision.root_path+"run-v3-backup.json",stale)
	var suffix=FileAccess.get_sha256(collision.root_path+"run.json").substr(0,12)
	var versioned=collision.root_path+"run-v3-backup-"+suffix+".json"
	check(not collision.resume().is_empty() and FileAccess.get_file_as_bytes(collision.root_path+"run-v3-backup.json")==stale and FileAccess.get_file_as_bytes(versioned)==fixture_bytes,"stale canonical backup stays intact and current original receives exact versioned backup")
	var blocked=S.new(isolated("two-backup-collisions"))
	write_bytes(blocked.root_path+"run.json",fixture_bytes);write_bytes(blocked.root_path+"run-v3-backup.json",stale);write_bytes(blocked.root_path+"run-v3-backup-"+suffix+".json",stale)
	check(blocked.resume().is_empty() and FileAccess.get_file_as_bytes(blocked.root_path+"run.json")==fixture_bytes and FileAccess.get_file_as_bytes(blocked.root_path+"run-v3-backup.json")==stale,"conflicting versioned backup rejects migration without overwriting original or backups")
	var source_shop=old.shop.duplicate(true);source_shop[4]={}
	check(run.shop==source_shop and run.shop.all(func(v):return not v.has("legacy_v3")),"eligible original offers survive while the locked-type sword offer and obsolete V3 exception are removed")
	var foreign=old.duplicate(true);foreign.catalogue_hash="foreign";rejects(S.new(isolated("foreign-hash")),foreign,"foreign hash migration rejects without backup or write")
	foreign=old.duplicate(true);foreign.ruleset="other";rejects(S.new(isolated("foreign-rules")),foreign,"foreign rules migration rejects without write")
	var forged=old.duplicate(true);forged.items[0].kind="weapon_21040016";rejects(S.new(isolated("forged-item")),forged,"forged expanded item under V3 header rejected")
	forged=old.duplicate(true);forged.shop[0]={"kind":"weapon_21040016","locked":true};rejects(S.new(isolated("forged-shop")),forged,"forged expanded shop offer rejected")
	forged=old.duplicate(true);forged.stash.append(old.items[0].duplicate(true));rejects(S.new(isolated("duplicate-uid")),forged,"duplicate UID across owned collections rejected")
	forged=old.duplicate(true);forged.gold=-1;rejects(S.new(isolated("bad-economy")),forged,"malformed old economy rejected")
	forged=old.duplicate(true);forged.serial=0;rejects(S.new(isolated("stale-v3-serial")),forged,"stale V3 serial rejects migration without writing run or backup")
	forged=old.duplicate(true);forged.history="not-an-array";rejects(S.new(isolated("corrupt-v3-history")),forged,"malformed V3 history rejects migration without overwriting source")
	var corrupted=run.duplicate(true);corrupted.history="not-an-array";var corrupt_store=S.new(isolated("corrupt-v4-history"));corrupt_store.write_json(corrupt_store.root_path+"run.json",corrupted)
	var corrupt_bytes=FileAccess.get_file_as_bytes(corrupt_store.root_path+"run.json")
	check(not inv.validate_run(corrupted) and corrupt_store.resume().is_empty() and FileAccess.get_file_as_bytes(corrupt_store.root_path+"run.json")==corrupt_bytes,"malformed V4 history fails validation and resume without changing corrupt file")
	forged=old.duplicate(true);forged.items[0].x=7;rejects(S.new(isolated("bad-geometry")),forged,"old uncovered weapon geometry rejected")
	forged=old.duplicate(true);forged.roster=["role_1402"];rejects(S.new(isolated("forged-v3-team")),forged,"V3 crew forgery rejected rather than silently erased")
	var lock_fixture=old.duplicate(true);lock_fixture.shop[0]={"kind":"w_broadblade","locked":true};lock_fixture.shop[1]={"kind":"whiff","locked":true}
	var legacy=storage.migrate_v3(lock_fixture)
	check(not legacy.is_empty() and legacy.shop[0].get("locked",false) and legacy.shop[1].get("locked",false),"eligible original weapon and echo offers retain both locks")
	legacy.gold=99;check(inv.buy(legacy,0) and legacy.stash.any(func(v):return v.kind=="w_broadblade"),"retained eligible locked offer can still be purchased")
	var cross_class=lock_fixture.duplicate(true);cross_class.shop[0]={"kind":"w_pistol","locked":true}
	var filtered=storage.migrate_v3(cross_class)
	check(not filtered.is_empty() and filtered.shop[0].is_empty() and filtered.shop[1].get("locked",false),"cross-class legacy lock is removed without losing the independent eligible echo lock")
	var old_ghost=inv.snapshot(run,"old-owner","old ghost");old_ghost.version=3;old_ghost.ruleset="wuwa-pack-v3";old_ghost.catalogue_hash=S.v3_hash;old_ghost.erase("roster");old_ghost.erase("supports")
	storage.write_json(path+"ghosts.json",[old_ghost])
	var ghosts=storage.pool()
	check(ghosts.size()==1 and ghosts[0].version==5 and ghosts[0].owner=="old-owner" and inv.validate_ghost(ghosts[0]),"old ghost pool exposes only validated migrated V5 builds")
	storage.write_json(path+"old-ghost.json",old_ghost)
	check(not storage.import_ghost(path+"old-ghost.json").is_empty(),"valid V3 ghost imports through strict migration")
	old_ghost.catalogue_hash="foreign";storage.write_json(path+"old-ghost.json",old_ghost)
	check(storage.import_ghost(path+"old-ghost.json").is_empty(),"foreign old ghost hash rejected")
	var crew=inv.new_run("jiyan",31);crew.round=3;crew.roster=["role_1402","role_1403"];crew.supports=["role_1403","role_1402"];crew.recruited_round=3
	var ghost=inv.snapshot(crew,"crew-owner","ordered crew")
	storage.write_json(path+"crew.json",ghost)
	var imported=storage.import_ghost(path+"crew.json")
	check(not imported.is_empty() and imported.roster==crew.roster and imported.supports==crew.supports,"crew snapshot round trips imported roster and support order")
	for ids in [["role_1402","role_1402"],["role_1303"],["role_1312"]]:
		var invalid=ghost.duplicate(true);invalid.roster=ids;invalid.supports=[]
		check(not inv.validate_ghost(invalid),"duplicate, wrong affinity or future crew rejected: "+str(ids))
	var bad_team=ghost.duplicate(true);bad_team.supports=["role_1402","role_1402"];check(not inv.validate_ghost(bad_team),"duplicate support team rejected at ghost boundary")
	bad_team=ghost.duplicate(true);bad_team.supports=["role_1405"];check(not inv.validate_ghost(bad_team),"unowned support rejected at ghost boundary")
	var future=ghost.duplicate(true);future.items=[inv.make_piece("weapon_21020107","announced")];future.bags=[inv.make_piece("satchel","future-b1"),inv.make_piece("travel","future-b2")];future.bags[1].x=3;future.primary="announced";future.relay=[]
	check(not C.items.weapon_21020107.released and C.items.weapon_21020107.demo_available and inv.validate_ghost(future),"announced prototype weapon is legal locally while canonical release remains false")
	var malformed_future=future.duplicate(true);malformed_future.items[0].x=7
	check(not inv.validate_ghost(malformed_future),"prototype availability does not bypass snapshot geometry")
	var result_fixture=old.duplicate(true);result_fixture.phase="result";result_fixture.combat={"winner":1,"duration":22.0,"events":[],"frames":[],"used":[[],[]]}
	var old_result=storage.migrate_v3(result_fixture)
	check(not old_result.is_empty() and old_result.phase=="result" and old_result.version==5 and old_result.combat.get("legacy_result",false) and old_result.combat.winner==1 and old_result.combat.duration==22.0 and old_result.combat.events.is_empty(),"earned old result survives as a safe summary under V5 without replaying obsolete combat")
	var v2={"version":2,"leader":"jiyan","round":2,"wins":1,"losses":0,"gold":7,"seed":4,"serial":0,"phase":"shop","shop":[],"stash":[],"history":[],"items":[{"kind":"windblade","uid":"i9","x":0,"y":0,"rotation":0}],"bags":[{"kind":"satchel","uid":"old-bag","x":0,"y":0,"rotation":0}]}
	var repaired=storage.migrate_v2(v2)
	check(not repaired.is_empty() and repaired.serial>=9 and inv.validate_run(repaired) and repaired.items.any(func(v):return v.uid=="i9"),"supported V2 migration repairs its stale serial while preserving old owned UID")
	finish()
func finish() -> void:
	print("RESULT: ",checks," legacy-to-V5 migration checks, ",failures," failures")
	quit(1 if failures else 0)
