extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const OUT="res://build/qa/qhd/native/"
var game
func _initialize()->void:
 root.unfocusable=true;root.mode=Window.MODE_MINIMIZED;AudioServer.set_bus_mute(0,true)
 root.size=Vector2i(2560,1440)
 root.content_scale_size=Vector2i(1440,960)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_KEEP
 RenderingServer.viewport_set_update_mode(root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
 DirAccess.make_dir_recursive_absolute(OUT);call_deferred("check")
func shot(name:String)->void:
 game.queue_redraw();await process_frame;RenderingServer.force_draw(true);await process_frame
 var img=root.get_texture().get_image()
 assert(root.size==Vector2i(2560,1440),"native QHD window")
 assert(img!=null and img.get_size()==Vector2i(2160,1440),"1440p content rendered directly, with side letterboxing")
 assert(img.save_png(OUT+name+".png")==OK)
func click(logical:Vector2)->void:
 var at=root.get_final_transform()*logical
 game.set_process_input(true)
 var move=InputEventMouseMotion.new();move.position=at;root.push_input(move,false)
 for down in [true,false]:
  var event=InputEventMouseButton.new();event.position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,false)
 game.set_process_input(false)
func target(action:String)->Vector2:
 for button in game.buttons:
  if button.action==action:return button.rect.get_center()
 assert(false,"missing action: "+action);return Vector2.ZERO
func check()->void:
 root.mode=Window.MODE_MINIMIZED
 if root.mode!=Window.MODE_MINIMIZED:printerr("FAIL capture window must remain minimized");quit(1);return
 game=G.new();root.add_child(game);await process_frame;game.set_process(false);game.set_process_input(false)
 game.screen="camp";game.camp_age=3;game.selection_age=3;game.transition_image=null;game.motion.transition_left=0
 await shot("01-home")
 click(target("settings"))
 print("QHD INPUT mouse ",game.mouse," overlay ",game.overlay)
 assert(game.overlay=="settings","physical 2K click maps to the settings button")
 game._process(.4);await shot("04-settings")
 click(target("settings:toggle:effects"));assert(game.sound_settings.effects_muted)
 click(target("settings:back"));assert(game.overlay.is_empty())
 game._process(.4)
 game.screen="game";game.joined_slice();await shot("02-preparation")
 var item=game.run.items[0]
 var center=game._board_to_screen(game._item_rect(item,game.BOARD).get_center())
 click(center);assert(game.overlay=="item_details" and game.detail_item.uid==item.uid,"scaled physical item click hits the same item")
 game._close_item_details();game._process(.4)
 game._start_battle();game.battle_entry_age=1;game.motion.transition_left=0;game.transition_image=null
 await shot("03-battle")
 click(target("pause"));assert(game.paused)
 click(target("speed"));assert(game.speed==2)
 click(target("skip"));assert(game.skip_requested)
 var probe=Window.new();probe.visible=false;probe.force_native=true;probe.unfocusable=true
 root.add_child(probe)
 var usable=DisplayServer.screen_get_usable_rect(probe.current_screen)
 game.DESKTOP_WINDOW.configure(probe)
 if probe.size!=game.DESKTOP_WINDOW.fit(usable.size) or probe.visible:
  printerr("FAIL desktop fitting on hidden native window");quit(1);return
 probe.queue_free()
 game.queue_free();await process_frame;print("PASS QHD: 2560x1440 window / 2160x1440 content, scaled input, minimized unfocusable root");quit()
