extends SceneTree
const SKIN=preload("res://scripts/ui/visual_skin.gd")
var OUT="res://build/qa/demo-v50/skins/"
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="):OUT=arg.trim_prefix("--evidence-dir=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(OUT)
	var errors=SKIN.validate_manifest()
	var out={"items":SKIN.manifest.get("items",{}).size(),"characters":SKIN.manifest.get("characters",{}).size(),"bags":SKIN.manifest.get("bags",{}).size(),"ui":SKIN.manifest.get("ui",{}).size(),"errors":errors,"failures":errors.size()}
	var file=FileAccess.open(OUT+"asset-coverage.json",FileAccess.WRITE);file.store_string(JSON.stringify(out,"\t"));file.close()
	for error in errors:printerr(error)
	print("SKIN ASSETS: ",out.items," items, ",out.characters," characters, ",out.bags," bags, ",out.ui," UI; ",errors.size()," failures")
	quit(1 if not errors.is_empty() else 0)
