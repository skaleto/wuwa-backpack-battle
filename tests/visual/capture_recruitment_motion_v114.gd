extends SceneTree
## Actual native render, deterministic presentation clock, hidden isolated game.
const G=preload("res://tests/fixtures/travel_fixture_v114.gd")
const R=preload("res://scripts/party/recruitment_v114.gd")
const OUT="/tmp/resonance-recruitment-motion-v114/"
var port:SubViewport
func _initialize()->void:
	root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true)
	DirAccess.make_dir_recursive_absolute(OUT);call_deferred("capture")
func click(g,p:Vector2)->void:
	for pressed in [true,false]:
		var event=InputEventMouseButton.new();event.position=p;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;g._input(event)
func capture()->void:
	port=SubViewport.new();port.size=Vector2i(1440,960);port.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(port)
	var g=G.new();port.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
	g.run.round=4;assert(R.open_draft(g.inventory,g.run,3));g.run.recruitment.candidates=["role_1302","role_1207","role_1504"];g._sync_recruitment()
	for frame in 165:
		if frame==51:click(g,Vector2(720,400))
		if frame==93:click(g,Vector2(720,895))
		g._process(1.0/30);g.set_process(false);g.queue_redraw()
		await process_frame;RenderingServer.force_draw(true);await process_frame
		assert(port.get_texture().get_image().save_png(OUT+"frame-%04d.png"%frame)==OK)
		if frame%30==0:print("MOTION_FRAME ",frame)
	assert(g.run.supports==["role_1207"] and g.run.phase=="shop")
	g.queue_free();await process_frame;print("MOTION_COMPLETE ",OUT);quit()
