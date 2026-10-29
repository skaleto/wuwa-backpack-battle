extends RefCounted
## Wire protocol and pure matchmaking. No network, UI, storage or live-run writes.
const C=preload("res://scripts/data/catalog.gd")
const R=preload("res://scripts/party/recruitment.gd")
const MAX_BYTES=262144
const PREFIX="test/pools/"
static func active(run:Dictionary)->bool:return run.get("mode","")=="async"
static func pool_id(run:Dictionary)->String:
	var parts=[C.RULESET,C.catalogue_hash,R.simulation_version(run),int(run.get("supply_version",0)),str(run.get("pool_mode","full")),int(run.get("recruitment",{}).get("version",0))]
	return JSON.stringify(parts).sha256_text()
static func digest(bytes:PackedByteArray)->String:
	var context=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(bytes);return context.finish().hex_encode()
static func safe_id(value:Variant,max_length:int=80)->bool:
	if not value is String or value.is_empty() or value.length()>max_length:return false
	for c in value:
		if c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-":return false
	return true
static func hex_hash(value:Variant)->bool:
	if not value is String or value.length()!=64:return false
	for c in value:
		if c not in "0123456789abcdef":return false
	return true
static func random_id()->String:return Crypto.new().generate_random_bytes(16).hex_encode()
static func matches_frozen(inv,run:Dictionary)->bool:
	var state=run.get("pvp",{});var body=str(state.get("frozen",""));var bytes=body.to_utf8_buffer()
	if bytes.is_empty() or bytes.size()>MAX_BYTES or digest(bytes)!=state.get("sha256"):return false
	var value=JSON.parse_string(body)
	if not value is Dictionary or value.get("pool_id")!=pool_id(run) or value.get("player_id")!=state.get("player_id") or value.get("run_id")!=state.get("run_id"):return false
	# JSON normalization removes harmless StringName / integer representation changes.
	return value.get("build")==JSON.parse_string(JSON.stringify(inv.snapshot(run,str(state.player_id))))
static func round_prefix(pool:String,round_number:int)->String:return PREFIX+pool+"/round/%02d/"%round_number
static func object_key(pool:String,round_number:int,wins:int,owner:String,run_id:String,hash_value:String)->String:
	return round_prefix(pool,round_number)+"wins/%02d/"%wins+owner+"/"+run_id+"-"+hash_value+".json"
static func freeze(inv,run:Dictionary,player_id:String,run_id:String)->Dictionary:
	if not safe_id(player_id) or not safe_id(run_id) or not inv.validate_run(run):return {"ok":false,"error":"snapshot"}
	var build=inv.snapshot(run,player_id)
	var envelope={"schema":1,"pool_id":pool_id(run),"player_id":player_id,"run_id":run_id,"round":int(run.round),"wins":int(run.wins),"losses":int(run.losses),"build":build}
	var bytes=JSON.stringify(envelope).to_utf8_buffer()
	if bytes.size()>MAX_BYTES or envelope.wins+envelope.losses!=envelope.round-1:return {"ok":false,"error":"snapshot"}
	return {"ok":true,"bytes":bytes,"sha256":digest(bytes),"envelope":envelope}
static func key_metadata(key:String,pool:String,round_number:int)->Dictionary:
	var prefix=round_prefix(pool,round_number)
	if not key.begins_with(prefix):return {}
	var parts=key.trim_prefix(prefix).split("/")
	if parts.size()!=4 or parts[0]!="wins" or parts[1].length()!=2 or not parts[1].is_valid_int() or not safe_id(parts[2]):return {}
	var wins=int(parts[1]);var file=str(parts[3])
	if wins<0 or wins>=round_number or not file.ends_with(".json") or file.length()<71:return {}
	var stem=file.trim_suffix(".json");var hash_value=stem.right(64)
	var run_id=stem.left(stem.length()-65)
	if not hex_hash(hash_value) or not safe_id(run_id) or stem.substr(stem.length()-65,1)!="-":return {}
	return {"key":key,"player_id":str(parts[2]),"wins":wins,"run_id":run_id,"sha256":hash_value}
static func _shape_safe(build:Variant,inv)->bool:
	if not build is Dictionary:return false
	for name in ["leader","owner","name","ruleset","catalogue_hash","simulation_version","pool_mode","primary"]:
		if not build.get(name) is String or build[name].length()>160:return false
	for name in ["round","version","supply_version"]:
		if not inv.bounded_integer(build.get(name),0,1000):return false
	for name in ["roster","supports","relay"]:
		if not build.get(name) is Array or build[name].size()>12:return false
		for value in build[name]:
			if not value is String:return false
	if not build.get("recruitment") is Dictionary:return false
	var template=R.initial()
	for name in template:
		var value=build.recruitment.get(name)
		if template[name] is int:
			if not inv.bounded_integer(value,0,1000):return false
		elif typeof(value)!=typeof(template[name]):return false
	if int(build.recruitment.version)!=int(template.version):return false
	for name in ["items","bags"]:
		if not build.get(name) is Array or build[name].size()>inv.MAX_CAPACITY:return false
		for piece in build[name]:
			if not piece is Dictionary or not piece.get("kind") is String or not piece.get("uid") is String:return false
			for field in ["x","y","rotation","level"]:
				if not inv.bounded_integer(piece.get(field),0,1000):return false
	for field in ["stash","pending_gifts","pending_rearrange"]:
		if build.has(field):return false
	return true
static func decode(inv,bytes:PackedByteArray,key:String,pool:String,round_number:int)->Dictionary:
	var fail={"ok":false,"error":"invalid_snapshot"}
	if bytes.size()==0 or bytes.size()>MAX_BYTES:return fail
	var metadata=key_metadata(key,pool,round_number)
	if metadata.is_empty() or digest(bytes)!=metadata.sha256:return fail
	var raw=JSON.parse_string(bytes.get_string_from_utf8())
	if not raw is Dictionary or raw.get("schema")!=1 or raw.get("pool_id")!=pool:return fail
	if raw.get("player_id")!=metadata.player_id or raw.get("run_id")!=metadata.run_id:return fail
	if not inv.bounded_integer(raw.get("round"),1,inv.PROGRESSION.MAX_ROUNDS) or int(raw.round)!=round_number:return fail
	if not inv.bounded_integer(raw.get("wins"),0,round_number-1) or not inv.bounded_integer(raw.get("losses"),0,round_number-1):return fail
	if int(raw.wins)!=metadata.wins or int(raw.wins)+int(raw.losses)!=round_number-1:return fail
	if not _shape_safe(raw.get("build"),inv):return fail
	var build:Dictionary=raw.build
	if build.owner!=raw.player_id or int(build.round)!=round_number or pool_id(build)!=pool or build.simulation_version!=R.simulation_version(build):return fail
	if not inv.validate_ghost(build) or build.get("inactive",false):return fail
	var clean=inv.snapshot(build,str(raw.player_id),str(build.name))
	clean.source="player";clean.pvp_key=key
	return {"ok":true,"build":clean,"metadata":metadata}
static func rank(entries:Array,owner:String,wins:int,recent:Array,seed_value:int)->Array:
	var rng=RandomNumberGenerator.new();rng.seed=seed_value
	var scored=[]
	for entry in entries:
		if entry.get("player_id","")==owner:continue
		var row=entry.duplicate(true);row._distance=absi(int(row.wins)-wins);row._recent=1 if row.player_id in recent else 0;row._random=rng.randf();scored.append(row)
	scored.sort_custom(func(a,b):return a._distance<b._distance if a._distance!=b._distance else a._recent<b._recent if a._recent!=b._recent else a._random<b._random)
	var seen={};var result=[]
	for row in scored:
		if seen.has(row.player_id):continue
		seen[row.player_id]=true;row.erase("_distance");row.erase("_recent");row.erase("_random");result.append(row)
	return result
static func parse_listing(bytes:PackedByteArray,pool:String,round_number:int)->Dictionary:
	var bad={"ok":false,"entries":[],"continuation":""}
	if bytes.size()==0 or bytes.size()>2*1024*1024:return bad
	var parser=XMLParser.new()
	if parser.open_buffer(bytes)!=OK:return bad
	var entries=[];var rows=[];var field="";var row={};var continuation="";var root_seen=false;var root_closed=false;var encoded=false;var truncated=false
	while true:
		var error=parser.read()
		if error==ERR_FILE_EOF:break
		if error!=OK:return bad
		if parser.get_node_type()==XMLParser.NODE_ELEMENT:
			field=parser.get_node_name()
			if field=="ListBucketResult":root_seen=true
			if field=="Contents":row={}
		elif parser.get_node_type()==XMLParser.NODE_TEXT:
			if field=="Key":row.key=parser.get_node_data()
			elif field=="Size":row.size=int(parser.get_node_data())
			elif field=="NextContinuationToken":continuation=parser.get_node_data()
			elif field=="EncodingType":encoded=parser.get_node_data()=="url"
			elif field=="IsTruncated":truncated=parser.get_node_data()=="true"
		elif parser.get_node_type()==XMLParser.NODE_ELEMENT_END:
			if parser.get_node_name()=="ListBucketResult":root_closed=true
			if parser.get_node_name()=="Contents" and row.get("size",MAX_BYTES+1)>0 and row.get("size",MAX_BYTES+1)<=MAX_BYTES:rows.append(row)
			field=""
	if not root_seen or not root_closed or (truncated and continuation.is_empty()):return bad
	for value in rows:
		var key=str(value.get("key",""));var entry=key_metadata(key.uri_decode() if encoded else key,pool,round_number)
		if not entry.is_empty():entries.append(entry)
	return {"ok":true,"entries":entries,"continuation":continuation}
