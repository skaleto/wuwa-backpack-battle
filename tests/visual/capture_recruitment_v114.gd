extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v114.gd")
const R=preload("res://scripts/party/recruitment_v114.gd")
const OUT="res://build/qa/recruitment-v114/native/"
var viewport:SubViewport
var images=[]
func _initialize()->void:
	root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true)
	DirAccess.make_dir_recursive_absolute(OUT);call_deferred("capture")
func shot(g,name:String)->void:
	g.queue_redraw();g.recruitment_view.queue_redraw();g.recruitment_view.foreground.queue_redraw()
	g.crew_setup_view.queue_redraw()
	for n in 3:await process_frame
	RenderingServer.force_draw(true);await process_frame
	assert(viewport.get_texture().get_image().save_png(OUT+name+".png")==OK)
	images.append(name);print("CAPTURE ",name)
func click(g,point:Vector2)->void:
	var move=InputEventMouseMotion.new();move.position=point;g._input(move)
	for down in [true,false]:
		var event=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;g._input(event)
func capture()->void:
	viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var g=G.new();viewport.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
	g.run.round=4;assert(R.open_draft(g.inventory,g.run,3))
	g.run.recruitment.candidates=["role_1302","role_1207","role_1504"]
	g._sync_recruitment();g.recruitment_view.advance(.22);await shot(g,"01-curtain-opening")
	g.recruitment_view.advance(.36);await shot(g,"02-cards-rising")
	g.recruitment_view.advance(.8);click(g,Vector2(700,400));g.recruitment_view.advance(.2)
	await shot(g,"03-round3-selected")
	click(g,Vector2(140,880));await shot(g,"04-backpack-peek")
	click(g,Vector2(1190,144))
	var before_gold=g.run.gold;click(g,Vector2(721,895))
	assert(g.run.phase=="shop" and g.run.gold==before_gold and g.run.supports==["role_1207"])
	g.recruitment_view.advance(.36);await shot(g,"05-card-dissolve")
	g.recruitment_view.advance(.46);await shot(g,"06-avatar-arrival")
	g._process(.4);g.set_process(false);await shot(g,"07-return-to-shop")
	g.crew_setup_view.close();g.run.round=7;assert(R.open_draft(g.inventory,g.run,6))
	g.run.recruitment.candidates=["role_1302","role_1505","role_1504"]
	g._sync_recruitment();g.recruitment_view.advance(1.5);click(g,Vector2(1100,400));g.recruitment_view.advance(.2)
	await shot(g,"08-round6-bonds")
	g.recruitment_view.clear();g.run.phase="shop";g.run.recruitment.candidates=[];g.run.recruitment.node=3
	g.run.items=[g.piece("w_sword","i1",0,0),g.piece("w_sword","i2",0,1),g.piece("medical","i3",5,2)]
	g.run.bags=preload("res://tests/fixtures/capacity_fixture_v111.gd").full_bags(g.inventory);g.run.serial=100
	g._open_crew_setup("volley");await shot(g,"09-crew-setup-options")
	click(g,Vector2(960,490));await shot(g,"10-crew-setup-selected")
	click(g,Vector2(1200,810));assert(g.run.recruitment.config.volley==["i1","i2"])
	await shot(g,"11-crew-setup-applied")
	g.run.roster=["role_1302","role_1505"];g.run.supports=g.run.roster.duplicate()
	g.run.items=[g.piece("medical","i1",0,0),g.piece("flower","i2",6,3)];g.run.primary=""
	g.run.recruitment.config={"guard":["i1","i2"],"link":{"mode":"guard","source":"i1","target":"i2"}}
	g._open_crew_setup("guard");await shot(g,"12-remote-guard")
	FileAccess.open(OUT+"result.json",FileAccess.WRITE).store_string(JSON.stringify({"images":images,"isolated_storage":true,"hidden_unfocusable":true,"synthetic_input":true,"real_pointer_untouched":true},"\t"))
	g.queue_free();await process_frame;print("V114 NATIVE COMPLETE");quit()
