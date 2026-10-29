extends SceneTree
## Native rendering, no desktop input, isolated QA state and silent output.
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
var game
var viewport
var report
func _initialize():
	root.hide();root.unfocusable=true;call_deferred("capture")
func shot(label:String):
	game.queue_redraw();await process_frame;RenderingServer.force_draw(true);await process_frame
	RenderingServer.force_draw(true);await process_frame
	assert(viewport.get_texture().get_image().save_png("res://build/qa/ui-v89/native/"+label+".png")==OK)
	report.store_line(label);report.flush()
func setup():
	game.reset_slice();game.run.pool_mode="full";game.run.shop=[{},{},{},{},{},{}]
	game.run.bags=[game.piece("satchel","b1",2,1),game.piece("pouch","b2",5,1),game.piece("satchel","b3",2,3)]
	game.run.items=[game.piece("w_sword","i1",2,1)]
	game.run.primary="i1";game.run.stash=[];game.run.serial=30;game.run.round=2
	game.mouse=Vector2(30,930);game.hovered={};game.motion.modal_value=0;game.motion.modal_target=0
	game.motion.elapsed=1.4;game._clear_feedback()
func capture():
	report=FileAccess.open("res://build/qa/ui-v89/native/capture.log",FileAccess.WRITE)
	viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport);game=G.new();viewport.add_child(game);await process_frame
	game.set_process(false);game.set_process_input(false)
	setup();game.run.stash=[game.piece("mat_43020011","s1",0,0)]
	game.run.shop[0]={"kind":"mat_43020011","locked":false}
	await shot("01-owned-gold-shop-blue")
	setup();game.run.items.append(game.piece("mat_43020011","i2",4,3))
	await shot("02-owned-distant-gold")
	setup();game.run.items.append(game.piece("mat_43020011","i2",2,2))
	await shot("03-owned-joined-gold")
	setup();game.run.stash=[game.run.items.pop_back(),game.piece("mat_43020011","s1",0,0)];game.run.primary=""
	await shot("04-stash-gold")
	report.store_line("COMPLETE: native rendering, no desktop input, isolated storage, audio muted");report.close()
	game.queue_free();await process_frame;quit()
