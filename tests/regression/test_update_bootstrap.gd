extends SceneTree
var failures=0
func ck(ok:bool,label:String):
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
 if not ResourceLoader.exists("res://scripts/update/bootstrap.gd"):ck(false,"bootstrap exists");quit(1);return
 var B=load("res://scripts/update/bootstrap.gd")
 var dir="user://qa-update-boot-"+str(OS.get_process_id())+"/";DirAccess.make_dir_recursive_absolute(dir+"async")
 ck(B.safe_to_activate(dir),"new profile permits activation")
 write(dir+"run.json",{"phase":"shop"});ck(not B.safe_to_activate(dir),"practice run protected")
 write(dir+"run.json",{"phase":"ending"});ck(B.safe_to_activate(dir),"completed practice permits activation")
 write(dir+"async/run.json",{"phase":"shop","pvp":{"stage":"pending"}});ck(not B.safe_to_activate(dir),"online pending match protected")
 write(dir+"async/run.json",{"phase":"ending"});ck(B.safe_to_activate(dir),"finished online run permits activation")
 var f=FileAccess.open(dir+"run.json",FileAccess.WRITE);f.store_string("bad-json");f.close()
 ck(not B.safe_to_activate(dir),"unreadable save never treated as absent")
 ck(FileAccess.get_file_as_string(dir+"run.json")=="bad-json","guard is read-only")
 ck(B.valid_ack("a".repeat(64)) and not B.valid_ack("../test"),"ack token cannot select arbitrary path")
 var scene=FileAccess.get_file_as_string("res://main.tscn")
 ck("scripts/update/bootstrap.gd" in scene and not "scripts/game.gd" in scene,"main scene loads bootstrap before game")
 print("UPDATE_BOOTSTRAP failures=",failures);quit(1 if failures else 0)
func write(path:String,value:Dictionary):
 var f=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(value));f.close()
