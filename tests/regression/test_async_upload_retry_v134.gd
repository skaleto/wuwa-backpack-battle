extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const S=preload("res://scripts/storage/storage.gd")
const P=preload("res://scripts/online/async_pvp.gd")
class RetryClient extends "res://scripts/online/async_pool_client.gd":
	var reads=0
	var snapshot_bytes=PackedByteArray()
	func _api(_path:String,body:Dictionary,_deadline:int)->Dictionary:
		var key=P.object_key(body.pool_id,int(body.round),int(body.wins),config.player_id,body.run_id,body.sha256)
		return {"ok":true,"status":200,"body":JSON.stringify({"key":key,"url":"https://fake.invalid/","fields":{"key":key}}).to_utf8_buffer()}
	func _request(_url:String,_method:int,_body:PackedByteArray,_headers:PackedStringArray,_deadline:int,_limit:int)->Dictionary:return {"ok":false,"status":409}
	func _read(_body:Dictionary,_deadline:int,_limit:int)->Dictionary:
		reads+=1
		return {"ok":false,"status":503} if reads==1 else {"ok":true,"status":200,"body":snapshot_bytes}
var failures=0
func ck(ok:bool,label:String):
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():call_deferred("test")
func test():
	var n=RetryClient.new();root.add_child(n);var files=S.new("user://qa-v134-retry-"+P.random_id()+"/");n.configure(files)
	ck(n._save_config({"url":"https://fake.invalid","player_id":"alice","token":"test-token"}),"private config saves")
	if OS.get_name()!="Windows":ck(FileAccess.get_unix_permissions(ProjectSettings.globalize_path(files.root_path))==448,"credential directory private before any temp write")
	var run=I.new().new_run("aemeath",19);var frozen=P.freeze(I.new(),run,"alice",P.random_id())
	n.snapshot_bytes=frozen.bytes;run.pvp={"frozen":frozen.bytes.get_string_from_utf8(),"sha256":frozen.sha256,"player_id":"alice"};n.enqueue(run)
	ck(not (await n.flush_one()) and n.outbox.size()==1,"409 plus transient GET failure retains upload")
	ck((await n.flush_one()) and n.outbox.is_empty(),"later exact GET verifies duplicate upload")
	n.queue_free();await process_frame;print("async upload retry failures ",failures);quit(1 if failures else 0)
