extends SceneTree
const S=preload("res://scripts/run/run_session.gd")
var failures=0
func ck(ok:bool,label:String):
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():call_deferred("test")
func test():
 var run={"gold":9};var plan={"ok":true,"source":S.stamp(run),"run":{"gold":8}}
 var result=S.commit(run,plan,func(_r):return true,func(_r):return false)
 ck(not result.ok and run.gold==9,"write failure must retain live state")
 ck(FileAccess.file_exists("res://scripts/online/device_identity.gd"),"installation identity module")
 if FileAccess.file_exists("res://scripts/online/device_identity.gd"):
  var module=load("res://scripts/online/device_identity.gd").new()
  var cfg={};var writes=[];var requests=[]
  var read=func():return cfg.duplicate(true)
  var save=func(value):cfg.clear();cfg.merge(value,true);writes.append(value.duplicate(true));return true
  var send=func(url,body,headers,_deadline):
   requests.append({"url":url,"body":body,"headers":headers})
   return {"ok":true,"data":{"player_id":"alice","token":"credential","expires_at":Time.get_unix_time_from_system()+86400}}
  module.configure(read,save,send)
  var identity=await module.ensure("http://127.0.0.1:1",Time.get_ticks_msec()+1000)
  ck(identity.ok and cfg.player_id=="alice","anonymous session")
  ck(writes.size()==2 and writes[0].device.secret.length()==64 and writes[0].device.installation_id.length()==32,"secret durable before network")
  var secret=cfg.device.secret
  await module.ensure("http://127.0.0.1:1",Time.get_ticks_msec()+1000)
  ck(requests.size()==1,"reuse unexpired session")
  cfg.expires_at=0
  await module.ensure("http://127.0.0.1:1",Time.get_ticks_msec()+1000)
  ck(requests.size()==2 and cfg.device.secret==secret and requests[-1].headers.is_empty(),"renew stable bound identity without old bearer")
  var failed=load("res://scripts/online/device_identity.gd").new()
  failed.configure(func():return {},func(_v):return false,send)
  identity=await failed.ensure("http://127.0.0.1:1",Time.get_ticks_msec()+1000)
  ck(not identity.ok and requests.size()==2,"failed credential write prevents registration")
 var files=preload("res://scripts/storage/storage.gd").new("user://qa-v138-save-"+preload("res://scripts/online/async_pvp.gd").random_id()+"/")
 var inv=preload("res://scripts/inventory/inventory.gd").new()
 var original=inv.new_run("aemeath",19)
 ck(files.save_checked(original),"initial save")
 var changed=original.duplicate(true);changed.gold+=1
 ck(files.save_checked(changed) and files.read_json(files.root_path+"run-previous.json",{}).gold==original.gold,"previous checkpoint retained")
 var bad=FileAccess.open(files.root_path+"run.json",FileAccess.WRITE);bad.store_string("broken-json");bad.close()
 ck(files.resume().is_empty() and files.resume_status=="corrupt","corrupt distinct from missing")
 ck(files.save_checked(original) and FileAccess.get_file_as_string(files.root_path+"run-preserved.json")=="broken-json","new save preserves damaged bytes")
 var pending=original.duplicate(true);pending.mode="async";pending.catalogue_hash="old-pool"
 files.write_json(files.root_path+"run.json",pending)
 ck(files.resume().is_empty() and files.resume_status=="incompatible","obsolete online pool identified")
 ck(files.save_checked(original) and files.read_json(files.root_path+"run-preserved-"+JSON.stringify(pending,"\t").sha256_text().substr(0,12)+".json",{}).get("catalogue_hash")=="old-pool","obsolete run preserved without replacing earlier backup")
 print("RELEASE_V138: ",failures," failures");quit(1 if failures else 0)
