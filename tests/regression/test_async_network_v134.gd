extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const S=preload("res://scripts/storage/storage.gd")
const P=preload("res://scripts/online/async_pvp.gd")
var failures=0
var checks=0
func ck(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():call_deferred("test")
func test():
	if not FileAccess.file_exists("res://scripts/online/async_pool_client.gd"):
		ck(false,"network adapter exists");quit(1);return
	var n=load("res://scripts/online/async_pool_client.gd").new();root.add_child(n)
	var files=S.new("user://qa-v134-network-"+P.random_id()+"/");n.configure(files)
	ck(not n.ready_for_online(),"no config is explicit")
	ck(not n.valid_endpoint("http://example.com") and n.valid_endpoint("https://example.com/pvp/v1"),"production requires TLS")
	var run=I.new().new_run("aemeath",19);var packet=P.freeze(I.new(),run,"alice",P.random_id())
	run.pvp={"frozen":packet.bytes.get_string_from_utf8(),"sha256":packet.sha256,"player_id":"alice"}
	ck(not n.enqueue(run),"unconfigured upload not queued as a false success")
	n.config={"url":"http://127.0.0.1:1","player_id":"alice","token":"test-token"}
	ck(n.enqueue(run) and n.enqueue(run) and n.outbox.size()==1,"frozen upload deduplicated independently of run")
	var copy=run.duplicate(true)
	ck(n.outbox[0].body==packet.bytes.get_string_from_utf8() and run==copy,"outbox preserves exact bytes")
	var restored=load("res://scripts/online/async_pool_client.gd").new();root.add_child(restored);restored.configure(files)
	ck(restored.outbox.size()==1,"queue survives restart")
	ck(n.has_method("_prune_queue"),"outbox can discard foreign identity and expired head")
	if n.has_method("_prune_queue"):
		n.config.player_id="bob";n.call("_prune_queue");ck(n.outbox.is_empty(),"old identity cannot block new uploads");n.config.player_id="alice"
	var form=n.multipart({"key":"test/key","policy":"policy"},packet.bytes,"boundary")
	var body=form.get_string_from_utf8()
	ck(body.contains('name="key"\r\n\r\ntest/key') and body.ends_with("\r\n--boundary--\r\n") and body.find('name="file"')>body.find('name="policy"'),"OSS multipart fields then exact file bytes")
	var result=await n.find_opponent(I.new(),run)
	ck(not result.ok and result.error=="network","connection failure is explicit fallback reason")
	n.queue_free();restored.queue_free()
	print("async network ",checks," checks, failures ",failures);quit(1 if failures else 0)
