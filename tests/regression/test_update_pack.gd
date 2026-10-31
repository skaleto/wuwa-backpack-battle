extends SceneTree
const S=preload("res://scripts/update/update_store.gd")
var failures=0
func ck(ok:bool,label:String):
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
 var dir="user://qa-update-pack-"+str(OS.get_process_id())+"/";DirAccess.make_dir_recursive_absolute(dir)
 var target="res://qa-patch-"+str(OS.get_process_id())+".gd"
 var file=FileAccess.open(dir+"source.gd",FileAccess.WRITE);file.store_string("extends RefCounted\nfunc version():return 11\n");file.close()
 var pack=PCKPacker.new();ck(pack.pck_start(dir+"download.part")==OK,"create real resource pack")
 ck(pack.add_file(target,dir+"source.gd")==OK and pack.flush()==OK,"pack script payload")
 var key=Crypto.new().generate_rsa(2048);var cfg={"sequence":10,"version":"v10","base_id":"qa","runtime":1,"hosts":["updates.example.org"],"public_key":key.save_to_string(true)}
 var f=FileAccess.open(dir+"download.part",FileAccess.READ);var size=f.get_length();f.close()
 var release={"schema":1,"sequence":11,"version":"v11","base_id":"qa","runtime":1,"platforms":{"Windows":{"kind":"patch","url":"https://updates.example.org/update.pck","bytes":size,"sha256":FileAccess.get_sha256(dir+"download.part")}}}
 var raw=JSON.stringify(release).to_utf8_buffer();var h=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(raw)
 var env=JSON.stringify({"payload":Marshalls.raw_to_base64(raw),"signature":Marshalls.raw_to_base64(Crypto.new().sign(HashingContext.HASH_SHA256,h.finish(),key))}).to_utf8_buffer()
 var store=S.new(dir,cfg,"Windows");ck(store.stage(dir+"download.part",env).ok,"stage signed real PCK")
 ck(not ResourceLoader.has_cached(target),"script not loaded before pack activation")
 var chosen=store.prepare_boot(true);ck(ProjectSettings.load_resource_pack(chosen.path),"mount verified PCK")
 var script=load(target);ck(script!=null and script.new().version()==11,"load new code only after mount")
 ck(store.acknowledge() and store.prepare_boot(true).get("release",{}).get("sequence")==11,"healthy patch stays active")
 var orphan="12-"+"f".repeat(64);file=FileAccess.open(dir+orphan+".pck",FileAccess.WRITE);file.store_string("unused");file.close()
 file=FileAccess.open(dir+"notes.txt",FileAccess.WRITE);file.store_string("keep");file.close();store.prune()
 ck(not FileAccess.file_exists(dir+orphan+".pck") and FileAccess.file_exists(chosen.path),"prune old cache only")
 ck(FileAccess.file_exists(dir+"notes.txt"),"unknown file preserved")
 print("UPDATE_PACK failures=",failures);quit(1 if failures else 0)
