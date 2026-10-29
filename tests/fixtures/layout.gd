extends RefCounted
## Test-only translation of published fixture paths after the directory move.
static var mapping:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tools/maintenance/layout-map.json"))
static func path(value:String)->String:
 var raw=value.trim_prefix("res://")
 return "res://"+str(mapping.get(raw,raw)) if value.begins_with("res://") else value
static func read(value:String)->String:return FileAccess.get_file_as_string(path(value))
static func published_text(value:String)->String:
 var text=read(value)
 var names=mapping.keys()
 names.sort_custom(func(a,b):return str(mapping[a]).length()>str(mapping[b]).length())
 for name in names:text=text.replace(str(mapping[name]),name)
 return text
static func exists(value:String)->bool:return FileAccess.file_exists(path(value))
