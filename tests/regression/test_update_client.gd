extends SceneTree
var failures=0
func ck(ok:bool,label:String):
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():call_deferred("run_test")
func run_test():
 if not ResourceLoader.exists("res://scripts/update/update_client.gd"):ck(false,"updater controller exists");quit(1);return
 var U=load("res://scripts/update/update_client.gd");var key=Crypto.new().generate_rsa(2048)
 var cfg={"public_key":key.save_to_string(true),"hosts":["updates.example.org"],"feed_url":"https://updates.example.org/feed.json","base_id":"test-base","runtime":1,"sequence":10,"version":"v10"}
 var path="user://qa-update-client-"+str(OS.get_process_id())+"/"
 var c=U.new();root.add_child(c);c.configure(cfg,path,"Windows",{},false)
 ck(c.status=="idle" and not c.busy(),"configure makes no request")
 var release={"schema":1,"sequence":11,"version":"v11","base_id":"test-base","runtime":1,"notes":["悬停查看详情"],"platforms":{"Windows":{"kind":"patch","url":"https://updates.example.org/11.pck","sha256":"test-content".sha256_text(),"bytes":12}}}
 var env=sign_release(release,key)
 c.accept_feed(env);ck(c.status=="available" and c.available.sequence==11,"signed newer release available")
 c.status="checking";c.accept_feed("{}".to_utf8_buffer());ck(c.status=="error","untrusted feed rejected")
 release.sequence=9;c.accept_feed(sign_release(release,key));ck(c.status=="current","older feed never enables downgrade")
 release.sequence=11;c.accept_feed(sign_release(release,key))
 var f=FileAccess.open(path+"download.part",FileAccess.WRITE);f.store_string("test-content");f.close()
 c.finish_download();ck(c.status=="verifying","verification is background work")
 for i in 600:
  if c.status!="verifying":break
  await process_frame
 ck(c.status=="ready" and not c.store.state().pending.is_empty(),"complete download staged")
 ck(c.store.state().active.is_empty(),"current process not patched")
 c.cancel();ck(c.status=="ready","cancel cannot discard verified pending release")
 var before=FileAccess.get_file_as_string(path+"state.json")
 ck(not c.restart(false),"restart refused during a run")
 ck(FileAccess.get_file_as_string(path+"state.json")==before,"refused restart never modifies update pointers")
 c.queue_free();await process_frame
 print("UPDATE_CLIENT failures=",failures);quit(1 if failures else 0)
func sign_release(value:Dictionary,key:CryptoKey)->PackedByteArray:
 var raw=JSON.stringify(value).to_utf8_buffer();var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(raw)
 return JSON.stringify({"payload":Marshalls.raw_to_base64(raw),"signature":Marshalls.raw_to_base64(Crypto.new().sign(HashingContext.HASH_SHA256,hash.finish(),key))}).to_utf8_buffer()
