extends SceneTree
## Run with the original released PCK. Only the dedicated QA directory is written.
const CLIENT=preload("res://scripts/update/update_client.gd")
const STORE=preload("res://scripts/update/update_store.gd")
const QA="user://qa-update-demo2-delivery/"
func _initialize():call_deferred("probe")
func probe():
 var args=OS.get_cmdline_user_args()
 var platform="Windows" if "--windows" in args else "macOS"
 var directory=QA+platform+("-live" if "--live" in args else "")+"/"
 var cfg=JSON.parse_string(FileAccess.get_file_as_string("res://data/update-channel.json"))
 if int(cfg.sequence)!=14100:printerr("FAIL expected original base");quit(1);return
 if "--offline" in args:
  var at=args.find("--feed")
  var feed=args[at+1]
  var data=STORE.P.read_envelope(feed)
  var artifact=feed.get_base_dir()+"/releases/0.2.0-demo.2/"+("windows.pck" if platform=="Windows" else "macos.pck")
  DirAccess.make_dir_recursive_absolute(directory)
  DirAccess.copy_absolute(artifact,directory+"download.part")
  var result=STORE.new(directory,cfg,platform).stage(directory+"download.part",data)
  print("OFFLINE_OLD_BASE_STAGE ",platform," ",result.ok)
  quit(0 if result.ok else 1);return
 if "--boot" not in args:
  var c=CLIENT.new();root.add_child(c);c.configure(cfg,directory,platform,{},true);c.check()
  for n in 600:
   if not c.busy():break
   await create_timer(.05).timeout
  if c.status!="available" or int(c.available.sequence)!=14101:
   printerr("FAIL release unavailable: ",c.status);quit(1);return
  c.download()
  for n in 2400:
   if not c.busy():break
   await create_timer(.05).timeout
  print("OLD_CLIENT_DOWNLOAD ",platform," ",c.status," bytes=",c.downloaded)
  var good=c.status=="ready";c.queue_free();await process_frame;quit(0 if good else 1);return
 var store=STORE.new(directory,cfg,platform)
 if not store.prepare_boot(false).is_empty():printerr("FAIL active run must defer new patch");quit(1);return
 var chosen=store.prepare_boot(true)
 if chosen.is_empty() or not ProjectSettings.load_resource_pack(chosen.path):printerr("FAIL mount");quit(1);return
 var script=load("res://scripts/game.gd")
 if script==null:printerr("FAIL game load");quit(1);return
 var game=script.new()
 game.storage=load("res://scripts/storage/storage.gd").new(directory+"play/")
 game.muted=true;root.add_child(game);await process_frame
 game.set_process(false);game.set_process_input(false)
 if not game.has_method("_begin_organization"):printerr("FAIL old game loaded");quit(1);return
 game.run=game.inventory.new_run("aemeath",19);game.screen="game"
 var before=game.run.duplicate(true);game._begin_organization()
 var bag=game.run.bags[0].duplicate(true);bag.x=5;bag.y=4
 var moved=game.pocket_organizer.move(game.run,bag,"board",game.inventory)
 var frozen=game.run==before
 var finished=game._finish_organization()
 var good=moved and frozen and finished and game.run.items.is_empty() and store.acknowledge()
 print("OLD_CLIENT_PATCH_BOOT ",platform," version=",chosen.release.version," new_organization=",good)
 game.queue_free();await process_frame;quit(0 if good else 1)
