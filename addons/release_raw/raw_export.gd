@tool
extends EditorExportPlugin
func _get_name()->String:return "RuntimeSourceBytes"
func _export_file(path:String,_type:String,_features:PackedStringArray)->void:
 if path.begins_with("res://assets/") and path.get_extension().to_lower() in ["png","jpg","jpeg","webp","ogg","wav"]:
  add_file(path,FileAccess.get_file_as_bytes(path),false)
