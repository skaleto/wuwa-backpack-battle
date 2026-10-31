extends Node2D
## This file and update trust code are part of the immutable desktop base.
## No game/catalog preloads: verified resource packs must mount first.
const STORE=preload("res://scripts/update/update_store.gd")
var update_store
var channel:Dictionary={}
var active_release:Dictionary={}
static func safe_to_activate(profile:String)->bool:
 for relative in ["run.json","async/run.json"]:
  var path=profile.trim_suffix("/")+"/"+relative
  if not FileAccess.file_exists(path):continue
  var file=FileAccess.open(path,FileAccess.READ)
  if file==null or file.get_length()>32*1024*1024:return false
  var parser=JSON.new();var error=parser.parse(file.get_as_text());file.close()
  if error!=OK:return false
  var value=parser.data
  if not value is Dictionary or (not value.is_empty() and value.get("phase","")!="ending"):return false
 return true
static func valid_ack(token:String)->bool:
 var regex=RegEx.new();regex.compile("^[0-9a-f]{64}$");return regex.search(token)!=null
func _ready()->void:
 channel=JSON.parse_string(FileAccess.get_file_as_string("res://data/update-channel.json"))
 var desktop=OS.has_feature("template") and not OS.has_feature("editor") and OS.get_name() in ["Windows","macOS","Linux"] and DisplayServer.get_name()!="headless"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--profile="):desktop=false
 if desktop:
  update_store=STORE.new("user://updates/",channel,OS.get_name())
  var chosen=update_store.prepare_boot(safe_to_activate("user://"))
  if not chosen.is_empty():
   if not ProjectSettings.load_resource_pack(chosen.path):
    update_store.reject_active();_restart_base();return
   active_release=chosen.release
 var script=load("res://scripts/game.gd")
 if script==null or not script.can_instantiate():
  if not active_release.is_empty():update_store.reject_active();_restart_base()
  else:_failed_start()
  return
 var game=script.new()
 game.set_meta("update_channel",channel)
 game.set_meta("update_release",active_release)
 game.set_meta("update_enabled",desktop or OS.has_feature("web"))
 add_child(game)
 await get_tree().process_frame
 await get_tree().process_frame
 if not game.get_meta("startup_complete",false):
  if not active_release.is_empty():update_store.reject_active();_restart_base()
  else:_failed_start()
  return
 if update_store!=null:update_store.acknowledge()
 if desktop:
  var args=OS.get_cmdline_user_args();var at=args.find("--update-ack")
  if at>=0 and at+1<args.size() and valid_ack(args[at+1]):STORE.atomic_file("user://updates/full-"+args[at+1]+".ack","ready".to_utf8_buffer())
func _restart_base()->void:
 OS.set_restart_on_exit(true,PackedStringArray());get_tree().quit()
func _failed_start()->void:
 var panel=AcceptDialog.new();panel.title="启动未完成";panel.dialog_text="游戏文件未能载入。请重新安装完整客户端，存档会保留。"
 add_child(panel);panel.confirmed.connect(func():get_tree().quit());panel.popup_centered()
