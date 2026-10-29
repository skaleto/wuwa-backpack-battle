extends SceneTree
## Regression coverage for the independent V138 persistence/identity review.
## All disk fixtures are isolated QA profiles and are removed at completion.
const STORE=preload("res://scripts/storage/storage.gd")
const INVENTORY=preload("res://scripts/inventory/inventory.gd")
const APPLICATION=preload("res://scripts/run/run_application.gd")
const IDENTITY=preload("res://scripts/online/device_identity.gd")
const PROTOCOL=preload("res://scripts/online/async_pvp.gd")
signal release_identity
var failures=0
var checks=0
var fixture_root=""
var inventory=INVENTORY.new()

func ck(value:bool,label:String)->void:
	checks+=1
	if not value:failures+=1;printerr("FAIL ",label)

func _initialize()->void:call_deferred("test")

func store(label:String):return STORE.new(fixture_root+label+"/")

func test()->void:
	fixture_root="user://qa-v138-storage-review-"+PROTOCOL.random_id()+"/"
	test_unreadable_original()
	test_invalid_checkpoint()
	test_malformed_pvp_checkpoint()
	test_same_seed_restart()
	await test_join_deadline()
	remove_fixture(fixture_root)
	print("release storage v138 ",checks," checks, failures ",failures)
	quit(1 if failures else 0)

func test_unreadable_original()->void:
	var files=store("unreadable")
	var run=inventory.new_run("aemeath",19)
	ck(files.save_checked(run),"unreadable fixture initial save")
	var path=files.root_path+"run.json"
	var original=FileAccess.get_file_as_bytes(path)
	if OS.get_name() not in ["macOS","Linux","FreeBSD","NetBSD","OpenBSD"]:
		print("SKIP unreadable permission fixture: no POSIX permissions")
		return
	ck(FileAccess.set_unix_permissions(path,0)==OK,"remove fixture read permission")
	var probe=FileAccess.open(path,FileAccess.READ)
	if probe:
		probe.close()
		ck(FileAccess.set_unix_permissions(path,384)==OK,"restore privileged fixture permissions")
		print("SKIP unreadable permission fixture: process bypasses permissions")
		return
	var backed_up=files.backup_run(files.root_path+"denied-backup.json")
	var replacement=run.duplicate(true);replacement.gold+=1
	var saved=files.save_checked(replacement)
	# Restore before assertions or cleanup, even if the implementation regresses.
	ck(FileAccess.set_unix_permissions(path,384)==OK,"restore unreadable fixture permissions")
	ck(not backed_up,"unreadable original cannot certify an empty backup")
	ck(not saved,"unreadable original prevents replacement")
	ck(FileAccess.get_file_as_bytes(path)==original,"unreadable original bytes remain unchanged")
	ck(not FileAccess.file_exists(files.root_path+"denied-backup.json"),"failed read does not create misleading backup")
	var empty=FileAccess.open(path,FileAccess.WRITE);empty.close()
	ck(files.backup_run(files.root_path+"empty-backup.json"),"genuinely empty readable original can be preserved")
	ck(FileAccess.file_exists(files.root_path+"empty-backup.json") and FileAccess.get_file_as_bytes(files.root_path+"empty-backup.json").is_empty(),"empty backup exists with exact bytes")

func test_invalid_checkpoint()->void:
	var files=store("invalid-checkpoint")
	var run=inventory.new_run("aemeath",19)
	ck(files.save_checked(run),"invalid fixture initial checkpoint")
	var next=run.duplicate(true);next.gold+=1
	ck(files.save_checked(next),"invalid fixture second checkpoint")
	var previous=FileAccess.get_file_as_bytes(files.root_path+"run-previous.json")
	var malformed=next.duplicate(true);malformed.gold=-999
	ck(not inventory.validate_run(malformed),"malformed fixture fails run validation")
	ck(files.write_json(files.root_path+"run.json",malformed),"write malformed fixture")
	var damaged=FileAccess.get_file_as_bytes(files.root_path+"run.json")
	ck(files.save_checked(next),"valid live checkpoint can replace preserved malformed JSON")
	ck(FileAccess.get_file_as_bytes(files.root_path+"run-previous.json")==previous,"invalid JSON object cannot replace latest valid checkpoint")
	ck(FileAccess.get_file_as_bytes(files.root_path+"run-preserved.json")==damaged,"malformed original retained byte for byte")

func test_malformed_pvp_checkpoint()->void:
	var files=store("malformed-pvp")
	var run=inventory.new_run("aemeath",19)
	ck(files.save_checked(run),"PVP shape fixture initial save")
	var malformed=run.duplicate(true);malformed.pvp=[]
	ck(files.write_json(files.root_path+"run.json",malformed),"write malformed nested PVP fixture")
	var damaged=FileAccess.get_file_as_bytes(files.root_path+"run.json")
	var result=files.save_checked(run)
	ck(result,"malformed nested PVP field does not abort valid save")
	ck(FileAccess.get_file_as_bytes(files.root_path+"run-preserved.json")==damaged,"malformed nested PVP original preserved")

func test_same_seed_restart()->void:
	var files=store("same-seed")
	var old=inventory.new_run("aemeath",19);old.gold+=3
	ck(files.save_checked(old),"same-seed original save")
	var original=FileAccess.get_file_as_bytes(files.root_path+"run.json")
	var app=APPLICATION.new(inventory,files,null)
	var started=app.start("aemeath",19,"full",old)
	ck(started.ok,"same-seed new game succeeds")
	if not started.ok:return
	var replacement:Dictionary=started.run;replacement.gold+=1
	ck(files.save_checked(replacement),"same-seed new game checkpoint succeeds")
	ck(FileAccess.get_file_as_bytes(files.root_path+"run-preserved.json")==original,"explicit new-game boundary retains original despite seed collision")

func test_join_deadline()->void:
	var module=IDENTITY.new()
	var config={};var requests=[];var completions=[]
	module.completed.connect(func(value):completions.append(value))
	module.configure(func():return config.duplicate(true),func(value):config.clear();config.merge(value,true);return true,func(_url,body,_headers,_deadline):
		requests.append(body.duplicate(true))
		await release_identity
		return {"ok":true,"data":{"player_id":"a".repeat(32),"token":"b".repeat(64),"expires_at":Time.get_unix_time_from_system()+86400}})
	module.ensure("http://127.0.0.1:1",Time.get_ticks_msec()+2000)
	ck(module.busy and requests.size()==1,"first identity request remains pending")
	var secret=config.device.secret
	# A finite release avoids hanging the test against the old unconditional wait.
	create_timer(.6).timeout.connect(func():release_identity.emit())
	var began=Time.get_ticks_msec()
	var short=await module.ensure("http://127.0.0.1:1",began+40)
	ck(not short.ok and short.get("error")=="network","short joining caller times out independently")
	ck(Time.get_ticks_msec()-began<350,"short join does not wait for shared request completion")
	ck(module.busy and completions.is_empty(),"joining timeout leaves original request running")
	var long=await module.ensure("http://127.0.0.1:1",Time.get_ticks_msec()+2000)
	ck(long.ok and not module.busy,"long joining caller receives eventual shared success")
	ck(requests.size()==1 and completions.size()==1,"concurrent callers allocate only once")
	ck(config.device.secret==secret and config.device.bound,"timeout preserves and eventually binds original installation")

func remove_fixture(path:String)->void:
	# Guard the cleanup boundary even if a test accidentally changes a path.
	if not path.begins_with(fixture_root) or not fixture_root.begins_with("user://qa-v138-storage-review-"):return
	for directory in DirAccess.get_directories_at(path):remove_fixture(path.path_join(directory)+"/")
	for filename in DirAccess.get_files_at(path):DirAccess.remove_absolute(path.path_join(filename))
	DirAccess.remove_absolute(path)
