extends SceneTree
## Build-only: compress copied caches in a fresh staging tree, never the source.
func _initialize():
	var args=OS.get_cmdline_user_args()
	if args.size()!=1:
		printerr("Expected absolute staging root")
		quit(1)
		return
	var folder=args[0].path_join("assets/generated/silhouettes")
	if not args[0].is_absolute_path() or args[0].simplify_path()==ProjectSettings.globalize_path("res://").trim_suffix("/"):
		printerr("Refusing to compress source caches")
		quit(1)
		return
	var total_before=0
	var total_after=0
	var count=0
	for name in DirAccess.get_files_at(folder):
		if not name.ends_with(".bin"):continue
		var path=folder.path_join(name)
		var bytes=FileAccess.get_file_as_bytes(path)
		var output=FileAccess.open_compressed(path,FileAccess.WRITE,FileAccess.COMPRESSION_ZSTD)
		if output==null:
			printerr("Cannot write cache: ",name)
			quit(1)
			return
		output.store_buffer(bytes)
		output.close()
		var verify=FileAccess.open_compressed(path,FileAccess.READ)
		if verify==null or verify.get_buffer(verify.get_length())!=bytes:
			printerr("Cache round-trip differs: ",name)
			quit(1)
			return
		verify.close()
		total_before+=bytes.size()
		total_after+=FileAccess.get_file_as_bytes(path).size()
		count+=1
	print(JSON.stringify({"cache_count":count,"before_bytes":total_before,"after_bytes":total_after,"exact_roundtrip":true}))
	quit()
