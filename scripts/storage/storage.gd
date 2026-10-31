extends RefCounted
const I = preload("res://scripts/inventory/inventory.gd")
const HISTORICAL_I=preload("res://scripts/compat/migration_pre_v113_inventory.gd")
const C = preload("res://scripts/data/catalog.gd")
static var v85_text=FileAccess.get_file_as_string("res://data/compat/catalog-v85.json")
static var v85_hash:String=preload("res://scripts/compat/catalogue_fingerprints.gd").text(v85_text)
var v85_inventory=HISTORICAL_I.new()
static var v82_text=FileAccess.get_file_as_string("res://data/compat/catalog-v82.json")
static var v82_hash:String=preload("res://scripts/compat/catalogue_fingerprints.gd").text(v82_text)
var v82_inventory=HISTORICAL_I.new()
static var v86_text=FileAccess.get_file_as_string("res://data/compat/catalog-v86.json")
static var v86_hash:String=preload("res://scripts/compat/catalogue_fingerprints.gd").text(v86_text)
var v86_inventory=HISTORICAL_I.new()
# Exact published baselines, including the accidentally frozen intermediate V87.
# V88 also carries older earned results/ghosts already migrated to its catalog hash.
static var recent_catalogues:Dictionary=recent_baselines()
static func recent_baselines()->Dictionary:
	var out={}
	for name in ["v86","v87-intermediate","v87","v88","v92","v93"]:
		var text=FileAccess.get_file_as_string("res://data/compat/catalog-"+name+".json")
		out[preload("res://scripts/compat/catalogue_fingerprints.gd").text(text)]={"items":JSON.parse_string(text).items,"backup":"v92" if name=="v88" else "v88","versions":["resonance-v60","resonance-v75","resonance-v83","resonance-v86","resonance-v87","resonance-v88"] if name=="v88" else ["resonance-v86"] if name=="v86" else ["resonance-v86","resonance-v87"] if name=="v87-intermediate" else ["resonance-v87"]}
		if name=="v92":
			out[preload("res://scripts/compat/catalogue_fingerprints.gd").text(text)].backup="v93"
			out[preload("res://scripts/compat/catalogue_fingerprints.gd").text(text)].versions=["resonance-v60","resonance-v75","resonance-v83","resonance-v86","resonance-v87","resonance-v88","resonance-v92"]
		if name=="v93":
			out[preload("res://scripts/compat/catalogue_fingerprints.gd").text(text)].backup="v101"
			out[preload("res://scripts/compat/catalogue_fingerprints.gd").text(text)].versions=["resonance-v60","resonance-v75","resonance-v83","resonance-v86","resonance-v87","resonance-v88","resonance-v92","resonance-v93"]
	return out
const V74=preload("res://scripts/compat/migration_v74_inventory.gd")
var v74_inventory=V74.new()
const OLD_I = preload("res://scripts/compat/v4/inventory.gd")
const OLD_C = preload("res://scripts/compat/v4/catalog.gd")
var old_inventory=OLD_I.new()
static var v3_hash: String=preload("res://scripts/compat/catalogue_fingerprints.gd").text(FileAccess.get_file_as_string("res://data/compat/catalog-v3.json"))
static var expansion_base_hash: String=preload("res://scripts/compat/catalogue_fingerprints.gd").text(FileAccess.get_file_as_string("res://data/compat/catalog-v4-base.json"))
static var expansion_base_items: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/compat/catalog-v4-base.json")).items
const LEGACY_MAP = {"pouch":"travel","windblade":"w_broadblade","pistol":"w_pistol","string":"w_rectifier","leaf":"rectifier25","bell":"bellborne","feather":"aero_coin","battery":"electro_coin","prism":"contract","flame":"inferno","turtle":"turtle","heron":"heron","crown":"thundering","flower":"flower","dagger":"w_sword","tea":"tea","metronome":"tuner","banner":"strategy","lens":"contract","gale":"verdant","stormstring":"stringmaster","spring":"rectifier25","blazepistol":"w_pistol"}
# A same-hash preparation can retain its earlier fight's version stamp.
# Keep live rules open; only explicit historical adapters freeze qualification.
var inventory=I.new()
static var pre_v43_text=FileAccess.get_file_as_string("res://data/compat/catalog-pre-v43.json")
static var pre_v43_hash:String=preload("res://scripts/compat/catalogue_fingerprints.gd").text(pre_v43_text)
var pre_v43_inventory=HISTORICAL_I.new()
static var pre_v53_text=FileAccess.get_file_as_string("res://data/compat/catalog-pre-v53.json")
static var pre_v53_hash:String=preload("res://scripts/compat/catalogue_fingerprints.gd").text(pre_v53_text)
var pre_v53_inventory=HISTORICAL_I.new()
static var pre_v70_hash:String=FileAccess.get_file_as_string("res://data/compat/design/v70-previous-catalog.sha256").strip_edges()
var pre_v70_inventory=HISTORICAL_I.new()
var resume_status="missing"
var owner: String
var root_path: String
var matchmaking=preload("res://scripts/shop/matchmaking.gd").new(inventory.practice,I.PB.METHOD)
var v114_matchmaking
var practice_cache:Dictionary:
	get:return matchmaking.practice_cache

func _init(path: String="user://") -> void:
	v114_matchmaking=preload("res://scripts/shop/matchmaking.gd").new(practice_v114,I.PB.METHOD+"-crew114",C.SIMULATION_VERSION+"-crew114")
	v85_inventory.accepted_catalogue_hash=v85_hash
	v85_inventory.footprint_catalogue=JSON.parse_string(v85_text).items
	v82_inventory.accepted_catalogue_hash=v82_hash
	v82_inventory.footprint_catalogue=JSON.parse_string(v82_text).items
	v86_inventory.accepted_catalogue_hash=v86_hash
	v86_inventory.footprint_catalogue=JSON.parse_string(v86_text).items
	pre_v43_inventory.footprint_catalogue=JSON.parse_string(pre_v43_text).items
	pre_v43_inventory.accepted_catalogue_hash=pre_v43_hash
	pre_v53_inventory.footprint_catalogue=JSON.parse_string(pre_v53_text).items
	pre_v53_inventory.accepted_catalogue_hash=pre_v53_hash
	pre_v70_inventory.accepted_catalogue_hash=pre_v70_hash
	root_path=path if path.ends_with("/") else path+"/"
	DirAccess.make_dir_recursive_absolute(root_path)
	var profile=read_json(root_path+"profile.json",{})
	owner=str(profile.get("owner","")) if profile is Dictionary else ""
	if owner.is_empty():
		owner="native-"+str(Time.get_unix_time_from_system())+"-"+str(randi())
		write_json(root_path+"profile.json",{"owner":owner})

func read_json(path: String,fallback: Variant) -> Variant:
	if not FileAccess.file_exists(path):return fallback
	var parser=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK:return fallback
	return parser.data

func write_json(path: String,data: Variant) -> bool:
	var temporary=path+".tmp"
	var file=FileAccess.open(temporary,FileAccess.WRITE)
	if not file:return false
	file.store_string(JSON.stringify(data,"\t"));file.flush()
	var written=file.get_error()==OK;file.close()
	if not written:return false
	return DirAccess.rename_absolute(temporary,path)==OK

func _read_bytes_checked(path:String)->Dictionary:
	var file=FileAccess.open(path,FileAccess.READ)
	if not file:return {"ok":false}
	var bytes=file.get_buffer(file.get_length());var ok=file.get_error()==OK;file.close()
	return {"ok":ok,"bytes":bytes}
func _same_bytes(path:String,expected:PackedByteArray)->bool:
	var read=_read_bytes_checked(path)
	return read.ok and read.bytes==expected
func backup_run(path: String) -> bool:
	var read=_read_bytes_checked(root_path+"run.json")
	if not read.ok:return false
	var original:PackedByteArray=read.bytes
	if FileAccess.file_exists(path):
		if _same_bytes(path,original):return true
		path=path.get_basename()+"-"+preload("res://scripts/online/async_pvp.gd").digest(original).substr(0,12)+".json"
		if FileAccess.file_exists(path):return _same_bytes(path,original)
	var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if not file:return false
	file.store_buffer(original);file.flush()
	var written=file.get_error()==OK;file.close()
	if not written or DirAccess.rename_absolute(path+".tmp",path)!=OK:return false
	return _same_bytes(path,original)

func protect_existing_run()->bool:
	return not FileAccess.file_exists(root_path+"run.json") or backup_run(root_path+"run-preserved.json")

func save(run: Dictionary) -> bool:
	return save_checked(run)

func save_checked(run:Dictionary)->bool:
	if not inventory.validate_run(run):return false
	if FileAccess.file_exists(root_path+"run.json"):
		var old=read_json(root_path+"run.json",{})
		if not old is Dictionary or old.is_empty() or not old.get("pvp",{}) is Dictionary or not inventory.validate_run(old) or old.get("catalogue_hash")!=C.catalogue_hash or old.get("seed")!=run.get("seed") or old.get("pvp",{}).get("run_id","")!=run.get("pvp",{}).get("run_id",""):
			if not backup_run(root_path+"run-preserved.json"):return false
		else:
			# One previous checkpoint; do not grow an archive on every drag.
			var previous=_read_bytes_checked(root_path+"run.json")
			if not previous.ok:return false
			var bytes:PackedByteArray=previous.bytes
			var file=FileAccess.open(root_path+"run-previous.json.tmp",FileAccess.WRITE)
			if not file:return false
			file.store_buffer(bytes);file.flush()
			var good=file.get_error()==OK;file.close()
			if not good or DirAccess.rename_absolute(root_path+"run-previous.json.tmp",root_path+"run-previous.json")!=OK:return false
	var saved=write_json(root_path+"run.json",run)
	if saved:resume_status="ready"
	return saved

func resume() -> Dictionary:
	resume_status="missing"
	if not FileAccess.file_exists(root_path+"run.json"):return {}
	var raw=read_json(root_path+"run.json",null)
	if not raw is Dictionary or raw.is_empty():resume_status="corrupt";return {}
	var restored=_resume_current()
	resume_status="ready" if not restored.is_empty() else "incompatible"
	return restored

func _resume_current() -> Dictionary:
	var run=read_json(root_path+"run.json",{})
	var legacy_source=run is Dictionary and run.get("catalogue_hash","")!=C.catalogue_hash
	if not run is Dictionary or run.is_empty():return {}
	if run.get("mode","")=="async":return _resume_async(run)
	if run.get("version",0)==2:
		var original=run.duplicate(true)
		run=migrate_v2(original)
		if run.is_empty() or not inventory.validate_run(run):return {}
		if not backup_run(root_path+"run-v2-backup.json"):return {}
		if not write_json(root_path+"run.json",run):return {}
	elif run.get("version",0)==3:
		var original=run.duplicate(true)
		run=migrate_v3(original)
		if run.is_empty() or not inventory.validate_run(run):return {}
		if not backup_run(root_path+"run-v3-backup.json"):return {}
		if not write_json(root_path+"run.json",run):return {}
	elif run.get("version",0)==4:
		var original=run.duplicate(true)
		run=migrate_v4_crafting(original)
		if run.is_empty() or not inventory.validate_run(run):return {}
		if not backup_run(root_path+"run-v4-before-crafting-backup.json"):return {}
		if not write_json(root_path+"run.json",run):return {}
	if run.get("version",0)==5 and run.get("catalogue_hash","")==pre_v43_hash:
		var migrated=migrate_v43(run)
		if migrated.is_empty():return {}
		if not backup_run(root_path+"run-before-v43-backup.json"):return {}
		if not write_json(root_path+"run.json",migrated):return {}
		run=migrated
	if run.get("version",0)==5 and run.get("catalogue_hash","")==pre_v53_hash:
		var migrated=migrate_v53(run)
		if migrated.is_empty():return {}
		if not backup_run(root_path+"run-before-v53-backup.json"):return {}
		if not write_json(root_path+"run.json",migrated):return {}
		run=migrated
	if run.get("version",0)==5 and run.get("catalogue_hash","")==pre_v70_hash and pre_v70_hash!=C.catalogue_hash:
		var migrated=migrate_v70(run)
		if migrated.is_empty():return {}
		if not backup_run(root_path+"run-before-v70-backup.json"):return {}
		if not write_json(root_path+"run.json",migrated):return {}
		run=migrated
	if run.get("version",0)==5 and run.get("catalogue_hash","")==V74.HASH:
		var migrated=migrate_v75(run)
		if migrated.is_empty():return {}
		if not backup_run(root_path+"run-before-v75-backup.json"):return {}
		if not write_json(root_path+"run.json",migrated):return {}
		run=migrated
	if run.get("version",0)==5 and run.get("catalogue_hash","")==v82_hash:
		var migrated=migrate_v83(run)
		if migrated.is_empty():return {}
		if not backup_run(root_path+"run-before-v83-backup.json"):return {}
		if not write_json(root_path+"run.json",migrated):return {}
		run=migrated
	if run.get("version",0)==5 and run.get("catalogue_hash","")==v85_hash:
		var migrated=migrate_v86(run)
		if migrated.is_empty():return {}
		if not backup_run(root_path+"run-before-v86-backup.json"):return {}
		if not write_json(root_path+"run.json",migrated):return {}
		run=migrated
	if run.get("version",0)==5 and recent_catalogues.has(run.get("catalogue_hash","")) and run.get("catalogue_hash","")!=C.catalogue_hash:
		var migrated=migrate_v88(run)
		if migrated.is_empty():return {}
		if not backup_run(root_path+"run-before-"+recent_catalogues[run.catalogue_hash].backup+"-backup.json"):return {}
		if not write_json(root_path+"run.json",migrated):return {}
		run=migrated
	if run.get("version",0)==5 and run.get("catalogue_hash","")==C.common_hash and C.common_hash!=C.catalogue_hash:
		var migrated=migrate_v114(run)
		if migrated.is_empty():return {}
		if not backup_run(root_path+"run-before-v114-backup.json"):return {}
		if not write_json(root_path+"run.json",migrated):return {}
		run=migrated
	if run.get("version",0)==5 and run.get("catalogue_hash","")==C.v114_hash:
		var migrated=migrate_v115(run)
		if migrated.is_empty():return {}
		if not backup_run(root_path+"run-before-v115-backup.json"):return {}
		if not write_json(root_path+"run.json",migrated):return {}
		run=migrated
	if run.get("version",0)==5 and run.get("catalogue_hash","")==C.v115_hash:
		var migrated=migrate_v116(run)
		if migrated.is_empty():return {}
		if not backup_run(root_path+"run-before-v116-backup.json"):return {}
		if not write_json(root_path+"run.json",migrated):return {}
		run=migrated
	if run.get("version",0)==5 and run.get("catalogue_hash","")==C.v116_hash:
		var migrated=migrate_v124(run)
		if migrated.is_empty():return {}
		if not backup_run(root_path+"run-before-v124-backup.json"):return {}
		if not write_json(root_path+"run.json",migrated):return {}
		run=migrated
	if run.get("version",0)==5 and run.get("catalogue_hash","")==C.v124_hash:
		var migrated=migrate_v125(run)
		if migrated.is_empty():return {}
		if not backup_run(root_path+"run-before-v125-backup.json"):return {}
		if not write_json(root_path+"run.json",migrated):return {}
		run=migrated
	if run.get("version",0)==5 and run.get("catalogue_hash","")==C.v125_hash:
		var migrated=migrate_v127(run)
		if migrated.is_empty():return {}
		if not backup_run(root_path+"run-before-v127-backup.json"):return {}
		if not write_json(root_path+"run.json",migrated):return {}
		run=migrated
	if run.get("version",0)==5 and run.get("catalogue_hash","")==C.v127_hash:
		var migrated=migrate_v128(run)
		if migrated.is_empty():return {}
		if not backup_run(root_path+"run-before-v128-backup.json"):return {}
		if not write_json(root_path+"run.json",migrated):return {}
		run=migrated
	if run.get("version",0)==5 and run.get("catalogue_hash","")==C.v128_hash:
		var migrated=migrate_v129(run)
		if migrated.is_empty():return {}
		if not backup_run(root_path+"run-before-v129-backup.json"):return {}
		if not write_json(root_path+"run.json",migrated):return {}
		run=migrated
	if legacy_source and not run.has("recruitment") and not run.get("recruitment_legacy",false):
		run.recruitment_legacy=true
		if not write_json(root_path+"run.json",run):return {}
	if not inventory.validate_run(run):return {}
	for key in ["version","round","serial","gold","wins","losses","seed","refreshes","recruited_round","capacity_refund_round","footprint_revision"]:
		if run.has(key):run[key]=int(run[key])
	normalize_owned(run)
	if run.has("recruitment"):
		for key in ["version","node","return_round","star_round","supply_round","bonus_round"]:
			if run.recruitment.has(key):run.recruitment[key]=int(run.recruitment[key])
		run.recruitment.done=run.recruitment.get("done",[]).map(func(v):return int(v))
		if run.recruitment.config.get("link",{}).has("star"):run.recruitment.config.link.star=int(run.recruitment.config.link.star)
	if run.phase=="battle":run.phase="result" if run.has("combat") else "shop"
	return run

func _resume_async(run:Dictionary)->Dictionary:
	var p=preload("res://scripts/online/async_pvp.gd")
	# Network snapshots are never migrated into a different opponent pool.
	if run.get("catalogue_hash","")!=C.catalogue_hash or not inventory.validate_run(run):return {}
	var state=run.get("pvp",{})
	if not state is Dictionary or not p.safe_id(state.get("run_id")) or state.get("stage") not in ["idle","pending","locked"] or not state.get("recent",[]) is Array:return {}
	if state.stage!="idle":
		if not p.safe_id(state.get("player_id")) or not state.get("frozen") is String:return {}
		if p.digest(state.frozen.to_utf8_buffer())!=state.get("sha256"):return {}
		if run.phase!="ending" and not p.matches_frozen(inventory,run):return {}
	if state.stage=="pending" and run.phase!="shop":return {}
	if state.stage=="locked":
		if not inventory.validate_ghost(run.get("opponent",{})) or p.pool_id(run.opponent)!=p.pool_id(run) or int(run.opponent.round)!=int(run.round):return {}
		if state.get("source") not in ["player","bot"]:return {}
	if run.phase in ["battle","result","ending"] and (state.stage!="locked" or not run.get("combat") is Dictionary):return {}
	for key in ["version","round","serial","gold","wins","losses","seed","refreshes","recruited_round","capacity_refund_round","footprint_revision"]:
		if run.has(key):run[key]=int(run[key])
	normalize_owned(run)
	normalize_async_recruitment(run)
	if run.has("opponent"):
		normalize_owned(run.opponent);normalize_async_recruitment(run.opponent)
	if run.phase=="battle":run.phase="result"
	return run

func normalize_async_recruitment(build:Dictionary)->void:
	if not build.has("recruitment"):return
	for key in ["version","node","return_round","star_round","supply_round","bonus_round"]:
		if build.recruitment.has(key):build.recruitment[key]=int(build.recruitment[key])
	build.recruitment.done=build.recruitment.get("done",[]).map(func(v):return int(v))

func normalize_owned(build:Dictionary)->void:
	# Called only after validation, for runs, the ghost pool and imports alike.
	if build.has("supply_version"):build.supply_version=int(build.supply_version)
	if build.has("pocket_version"):build.pocket_version=int(build.pocket_version)
	for key in I.OWNED_COLLECTIONS:
		for item in build.get(key,[]):
			if item.has("crew_star"):item.crew_star=int(item.crew_star)
			for field in ["x","y","rotation","level","paid_cost","salvage_credit"]:
				if field not in ["paid_cost","salvage_credit"] or item.has(field):item[field]=int(item.get(field,0))

# Preserve paid inventory and already-earned results; old ghosts stay versioned.
func migrate_v86(old:Variant,ghost:bool=false)->Dictionary:
	if not old is Dictionary or old.get("catalogue_hash","")!=v85_hash:return {}
	if old.get("simulation_version","resonance-v83") not in ["resonance-v60","resonance-v75","resonance-v83"]:return {}
	if not (v85_inventory.validate_ghost(old) if ghost else v85_inventory.validate_run(old)):return {}
	var run=old.duplicate(true);run.catalogue_hash=C.catalogue_hash
	run.simulation_version=old.get("simulation_version","resonance-v83") if ghost or old.get("phase","")=="ending" else C.SIMULATION_VERSION
	if not ghost:
		if run.get("opponent",{}).get("catalogue_hash","")==v85_hash:
			run.opponent=migrate_v86(run.opponent,true)
			if run.opponent.is_empty():return {}
		if run.phase in ["battle","result"] and run.has("combat"):
			var summary=legacy_result(old)
			if summary.is_empty():return {}
			run.combat=summary;run.phase="result";run.simulation_version=old.get("simulation_version","resonance-v83")
	return run if (inventory.validate_ghost(run) if ghost else inventory.validate_run(run)) else {}

# Geometry and ownership do not change. Validate against the exact old shapes,
# retain completed outcomes, and keep old ghosts stamped with their actual rules.
func migrate_v87(old:Variant,ghost:bool=false)->Dictionary:return migrate_v88(old,ghost)
func migrate_v88(old:Variant,ghost:bool=false)->Dictionary:
	if not old is Dictionary:return {}
	var hash_value=str(old.get("catalogue_hash",""))
	if not recent_catalogues.has(hash_value):return {}
	var baseline=recent_catalogues[hash_value]
	var version=str(old.get("simulation_version",baseline.versions[-1]))
	if version not in baseline.versions:return {}
	var previous=HISTORICAL_I.new();previous.accepted_catalogue_hash=hash_value;previous.footprint_catalogue=baseline.items
	if not (previous.validate_ghost(old) if ghost else previous.validate_run(old)):return {}
	var run=old.duplicate(true);run.catalogue_hash=C.catalogue_hash
	run.simulation_version=version if ghost or old.get("phase","")=="ending" else C.SIMULATION_VERSION
	if not ghost:
		if recent_catalogues.has(run.get("opponent",{}).get("catalogue_hash","")):
			run.opponent=migrate_v88(run.opponent,true)
			if run.opponent.is_empty():return {}
		if run.phase in ["battle","result"] and run.has("combat"):
			var summary=legacy_result(old)
			if summary.is_empty():return {}
			run.combat=summary;run.phase="result";run.simulation_version=version
	return run if (inventory.validate_ghost(run) if ghost else inventory.validate_run(run)) else {}

# V83 changes no geometry, eligibility or ownership. Existing money, shelves and
# food stay exact; only identifiable unsold free starter weapons gain salvage credit.
func migrate_v83(old:Variant,ghost:bool=false)->Dictionary:
	if not old is Dictionary or old.get("catalogue_hash","")!=v82_hash:return {}
	if old.get("simulation_version","resonance-v75") not in ["resonance-v60","resonance-v75"]:return {}
	if not (v82_inventory.validate_ghost(old) if ghost else v82_inventory.validate_run(old)):return {}
	var run=old.duplicate(true);run.catalogue_hash=C.catalogue_hash
	run.simulation_version=old.get("simulation_version","resonance-v75") if ghost or old.get("phase","")=="ending" else C.SIMULATION_VERSION
	if not ghost:
		var starter=JSON.parse_string(v82_text).characters[run.leader].starter
		for key in I.OWNED_COLLECTIONS:
			for piece in run.get(key,[]):
				if piece.uid=="i1" and piece.kind==starter and int(piece.get("paid_cost",0))==0:
					piece.salvage_credit=int(I.ECONOMY.rules.starter_credit)
		if run.get("opponent",{}) is Dictionary and run.get("opponent",{}).get("catalogue_hash","")==v82_hash:
			run.opponent=migrate_v83(run.opponent,true)
			if run.opponent.is_empty():return {}
		if run.phase in ["battle","result"] and run.has("combat"):
			var summary=legacy_result(old)
			if summary.is_empty():return {}
			run.combat=summary;run.phase="result"
			run.simulation_version=old.get("simulation_version","resonance-v75")
	return run if (inventory.validate_ghost(run) if ghost else inventory.validate_run(run)) else {}

# Validate the exact old catalogue before applying new eligibility. No reroll/reflow.
func migrate_v75(old:Variant,ghost:bool=false)->Dictionary:
	if preload("res://scripts/compat/catalogue_fingerprints.gd").text(V74.frozen_text)!=V74.HASH or not old is Dictionary or old.get("catalogue_hash","")!=V74.HASH:return {}
	if not (v74_inventory.validate_ghost(old) if ghost else v74_inventory.validate_run(old)):return {}
	var run=old.duplicate(true)
	run.catalogue_hash=C.catalogue_hash
	# Old replay provenance must survive pool/import/snapshot; only future fights use V75.
	run.simulation_version=old.get("simulation_version","resonance-v60") if ghost or old.get("phase","")=="ending" else C.SIMULATION_VERSION
	for key in I.OWNED_COLLECTIONS:
		for piece in run.get(key,[]):
			if piece.has("paid_cost"):
				piece.paid_cost=int(piece.paid_cost)
				continue
			var leader=V74.frozen.characters[run.leader]
			var free=(piece.uid=="b1" and piece.kind=="satchel") or (piece.uid=="i1" and piece.kind==leader.starter) or (piece.uid=="i2" and piece.kind==leader.get("starter_supply","nutrition"))
			piece.paid_cost=0 if free else int(V74.frozen.items[piece.kind].price)
			piece.cost_basis="known_free" if free else "legacy_estimate"
	if not ghost:
		for index in run.shop.size():
			if not run.shop[index].is_empty() and not inventory.shop_eligible(run,run.shop[index].kind):run.shop[index]={}
		if run.get("opponent",{}) is Dictionary and run.get("opponent",{}).get("catalogue_hash","")==V74.HASH:
			run.opponent=migrate_v75(run.opponent,true)
			if run.opponent.is_empty():return {}
		if run.phase in ["battle","result"] and run.has("combat"):
			var summary=legacy_result(old)
			if summary.is_empty():return {}
			run.combat=summary;run.phase="result"
			run.simulation_version=old.get("simulation_version","resonance-v60")
	return run if (inventory.validate_ghost(run) if ghost else inventory.validate_run(run)) else {}

# V70 adds recipes/items while retaining every previously active item's geometry,
# battle data and simulation version. Validate both sides of the hash-only upgrade.
func migrate_v70(old:Variant,ghost:bool=false)->Dictionary:
	if pre_v70_hash.is_empty() or not old is Dictionary or old.get("catalogue_hash","")!=pre_v70_hash:return {}
	if not (pre_v70_inventory.validate_ghost(old) if ghost else pre_v70_inventory.validate_run(old)):return {}
	var upgraded=old.duplicate(true)
	upgraded.catalogue_hash=C.catalogue_hash
	if not ghost and upgraded.get("opponent",{}) is Dictionary and upgraded.get("opponent",{}).get("catalogue_hash","")==pre_v70_hash:
		upgraded.opponent=migrate_v70(upgraded.opponent,true)
		if upgraded.opponent.is_empty():return {}
	return upgraded if (inventory.validate_ghost(upgraded) if ghost else inventory.validate_run(upgraded)) else {}

func migrate_v4_expansion(old: Variant,ghost: bool=false) -> Dictionary:
	return migrate_v4_crafting(old,ghost)

func migrate_v43(old:Variant,ghost:bool=false) -> Dictionary:
	if not (pre_v43_inventory.validate_ghost(old) if ghost else pre_v43_inventory.validate_run(old)):return {}
	var run=old.duplicate(true)
	run.catalogue_hash=C.catalogue_hash
	for key in ["stash","pending_rearrange"]:run[key]=run.get(key,[])
	run.items=[]
	var displaced=[]
	for piece in old.items:
		if inventory.can_place(piece,run.items,run.bags):run.items.append(piece.duplicate(true))
		else:displaced.append(piece.duplicate(true))
	for piece in displaced:
		var fit=inventory.first_fit(piece,run.items,run.bags)
		if not fit.is_empty():run.items.append(fit)
		else:run.stash.append(piece)
	inventory.clean_relay(run)
	if ghost:
		run.inactive=run.items.is_empty()
		return run if inventory.validate_ghost(run) else {}
	if run.get("opponent",{}) is Dictionary and run.get("opponent",{}).get("catalogue_hash","")==pre_v43_hash:
		run.opponent=migrate_v43(run.opponent,true)
	if run.phase in ["battle","result"] and run.has("combat"):
		var summary=legacy_result(old)
		if not summary.is_empty():run.combat=summary;run.phase="result"
	run.footprint_revision=43
	return run if inventory.validate_run(run) else {}

func migrate_v53(old:Variant,ghost:bool=false) -> Dictionary:
	if not (pre_v53_inventory.validate_ghost(old) if ghost else pre_v53_inventory.validate_run(old)):return {}
	var run=old.duplicate(true)
	run.catalogue_hash=C.catalogue_hash
	run.simulation_version=C.SIMULATION_VERSION
	for key in ["stash","pending_rearrange"]:run[key]=run.get(key,[])
	run.items=[]
	var displaced=[]
	for piece in old.items:
		if inventory.can_place(piece,run.items,run.bags):run.items.append(piece.duplicate(true))
		else:displaced.append(piece.duplicate(true))
	for piece in displaced:
		var fit=inventory.first_fit(piece,run.items,run.bags)
		if not fit.is_empty():run.items.append(fit)
		else:run.stash.append(piece)
	inventory.clean_relay(run)
	if ghost:
		run.inactive=run.items.is_empty()
		return run if inventory.validate_ghost(run) else {}
	if run.get("opponent",{}) is Dictionary and run.get("opponent",{}).get("catalogue_hash","")==pre_v53_hash:
		run.opponent=migrate_v53(run.opponent,true)
	if run.phase in ["battle","result"] and run.has("combat"):
		var summary=legacy_result(old)
		if not summary.is_empty():run.combat=summary;run.phase="result"
	run.footprint_revision=53
	return run if inventory.validate_run(run) else {}


func migrate_v4_crafting(old: Variant,ghost: bool=false) -> Dictionary:
	if not old is Dictionary or old.get("version",0)!=4 or old.get("ruleset","")!="wuwa-pack-v4":return {}
	if old.get("catalogue_hash","") not in [OLD_C.catalogue_hash,expansion_base_hash]:return {}
	var source=old.duplicate(true)
	if source.catalogue_hash==expansion_base_hash:
		for key in (["items","bags"] if ghost else OLD_I.OWNED_COLLECTIONS+["shop"]):
			if not source.get(key,[]) is Array:return {}
			for piece in source.get(key,[]):
				if not piece is Dictionary or (not piece.is_empty() and not expansion_base_items.has(piece.get("kind",""))):return {}
	source.catalogue_hash=OLD_C.catalogue_hash
	if not (old_inventory.validate_ghost(source) if ghost else old_inventory.validate_run(source)):return {}
	return reflow(source,ghost)

func migrate_v3(old: Variant,ghost: bool=false) -> Dictionary:
	if not old is Dictionary or old.get("version",0)!=3 or old.get("ruleset","")!="wuwa-pack-v3" or old.get("catalogue_hash","")!=v3_hash:return {}
	if old.get("roster",[])!=[] or old.get("supports",[])!=[]:return {}
	for key in (["items","bags"] if ghost else OLD_I.OWNED_COLLECTIONS+["shop"]):
		if not old.get(key,[]) is Array:return {}
		for piece in old.get(key,[]):
			if not piece is Dictionary:return {}
			if key=="shop" and piece.is_empty():continue
			if not I.legacy_items.has(piece.get("kind","")):return {}
	var source=old.duplicate(true)
	source.version=4;source.ruleset="wuwa-pack-v4";source.catalogue_hash=OLD_C.catalogue_hash;source.roster=[];source.supports=[]
	if not ghost:
		source.recruited_round=0;source.migrated_from=3
		for offer in source.shop:
			if not offer.is_empty():offer.legacy_v3=true
	if not (old_inventory.validate_ghost(source) if ghost else old_inventory.validate_run(source)):return {}
	return reflow(source,ghost)

func reflow(source: Dictionary,ghost: bool=false) -> Dictionary:
	var run=source.duplicate(true)
	run.version=5;run.ruleset=C.RULESET;run.catalogue_hash=C.catalogue_hash
	if ghost:
		# Ghosts keep displaced items as metadata; they cannot participate until a
		# player imports/rearranges them. Never discard original ownership.
		run.stash=[];run.pending_rearrange=[]
	else:
		run.pending_rearrange=run.get("pending_rearrange",[])
	var displaced: Array=[];run.items=[]
	# Reserve still-legal placements before trying to fill displaced ones.
	for piece in source.items:
		if inventory.can_place(piece,run.items,run.bags):run.items.append(piece.duplicate(true))
		else:displaced.append(piece.duplicate(true))
	for piece in displaced:
		var fit=inventory.first_fit(piece,run.items,run.bags)
		if not fit.is_empty():run.items.append(fit)
		else:run.stash.append(piece)
	inventory.clean_relay(run)
	if ghost:
		run.inactive=run.items.is_empty()
		return run if inventory.validate_ghost(run) else {}
	for index in range(run.shop.size()):
		var offer=run.shop[index]
		if offer.is_empty():continue
		offer.erase("legacy_v3")
		if not inventory.shop_eligible(run,offer.kind):run.shop[index]={}
	run.migrated_from=int(source.version);run.free_rearrange=1
	if run.phase in ["battle","result"]:
		var summary=legacy_result(source)
		if summary.is_empty():run.phase="shop";run.erase("combat")
		else:
			run.phase="result";run.combat=summary
			var old_opponent=source.get("opponent",{})
			run.opponent=migrate_v4_crafting(old_opponent,true) if old_opponent is Dictionary else {}
			if run.opponent.is_empty():run.opponent=inventory.practice(int(run.round),int(run.seed)%31)
	inventory.grant_milestones(run,true)
	return run if inventory.validate_run(run) else {}

# Preserve an earned but unclaimed outcome without replaying the obsolete rules.
func legacy_result(source: Dictionary) -> Dictionary:
	var combat=source.get("combat",{})
	if not combat is Dictionary or not inventory.bounded_integer(combat.get("winner",null),-1,1):return {}
	var duration=combat.get("duration",0)
	if not (duration is int or duration is float) or not is_finite(float(duration)) or duration<0 or duration>60:return {}
	var totals: Array=[];var sides: Array=[]
	for side in range(2):
		var total={"damage":0,"heal":0,"shield":0,"bursts":0,"relays":0,"tired":0,"intros":0,"outros":0}
		var old_totals=combat.get("totals",[])
		if old_totals is Array and old_totals.size()==2 and old_totals[side] is Dictionary:
			for key in total:
				var value=old_totals[side].get(key,0)
				if (value is int or value is float) and is_finite(float(value)) and value>=0 and value<1e9:total[key]=value
		totals.append(total)
		var state={"hp":102,"max_hp":102,"shield":0,"stamina":0,"energy":0,"concerto":0,"mark":0,"burn":0,"statuses":[]}
		var frames=combat.get("frames",[])
		if frames is Array and not frames.is_empty() and frames[-1] is Dictionary:
			var old_sides=frames[-1].get("sides",[])
			if old_sides is Array and old_sides.size()==2 and old_sides[side] is Dictionary:
				for key in ["hp","max_hp","shield"]:
					var value=old_sides[side].get(key,102 if key=="max_hp" else 0)
					if (value is int or value is float) and is_finite(float(value)) and value>=0 and value<1e9:state[key]=value
		state.max_hp=maxf(1,state.max_hp);state.hp=minf(state.hp,state.max_hp);sides.append(state)
	var used: Array=[[],[]]
	var old_used=combat.get("used",[[],[]])
	if old_used is Array and old_used.size()==2 and old_used[0] is Array:
		used[0]=old_used[0].filter(func(v):return v is String and source.items.any(func(p):return p.uid==v and C.is_tag(p.kind,"provision")))
	return {"winner":int(combat.winner),"duration":float(duration),"totals":totals,"frames":[{"time":float(duration),"sides":sides,"progress":[{},{}],"waiting":[{},{}]}],"events":[],"used":used,"legacy_result":true}

func old_cells(item: Dictionary,legacy: Dictionary) -> Array:
	var out: Array=[];var low=Vector2i(100,100)
	for p in legacy[item.kind].shape:
		var v=inventory.rotated(Vector2i(int(p[0]),int(p[1])),int(item.rotation))
		low.x=mini(low.x,v.x);low.y=mini(low.y,v.y);out.append(v)
	return out.map(func(v):return v-low+Vector2i(int(item.x),int(item.y)))

func migrate_v2(old: Dictionary) -> Dictionary:
	if not C.characters.has(old.get("leader","")) or not old.get("items") is Array or not old.get("bags") is Array or not old.get("stash",[]) is Array or old.items.size()>30 or old.bags.is_empty() or old.bags.size()>8 or old.get("stash",[]).size()>8:return {}
	if old.get("phase","") not in ["shop","battle","result","ending"] or not inventory.bounded_integer(old.get("round",0),1,10):return {}
	for key in ["gold","wins","losses","seed","serial"]:
		if not inventory.bounded_integer(old.get(key,0),0,4294967295 if key=="seed" else 2147483647):return {}
	var legacy=read_json("res://data/compat/catalog-v2.json",{}).get("items",{})
	var ids: Array=[];var cover: Array=[]
	for key in ["bags","items","stash"]:
		for item in old.get(key,[]):
			if not item is Dictionary or not item.get("kind") is String or not item.get("uid") is String or item.uid.is_empty() or item.uid.length()>80 or item.uid in ids:return {}
			ids.append(item.uid)
			if not inventory.bounded_integer(item.get("x",null),0,7) or not inventory.bounded_integer(item.get("y",null),0,5) or not inventory.bounded_integer(item.get("rotation",null),0,3):return {}
			if key=="bags":
				if item.kind not in ["satchel","pouch"]:return {}
				for cell in old_cells(item,legacy):
					if cell in cover or cell.x<0 or cell.x>=6 or cell.y<0 or cell.y>=5:return {}
					cover.append(cell)
	if cover.size()<6 or cover.size()>30:return {}
	var old_taken: Array=[]
	for item in old.items:
		if not legacy.has(item.kind):continue
		for cell in old_cells(item,legacy):
			if cell not in cover or cell in old_taken:return {}
			old_taken.append(cell)
	var run=inventory.new_run_supply(old.leader,int(old.seed),"full",0)
	for key in ["round","gold","wins","losses","seed","serial"]:run[key]=int(old.get(key,run[key]))
	run.phase="shop" if old.phase in ["battle","result"] else old.phase
	run.migrated_from=2
	run.items=[];run.stash=[];run.bags=[];run.primary="";run.free_rearrange=1
	run.history=old.get("history",[]).duplicate(true) if old.get("history",[]) is Array else []
	# The retained V2 catalogue has nine-cell satchels and six-cell pouches.
	# Cover every legal legacy sum; keep the former 22/26 decomposition as compatibility fallback.
	var capacities={
		6:["satchel"],9:["satchel","strip"],12:["satchel","travel"],15:["satchel","travel","strip"],
		18:["satchel","travel","travel"],21:["satchel","travel","travel","strip"],
		22:["satchel","travel","travel","pouch"],24:["satchel","travel","travel","travel"],
		26:["satchel","travel","travel","pouch","pouch"],27:["satchel","travel","travel","travel","strip"],
		30:["satchel","travel","travel","travel","travel"]
	}
	var kinds: Array=capacities.get(cover.size(),[])
	if kinds.is_empty():return {}
	for n in range(kinds.size()):
		var bag=inventory.first_fit(inventory.make_piece(kinds[n],"migrated-bag-"+str(n)),[],run.bags)
		if bag.is_empty():return {}
		run.bags.append(bag)
	for item in old.items+old.get("stash",[]):
		var kind=LEGACY_MAP.get(item.kind,"")
		var value=int(legacy.get(item.kind,{}).get("price",item.get("price",0))) if inventory.bounded_integer(legacy.get(item.kind,{}).get("price",item.get("price",0)),0,100) else 0
		if kind.is_empty() or (C.is_tag(kind,"keepsake") and C.items[kind].owner!=run.leader):
			run.gold+=value;continue
		var piece=inventory.make_piece(kind,item.uid)
		if not inventory.collection_legal(run.items+run.stash+run.pending_rearrange+[piece],run.leader):
			run.gold+=value;continue
		if item in old.items:
			var fit=inventory.first_fit(piece,run.items,run.bags)
			if not fit.is_empty():run.items.append(fit);continue
		run.stash.append(piece)
	# Never reuse an ID from the original, even when an imported serial was stale.
	for item in old.items+old.get("stash",[]):
		var owned_serial=inventory.uid_serial(item.uid)
		if owned_serial<0:return {}
		run.serial=maxi(run.serial,owned_serial)
	run.primary=inventory.primary_weapon(run).get("uid","")
	if C.SIMULATION_VERSION=="resonance-v60" and run.round>=2:inventory.gift(run,C.characters[run.leader].core)
	inventory.grant_milestones(run,true)
	run.shop=[];inventory.refresh(run)
	return run if inventory.validate_run(run) else {}

func pool() -> Array:
	var raw=read_json(root_path+"ghosts.json",[])
	var result: Array=[]
	if not raw is Array:return result
	for ghost in raw:
		if inventory.validate_ghost(ghost):
			normalize_owned(ghost);result.append(ghost)
		elif ghost is Dictionary and ghost.get("catalogue_hash","")==C.v128_hash:
			var migrated=migrate_v129(ghost,true)
			if not migrated.is_empty():result.append(migrated)
		elif ghost is Dictionary and ghost.get("catalogue_hash","")==C.v127_hash:
			var migrated=migrate_v128(ghost,true)
			if not migrated.is_empty():result.append(migrated)
		elif ghost is Dictionary and ghost.get("catalogue_hash","")==C.v125_hash:
			var migrated=migrate_v127(ghost,true)
			if not migrated.is_empty():result.append(migrated)
		elif ghost is Dictionary and ghost.get("catalogue_hash","")==C.v124_hash:
			var migrated=migrate_v125(ghost,true)
			if not migrated.is_empty():result.append(migrated)
		elif ghost is Dictionary and ghost.get("catalogue_hash","")==C.v116_hash:
			var migrated=migrate_v124(ghost,true)
			if not migrated.is_empty():result.append(migrated)
		elif ghost is Dictionary and ghost.get("catalogue_hash","")==C.v115_hash:
			var migrated=migrate_v116(ghost,true)
			if not migrated.is_empty():result.append(migrated)
		elif ghost is Dictionary and ghost.get("catalogue_hash","")==C.v114_hash:
			var migrated=migrate_v115(ghost,true)
			if not migrated.is_empty():result.append(migrated)
		elif ghost is Dictionary and ghost.get("catalogue_hash","")==C.common_hash:
			var migrated=migrate_v114(ghost,true)
			if not migrated.is_empty():result.append(migrated)
		elif ghost is Dictionary and recent_catalogues.has(ghost.get("catalogue_hash","")):
			var migrated=migrate_v88(ghost,true)
			if not migrated.is_empty():result.append(migrated)
		elif ghost is Dictionary and ghost.get("catalogue_hash","")==v85_hash:
			var migrated=migrate_v86(ghost,true)
			if not migrated.is_empty():result.append(migrated)
		elif ghost is Dictionary and ghost.get("catalogue_hash","")==v82_hash:
			var migrated=migrate_v83(ghost,true)
			if not migrated.is_empty():result.append(migrated)
		elif ghost is Dictionary and ghost.get("catalogue_hash","")==V74.HASH:
			var migrated=migrate_v75(ghost,true)
			if not migrated.is_empty():result.append(migrated)
		elif ghost is Dictionary and ghost.get("catalogue_hash","")==pre_v70_hash:
			var migrated=migrate_v70(ghost,true)
			if not migrated.is_empty():result.append(migrated)
		elif ghost is Dictionary and ghost.get("version",0)==5 and ghost.get("catalogue_hash","")==pre_v53_hash:
			var migrated=migrate_v53(ghost,true)
			if not migrated.is_empty():result.append(migrated)
		elif ghost is Dictionary and ghost.get("version",0)==5 and ghost.get("catalogue_hash","")==pre_v43_hash:
			var migrated=migrate_v43(ghost,true)
			if not migrated.is_empty():result.append(migrated)
		elif ghost is Dictionary and ghost.get("version",0)==3:
			var migrated=migrate_v3(ghost,true)
			if not migrated.is_empty():result.append(migrated)
		elif ghost is Dictionary and ghost.get("version",0)==4:
			var migrated=migrate_v4_expansion(ghost,true)
			if not migrated.is_empty():result.append(migrated)
	return result

func publish(ghost: Dictionary) -> bool:
	if not inventory.validate_ghost(ghost):return false
	var ghosts=pool().filter(func(g):return not(g.get("owner","")==ghost.get("owner","") and g.round==ghost.round and g.leader==ghost.leader))
	ghosts.append(ghost)
	if ghosts.size()>300:ghosts=ghosts.slice(ghosts.size()-300)
	return write_json(root_path+"ghosts.json",ghosts)

# Compatibility query entry points; policy and cache belong to Matchmaking.
var legacy_practice_cache={}
func opponent(run: Dictionary) -> Dictionary:
	if run.get("recruitment",{}).get("version",0)==114:
		return v114_matchmaking.choose(int(run.round),int(run.seed),pool() if int(run.round)>3 else [],owner,run.get("pool_mode","full"))
	if run.get("recruitment_legacy",false):
		var key=str(run.round)+":"+str(int(run.seed)%31)+":"+run.get("pool_mode","full")
		if not legacy_practice_cache.has(key):legacy_practice_cache[key]=I.PB.build(inventory,int(run.round),int(run.seed)%31,run.get("pool_mode","full"),true)
		return legacy_practice_cache[key].duplicate(true)
	return matchmaking.choose(int(run.round),int(run.seed),pool() if int(run.round)>3 else [],owner,run.get("pool_mode","full"),int(run.get("supply_version",0)),int(run.get("pocket_version",0)))
func practice_v114(round_number:int,seed_value:int,pool_mode:String="full")->Dictionary:
	return I.PB.build(inventory,round_number,seed_value,pool_mode,false,114)
func practice_opponent(run:Dictionary)->Dictionary:
	return matchmaking.practice(int(run.round),int(run.seed),run.get("pool_mode","full"),int(run.get("supply_version",0)),int(run.get("pocket_version",0)))

func import_ghost(path: String,publish_import:bool=true) -> Dictionary:
	if not FileAccess.file_exists(path) or FileAccess.get_file_as_bytes(path).size()>30000:return {}
	var raw=read_json(path,{})
	if raw is Dictionary and raw.get("catalogue_hash","")==C.v128_hash:raw=migrate_v129(raw,true)
	if raw is Dictionary and raw.get("catalogue_hash","")==C.v127_hash:raw=migrate_v128(raw,true)
	if raw is Dictionary and raw.get("catalogue_hash","")==C.v125_hash:raw=migrate_v127(raw,true)
	if raw is Dictionary and raw.get("catalogue_hash","")==C.v124_hash:raw=migrate_v125(raw,true)
	if raw is Dictionary and raw.get("catalogue_hash","")==C.v116_hash:raw=migrate_v124(raw,true)
	if raw is Dictionary and raw.get("catalogue_hash","")==C.v115_hash:raw=migrate_v116(raw,true)
	if raw is Dictionary and raw.get("catalogue_hash","")==C.v114_hash:raw=migrate_v115(raw,true)
	if raw is Dictionary and raw.get("catalogue_hash","")==C.common_hash:raw=migrate_v114(raw,true)
	if raw is Dictionary and recent_catalogues.has(raw.get("catalogue_hash","")):raw=migrate_v88(raw,true)
	if raw is Dictionary and raw.get("catalogue_hash","")==v85_hash:raw=migrate_v86(raw,true)
	if raw is Dictionary and raw.get("catalogue_hash","")==v82_hash:raw=migrate_v83(raw,true)
	if raw is Dictionary and raw.get("catalogue_hash","")==V74.HASH:raw=migrate_v75(raw,true)
	if raw is Dictionary and raw.get("catalogue_hash","")==pre_v70_hash and pre_v70_hash!=C.catalogue_hash:raw=migrate_v70(raw,true)
	if raw is Dictionary and raw.get("version",0)==3:raw=migrate_v3(raw,true)
	elif raw is Dictionary and raw.get("version",0)==4:raw=migrate_v4_crafting(raw,true)
	elif raw is Dictionary and raw.get("version",0)==5 and raw.get("catalogue_hash","")==pre_v43_hash:raw=migrate_v43(raw,true)
	elif raw is Dictionary and raw.get("version",0)==5 and raw.get("catalogue_hash","")==pre_v53_hash:raw=migrate_v53(raw,true)
	if not inventory.validate_ghost(raw):return {}
	var clean=inventory.snapshot(raw,"imported-"+str(Time.get_ticks_msec()),str(raw.get("name","导入影像")).substr(0,24))
	# A migrated ghost may have displaced equipment. Preserve it for review and
	# later rearrangement, after independently validating every metadata UID.
	clean.inactive=bool(raw.get("inactive",false))
	var ids=(clean.items+clean.bags).map(func(v):return v.uid)
	for key in ["stash","pending_gifts","pending_rearrange"]:
		if not raw.get(key,[]) is Array:return {}
		if key!="stash" and raw.get(key,[]).size()>(256 if key=="pending_rearrange" else 128):return {}
		clean[key]=[]
		for piece in raw.get(key,[]):
			if not inventory.valid_piece(piece) or piece.uid in ids:return {}
			ids.append(piece.uid);clean[key].append(piece.duplicate(true))
	if not inventory.collection_legal(clean.items+clean.stash+clean.pending_gifts+clean.pending_rearrange,clean.leader):return {}
	normalize_owned(clean)
	clean.source="saved"
	return clean if not publish_import or publish(clean) else {}

func migrate_v114(old:Variant,ghost:bool=false)->Dictionary:
	if not old is Dictionary or old.get("catalogue_hash","")!=C.common_hash:return {}
	if not validate_v115_space(old,ghost):return {}
	var checked=old.duplicate(true);checked.catalogue_hash=C.catalogue_hash
	var next=preload("res://scripts/party/recruitment_v114.gd").migrate(checked)
	if not next.has("simulation_version"):next.simulation_version="resonance-v113"
	if not ghost and not has_completed_combat(old):next.simulation_version=preload("res://scripts/party/recruitment.gd").simulation_version(next)
	return next if (inventory.validate_ghost(next) if ghost else inventory.validate_run(next)) else {}

# Exact V114 hash only. Preserve teams, inventory, RNG and completed combat bytes.
func migrate_v115(old:Variant,ghost:bool=false)->Dictionary:
	if not old is Dictionary or old.get("catalogue_hash","")!=C.v114_hash:return {}
	if old.get("recruitment",{}).get("version",114)!=114:return {}
	if not validate_v115_space(old,ghost):return {}
	var next=old.duplicate(true);next.catalogue_hash=C.catalogue_hash
	if not (inventory.validate_ghost(next) if ghost else inventory.validate_run(next)):return {}
	if not next.has("simulation_version"):next.simulation_version="resonance-v114"
	if not ghost and not has_completed_combat(old):next.simulation_version=preload("res://scripts/party/recruitment.gd").simulation_version(next)
	if not ghost and next.get("opponent",{}).get("catalogue_hash","")==C.v114_hash:
		next.opponent=migrate_v115(next.opponent,true)
		if next.opponent.is_empty():return {}
	return next

# V115 already had unlimited stash and open recruitment; only its geometry is
# frozen here. Setting accepted_catalogue_hash would enable the pre-V103 limit.
func validate_v115_space(old:Dictionary,ghost:bool)->bool:
	if not valid_pre_v129_content(old):return false
	var previous=I.new();previous.footprint_catalogue=C.v115_space.items
	var checked=old.duplicate(true);checked.catalogue_hash=C.catalogue_hash
	return previous.validate_ghost(checked) if ghost else previous.validate_run(checked)

func has_completed_combat(run:Dictionary)->bool:
	return run.get("phase","")=="ending" or (run.get("phase","") in ["battle","result"] and run.has("combat"))

# Exact published V115 input only: validate old footprints before shrinking.
# Inventory, coordinates and earned recordings stay byte-equivalent JSON values.
func migrate_v116(old:Variant,ghost:bool=false)->Dictionary:
	if not old is Dictionary or old.get("catalogue_hash","")!=C.v115_hash:return {}
	var previous_version=str(old.get("simulation_version","resonance-v113" if old.get("recruitment_legacy",false) else "resonance-v114" if old.get("recruitment",{}).get("version",0)==114 else "resonance-v115"))
	if previous_version not in ["resonance-v60","resonance-v75","resonance-v83","resonance-v86","resonance-v87","resonance-v88","resonance-v92","resonance-v93","resonance-v101","resonance-v112","resonance-v113","resonance-v114","resonance-v115"]:return {}
	if not validate_v115_space(old,ghost):return {}
	var next=old.duplicate(true);next.catalogue_hash=C.catalogue_hash
	next.simulation_version=previous_version if ghost or has_completed_combat(old) else preload("res://scripts/party/recruitment.gd").simulation_version(next)
	if not ghost and next.get("opponent",{}).get("catalogue_hash","")==C.v115_hash:
		next.opponent=migrate_v116(next.opponent,true)
		if next.opponent.is_empty():return {}
	return next if (inventory.validate_ghost(next) if ghost else inventory.validate_run(next)) else {}

# History files live beside, never inside, the active run. Loading a replay does
# not call resume(), migrate(), matchmaking or simulate().
func migrate_v124(old:Variant,ghost:bool=false)->Dictionary:
	if not old is Dictionary or old.get("catalogue_hash","")!=C.v116_hash:return {}
	if not valid_pre_v129_content(old):return {}
	var version=str(old.get("simulation_version","resonance-v116"))
	if version not in ["resonance-v60","resonance-v75","resonance-v83","resonance-v86","resonance-v87","resonance-v88","resonance-v92","resonance-v93","resonance-v101","resonance-v112","resonance-v113","resonance-v114","resonance-v115","resonance-v116","resonance-v116-crew113","resonance-v116-crew114"]:return {}
	# V124 does not change footprints or ownership limits. Validate a detached
	# hash projection with the same geometry; never mutate the original save.
	var next=old.duplicate(true);next.catalogue_hash=C.catalogue_hash
	if not (inventory.validate_ghost(next) if ghost else inventory.validate_run(next)):return {}
	next.simulation_version=version if ghost or has_completed_combat(old) else preload("res://scripts/party/recruitment.gd").simulation_version(next)
	if not ghost and next.get("opponent",{}).get("catalogue_hash","")==C.v116_hash:
		next.opponent=migrate_v124(next.opponent,true)
		if next.opponent.is_empty():return {}
	return next

func archive_completed(run:Dictionary)->bool:
	return preload("res://scripts/storage/battle_archive.gd").new(root_path).remember(run)
func battle_reference(run:Dictionary)->String:
	return preload("res://scripts/storage/battle_archive.gd").identifier(run)
func battle_history(current:Dictionary={})->Array:
	var archive=preload("res://scripts/storage/battle_archive.gd").new(root_path)
	var rows=archive.entries()
	for old in current.get("history",[]):
		var build=old.get("build",{});var kinds=build.get("items",[]).map(func(i):return i.kind)
		# Equal item kinds do not establish battle identity across different runs.
		var id=archive.identifier(current) if archive.is_current_result(old,current) else archive.summary_id(old)
		if rows.any(func(r):return r.id==id):continue
		rows.append({"id":"","round":old.get("round",0),"winner":old.get("winner",0),"duration":old.get("duration",0),"leaders":[build.get("leader",current.get("leader","")),""],"items":[kinds,[]],"replayable":false,"time":0})
	return rows
func battle_record(id:String)->Dictionary:
	return preload("res://scripts/storage/battle_archive.gd").new(root_path).read(id)

func migrate_v125(old:Variant,ghost:bool=false)->Dictionary:
	if not old is Dictionary or old.get("catalogue_hash","")!=C.v124_hash:return {}
	if not valid_pre_v129_content(old):return {}
	var version=str(old.get("simulation_version","resonance-v124"))
	if version not in ["resonance-v60", "resonance-v75", "resonance-v83", "resonance-v86", "resonance-v87", "resonance-v88", "resonance-v92", "resonance-v93", "resonance-v101", "resonance-v112", "resonance-v113", "resonance-v114", "resonance-v115", "resonance-v116", "resonance-v124", "resonance-v116-crew113", "resonance-v116-crew114", "resonance-v124-crew113", "resonance-v124-crew114"]:return {}
	var next=old.duplicate(true);next.catalogue_hash=C.catalogue_hash
	if not (inventory.validate_ghost(next) if ghost else inventory.validate_run(next)):return {}
	next.simulation_version=version if ghost or has_completed_combat(old) else preload("res://scripts/party/recruitment.gd").simulation_version(next)
	if not ghost and next.get("opponent",{}).get("catalogue_hash","")==C.v124_hash:
		next.opponent=migrate_v125(next.opponent,true)
		if next.opponent.is_empty():return {}
	return next

func migrate_v127(old:Variant,ghost:bool=false)->Dictionary:
	if not old is Dictionary or old.get("catalogue_hash","")!=C.v125_hash:return {}
	if not valid_pre_v129_content(old):return {}
	var version=str(old.get("simulation_version","resonance-v125"))
	var previous_versions=["resonance-v60","resonance-v75","resonance-v83","resonance-v86","resonance-v87","resonance-v88","resonance-v92","resonance-v93","resonance-v101","resonance-v112","resonance-v113","resonance-v114","resonance-v115","resonance-v116","resonance-v124","resonance-v125"]
	if version.trim_suffix("-crew113").trim_suffix("-crew114") not in previous_versions:return {}
	# An exact historical hash cannot legitimize newly introduced item IDs.
	for collection in I.OWNED_COLLECTIONS+['bags','shop']:
		for piece in old.get(collection,[]):
			if piece is Dictionary and piece.get('kind','') not in C.v125_item_ids:return {}
	var next=old.duplicate(true);next.catalogue_hash=C.catalogue_hash
	if not (inventory.validate_ghost(next) if ghost else inventory.validate_run(next)):return {}
	# Frozen combat and its historical version survive verbatim. Only future
	# battles use the current engine; ongoing runs keep their procurement policy.
	next.simulation_version=version if ghost or has_completed_combat(old) else preload('res://scripts/party/recruitment.gd').simulation_version(next)
	if not ghost and next.get('opponent',{}).get('catalogue_hash','')==C.v125_hash:
		next.opponent=migrate_v127(next.opponent,true)
		if next.opponent.is_empty():return {}
	return next

func migrate_v128(old:Variant,ghost:bool=false)->Dictionary:
	if not old is Dictionary or old.get('catalogue_hash','')!=C.v127_hash:return {}
	if not inventory.bounded_integer(old.get('supply_version',0),0,127) or int(old.get('supply_version',0)) not in [0,122,125,127]:return {}
	var version=str(old.get('simulation_version','resonance-v127'))
	var previous_versions=['resonance-v60','resonance-v75','resonance-v83','resonance-v86','resonance-v87','resonance-v88','resonance-v92','resonance-v93','resonance-v101','resonance-v112','resonance-v113','resonance-v114','resonance-v115','resonance-v116','resonance-v124','resonance-v125','resonance-v127']
	if version.trim_suffix('-crew113').trim_suffix('-crew114') not in previous_versions:return {}
	# Validate historical identities against the pre-overlay snapshot, independently
	# of supply introduction versions (old objects may have re-entered the shop).
	for collection in I.OWNED_COLLECTIONS+['bags','shop']:
		if not old.get(collection,[]) is Array:return {}
		for piece in old.get(collection,[]):
			if piece is Dictionary and not piece.is_empty() and piece.get('kind','') not in C.v127_item_ids:return {}
	var next=old.duplicate(true);next.catalogue_hash=C.catalogue_hash
	if not (inventory.validate_ghost(next) if ghost else inventory.validate_run(next)):return {}
	next.simulation_version=version if ghost or has_completed_combat(old) else preload('res://scripts/party/recruitment.gd').simulation_version(next)
	if not ghost and next.get('opponent',{}).get('catalogue_hash','')==C.v127_hash:
		next.opponent=migrate_v128(next.opponent,true)
		if next.opponent.is_empty():return {}
	return next

# The new pocket IDs cannot be made historical by replacing their catalogue hash.
# Earlier migrations keep their stricter per-release ID and shape checks as well.
func valid_pre_v129_content(old:Dictionary)->bool:
	if not inventory.bounded_integer(old.get('supply_version',0),0,128) or int(old.get('supply_version',0)) not in [0,122,125,127,128]:return false
	for collection in I.OWNED_COLLECTIONS+['shop']:
		if not old.get(collection,[]) is Array:return false
		for piece in old.get(collection,[]):
			if piece is Dictionary and not piece.is_empty() and piece.get('kind','') not in C.v128_item_ids:return false
	return true

func migrate_v129(old:Variant,ghost:bool=false)->Dictionary:
	if not old is Dictionary or old.get('catalogue_hash','')!=C.v128_hash or not valid_pre_v129_content(old):return {}
	var version=str(old.get('simulation_version','resonance-v128'))
	var previous_versions=['resonance-v60','resonance-v75','resonance-v83','resonance-v86','resonance-v87','resonance-v88','resonance-v92','resonance-v93','resonance-v101','resonance-v112','resonance-v113','resonance-v114','resonance-v115','resonance-v116','resonance-v124','resonance-v125','resonance-v127','resonance-v128']
	if version.trim_suffix('-crew113').trim_suffix('-crew114') not in previous_versions:return {}
	var next=old.duplicate(true);next.catalogue_hash=C.catalogue_hash
	if not (inventory.validate_ghost(next) if ghost else inventory.validate_run(next)):return {}
	next.simulation_version=version if ghost or has_completed_combat(old) else preload('res://scripts/party/recruitment.gd').simulation_version(next)
	if not ghost and next.get('opponent',{}).get('catalogue_hash','')==C.v128_hash:
		next.opponent=migrate_v129(next.opponent,true)
		if next.opponent.is_empty():return {}
	return next

func abandon_run(expected:Dictionary)->bool:
	# Ending a run is explicit; unknown/corrupt or changed disk state is preserved.
	if expected.is_empty() or not inventory.validate_run(expected):return false
	var path=root_path+"run.json"
	if not FileAccess.file_exists(path):return false
	var old=read_json(path,null)
	if not old is Dictionary:return false
	var compared=old.duplicate(true)
	if compared.get("phase","")=="battle" and expected.get("phase","")=="result":compared.phase="result"
	if compared!=JSON.parse_string(JSON.stringify(expected)):return false
	if not backup_run(root_path+"run-abandoned.json"):return false
	if DirAccess.remove_absolute(path)!=OK:return false
	resume_status="missing"
	return true
