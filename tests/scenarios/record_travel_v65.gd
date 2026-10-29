extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const OUT="res://build/qa/ui-v65/video-frames/"
var game
func _initialize():call_deferred("record")
func pointer(at:Vector2,down:bool):
	var event=InputEventMouseButton.new();event.position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;game._input(event)
func move(at:Vector2):
	var event=InputEventMouseMotion.new();event.position=at;game._input(event)
func record():
	if DisplayServer.get_name()=="headless":quit(1);return
	DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1440,960)
	game=G.new();root.add_child(game);await process_frame
	game.set_process(false);game.set_process_input(false);game.set_visual_skin("chibi",false);game.joined_slice()
	var offer=game._offer_rect(1).get_center()
	var destination=game._board_to_screen(game.BOARD+Vector2(.5,1.5)*game.CELL)
	for n in 96:
		if n<24:move(Vector2(1189,142))
		if n==24:pointer(offer,true)
		if n>=24 and n<48:move(offer.lerp(destination,smoothstep(0,1,(n-24)/23.0)))
		if n==48:pointer(destination,false)
		if n>=65:move(Vector2(940,775))
		game._process(1.0/24.0);game.queue_redraw();await process_frame;RenderingServer.force_draw(true)
		root.get_texture().get_image().save_png(OUT+("%03d.png"%n))
	print("V65 RECORD: actual drag replacement ends with ",game.run.stash.size()," stored items; gold ",game.run.gold)
	game.queue_free();await process_frame;quit()
