extends RefCounted
## Presentation preferences only. Never stored in a run or online snapshot.
var music_volume=1.0
var effects_volume=1.0
var music_muted=false
var effects_muted=false
var path:String
func _init(root:String="user://")->void:
 path=root.path_join("settings.cfg")
 var cfg=ConfigFile.new()
 if cfg.load(path)!=OK:return
 music_volume=_volume(cfg.get_value("audio","music_volume",1.0))
 effects_volume=_volume(cfg.get_value("audio","effects_volume",1.0))
 var m=cfg.get_value("audio","music_muted",false);music_muted=m if m is bool else false
 var e=cfg.get_value("audio","effects_muted",false);effects_muted=e if e is bool else false
static func _volume(value:Variant)->float:
 if not (value is float or value is int) or not is_finite(float(value)):return 1.0
 return clampf(float(value),0,1)
func volume(channel:String)->float:return music_volume if channel=="music" else effects_volume
func is_muted(channel:String)->bool:return music_muted if channel=="music" else effects_muted
func set_volume(channel:String,value:float)->void:
 if channel=="music":music_volume=_volume(value)
 elif channel=="effects":effects_volume=_volume(value)
func toggle(channel:String)->void:
 if channel=="music":music_muted=not music_muted
 elif channel=="effects":effects_muted=not effects_muted
func reset()->void:
 music_volume=1.0;effects_volume=1.0;music_muted=false;effects_muted=false
func save()->bool:
 var cfg=ConfigFile.new()
 for key in ["music_volume","effects_volume","music_muted","effects_muted"]:cfg.set_value("audio",key,get(key))
 if DirAccess.make_dir_recursive_absolute(path.get_base_dir())!=OK:return false
 var temporary=path+".tmp"
 if cfg.save(temporary)!=OK:return false
 return DirAccess.rename_absolute(temporary,path)==OK
