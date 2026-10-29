extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const P=preload("res://scripts/ui/items/icon_projection.gd")
const GEO=preload("res://scripts/ui/items/art_geometry.gd")
var game
func _initialize():call_deferred("measure")
func measure():
	var begin=Time.get_ticks_usec()
	game=G.new();root.add_child(game);game.screen="camp";game.queue_redraw()
	await process_frame;await process_frame
	var camp=(Time.get_ticks_usec()-begin)/1000.0
	game.set_process(false)
	begin=Time.get_ticks_usec();game._action("start");var action=(Time.get_ticks_usec()-begin)/1000.0
	game.queue_redraw();await process_frame;await process_frame
	var first=(Time.get_ticks_usec()-begin)/1000.0
	var rows=[]
	for kind in ["w_sword","w_rectifier","turtle","mat_43020011"]:
		var image=Image.new();image.load_png_from_buffer(FileAccess.get_file_as_bytes(game.SKIN.item_path(kind)))
		begin=Time.get_ticks_usec();var fresh=P.descriptor(image,game.SKIN.item_angle(kind),false);var scan=(Time.get_ticks_usec()-begin)/1000.0
		begin=Time.get_ticks_usec();var cached=GEO.descriptor(kind,0,image);var read=(Time.get_ticks_usec()-begin)/1000.0
		assert(fresh==cached);rows.append({"kind":kind,"scan_ms":scan,"cached_ms":read})
	print(JSON.stringify({"headless_cpu_only":true,"camp_first_draw_ms":camp,"start_action_ms":action,"start_through_draw_ms":first,"geometry":rows}))
	game.queue_free();await process_frame;quit()
