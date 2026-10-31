@tool
extends EditorExportPlugin
func _get_name()->String:return "RuntimeSourceBytes"
func _export_file(path:String,_type:String,_features:PackedStringArray)->void:
 if path.begins_with("res://assets/") and path.get_extension().to_lower() in ["png","jpg","jpeg","webp","ogg","wav"]:
  add_file(path,FileAccess.get_file_as_bytes(path),false)
  # These image roots are decoded from source bytes by VisualSkin, BagForm,
  # and VfxSprites. Their imported textures are a duplicate, unused Web copy.
  # Keep normal imports for fonts, fallback audio, and authored rig textures.
  if "web" in _features and path.get_extension().to_lower() in ["png","jpg","jpeg","webp"]:
   for root in ["res://assets/items/","res://assets/ui/","res://assets/vfx/","res://assets/characters/"]:
    if path.begins_with(root) and not path.contains("/rigs/") and not path.begins_with("res://assets/ui/branding/"):
     skip()
     break
