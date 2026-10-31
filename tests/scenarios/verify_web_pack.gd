extends SceneTree
## Run against --main-pack from an empty directory, so missing files cannot
## accidentally resolve from the development checkout.
const SKIN=preload("res://scripts/ui/visual_skin.gd")
const GEO=preload("res://scripts/ui/items/art_geometry.gd")
var errors:Array=[]

func _initialize():
	var args=OS.get_cmdline_user_args()
	var desktop=args.size()==2 and args[1]=="--desktop"
	if args.size()!=1 and not desktop:
		printerr("Expected original staging manifest path")
		quit(1)
		return
	var entries=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var raw_count=0
	var cache_count=0
	var images=0
	for entry in entries:
		var rel:String=entry.path
		var path="res://"+rel
		if rel.begins_with("assets/generated/silhouettes/"):
			if desktop:
				if FileAccess.get_sha256(path)!=str(entry.sha256):errors.append("changed cache bytes: "+rel)
				var data=GEO.read_cache(path)
				if not data is Array or data.size()!=4:errors.append("unreadable cache geometry: "+rel)
				cache_count+=1
				continue
			var file=FileAccess.open_compressed(path,FileAccess.READ)
			if file==null:
				errors.append("missing compressed cache: "+rel)
				continue
			var bytes=file.get_buffer(file.get_length())
			var hashing=HashingContext.new()
			hashing.start(HashingContext.HASH_SHA256)
			hashing.update(bytes)
			if hashing.finish().hex_encode()!=str(entry.sha256):errors.append("changed cache bytes: "+rel)
			var data=GEO.read_cache(path)
			if not data is Array or data.size()!=4:errors.append("unreadable cache geometry: "+rel)
			cache_count+=1
		elif rel.get_extension() in ["png","jpg","webp","wav","ogg","json","sha256","ico","icns"]:
			if FileAccess.get_sha256(path)!=str(entry.sha256):errors.append("changed/missing raw bytes: "+rel)
			raw_count+=1
			if rel.get_extension() in ["png","jpg","webp"]:
				if SKIN.texture(path)==null:errors.append("cannot decode image: "+rel)
				images+=1
	if not SKIN.validate_manifest().is_empty():errors.append("missing manifest assets")
	print(JSON.stringify({"raw_files_verified":raw_count,"compressed_caches_verified":cache_count,"images_decoded":images,"errors":errors}))
	quit(0 if errors.is_empty() else 1)
