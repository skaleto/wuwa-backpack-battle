extends SceneTree
## Read-only display metadata and exact native bag previews for contact sheets.
const C=preload("res://scripts/data/catalog.gd")
const SKIN=preload("res://scripts/ui/visual_skin.gd")
const POCKETS=preload("res://scripts/inventory/pocket_rules.gd")
var output=""
class BagCanvas extends Node2D:
	const TERMINAL=preload("res://scripts/ui/pockets/terminal_grid.gd")
	const VISUAL=preload("res://scripts/ui/visual_skin.gd")
	var kind="satchel"
	func _draw():
		VISUAL.begin_frame()
		TERMINAL.thumbnail(self,Rect2(30,30,660,420),kind,0,1)
		VISUAL.end_frame()
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="):output=arg.trim_prefix("--output-dir=")
	call_deferred("run")
func entry(path:String,angle:float=0.0)->Dictionary:
	return {"path":ProjectSettings.globalize_path(path),"angle":angle}
func run():
	if output.is_empty() or DisplayServer.get_name()=="headless":
		printerr("Comparison export requires --output-dir and native rendering for the current bag surfaces.")
		quit(2);return
	DirAccess.make_dir_recursive_absolute(output.path_join("native-bags"))
	root.size=Vector2i(720,480);root.content_scale_size=Vector2i(720,480);root.transparent_bg=true
	var canvas=BagCanvas.new();root.add_child(canvas)
	var data={"items":[],"characters":[],"leaders":[],"renderer":"scripts/ui/pockets/terminal_grid.gd::thumbnail"}
	for kind in C.items:
		var definition=C.items[kind]
		var row={"id":kind,"name":POCKETS.profile(kind).name if C.is_tag(kind,"bag") else definition.name,"catalogue_name":definition.name,"tags":definition.tags,"weapon_type":definition.get("weapon_type",""),"tier":int(definition.get("craft_tier",definition.get("rarity",1))),"shape":definition.shape}
		for skin in ["original","chibi"]:
			SKIN.set_skin(skin,false)
			row[skin]=entry(SKIN.item_path(kind),SKIN.item_angle(kind))
			if C.is_tag(kind,"bag"):
				if skin=="original":row[skin]={"path":"","angle":0,"runtime":true}
				row[skin].render_path=output.path_join("native-bags").path_join(skin+"-"+kind+".png")
				if skin=="original" or FileAccess.file_exists(SKIN.bag_path(kind)):
					canvas.kind=kind;canvas.queue_redraw();await process_frame
					RenderingServer.force_draw(true);await process_frame;RenderingServer.force_draw(true);await process_frame
					var result=root.get_texture().get_image().save_png(row[skin].render_path)
					if result!=OK:printerr("Cannot save native bag: ",kind);quit(2);return
		data.items.append(row)
	for role in C.roster:
		var definition=C.roster[role]
		var row={"id":role,"name":definition.name,"element":definition.element,"weapon_type":definition.weapon_type}
		for skin in ["original","chibi"]:
			SKIN.set_skin(skin,false);row[skin]=entry(SKIN.portrait_path(role,"body"))
		data.characters.append(row)
	for leader in C.characters:
		var definition=C.characters[leader]
		var row={"id":leader,"name":definition.name,"element":definition.element,"role_id":definition.get("roster_id","")}
		for skin in ["original","chibi"]:
			SKIN.set_skin(skin,false);row[skin]=entry(SKIN.portrait_path(leader,"body"))
		data.leaders.append(row)
	var file=FileAccess.open(output.path_join("source-index.json"),FileAccess.WRITE)
	if file==null:printerr("Cannot create source-index.json");quit(2);return
	file.store_string(JSON.stringify(data,"\t"));file.close()
	print("COMPARISON SOURCES: ",data.items.size()," items including bags; ",data.characters.size()," recruit portraits; ",data.leaders.size()," leaders")
	canvas.queue_free();await process_frame;quit()
