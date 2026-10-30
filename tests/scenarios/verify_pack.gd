extends SceneTree
var failures=0
func ck(ok:bool,label:String):
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():call_deferred("test")
func test():
 var C=load("res://scripts/data/catalog.gd")
 var Q=load("res://scripts/ui/visual_skin.gd")
 var I=load("res://scripts/inventory/inventory.gd")
 var P=load("res://scripts/online/async_pvp.gd")
 ck(P.pool_id(I.new().new_run("aemeath",19))=="6782d653abb077bcc2680a872f723d69ee7239c1297977028dd2349062ab7b11","new random supply pool")
 ck(C.catalogue_hash=="16cf6ae5e46b9328761bf304624cd172bbf74e7da6f6bcc0a639e7c7ee46e82f","catalogue unchanged")
 ck(P.pool_id(I.new().new_run_supply("aemeath",19,"full",129))=="f38abbcaa0cf07b37a2731e5a98a4e79b41ba7cdef8ac6036d69420bcc9f88c8","historical online pool unchanged")
 Q.configure([],"user://qa-v138-structure-export/")
 for id in C.items:
  var path=Q.item_path(id)
  ck(not path.is_empty() and FileAccess.file_exists(path),"item source "+id)
 for role in C.characters:
  ck(FileAccess.file_exists(Q.portrait_path(role)),"portrait "+role)
 ck(load("res://assets/fonts/body.ttf")!=null,"font resource")
 ck(Image.load_from_file(Q.item_path("w_sword")).get_width()>0,"raw image decode")
 ck(AudioStreamOggVorbis.load_from_file("res://assets/audio/music/battle_fun.ogg")!=null,"raw OGG decode")
 ck(AudioStreamWAV.load_from_file("res://assets/audio/sfx/cloth/bag_pick.wav")!=null,"raw WAV decode")
 for path in ["res://services/pvp_signer/main.py","res://tests/regression/test_release_v138.gd","res://docs/release-v138/before.zip","res://online.json"]:ck(not FileAccess.file_exists(path),"excluded "+path)
 var game=load("res://scripts/game.gd").new()
 game.storage=load("res://scripts/storage/storage.gd").new("user://qa-v138-structure-export/")
 root.add_child(game);await process_frame;await process_frame
 ck(not game.font==null and game.screen=="camp","isolated title scene ready")
 game.queue_free();await process_frame
 print("PACK_V138: ",failures," failures");quit(1 if failures else 0)
