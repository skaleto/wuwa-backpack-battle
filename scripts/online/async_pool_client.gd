extends Node
## Network and durable upload outbox. Never receives permission to mutate a run.
const P=preload("res://scripts/online/async_pvp.gd")
const DEFAULT_URL="https://skbaby.top/resonance-pvp/v1"
const IDENTITY=preload("res://scripts/online/device_identity.gd")
var identity=IDENTITY.new()
var automatic_identity=false
var identity_retry_at=0
var identity_failures=0
var config_error=false
const QUEUE_LIMIT=64
const QUEUE_AGE=7*86400
var files
var config:Dictionary={}
var outbox:Array=[]
var uploading=false
var active=false
var next_retry=0.0
var retry_count=0
var last_upload_error=""
func configure(store)->void:
	files=store
	var saved=files.read_json(files.root_path+"online.json",{})
	config=saved if saved is Dictionary else {}
	config_error=FileAccess.file_exists(files.root_path+"online.json") and (not saved is Dictionary or saved.is_empty())
	identity.configure(func():return config.duplicate(true),_save_config,_device_request)
	var queue=files.read_json(files.root_path+"upload-queue.json",[])
	outbox=queue if queue is Array else []
	outbox=outbox.filter(func(row):return row is Dictionary and row.get("body") is String and row.body.to_utf8_buffer().size()<=P.MAX_BYTES and row.get("created",0)>Time.get_unix_time_from_system()-QUEUE_AGE)
	if outbox.size()>QUEUE_LIMIT:outbox=outbox.slice(-QUEUE_LIMIT)
func valid_endpoint(url:String)->bool:
	return (url.begins_with("https://") or url.begins_with("http://127.0.0.1:") or url.begins_with("http://localhost:")) and not url.contains("@") and not url.contains("?") and not url.contains("#")
func ready_for_online()->bool:
	return valid_endpoint(str(config.get("url",""))) and P.safe_id(config.get("player_id","")) and config.get("token","") is String and not str(config.get("token","")).is_empty()
func _save_config(next:Dictionary)->bool:
	# Protect the directory BEFORE storage creates a credential-bearing .tmp file.
	if OS.get_name() in ["macOS","Linux","FreeBSD","NetBSD","OpenBSD"] and FileAccess.set_unix_permissions(ProjectSettings.globalize_path(files.root_path),448)!=OK:return false
	if not files.write_json(files.root_path+"online.json",next):return false
	if OS.get_name() in ["macOS","Linux","FreeBSD","NetBSD","OpenBSD"] and FileAccess.set_unix_permissions(ProjectSettings.globalize_path(files.root_path+"online.json"),384)!=OK:return false
	config=next;return true
func start_identity()->void:
	automatic_identity=true
	ensure_identity()
func ensure_identity()->Dictionary:
	if config_error:return {"ok":false,"error":"invalid_identity"}
	var url=str(config.get("url",DEFAULT_URL))
	if not valid_endpoint(url):return {"ok":false,"error":"configuration"}
	var result=await identity.ensure(url,Time.get_ticks_msec()+4000)
	identity_failures=0 if result.ok else mini(identity_failures+1,6)
	identity_retry_at=Time.get_ticks_msec()+int(5000*pow(2,identity_failures))
	return result
func _device_request(url:String,body:Dictionary,headers:PackedStringArray,deadline:int)->Dictionary:
	headers.append("Content-Type: application/json")
	var response=await _request(url,HTTPClient.METHOD_POST,JSON.stringify(body).to_utf8_buffer(),headers,deadline,16384)
	return {"ok":response.ok,"data":_json(response),"error":_reason(response)}
func activate(url:String,invite:String)->Dictionary:
	url=url.strip_edges().trim_suffix("/");invite=invite.strip_edges()
	if not valid_endpoint(url) or invite.is_empty():return {"ok":false,"error":"configuration"}
	var pending=config.get("activation",{})
	if not pending is Dictionary or pending.get("invite")!=invite or pending.get("url")!=url:pending={"url":url,"invite":invite,"request_id":P.random_id()+P.random_id()}
	var next=config.duplicate(true);next.activation=pending
	if not _save_config(next):return {"ok":false,"error":"save_failed"}
	var response=await _request(url+"/sessions",HTTPClient.METHOD_POST,JSON.stringify({"invite":invite,"request_id":pending.request_id}).to_utf8_buffer(),["Content-Type: application/json"],Time.get_ticks_msec()+8000,16384)
	var data=_json(response)
	if not response.ok or not P.safe_id(data.get("player_id")) or not data.get("token") is String:return {"ok":false,"error":_reason(response)}
	if not _save_config({"url":url,"player_id":data.player_id,"token":data.token}):return {"ok":false,"error":"save_failed"}
	return {"ok":true}
func _json(response:Dictionary)->Dictionary:
	var value=JSON.parse_string(response.get("body",PackedByteArray()).get_string_from_utf8())
	return value if value is Dictionary else {}
func _reason(response:Dictionary)->String:
	match int(response.get("status",0)):
		401:return "auth_expired"
		403:return "forbidden"
		409:return "conflict"
		429:return "rate_limit"
		503:return "unconfigured"
	return "network"
func _request(url:String,method:int,body:PackedByteArray,headers:PackedStringArray,deadline:int,limit:int)->Dictionary:
	var left=deadline-Time.get_ticks_msec()
	if left<=0:return {"ok":false,"status":0}
	# Private tickets are never logged; disallow redirects to another origin.
	if not valid_endpoint(url.split("?")[0]):return {"ok":false,"status":0}
	var request=HTTPRequest.new();request.timeout=maxf(.05,left/1000.0);request.body_size_limit=limit;request.max_redirects=0
	add_child(request)
	var error=request.request_raw(url,headers,method,body)
	if error!=OK:request.queue_free();return {"ok":false,"status":0}
	var result=await request.request_completed
	request.queue_free()
	return {"ok":result[0]==HTTPRequest.RESULT_SUCCESS and result[1]>=200 and result[1]<300,"status":int(result[1]),"body":result[3]}
func _api(path:String,body:Dictionary,deadline:int)->Dictionary:
	if not ready_for_online():return {"ok":false,"status":503}
	var response=await _request(str(config.url)+path,HTTPClient.METHOD_POST,JSON.stringify(body).to_utf8_buffer(),["Content-Type: application/json","Authorization: Bearer "+str(config.token)],deadline,16384)
	if response.status==401 and config.get("device",{}) is Dictionary and config.get("device",{}).get("bound",false) and deadline-Time.get_ticks_msec()>500:
		config.expires_at=0
		var renewed=await identity.ensure(str(config.url),deadline)
		if renewed.ok:return await _request(str(config.url)+path,HTTPClient.METHOD_POST,JSON.stringify(body).to_utf8_buffer(),["Content-Type: application/json","Authorization: Bearer "+str(config.token)],deadline,16384)
	return response
func _read(body:Dictionary,deadline:int,limit:int)->Dictionary:
	var ticket=await _api("/storage/read-ticket",body,deadline)
	if not ticket.ok:return ticket
	var data=_json(ticket)
	if not data.get("url") is String:return {"ok":false,"status":0}
	return await _request(data.url,HTTPClient.METHOD_GET,PackedByteArray(),[],deadline,limit)
func find_opponent(inv,run:Dictionary)->Dictionary:
	if not ready_for_online():return {"ok":false,"error":"unconfigured"}
	var deadline=Time.get_ticks_msec()+3000;var pool=P.pool_id(run);var round_number=int(run.round)
	# Sample an exact wins bucket before widening. A random lexicographic cursor
	# avoids permanently selecting only the first accounts in a large OSS prefix.
	var buckets=[]
	for distance in round_number:
		for value in [int(run.wins)-distance,int(run.wins)+distance]:
			if value>=0 and value<round_number and not value in buckets:buckets.append(value)
	var reads=0;var downloads=0;var saw_candidate=false
	for wins in buckets:
		if reads>=8 or Time.get_ticks_msec()>=deadline:break
		var prefix=P.PREFIX+pool+"/round/%02d/wins/%02d/"%[round_number,wins]
		var cursor=prefix+P.random_id()
		for wrap in 2:
			var continuation=""
			for page in 2:
				if reads>=8 or Time.get_ticks_msec()>=deadline:break
				var body={"pool_id":pool,"round":round_number,"wins":wins}
				if not continuation.is_empty():body.continuation=continuation
				elif wrap==0:body.start_after=cursor
				reads+=1
				var response=await _read(body,deadline,2*1024*1024)
				if not response.ok:return {"ok":false,"error":_reason(response)}
				var listing=P.parse_listing(response.body,pool,round_number)
				if not listing.ok:return {"ok":false,"error":"invalid_listing"}
				var ranked=P.rank(listing.entries,str(config.player_id),int(run.wins),run.pvp.get("recent",[]),int(run.seed)+round_number)
				for entry in ranked.slice(0,4):
					if downloads>=8:break
					downloads+=1;saw_candidate=true
					var object=await _read({"pool_id":pool,"round":round_number,"key":entry.key},deadline,P.MAX_BYTES)
					if not object.ok:continue
					var decoded=P.decode(inv,object.body,entry.key,pool,round_number)
					if decoded.ok:return {"ok":true,"opponent":decoded.build,"source":"player","reason":""}
				if listing.continuation.is_empty() or listing.continuation==continuation:break
				continuation=listing.continuation

	return {"ok":false,"error":"invalid_or_unavailable" if saw_candidate else "empty_pool"}

func enqueue(run:Dictionary)->bool:
	if not ready_for_online() or run.get("pvp",{}).get("player_id")!=config.player_id:return false
	var text=str(run.pvp.get("frozen",""));var bytes=text.to_utf8_buffer();var hash_value=P.digest(bytes)
	if bytes.is_empty() or bytes.size()>P.MAX_BYTES or hash_value!=run.pvp.get("sha256"):return false
	if outbox.any(func(row):return row.sha256==hash_value):return true
	var next=outbox.duplicate(true)
	next.append({"body":text,"sha256":hash_value,"created":int(Time.get_unix_time_from_system())})
	if next.size()>QUEUE_LIMIT:next.pop_front()
	if not files.write_json(files.root_path+"upload-queue.json",next):return false
	outbox=next;next_retry=0;return true
static func multipart(fields:Dictionary,bytes:PackedByteArray,boundary:String)->PackedByteArray:
	var result=PackedByteArray()
	for key in fields:
		if str(key).contains('"') or str(key).contains("\r") or str(key).contains("\n"):return PackedByteArray()
		result.append_array(("--"+boundary+"\r\nContent-Disposition: form-data; name=\""+str(key)+"\"\r\n\r\n"+str(fields[key])+"\r\n").to_utf8_buffer())
	result.append_array(("--"+boundary+"\r\nContent-Disposition: form-data; name=\"file\"; filename=\"snapshot.json\"\r\nContent-Type: application/json\r\n\r\n").to_utf8_buffer())
	result.append_array(bytes);result.append_array(("\r\n--"+boundary+"--\r\n").to_utf8_buffer());return result
func _process(_delta:float)->void:
	if automatic_identity and not identity.busy and Time.get_ticks_msec()>=identity_retry_at and (not ready_for_online() or float(config.get("expires_at",0))<=Time.get_unix_time_from_system()+30):ensure_identity()
	if active and not uploading and not outbox.is_empty() and ready_for_online() and Time.get_ticks_msec()>=next_retry:flush_one()
func flush_one()->bool:
	if uploading or outbox.is_empty() or not ready_for_online():return false
	if not _prune_queue() or outbox.is_empty():return false
	uploading=true
	var row=outbox[0].duplicate(true);var ok=await _upload(row)
	if ok:
		var next=outbox.filter(func(value):return value.sha256!=row.sha256)
		ok=files.write_json(files.root_path+"upload-queue.json",next)
		if ok:outbox=next;retry_count=0;last_upload_error=""
	if not ok:
		retry_count+=1
		# A revoked old rules pool or a frozen-key conflict must not starve newer rounds.
		if last_upload_error in ["retired_pool","conflict","identity"]:
			var remaining=outbox.filter(func(value):return value.sha256!=row.sha256)
			if files.write_json(files.root_path+"upload-queue.json",remaining):outbox=remaining
		elif outbox.size()>1:
			var rotated=outbox.duplicate(true);rotated.append(rotated.pop_front())
			if files.write_json(files.root_path+"upload-queue.json",rotated):outbox=rotated
	next_retry=Time.get_ticks_msec()+([1000,3000,10000,30000,60000][mini(retry_count,4)])
	uploading=false;return ok
func _prune_queue()->bool:
	var next=outbox.filter(func(row):
		var body=JSON.parse_string(str(row.get("body","")))
		return body is Dictionary and body.get("player_id")==config.get("player_id") and row.get("created",0)>Time.get_unix_time_from_system()-QUEUE_AGE)
	if next==outbox:return true
	if not files.write_json(files.root_path+"upload-queue.json",next):return false
	outbox=next;return true
func _upload(row:Dictionary)->bool:
	var body=JSON.parse_string(row.body)
	if not body is Dictionary or body.get("player_id")!=config.player_id:last_upload_error="identity";return false
	var bytes=str(row.body).to_utf8_buffer()
	var deadline=Time.get_ticks_msec()+10000
	var args={"pool_id":body.pool_id,"round":int(body.round),"wins":int(body.wins),"losses":int(body.losses),"run_id":body.run_id,"sha256":row.sha256,"size":bytes.size()}
	var ticket=await _api("/storage/upload-ticket",args,deadline)
	if not ticket.ok:last_upload_error="retired_pool" if ticket.status==400 else _reason(ticket);return false
	var data=_json(ticket);var key=P.object_key(body.pool_id,int(body.round),int(body.wins),body.player_id,body.run_id,row.sha256)
	if data.get("key")!=key or not data.get("url") is String or not data.get("fields") is Dictionary:last_upload_error="invalid_ticket";return false
	var boundary="pvp"+P.random_id()
	var response=await _request(data.url,HTTPClient.METHOD_POST,multipart(data.fields,bytes,boundary),["Content-Type: multipart/form-data; boundary="+boundary],deadline,16384)
	if response.ok:return true
	if response.status==409:
		# A lost success response is safe only if the existing exact bytes match.
		var existing=await _read({"pool_id":body.pool_id,"round":int(body.round),"key":key},deadline,P.MAX_BYTES)
		if not existing.ok:last_upload_error=_reason(existing);return false
		if existing.ok and P.digest(existing.body)==row.sha256:return true
	last_upload_error=_reason(response);return false
