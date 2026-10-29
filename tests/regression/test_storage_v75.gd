extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const C=preload("res://scripts/data/catalog.gd")
const F=preload("res://scripts/crafting/craft.gd")
const S=preload("res://scripts/storage/storage.gd")
var failures=0
var checks=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL "+message)
func _init()->void:
	var i=I.new();var dir="/tmp/resonance-storage-v75-"+str(Time.get_ticks_usec())+"/";var s=S.new(dir)
	var old=i.new_run("jiyan",77);old.catalogue_hash="8dd957bb1713f16466b349407f1a5641f47cd19fb3e2519b8454f7c7b3e6c8f8"
	old.shop=[{"kind":"w_broadblade","locked":true},{"kind":"turtle","locked":false},{},{},{},{"kind":"pouch","locked":false}]
	for key in I.OWNED_COLLECTIONS:
		for p in old[key]:p.erase("paid_cost")
	var extra=i.make_piece("w_broadblade","i3");extra.erase("paid_cost");old.stash=[extra];old.serial=3
	var bytes=JSON.stringify(old,"  ").to_utf8_buffer();var f=FileAccess.open(dir+"run.json",FileAccess.WRITE);f.store_buffer(bytes);f.close()
	var migrated=s.resume();check(not migrated.is_empty(),"V74 resume migrates frozen catalogue")
	if not migrated.is_empty():
		check(migrated.shop[0]==old.shop[0],"eligible locked offer survives")
		check(migrated.gold==old.gold and migrated.seed==old.seed,"migration grants no refresh or income")
		check(migrated.items[0].paid_cost==0 and migrated.bags[0].paid_cost==0,"recognized starters remain free")
		check(migrated.stash[0].paid_cost==4 and migrated.stash[0].cost_basis=="legacy_estimate","unknown old payment uses marked old-price estimate")
		check(FileAccess.get_file_as_bytes(dir+"run-before-v75-backup.json")==bytes,"exact original bytes backed up")
		check(s.resume()==migrated,"migration idempotent")
	var run=i.new_run("jiyan",9);run.items[0].paid_cost=7;run.items[0].cost_basis="actual";s.save(run)
	check(s.resume()==run,"paid cost roundtrip preserves integer deep equality")
	var without_marker=run.duplicate(true);without_marker.items[0].erase("cost_basis")
	check(i.snapshot(without_marker,"paid").items[0].cost_basis=="actual","existing paid amount is not relabeled as free by snapshot")
	var snap=i.snapshot(run,"test");check(snap.items[0].paid_cost==7 and snap.items[0].get("cost_basis","")=="actual","snapshot retains payment provenance")
	run.phase="result";run.combat={"used":[[],[]]};var before=run.items.size()+run.stash.size();i.finish(run,1)
	check(run.round==2 and run.gold==20,"finish retains approved round income")
	check(run.items.size()+run.stash.size()+run.pending_gifts.size()==before,"new V75 run receives no R2 core gift")
	# Frozen policy must accept old offers before V75 removes only newly ineligible slots.
	old.shop[2]={"kind":"flower","locked":true}
	s.write_json(dir+"run.json",old);var original_bytes=FileAccess.get_file_as_bytes(dir+"run.json");migrated=s.resume()
	check(not migrated.is_empty() and migrated.shop[2].is_empty() and migrated.shop[0].locked,"only newly ineligible old offer cleared")
	check(FileAccess.get_file_as_bytes(dir+"run-before-v75-backup.json")==bytes,"prior backup remains untouched on another original")
	var corrupt=old.duplicate(true);corrupt.shop[2]={"kind":"feilian","locked":false}
	s.write_json(dir+"run.json",corrupt);var invalid_bytes=FileAccess.get_file_as_bytes(dir+"run.json")
	check(s.resume().is_empty() and FileAccess.get_file_as_bytes(dir+"run.json")==invalid_bytes,"invalid old shop gate rejected without overwrite")
	corrupt=old.duplicate(true);corrupt.catalogue_hash="unknown";s.write_json(dir+"run.json",corrupt)
	check(s.resume().is_empty(),"unknown hash rejected")
	corrupt=old.duplicate(true);corrupt.stash[0].uid=corrupt.items[0].uid;s.write_json(dir+"run.json",corrupt)
	check(s.resume().is_empty(),"duplicate ownership rejected")
	old.pending_gifts=[i.make_piece("medical","i4")];old.pending_gifts[0].erase("paid_cost");old.serial=4
	old.history=[{"round":1,"winner":1,"note":"earned"}];old.phase="battle"
	old.combat={"winner":1,"duration":11.5,"used":[["i2"],[]],"totals":[{"damage":23},{}],"frames":[]}
	s.write_json(dir+"run.json",old);migrated=s.resume()
	check(not migrated.is_empty() and migrated.phase=="result" and migrated.combat.legacy_result and migrated.combat.winner==1,"earned old outcome preserved without replay")
	check(not migrated.is_empty() and migrated.history==JSON.parse_string(JSON.stringify(old.history)) and migrated.pending_gifts[0].uid=="i4","history and pending gift identity preserved")
	if not migrated.is_empty():
		check(migrated.combat.used[0]==["i2"],"old used supply identities preserved")
		check(i.snapshot(migrated,"result").simulation_version=="resonance-v60","earned old result snapshot keeps replay provenance")
		i.finish(migrated,1);check(migrated.simulation_version==C.SIMULATION_VERSION,"future rounds switch to current simulation")
		check((migrated.items+migrated.stash).any(func(v):return v.uid=="i2"),"claimed legacy result preserves now-permanent supply")
	var ghost=i.snapshot(i.new_run("jiyan",7),"old-owner");ghost.catalogue_hash=old.catalogue_hash;ghost.simulation_version="resonance-v60"
	ghost.items[0].paid_cost=5;ghost.items[0].cost_basis="actual"
	s.write_json(dir+"ghosts.json",[ghost]);var pool=s.pool()
	check(pool.size()==1 and pool[0].simulation_version=="resonance-v60" and pool[0].items[0].paid_cost==5,"pool migrates old ghost without blessing replay or losing payment")
	s.write_json(dir+"import.json",ghost);var imported=s.import_ghost(dir+"import.json")
	check(not imported.is_empty() and imported.simulation_version=="resonance-v60" and imported.items[0].paid_cost==5,"import and snapshot retain old simulation provenance")
	var query=i.new_run("jiyan",2);query.round=4
	check(s.opponent(query).get("owner","")!="old-owner","old replay cannot match V75 live opponent")
	ghost.simulation_version=C.SIMULATION_VERSION;s.write_json(dir+"import.json",ghost)
	check(s.import_ghost(dir+"import.json").is_empty(),"old catalogue cannot assert V75 replay provenance")
	var moved=i.new_run("jiyan",10);var original=moved.items[0].duplicate(true);var forgery=original.duplicate(true);forgery.paid_cost=1000;forgery.cost_basis="actual"
	check(i.place(moved,forgery) and moved.items[0].paid_cost==original.paid_cost and moved.items[0].cost_basis==original.cost_basis,"move payload cannot forge resale basis")
	var quote_run=i.new_run("jiyan",8);quote_run.items=[];quote_run.primary="";quote_run.gold=20;quote_run.shop[5]={"kind":"pouch","locked":false}
	var quoted=i.replacement_quote(quote_run,"b1","pouch")
	check(quoted.refund==0 and quoted.price==C.items.pouch.price,"free starter replacement quote has zero refund")
	var money=quote_run.gold;check(i.replace_bag(quote_run,"b1","pouch",0) and money-quote_run.gold==quoted.price,"replacement deduction equals shared quote")
	for leader in S.V74.frozen.selectable_leaders:
		var legacy=i.new_run(leader,82);legacy.catalogue_hash=old.catalogue_hash;legacy.shop=[{},{},{},{},{},{}]
		var frozen=S.V74.frozen.characters[leader]
		legacy.items=[];legacy.stash=[];legacy.primary="i1"
		for starter in [[frozen.starter,"i1"],[frozen.get("starter_supply","nutrition"),"i2"]]:
			var piece=i.make_piece(starter[0],starter[1]);piece.erase("paid_cost");piece.erase("cost_basis")
			var fit=i.first_fit(piece,legacy.items,legacy.bags)
			if fit.is_empty():legacy.stash.append(piece)
			else:legacy.items.append(fit)
		legacy.bags[0].erase("paid_cost");legacy.bags[0].erase("cost_basis")
		s.write_json(dir+"run.json",legacy);var resumed=s.resume()
		check(not resumed.is_empty() and (resumed.items+resumed.stash+resumed.bags).all(func(v):return v.paid_cost==0),"all leader old starters recognized free: "+leader)
	var suffixes=JSON.parse_string(FileAccess.get_file_as_string("res://data/compat/design/v75.json")).legacy
	var legacy=old.duplicate(true);legacy.phase="shop";legacy.erase("combat");legacy.stash=[];legacy.pending_gifts=[];legacy.pending_rearrange=[];legacy.serial=100
	for n in suffixes.size():
		var piece=i.make_piece(suffixes[n],"legacy-"+str(n));piece.x=2;piece.y=3;piece.rotation=n%4;piece.erase("paid_cost");piece.erase("cost_basis")
		legacy["stash" if n<6 else "pending_gifts" if n<10 else "pending_rearrange"].append(piece)
	s.write_json(dir+"run.json",legacy);migrated=s.resume()
	check(not migrated.is_empty(),"full stash plus all 14 legacy suffix items migrate")
	if not migrated.is_empty():
		for key in ["stash","pending_gifts","pending_rearrange"]:
			for n in legacy[key].size():
				var a=legacy[key][n];var b=migrated[key][n]
				check(a.uid==b.uid and a.kind==b.kind and a.x==b.x and a.y==b.y and a.rotation==b.rotation,"legacy item ownership/position preserved "+a.kind)
	var bad=legacy.duplicate(true);bad.stash[0].paid_cost=-1;s.write_json(dir+"run.json",bad)
	check(s.resume().is_empty(),"negative old paid_cost rejected")
	bad=legacy.duplicate(true);bad.stash[0].paid_cost=1.25;s.write_json(dir+"run.json",bad)
	check(s.resume().is_empty(),"fractional old paid_cost rejected")
	var blocked=S.new(dir+"backup-blocked");blocked.write_json(blocked.root_path+"run.json",legacy)
	DirAccess.make_dir_recursive_absolute(blocked.root_path+"run-before-v75-backup.json")
	var original_save=FileAccess.get_file_as_bytes(blocked.root_path+"run.json")
	check(blocked.resume().is_empty() and FileAccess.get_file_as_bytes(blocked.root_path+"run.json")==original_save,"backup failure prevents save overwrite")
	var current=i.snapshot(i.new_run("jiyan",70),"current");current.items[0].paid_cost=5;current.items[0].cost_basis="actual"
	s.write_json(dir+"ghosts.json",[current]);check(s.pool()[0].items[0].paid_cost is int,"current ghost pool normalizes paid cost integer")
	current.pending_gifts=[i.make_piece("nutrition","pending-price")];current.pending_gifts[0].paid_cost=2
	s.write_json(dir+"import-current.json",current);var imported_current=s.import_ghost(dir+"import-current.json")
	check(not imported_current.is_empty() and imported_current.pending_gifts[0].paid_cost is int,"imported pending cost normalized")
	for shelf in [
		[{"kind":"nutrition","locked":false},{"kind":"nutrition","locked":false},{},{},{},{}],
		[{"kind":"nutrition","locked":false},{"kind":"soup","locked":false},{},{},{},{}],
		[{},{},{},{},{},{"kind":"pouch","locked":true}]
	]:
		var old_shelf=i.new_run("jiyan",3);old_shelf.shop=shelf;old_shelf.catalogue_hash=S.V74.HASH
		check(not s.v74_inventory.validate_run(old_shelf),"frozen V74 rejects multiple supplies or locked bag")
		s.write_json(dir+"run.json",old_shelf);var shelf_bytes=FileAccess.get_file_as_bytes(dir+"run.json")
		check(s.resume().is_empty() and FileAccess.get_file_as_bytes(dir+"run.json")==shelf_bytes,"invalid frozen shelf cannot migrate or overwrite")
		old_shelf.catalogue_hash=C.catalogue_hash
		check(i.validate_run(old_shelf),"V75 shelf policy remains independent of frozen restrictions")
	var legal_shelf=i.new_run("jiyan",3);legal_shelf.catalogue_hash=S.V74.HASH
	legal_shelf.shop=[{"kind":"nutrition","locked":true},{},{},{},{},{"kind":"pouch","locked":false}]
	check(s.v74_inventory.validate_run(legal_shelf) and not s.migrate_v75(legal_shelf).is_empty(),"one old supply and unlocked bag remain valid")
	for mixed_on_base in [true,false]:
		var mixed_run=i.new_run("jiyan",131);mixed_run.round=10;mixed_run.items=[];mixed_run.stash=[];mixed_run.bags=[];mixed_run.primary="i1"
		for y in range(0,6,2):
			for x in range(0,8,2):
				var bag=i.make_piece("pouch","b%d_%d"%[x,y]);bag.x=x;bag.y=y;mixed_run.bags.append(bag)
		var recipe=C.combinations.filter(func(r):return r.base=="w_broadblade")[0]
		var input=i.make_piece(recipe.base,"i1");input.paid_cost=4;input.cost_basis="mixed" if mixed_on_base else "actual";mixed_run.items=[input]
		var material=i.make_piece(recipe.materials[0],"i2");material.paid_cost=2;material.cost_basis="actual" if mixed_on_base else "mixed";mixed_run.stash=[material]
		check(i.validate_run(mixed_run) and F.place_material(mixed_run,recipe.target,"i1",material.kind,i).ok,"mixed payment input is valid and placeable")
		var result=F.transact(mixed_run,recipe.target,"i1",i)
		check(result.ok and result.output.paid_cost==6 and result.output.cost_basis=="mixed","craft preserves mixed payment provenance from either input")
		if result.ok:
			check(i.snapshot(mixed_run,"mixed").items[0].cost_basis=="mixed","crafted snapshot preserves mixed estimate marker")
			s.save(mixed_run);check(s.resume().items[0].cost_basis=="mixed","crafted save roundtrip preserves mixed estimate marker")
	print("Storage V75: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
