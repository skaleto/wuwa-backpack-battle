extends SceneTree
## Old-base and fresh-full probes write only their dedicated QA profile.
const CLIENT=preload("res://scripts/update/update_client.gd")
const STORE=preload("res://scripts/update/update_store.gd")
func _initialize():call_deferred("probe")
func probe():
 var args=OS.get_cmdline_user_args();var platform="Windows" if "--windows" in args else "macOS"
 var directory="user://qa-update-demo3-"+platform+("-live/" if "--live" in args else "-full/" if "--full" in args else "-offline/")
 var cfg=JSON.parse_string(FileAccess.get_file_as_string("res://data/update-channel.json"))
 if int(cfg.sequence)!=(14102 if "--full" in args else 14100):printerr("FAIL base version");quit(1);return
 if "--offline" in args:
  var feed=args[args.find("--feed")+1];var data=STORE.P.read_envelope(feed)
  var file=feed.get_base_dir()+"/releases/0.2.0-demo.3/"+("windows.pck" if platform=="Windows" else "macos.pck")
  DirAccess.make_dir_recursive_absolute(directory);DirAccess.copy_absolute(file,directory+"download.part")
  var result=STORE.new(directory,cfg,platform).stage(directory+"download.part",data)
  print("STAGE_DEMO3 ",platform," ",result.ok);quit(0 if result.ok else 1);return
 if "--boot" not in args and "--full" not in args:
  var client=CLIENT.new();root.add_child(client);client.configure(cfg,directory,platform,{},true);client.check()
  for n in 600:
   if not client.busy():break
   await create_timer(.05).timeout
  if client.status!="available" or int(client.available.sequence)!=14102:printerr("FAIL release ",client.status);quit(1);return
  client.download()
  for n in 2400:
   if not client.busy():break
   await create_timer(.05).timeout
  var good=client.status=="ready";print("DOWNLOAD_DEMO3 ",platform," ",client.status," bytes=",client.downloaded)
  client.queue_free();await process_frame;quit(0 if good else 1);return
 var store=STORE.new(directory,cfg,platform);var chosen={}
 if "--full" not in args:
  if not store.prepare_boot(false).is_empty():printerr("FAIL early activation");quit(1);return
  chosen=store.prepare_boot(true)
  if chosen.is_empty() or not ProjectSettings.load_resource_pack(chosen.path):printerr("FAIL mount");quit(1);return
 var game=load("res://scripts/game.gd").new()
 game.storage=load("res://scripts/storage/storage.gd").new(directory+"play/");game.muted=true
 game.set_meta("update_release",chosen.get("release",{}))
 root.add_child(game);await process_frame;game.set_process(false);game.set_process_input(false)
 if not game.has_method("_request_end_run"):printerr("FAIL old code");quit(1);return
 game.run=game.inventory.new_run("aemeath",37);game.screen="game";game.storage.save(game.run)
 game._request_end_run("practice","menu");game._confirm_end_run()
 var good=game.run.is_empty() and game.screen=="camp" and game.storage.resume().is_empty() and game.update_client.version()=="0.2.0-demo.3"
 if "--full" not in args:good=good and store.acknowledge()
 print("BOOT_DEMO3 ",platform," full=",("--full" in args)," abandon_and_version=",good)
 game.queue_free();await process_frame;quit(0 if good else 1)
