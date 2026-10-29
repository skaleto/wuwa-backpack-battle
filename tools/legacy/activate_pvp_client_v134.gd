extends SceneTree
## Local operator helper. Input contains a GAME invite, never an Alibaba key.
const N=preload("res://scripts/online/async_pool_client.gd")
const S=preload("res://scripts/storage/storage.gd")
func _initialize():call_deferred("activate")
func activate():
	var args=OS.get_cmdline_user_args()
	if args.size()!=1:printerr("Expected private invitation JSON path");quit(2);return
	var input=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not input is Dictionary or not input.has_all(["base_url","user_invite"]):quit(2);return
	var n=N.new();root.add_child(n);n.configure(S.new("user://async/"))
	if n.ready_for_online():
		if not n._save_config(n.config):printerr("Private config permissions failed");quit(1);return
		var pool=preload("res://scripts/online/async_pvp.gd").pool_id(preload("res://scripts/inventory/inventory.gd").new().new_run("aemeath",19))
		var check=await n._api("/storage/read-ticket",{"pool_id":pool,"round":1},Time.get_ticks_msec()+8000)
		print("Existing client identity verified; private config protected; no run modified." if check.ok else "Existing identity check failed")
		n.queue_free();quit(0 if check.ok else 1);return
	var result=await n.activate(str(input.base_url),str(input.user_invite))
	print("Client game identity configured; no run modified." if result.ok else "Client activation failed: "+str(result.get("error","unknown")))
	n.queue_free();quit(0 if result.ok else 1)
