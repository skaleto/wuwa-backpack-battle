extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
var g
var viewport
func _initialize():
 root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true);call_deferred("capture")
func frame(name:String):
 g.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(true)
 viewport.get_texture().get_image().save_png("res://build/qa/update-hover/"+name+".png")
func capture():
 if DisplayServer.get_name()=="headless":quit(2);return
 DirAccess.make_dir_recursive_absolute("res://build/qa/update-hover")
 viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 g=G.new();viewport.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
 g.screen="camp";g.overlay="settings";g.motion.modal_value=1;g.paint_alpha=1
 await frame("settings")
 g._settings_action("settings:updates");g.update_client.status="available"
 g.update_client.available={"version":"0.2.0-demo.2","notes":["物品悬停即可查看详情，点击固定卡片。","更新可在游戏内下载，重启后生效。"]}
 g.update_client.artifact={"kind":"patch","bytes":1835008};g.motion.modal_value=1
 await frame("update-available")
 g.update_client.status="downloading";g.update_client.downloaded=927123;g.update_client.total=1835008
 await frame("update-downloading")
 g.screen="game";g.overlay="";g.motion.modal_value=0;g.hover_details.pointer_active=true
 var item=g.run.items[0];g.mouse=g._board_to_screen(g._item_rect(item,g.BOARD).get_center(),0)
 g._sync_hover_details(.3);await frame("hover")
 g._open_item_details(item,"board");await frame("pinned")
 g.queue_free();await process_frame;print("UPDATE HOVER VISUAL OK");quit()
