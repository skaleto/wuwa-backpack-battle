extends SceneTree
## Fake OSS listing/object transport only: no HTTP, disk profiles, or cloud access.
const INV=preload("res://scripts/inventory/inventory.gd")
const PROTOCOL=preload("res://scripts/online/async_pvp.gd")

class PoolFixture:
	extends "res://scripts/online/async_pool_client.gd"
	var entries:Array=[]
	var payloads:Dictionary={}
	var calls:Array=[]
	var lists=0
	var downloads=0
	var force_empty_tail=false
	var delayed=false
	func _read(body:Dictionary,deadline:int,_limit:int)->Dictionary:
		calls.append({"body":body.duplicate(true),"deadline":deadline,"at":Time.get_ticks_msec()})
		if body.has("key"):
			downloads+=1
			return {"ok":true,"status":200,"body":payloads.get(body.key,"corrupt snapshot".to_utf8_buffer())}
		lists+=1
		if delayed:
			# Model a transport whose response arrives at its supplied deadline.
			while Time.get_ticks_msec()<deadline:await get_tree().process_frame
			return {"ok":false,"status":0}
		var prefix=P.round_prefix(body.pool_id,int(body.round))
		if body.has("wins"):prefix+="wins/%02d/"%int(body.wins)
		var selected=entries.filter(func(row):return str(row.key).begins_with(prefix))
		selected.sort_custom(func(a,b):return str(a.key)<str(b.key))
		var offset=0
		if body.has("continuation"):
			offset=int(body.continuation)
		elif body.has("start_after"):
			# Explicitly exercise an empty suffix followed by a wrap-around request.
			if force_empty_tail:selected=[]
			else:selected=selected.filter(func(row):return str(row.key)>str(body.start_after))
		var page=selected.slice(offset,mini(offset+100,selected.size()))
		var more=offset+100<selected.size()
		var xml="<ListBucketResult><IsTruncated>"+("true" if more else "false")+"</IsTruncated>"
		if more:xml+="<NextContinuationToken>"+str(offset+100)+"</NextContinuationToken>"
		for row in page:xml+="<Contents><Key>"+str(row.key)+"</Key><Size>"+str(row.size)+"</Size></Contents>"
		return {"ok":true,"status":200,"body":(xml+"</ListBucketResult>").to_utf8_buffer()}

var checks=0
var failures=0
var inventory=INV.new()

func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)

func _initialize()->void:call_deferred("test")

func run_at(round_number:int,wins:int)->Dictionary:
	var run=inventory.new_run("aemeath",19)
	run.round=round_number;run.wins=wins;run.losses=round_number-1-wins
	run.pvp={"recent":[]}
	return run

func fixture():
	var client=PoolFixture.new();root.add_child(client)
	client.config={"url":"http://127.0.0.1:1","player_id":"f".repeat(32),"token":"synthetic-test-only"}
	return client

func add_valid(client,run:Dictionary,owner:String,run_id:String)->String:
	var packet=PROTOCOL.freeze(inventory,run,owner,run_id)
	ck(packet.ok,"fixture snapshot is valid")
	if not packet.ok:return ""
	var key=PROTOCOL.object_key(PROTOCOL.pool_id(run),int(run.round),int(run.wins),owner,run_id,packet.sha256)
	client.entries.append({"key":key,"size":packet.bytes.size()});client.payloads[key]=packet.bytes
	return key

func add_invalid(client,run:Dictionary,owner:String,run_id:String,wins:int)->void:
	var key=PROTOCOL.object_key(PROTOCOL.pool_id(run),int(run.round),wins,owner,run_id,"a".repeat(64))
	client.entries.append({"key":key,"size":16})

func listing_calls(client)->Array:return client.calls.filter(func(call):return not call.body.has("key"))

func test()->void:
	await test_large_pool_exact_wins_and_wrap()
	await test_nearest_bucket_order()
	await test_own_page_continuation()
	await test_corrupt_download_budget()
	await test_deadline()
	print("match sampling v138 ",checks," checks, failures ",failures)
	quit(1 if failures else 0)

func test_large_pool_exact_wins_and_wrap()->void:
	var client=fixture();client.force_empty_tail=true
	var run=run_at(3,1)
	# The legacy whole-round first-three-page scan sees only these 1,200 keys.
	for index in 1200:add_invalid(client,run,"%032x"%(index+1),"old-%04d"%index,0)
	var desired=add_valid(client,run,"a".repeat(32),"same-wins")
	var ordered=client.entries.map(func(row):return str(row.key));ordered.sort()
	ck(client.entries.size()>1000 and ordered.find(desired)>=1200,"same-wins fixture lies beyond legacy first 300 keys")
	var original=run.duplicate(true)
	seed(8128);var expected_random=randi();seed(8128)
	var result=await client.find_opponent(inventory,run)
	ck(randi()==expected_random,"sampling leaves global gameplay RNG untouched")
	ck(result.ok and result.opponent.get("pvp_key")==desired,"large pool reaches same-wins candidate beyond old scan limit")
	ck(run==original,"matching never mutates supplied live-run data")
	var listing=listing_calls(client)
	ck(listing.size()==2 and listing.all(func(call):return int(call.body.get("wins",-1))==1),"exact wins queried before all neighboring buckets")
	var prefix=PROTOCOL.round_prefix(PROTOCOL.pool_id(run),3)+"wins/01/"
	var cursor=str(listing[0].body.get("start_after",""))
	ck(cursor.begins_with(prefix) and cursor.length()==prefix.length()+32 and PROTOCOL.hex_hash(cursor.trim_prefix(prefix)+"a".repeat(32)),"first request uses a random 32-hex owner cursor within wins bucket")
	ck(not listing[1].body.has("start_after") and not listing[1].body.has("continuation"),"empty suffix wraps to beginning of exact bucket")
	ck(client.downloads==1,"valid same-wins result stops further object requests")
	client.queue_free()

func test_nearest_bucket_order()->void:
	var client=fixture();client.force_empty_tail=true
	var run=run_at(4,1)
	var neighbor=run.duplicate(true);neighbor.wins=0;neighbor.losses=3
	var desired=add_valid(client,neighbor,"b".repeat(32),"nearest")
	var result=await client.find_opponent(inventory,run)
	var listing=listing_calls(client)
	ck(result.ok and result.opponent.get("pvp_key")==desired,"empty exact bucket widens to nearest available wins")
	ck(listing.map(func(call):return int(call.body.wins))==[1,1,0,0],"bucket expansion follows exact then distance-one, with bounded wrap")
	client.queue_free()

func test_own_page_continuation()->void:
	var client=fixture();client.force_empty_tail=true
	client.config.player_id="0".repeat(32)
	var run=run_at(2,1)
	for index in 100:add_invalid(client,run,str(client.config.player_id),"own-%04d"%index,1)
	var desired=add_valid(client,run,"b".repeat(32),"after-own-page")
	var result=await client.find_opponent(inventory,run)
	var listing=listing_calls(client)
	ck(result.ok and result.opponent.get("pvp_key")==desired,"own-only first page does not hide next-page opponents")
	ck(listing.size()==3 and listing[2].body.get("continuation")=="100","own-only page continuation is forwarded unchanged")
	ck(not listing[2].body.has("start_after"),"continuation excludes start_after")
	ck(client.downloads==1,"own objects excluded without downloading their malformed payloads")
	client.queue_free()

func test_corrupt_download_budget()->void:
	var client=fixture();client.force_empty_tail=true
	var run=run_at(4,1)
	for wins in 4:
		for index in 4:add_invalid(client,run,"%032x"%(index+1),"corrupt-%d-%d"%[wins,index],wins)
	var result=await client.find_opponent(inventory,run)
	ck(not result.ok and result.error=="invalid_or_unavailable","malformed snapshots give explicit local fallback")
	ck(client.downloads==8 and client.lists<=8,"malformed pool respects eight-object and eight-list budgets")
	ck(client.calls.size()<=16,"logical ticket-plus-object reads stay bounded by combined limits")
	ck(client.calls.all(func(call):return call.deadline==client.calls[0].deadline),"all operations share a single matching deadline")
	client.queue_free()

func test_deadline()->void:
	var client=fixture();client.delayed=true
	var began=Time.get_ticks_msec()
	var result=await client.find_opponent(inventory,run_at(3,1))
	var elapsed=Time.get_ticks_msec()-began
	print("matching deadline elapsed_ms ",elapsed)
	ck(not result.ok and result.error=="network","deadline transport failure reports fallback")
	ck(client.calls.size()==1 and client.downloads==0,"timed-out list does not trigger later pages or downloads")
	ck(client.calls[0].deadline-began>=2990 and client.calls[0].deadline-began<=3050,"transport receives one three-second budget")
	ck(elapsed>=2900 and elapsed<3500,"match completes at deadline with bounded frame-scheduling tolerance")
	client.queue_free()
