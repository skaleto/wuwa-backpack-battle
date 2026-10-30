extends SceneTree
const GEO = preload("res://scripts/ui/items/art_geometry.gd")

func _initialize():
	var reader = GEO.new()
	if not reader.has_method("read_cache"):
		printerr("FAIL losslessly compressed silhouette cache is not supported")
		quit(1)
		return
	var root = "user://qa-web-cache/"
	DirAccess.make_dir_recursive_absolute(root)
	var sample = [{"bounds": Rect2(-3, 5, 13, 21), "points": PackedVector2Array([Vector2(0.25, -4.5), Vector2(123, 456)]), "empty": false}]
	var raw = FileAccess.open(root + "plain.bin", FileAccess.WRITE)
	raw.store_var(sample)
	raw.close()
	var zipped = FileAccess.open_compressed(root + "compressed.bin", FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	zipped.store_buffer(FileAccess.get_file_as_bytes(root + "plain.bin"))
	zipped.close()
	for path in [root + "plain.bin", root + "compressed.bin"]:
		if reader.call("read_cache", path) != sample:
			printerr("FAIL cache changed geometry: ", path)
			quit(1)
			return
		DirAccess.remove_absolute(path)
	print("PASS plain and compressed caches return identical typed geometry")
	quit()
