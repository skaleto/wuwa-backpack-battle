extends SceneTree
const U=preload("res://scripts/update/update_client.gd")
func _initialize():call_deferred("probe")
func probe():
 var cfg=JSON.parse_string(FileAccess.get_file_as_string("res://data/update-channel.json"))
 var c=U.new();root.add_child(c);c.configure(cfg,"user://qa-update-live-"+str(OS.get_process_id())+"/",OS.get_name(),{},true)
 c.check()
 for n in 400:
  if not c.busy():break
  await create_timer(.05).timeout
 print("LIVE_UPDATE_CHANNEL ",c.status)
 var good=c.status in ["current","available"]
 c.queue_free();await process_frame;quit(0 if good else 1)
