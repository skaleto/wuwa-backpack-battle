extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
var g
var view
func _initialize():
 root.unfocusable=true;root.mode=Window.MODE_MINIMIZED
 AudioServer.set_bus_mute(0,true);call_deferred("capture")
func frame(label:String):
 g.queue_redraw();await process_frame;await process_frame;RenderingServer.force_draw(true)
 view.get_texture().get_image().save_png("res://build/qa/organizer/"+label+".png")
func capture():
 DirAccess.make_dir_recursive_absolute("res://build/qa/organizer")
 view=SubViewport.new();view.size=Vector2i(1440,960);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 g=G.new();view.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
 g.motion.modal_value=0;g.motion.modal_target=0;g.paint_alpha=1
 await frame("before")
 g._begin_organization()
 var bag=g.run.bags[0].duplicate(true);bag.x=5;bag.y=4
 g.pocket_organizer.move(g.run,bag,"board",g.inventory)
 await frame("organizing")
 g._finish_organization();await frame("finished")
 g.stash_transfer.clear();await frame("stored")
 g.queue_free();await process_frame;quit()
