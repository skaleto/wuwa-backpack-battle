extends SceneTree
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const S=preload("res://scripts/storage/storage.gd")
const R=preload("res://scripts/party/recruitment.gd")
const SPACE=preload("res://scripts/data/space_catalog_v116.gd")
const FIX=preload("res://tests/fixtures/capacity_fixture_v111.gd")
var inv=I.new()
var checks=0
var failures=0
var store

func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func json_value(value:Variant)->Variant:return JSON.parse_string(JSON.stringify(value))
func old_run()->Dictionary:
	var run=inv.new_run_supply("aemeath",116,"full",0)
	run.catalogue_hash=C.v115_hash;run.simulation_version="resonance-v115"
	run.bags=FIX.full_bags(inv);run.items=[];run.stash=[];run.primary="";run.serial=200;run.shop=[{},{},{},{},{},{}]
	return run
func owned(kind:String,uid:String,x:int=0,y:int=0,turn:int=0)->Dictionary:
	var item=inv.make_piece(kind,uid);item.merge({"x":x,"y":y,"rotation":turn,"paid_cost":7},true);return item

func catalogue_checks()->void:
	var published_source=C.v114_hash+preload("res://tests/fixtures/layout.gd").published_text("res://scripts/data/leader_catalog_v115.gd")+preload("res://tests/fixtures/layout.gd").published_text("res://scripts/party/crew_abilities_v115.gd")+preload("res://tests/fixtures/layout.gd").published_text("res://scripts/party/recruitment_v115.gd")
	var published=published_source.sha256_text()
	ck(C.v115_hash=="627aca53f2712c80fd3c2dae4205b051923284a664d51c85d002d59b11161203" and published==C.v115_hash,"frozen V115 hash matches the exact published formula")
	var v116=preload("res://tests/fixtures/catalog_fixture_v116.gd").data()
	var v116_hash=(published_source+preload("res://tests/fixtures/layout.gd").published_text("res://scripts/data/space_catalog_v116.gd")+preload("res://tests/fixtures/layout.gd").published_text("res://scripts/inventory/pocket_rules.gd")+"resonance-v116").sha256_text()
	ck(C.v116_hash==v116_hash and C.v116_hash!=C.v115_hash,"frozen V116 geometry and pockets retain their exact published catalogue identity")
	var previous=preload("res://scripts/data/specialty_catalog_v114.gd").apply(JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json")))
	previous=preload("res://scripts/data/leader_catalog_v115.gd").apply(previous)
	ck(SPACE.CHANGES.size()==27 and v116.items.size()==previous.items.size(),"only the approved 21 weapons and six other footprints change")
	for kind in v116.items:
		var old=previous.items[kind].duplicate(true);var current=v116.items[kind].duplicate(true)
		ck(C.v115_space.items[kind].shape==json_value(old.shape) and C.v115_space.items[kind].stars==json_value(old.get("stars",[])),"frozen exact V115 geometry "+kind)
		if kind in SPACE.CHANGES:
			ck(current.shape.size()<old.shape.size() and json_value(current.shape).all(func(cell):return cell in json_value(old.shape)),"new footprint is a strict subset "+kind)
			ck(current.stars.size()==old.stars.size() and current.stars.all(func(cell):return cell not in current.shape and current.stars.count(cell)==1),"star count and unique unoccupied targets preserved "+kind)
			for key in ["shape","stars","space"]:
				old.erase(key);current.erase(key)
				if old.has("v75"):old.v75.erase(key);current.v75.erase(key)
		ck(current==old,"combat, prices, effects and all other fields preserved "+kind)

func geometry_checks()->void:
	var historical=I.new();historical.footprint_catalogue=C.v115_space.items
	for kind in SPACE.CHANGES:
		for turn in 4:
			var source=old_run();source.items=[owned(kind,"i1",2,1,turn)]
			var before=source.duplicate(true);var migrated=store.migrate_v116(source)
			ck(not migrated.is_empty() and source==before,"old legal placement migrates read-only "+kind+"/"+str(turn))
			if migrated.is_empty():continue
			ck(migrated.items==source.items and migrated.bags==source.bags and inv.validate_run(migrated),"migration preserves exact placement and ownership "+kind+"/"+str(turn))
			ck(inv.occupied(migrated.items[0]).all(func(cell):return cell in historical.occupied(source.items[0])),"rotated new cells are a subset of old cells "+kind+"/"+str(turn))
	var bad=old_run();bad.items=[owned("weapon_21010046","i1"),owned("whiff","i2",4,0)]
	var check_current=bad.duplicate(true);check_current.catalogue_hash=C.catalogue_hash
	ck(inv.validate_run(check_current),"malformed historical fixture would fit only after shrinking")
	ck(store.migrate_v116(bad).is_empty(),"old overlap cannot be legalized by the new smaller footprint")
	bad=old_run();bad.items=[owned("w_sword","i1")];bad.catalogue_hash="unknown-published-hash"
	ck(store.migrate_v116(bad).is_empty(),"unknown source hash is rejected")
	bad.catalogue_hash=C.v115_hash;bad.simulation_version="resonance-v999"
	ck(store.migrate_v116(bad).is_empty(),"unknown source simulation version is rejected")

func storage_checks()->void:
	var source=old_run();source.items=[owned("weapon_21010046","i1",1,1,2)];source.primary="i1"
	source.gold=23;source.refreshes=2;source.round=4
	for n in 12:source.stash.append(owned("nutrition","i"+str(n+2)))
	source.history=[{"round":1,"winner":1,"totals":{"damage":32.125},"build":{"catalogue_hash":C.v115_hash,"simulation_version":"resonance-v115"}}]
	store.write_json(store.root_path+"run.json",source)
	var original=FileAccess.get_file_as_bytes(store.root_path+"run.json")
	var resumed=store.resume()
	ck(not resumed.is_empty(),"old live preparation resumes with an unlimited stash")
	if resumed.is_empty():return
	for key in source:
		if key in ["catalogue_hash","simulation_version"]:continue
		ck(json_value(resumed[key])==json_value(source[key]),"resume preserves "+key)
	ck(resumed.simulation_version==C.SIMULATION_VERSION and resumed.recruitment.version==115,"future battle upgrades while recruitment version stays 115")
	ck(FileAccess.get_file_as_bytes(store.root_path+"run-before-v116-backup.json")==original,"migration saves byte-exact original backup")
	var migrated_bytes=FileAccess.get_file_as_bytes(store.root_path+"run.json")
	ck(store.resume()==resumed and FileAccess.get_file_as_bytes(store.root_path+"run.json")==migrated_bytes,"repeat resume is idempotent without rewriting")
	var combat={"winner":1,"duration":7.3,"events":[{"kind":"attack","value":5.1875}],"frames":[{"time":0,"sides":[]}],"totals":[{"damage":5.1875},{}]}
	for phase in ["battle","result","ending"]:
		var completed=source.duplicate(true);completed.phase=phase;completed.combat=combat.duplicate(true)
		completed.opponent=inv.snapshot(source,"old-enemy");completed.opponent.catalogue_hash=C.v115_hash
		var next=store.migrate_v116(completed)
		ck(not next.is_empty() and next.simulation_version=="resonance-v115" and next.combat==combat and next.history==source.history,"completed "+phase+" keeps recorded combat and provenance")
		ck(not next.is_empty() and next.opponent.simulation_version=="resonance-v115","completed opponent retains actual old rules")
	# Settling an already-recorded old fight must stamp its final result and
	# history with the actual old simulator; only a future shop/draft upgrades.
	for outcome in [[7,0,4,1,"ending"],[0,3,4,-1,"ending"],[0,0,4,1,"shop"],[0,0,3,1,"recruit"]]:
		var old_result=source.duplicate(true);old_result.phase="result";old_result.combat=combat.duplicate(true)
		old_result.wins=outcome[0];old_result.losses=outcome[1];old_result.round=outcome[2]
		old_result.combat.winner=outcome[3]
		var migrated_result=store.migrate_v116(old_result);var unchanged=migrated_result.duplicate(true)
		var advance=preload("res://scripts/run/run_lifecycle.gd").advance(migrated_result,migrated_result.combat,"qa-old-result",inv)
		ck(advance.ok and advance.run.phase==outcome[4] and migrated_result==unchanged,"old result advances atomically into "+outcome[4])
		if not advance.ok:continue
		ck(advance.run.simulation_version==("resonance-v115" if outcome[4]=="ending" else C.SIMULATION_VERSION),"only future preparation upgrades simulator after "+outcome[4])
		ck(advance.run.history[-1].build.simulation_version=="resonance-v115" and advance.run.history[-1].totals==old_result.combat.totals,"recorded history retains old combat provenance before "+outcome[4])
		if outcome[4]=="ending":ck(advance.run.combat==old_result.combat,"terminal run retains the exact old combat recording")
	for crew_version in [114,113]:
		var old=source.duplicate(true)
		if crew_version==114:old.recruitment=preload("res://scripts/party/recruitment_v114.gd").initial()
		else:old.erase("recruitment");old.recruitment_legacy=true
		old.simulation_version="resonance-v"+str(crew_version)
		var upgraded=store.migrate_v116(old)
		ck(not upgraded.is_empty() and upgraded.get("recruitment",{})==old.get("recruitment",{}) and upgraded.supports==old.supports,"crew "+str(crew_version)+" abilities and membership retained")
		ck(not upgraded.is_empty() and upgraded.simulation_version==C.SIMULATION_VERSION+"-crew"+str(crew_version),"crew "+str(crew_version)+" future combat has separate V116 compatibility")
		var practice=I.PB.build(inv,1,116,"full",crew_version==113,crew_version)
		ck(practice.simulation_version==R.simulation_version(upgraded),"crew "+str(crew_version)+" practice uses the same compatibility key")

func ghost_checks()->void:
	var source=old_run();source.items=[owned("w_sword","i1")];source.primary="i1";source.round=4
	var ghost=inv.snapshot(source,"old-player");ghost.catalogue_hash=C.v115_hash
	var path=store.root_path+"old-ghost.json";store.write_json(path,ghost)
	store.write_json(store.root_path+"ghosts.json",[ghost])
	var bytes=FileAccess.get_file_as_bytes(path);var pooled=store.pool();var imported=store.import_ghost(path,false)
	ck(pooled.size()==1 and not imported.is_empty() and pooled[0].simulation_version=="resonance-v115" and imported.simulation_version=="resonance-v115","pool and import use one V115 migration and preserve ghost version")
	ck(pooled.size()==1 and json_value(pooled[0].items)==json_value(ghost.items) and json_value(imported.items)==json_value(ghost.items) and FileAccess.get_file_as_bytes(path)==bytes,"ghost ownership and source export bytes remain unchanged")
	var live=store.migrate_v116(source)
	var app=preload("res://scripts/run/run_application.gd").new(inv,store,null)
	var before=live.duplicate(true);var pool_bytes=FileAccess.get_file_as_bytes(store.root_path+"ghosts.json")
	ck(app.import_opponent(live,path).status=="version" and live==before and FileAccess.get_file_as_bytes(store.root_path+"ghosts.json")==pool_bytes,"old manual opponent is rejected without publishing or mutating run")
	var enemy=store.opponent(live)
	ck(enemy.source=="practice" and enemy.simulation_version==C.SIMULATION_VERSION,"current matchmaking excludes old V115 player ghosts")
	var current=inv.snapshot(live,"current-player");store.write_json(store.root_path+"current-ghost.json",current)
	ck(app.import_opponent(live,store.root_path+"current-ghost.json").status=="ready","current matching ghost imports through normal path")

func _initialize()->void:
	store=S.new("/tmp/resonance-v116-migration-"+str(OS.get_process_id())+"/")
	catalogue_checks();geometry_checks();storage_checks();ghost_checks()
	print("MIGRATION_V116 ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
