extends RefCounted
## Frozen local evidence, separate from live run persistence and simulation.
const REVIEW=preload('res://scripts/battle/battle_review.gd')
const C=preload('res://scripts/data/catalog.gd')
var directory:String
func _init(root_path:String):
	directory=root_path.path_join('battles')+'/'
static func participant(run:Dictionary)->Dictionary:
	var result={}
	for key in ['seed','leader','round','wins','losses','gold','items','bags','supports','recruitment','recruitment_legacy','simulation_version','pool_mode','supply_version','primary','relay']:
		if run.has(key):result[key]=run[key]
	if run.get('mode','')=='async':
		result.mode='async';result.pvp_source=run.get('pvp',{}).get('source','');result.pvp_reason=run.get('pvp',{}).get('reason','')
	return result.duplicate(true)
static func valid(record:Dictionary)->bool:
	if record.get('version',0)!=1 or not record.get('combat',null) is Dictionary or not record.get('builds',null) is Array or record.builds.size()!=2:return false
	if not record.combat.get('frames',null) is Array or not record.combat.get('events',null) is Array or not record.combat.get('duration',null) is float and not record.combat.get('duration',null) is int:return false
	if not REVIEW.available(record.combat):return false
	for entry in record.combat.frames+record.combat.events:
		if not entry is Dictionary or not entry.get('time',null) is float and not entry.get('time',null) is int:return false
	for build in record.builds:
		if not build is Dictionary or not C.characters.has(build.get('leader','')) or not build.get('items',null) is Array or not build.get('bags',null) is Array:return false
		for item in build.items+build.bags:
			if not item is Dictionary or not C.items.has(item.get('kind','')) or not item.has('uid'):return false
	return true
static func valid_id(id:String)->bool:
	if id.length()!=64:return false
	for c in id:
		if c not in '0123456789abcdef':return false
	return true
static func digest(bytes:PackedByteArray)->String:
	var hash_context=HashingContext.new();hash_context.start(HashingContext.HASH_SHA256);hash_context.update(bytes)
	return hash_context.finish().hex_encode()
static func frozen_record(run:Dictionary)->Dictionary:
	return {'version':1,'combat':run.get('combat',{}),'builds':[participant(run),participant(run.get('opponent',{}))]}
static func identifier(run:Dictionary)->String:
	var record=frozen_record(run)
	return record_id(record) if valid(record) else ''
static func record_id(record:Dictionary)->String:
	# Battle identity uses seeded combatants, not transient float residue in frames.
	# Normalize JSON number types so a resumed run has the same identity.
	var builds=record.builds.duplicate(true)
	# Keep HUD counters in the payload, but settlement must not change identity.
	for build in builds:
		for counter in ['wins','losses','gold']:build.erase(counter)
	var key={'builds':JSON.parse_string(JSON.stringify(builds)),'winner':int(record.combat.get('winner',0)),'duration_ms':roundi(float(record.combat.duration)*1000),'event_count':record.combat.events.size()}
	return JSON.stringify(key).sha256_text()
static func summary_id(old:Dictionary)->String:
	return str(old.replay_id) if old.has('replay_id') else JSON.stringify({'legacy':old}).sha256_text()
static func is_current_result(old:Dictionary,run:Dictionary)->bool:
	var combat:Dictionary=run.get('combat',{});var build:Dictionary=old.get('build',{})
	return run.get('phase','') in ['result','ending'] and old.get('round',-1)==run.get('round',0) and build.get('leader','')==run.get('leader','?') and old.get('winner',2)==combat.get('winner',3) and old.get('duration',-1)==combat.get('duration',-2) and old.get('totals',{})==combat.get('totals',null) and build.get('items',[])==run.get('items',null) and build.get('bags',[])==run.get('bags',null)
func _remember_summary(old:Dictionary)->bool:
	if old.has('replay_id'):return true
	var build:Dictionary=old.get('build',{})
	if not C.characters.has(build.get('leader','')):return true
	var row={'id':summary_id(old),'legacy':true,'time':0,'round':old.get('round',0),'winner':old.get('winner',0),'duration':old.get('duration',0),'leaders':[build.leader,''],'items':[build.get('items',[]).map(func(i):return i.kind),[]]}
	return _write_summary(row)
func remember(run:Dictionary)->bool:
	for old in run.get('history',[]):
		if not is_current_result(old,run) and not _remember_summary(old):return false
	# No simulation is invented for old summaries or unfinished battles.
	if run.get('phase','') not in ['result','ending'] or not REVIEW.available(run.get('combat',{})):return true
	var record=frozen_record(run)
	if not valid(record):return false
	# Variant bytes preserve exact floating-point replay frames; JSON round-trips
	# can change a value by an ULP even with full_precision enabled.
	# Stable ID survives JSON run reload; independent checksum protects the exact
	# binary payload. A loaded ending never overwrites the original full precision.
	var body=var_to_bytes(record);var id=record_id(record)
	if not read(id).is_empty():return _ensure_summary(id,record)
	if not _prepare_directory():return false
	var path=directory+id+'.rpl'
	var file=FileAccess.open_compressed(path+'.tmp',FileAccess.WRITE,FileAccess.COMPRESSION_GZIP)
	if file==null:return false
	file.store_line(digest(body));file.store_buffer(body);var ok=file.get_error()==OK;file.close()
	if not ok or DirAccess.rename_absolute(path+'.tmp',path)!=OK:return false
	return _ensure_summary(id,record)
func _ensure_summary(id:String,record:Dictionary)->bool:
	var summary={'id':id,'time':int(Time.get_unix_time_from_system()),'round':int(record.builds[0].get('round',1)),
		'winner':int(record.combat.get('winner',0)),'duration':float(record.combat.get('duration',0)),
		'leaders':[record.builds[0].leader,record.builds[1].leader],
		'items':[record.builds[0].items.map(func(i):return i.kind),record.builds[1].items.map(func(i):return i.kind)]}
	if record.builds[0].get('mode','')=='async':summary.pvp_source=record.builds[0].get('pvp_source','')
	return _write_summary(summary)
func _prepare_directory()->bool:
	if FileAccess.file_exists(directory.trim_suffix('/')) or FileAccess.file_exists(directory.trim_suffix('/').get_base_dir()):return false
	return DirAccess.make_dir_recursive_absolute(directory)==OK
func _write_summary(summary:Dictionary)->bool:
	if not _prepare_directory():return false
	var path=directory+str(summary.id)+'.json'
	if FileAccess.file_exists(path):
		var prior=JSON.parse_string(FileAccess.get_file_as_string(path))
		if valid_summary(prior,str(summary.id)):return true
	var file=FileAccess.open(path+'.tmp',FileAccess.WRITE)
	if file==null:return false
	file.store_string(JSON.stringify(summary));var ok=file.get_error()==OK;file.close()
	return ok and DirAccess.rename_absolute(path+'.tmp',path)==OK
static func valid_summary(row:Variant,id:String)->bool:
	if not row is Dictionary or row.get('id','')!=id or not row.get('leaders',null) is Array or row.leaders.size()!=2:return false
	for key in ['round','winner','duration','time']:
		if not row.get(key,null) is float and not row.get(key,null) is int:return false
	if not row.get('items',null) is Array or row.items.size()!=2 or not row.items[0] is Array or not row.items[1] is Array:return false
	return C.characters.has(row.leaders[0]) and (C.characters.has(row.leaders[1]) or (row.get('legacy',false) and row.leaders[1]==''))
func entries()->Array:
	var out=[];var dir=DirAccess.open(directory)
	if dir==null:return out
	for filename in dir.get_files():
		if not filename.ends_with('.json') or not valid_id(filename.trim_suffix('.json')):continue
		var row=JSON.parse_string(FileAccess.get_file_as_string(directory+filename))
		if not valid_summary(row,filename.trim_suffix('.json')):continue
		row.replayable=FileAccess.file_exists(directory+row.id+'.rpl');out.append(row)
	out.sort_custom(func(a,b):return int(a.get('time',0))>int(b.get('time',0)) if a.get('time',0)!=b.get('time',0) else int(a.get('round',0))>int(b.get('round',0)))
	return out
func read(id:String)->Dictionary:
	if not valid_id(id):return {}
	var path=directory+id+'.rpl'
	if not FileAccess.file_exists(path):return {}
	var raw=FileAccess.open(path,FileAccess.READ)
	if raw==null or raw.get_length()<12:return {}
	raw.close()
	var file=FileAccess.open_compressed(path,FileAccess.READ,FileAccess.COMPRESSION_GZIP)
	if file==null:return {}
	var checksum=file.get_line();var body=file.get_buffer(file.get_length()-file.get_position());file.close()
	if digest(body)!=checksum:return {}
	# bytes_to_var does not allow encoded Object construction.
	var record=bytes_to_var(body)
	return record if record is Dictionary and valid(record) and record_id(record)==id else {}
