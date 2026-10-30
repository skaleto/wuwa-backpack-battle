extends RefCounted
## Offline silhouette descriptors preserve exact original-image fitting.
const SKIN=preload("res://scripts/ui/visual_skin.gd")
const PROJECTION=preload("res://scripts/ui/items/icon_projection.gd")
const ROOT="res://assets/generated/silhouettes/"
static func path(kind:String)->String:
	var source_hash=str(SKIN.manifest.get("items",{}).get(kind,{}).get("sha256",""))
	return ROOT+("silhouette-v1:"+source_hash+":"+SKIN.item_path(kind)+":"+str(SKIN.item_angle(kind))).sha256_text()+".bin"
static func descriptor(kind:String,turn:int,image:Image)->Dictionary:
	var file_path=path(kind)
	if FileAccess.file_exists(file_path):
		var data=read_cache(file_path)
		if data is Array and data.size()==4 and data[posmod(turn,4)] is Dictionary:
			return data[posmod(turn,4)]
	return PROJECTION.descriptor(image,SKIN.item_angle(kind)+posmod(turn,4)*PI/2.0,false)

static func read_cache(file_path:String)->Variant:
	var file=FileAccess.open(file_path,FileAccess.READ)
	if file==null:return null
	# Web builds compress the same serialized bytes, without regenerating shape
	# samples or changing asset hashes. Source/desktop caches remain readable.
	if file.get_buffer(4).get_string_from_ascii()=="GCPF":
		file.close()
		file=FileAccess.open_compressed(file_path,FileAccess.READ)
	else:
		file.seek(0)
	return file.get_var(false) if file!=null else null
