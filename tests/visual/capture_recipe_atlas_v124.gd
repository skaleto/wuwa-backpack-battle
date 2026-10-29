extends SceneTree
## Native rendering and synthetic input only; root never becomes focusable.
const OUT="res://build/qa/strategy-v124/native/"
const TREE=preload("res://scripts/crafting/recipe_tree.gd")
const C=preload("res://scripts/data/catalog.gd")
var g
var viewport
var checks=0
var failures=0
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
	root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true);call_deferred("test")
func shot(name:String):
	var navigation_before=TREE.navigation_state().duplicate(true)
	g.motion.modal_value=1;g.motion.modal_target=1;g.queue_redraw()
	await process_frame;RenderingServer.force_draw(true);await process_frame
	ck(TREE.navigation_state()==navigation_before,"rendering does not write navigation "+name)
	if OS.get_cmdline_user_args().has("--single") and name!="01-local-branches":return
	ck(viewport.get_texture().get_image().save_png(OUT+name+".png")==OK,"native capture "+name)
func click(action:String):
	var buttons=g.buttons.filter(func(b):return b.action==action and b.enabled)
	ck(not buttons.is_empty(),"registered native control "+action)
	if buttons.is_empty():return
	var e=InputEventMouseButton.new();e.position=buttons[0].rect.get_center();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;g._input(e)
	e=InputEventMouseButton.new();e.position=buttons[0].rect.get_center();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=false;g._input(e)
func test():
	if DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(OUT)
	viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	g=preload("res://tests/fixtures/travel_fixture_v64.gd").new();viewport.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
	g.run.items=[g.piece("weapon_21020044","atlas-a",0,0),g.piece("spicy_meat","atlas-b",2,0)]
	g.run.stash=[g.piece("mat_43020051","atlas-c",0,0),g.piece("tube","atlas-d",0,0)]
	var before=g.run.duplicate(true);var disk=FileAccess.get_file_as_bytes(g.storage.root_path+"run.json")
	g._open_item_details(g.run.items[0],"board");g.ITEM_PANEL.action(g,"detail_recipes")
	var painter=g.ITEM_PANEL.atlas_painter(g)
	var fields=painter.get_property_list().map(func(property):return property.name)
	ck(not fields.has("game") and not fields.has("run") and not fields.has("inventory"),"drawing port does not expose game state")
	await shot("01-local-branches")
	ck(g.buttons.filter(func(b):return b.action.begins_with("atlas_recipe:")).size()<=3,"at most three immediate choices on screen")
	click("atlas_recipe:V124_01");await shot("02-selected-trade")
	ck(TREE.current_recipe().id=="V124_01","native choice selects exact branch")
	click("atlas_focus:weapon_21020104");await shot("03-next-branches")
	ck(TREE.focus_kind=="weapon_21020104","native successor opens its own nearby branches")
	click("atlas_history");await shot("04-restored-branch")
	ck(TREE.focus_kind=="weapon_21020044" and TREE.current_recipe().id=="V124_01","back restores focus and exact selected recipe")
	TREE.open(g,"weapon_21010064");await shot("05-merged-target")
	click("atlas_direction:incoming");await shot("06-source-recipes")
	var candidates=TREE.incoming_all("weapon_21010064")
	var alternative=candidates.filter(func(recipe):return recipe.id=="V124_04")[0]
	var at=candidates.find(alternative);TREE.option_page=at/3;await shot("07-source-alternative")
	click("atlas_recipe:V124_04");await shot("08-exact-source-materials")
	ck(TREE.current_recipe().id=="V124_04" and TREE.current_recipe().base=="weapon_21010104","native merged target binds selected source ingredients")
	TREE.open(g,"tube");await shot("09-material-network")
	if TREE.option_rows(g.run,"tube").size()>3:
		click("atlas_options_next");await shot("10-material-next-page")
		ck(TREE.option_page==1,"shared material choices paginate")
	TREE.open(g,"weapon_21020074");await shot("12-feijing-three-routes")
	ck(TREE.option_rows(g.run,"weapon_21020074").size()==3,"native Feijing exposes its three distinct directions")
	click("atlas_close");await shot("11-return-to-preparation")
	ck(g.overlay.is_empty(),"native close returns to preparation")
	ck(g.run==before and FileAccess.get_file_as_bytes(g.storage.root_path+"run.json")==disk,"native browsing never changes run or saved bytes")
	g.queue_free();await process_frame
	print("NATIVE_RECIPE_ATLAS_V124 ",checks," checks, ",failures," failures");quit(1 if failures else 0)
