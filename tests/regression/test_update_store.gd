extends SceneTree
var failures=0
func ck(ok:bool,label:String):
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
 if not ResourceLoader.exists("res://scripts/update/update_store.gd"):ck(false,"atomic update store exists");quit(1);return
 var S=load("res://scripts/update/update_store.gd");var key=Crypto.new().generate_rsa(2048)
 var root_path="user://qa-update-store-"+str(OS.get_process_id())+"/";DirAccess.make_dir_recursive_absolute(root_path)
 var cfg={"public_key":key.save_to_string(true),"hosts":["updates.example.org"],"base_id":"test-base","runtime":1,"sequence":10}
 var store=S.new(root_path,cfg,"Windows");var payload=root_path+"download.part"
 var f=FileAccess.open(payload,FileAccess.WRITE);f.store_string("test-content");f.close()
 var release={"schema":1,"sequence":11,"version":"v11","base_id":"test-base","runtime":1,"notes":[],"platforms":{"Windows":{"kind":"patch","url":"https://updates.example.org/11.pck","sha256":FileAccess.get_sha256(payload),"bytes":12}}}
 var raw=JSON.stringify(release).to_utf8_buffer();var hc=HashingContext.new();hc.start(HashingContext.HASH_SHA256);hc.update(raw)
 var env=JSON.stringify({"payload":Marshalls.raw_to_base64(raw),"signature":Marshalls.raw_to_base64(Crypto.new().sign(HashingContext.HASH_SHA256,hc.finish(),key))}).to_utf8_buffer()
 ck(store.stage(payload,env).get("ok",false),"verified content staged")
 ck(store.state().active.is_empty() and not store.state().pending.is_empty(),"download does not activate current process")
 ck(store.prepare_boot(false).is_empty() and not store.state().pending.is_empty(),"unfinished run prevents activation")
 var boot=store.prepare_boot(true);ck(boot.get("release",{}).get("sequence")==11,"restart chooses pending release")
 ck(not store.state().trial.is_empty(),"trial marker precedes loading executable patch")
 ck(store.prepare_boot(true).is_empty() and store.state().active.is_empty(),"unacknowledged boot restores base")
 f=FileAccess.open(payload,FileAccess.WRITE);f.store_string("test-content");f.close()
 ck(store.stage(payload,env).ok,"explicit retry can stage quarantined candidate")
 store.prepare_boot(true);ck(store.acknowledge(),"healthy game acknowledges activation")
 ck(store.prepare_boot(true).get("release",{}).get("sequence")==11,"healthy pack survives restart")
 var path=store.prepare_boot(true).path;f=FileAccess.open(path,FileAccess.WRITE);f.store_string("tampered");f.close()
 ck(store.prepare_boot(true).is_empty(),"tampered active pack never loads")
 f=FileAccess.open(payload,FileAccess.WRITE);f.store_string("bad-data");f.close()
 ck(not store.stage(payload,env).ok,"corrupt download rejected")
 print("UPDATE_STORE failures=",failures);quit(1 if failures else 0)
