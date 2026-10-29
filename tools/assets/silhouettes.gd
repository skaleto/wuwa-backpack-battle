extends SceneTree
const C=preload("res://scripts/data/catalog.gd")
const SKIN=preload("res://scripts/ui/visual_skin.gd")
const GEO=preload("res://scripts/ui/items/art_geometry.gd")
const P=preload("res://scripts/ui/items/icon_projection.gd")
func _initialize():
	DirAccess.make_dir_recursive_absolute(GEO.ROOT)
	var seen={};var count=0
	for kind in C.items:
		if C.is_tag(kind,"bag"):continue
		var path=GEO.path(kind)
		if seen.has(path):continue
		seen[path]=true
		if FileAccess.file_exists(path):
			var prior=FileAccess.open(path,FileAccess.READ).get_var(false)
			if prior is Array and prior.size()==4 and not prior[0].get("empty",true):continue
		var texture=SKIN.texture(SKIN.item_path(kind))
		if texture==null:push_error("Cannot cache "+kind);quit(1);return
		var image=texture.get_image()
		if image==null or image.is_empty():push_error("Cannot cache "+kind);quit(1);return
		var values=[]
		for turn in 4:values.append(P.descriptor(image,SKIN.item_angle(kind)+turn*PI/2.0,false))
		var file=FileAccess.open(path,FileAccess.WRITE);file.store_var(values);file.close()
		count+=1
	print("V70 cached silhouettes: ",count," unique assets: ",seen.size())
	quit()
