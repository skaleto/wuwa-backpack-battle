extends SceneTree
const G=preload("res://tests/fixtures/playable_fixture_v50.gd")
var game
var checks:Array=[]
var anchor:Transform2D
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	checks.append({"ok":ok,"label":label})
	if not ok:printerr("FAIL ",label)
func tick(n:int=1):
	for i in n:
		game._process(1.0/60);game.queue_redraw();await process_frame
		if DisplayServer.get_name()!="headless":RenderingServer.force_draw(true,1.0/60)
func at(x:float,y:float)->Vector2:return game._board_to_screen(game.BOARD+Vector2(x,y)*game.CELL)
func move(p:Vector2):
	var e=InputEventMouseMotion.new();e.position=p;game._input(e);await tick()
func button(down:bool,id:int=MOUSE_BUTTON_LEFT):
	var e=InputEventMouseButton.new();e.position=game.mouse;e.button_index=id;e.pressed=down;game._input(e)
func stable(label:String):
	check(game._board_transform().is_equal_approx(anchor),label+" keeps immediate cell origin and pitch")
	for n in 16:
		await tick()
		check(game._board_transform().is_equal_approx(anchor),label+" keeps cell origin and pitch at frame "+str(n))
func snapshot()->Dictionary:
	return {"run":game.run.duplicate(true),"opponent":game.opponent.duplicate(true),"combat":game.combat.duplicate(true),"cursor":game.event_cursor,"time":game.combat_time,"paused":game.paused,"speed":game.speed}
func shot(name:String):
	if DisplayServer.get_name()=="headless":return
	game.queue_redraw();await process_frame;RenderingServer.force_draw(true)
	root.get_texture().get_image().save_png("res://build/qa/demo-v51/after/"+name+".png")
func run():
	DirAccess.make_dir_recursive_absolute("res://build/qa/demo-v51/checks");DirAccess.make_dir_recursive_absolute("res://build/qa/demo-v51/after")
	root.size=Vector2i(1440,960);game=G.new();root.add_child(game);await process_frame;game.set_process(false);game.set_process_input(false)
	for skin in ["original","chibi","paper"]:
		game.reset_slice();game.set_visual_skin("chibi" if skin=="paper" else skin,false)
		game.SKIN.set_bag_style("paper" if skin=="paper" else "patchwork",false)
		game.run.items=[];game.run.primary="";game.run.stash=[];game.run.gold=50
		game.run.bags=[game.piece("satchel","b1",0,0),game.piece("strip","b2",3,0)]
		game.run.shop[5]={"kind":"pouch","locked":false};game.motion.modal_value=0;game.motion.modal_target=0
		anchor=game._board_transform();await tick(18)
		if skin=="original":check(game.buttons.all(func(b):return b.action!="bag_style"),"original skin does not expose Q bag styling controls")
		var expected=Rect2(at(0,0),at(8,6)-at(0,0))
		check(game._board_screen_rect().is_equal_approx(expected),skin+" visible placement domain equals all 8 by 6 logical cells")
		await shot(skin+"-bag-move-before")
		await move(at(3.5,.5));button(true);await move(at(3.5,1.5));button(false)
		check(game.run.bags[1].y==1,skin+" empty-cell pointer drag moves the independent strip")
		await stable(skin+" bag move");await shot(skin+"-bag-move-after")
		await move(at(3.5,1.5));button(true);button(true,MOUSE_BUTTON_RIGHT);button(false,MOUSE_BUTTON_RIGHT);await move(at(4.5,2.5));await shot(skin+"-bag-rotate-held");button(false)
		check(game.run.bags[1].rotation==1 and game.run.bags[1].x==2 and game.run.bags[1].y==2,skin+" right rotation commits a legal rejoin")
		await stable(skin+" bag rotation");await shot(skin+"-bag-rotate-after")
		var legal_state=game.run.duplicate(true)
		await move(at(2.5,2.5));button(true);await move(at(.5,.5));await shot(skin+"-bag-invalid");button(false)
		check(game.run==legal_state,skin+" invalid overlap preserves exact ownership and currency")
		await stable(skin+" rejected bag move")
		await move(game._offer_rect(5).position+Vector2(60,40));button(true);await move(at(.5,2.5));button(false)
		check(game.run.bags.size()==3 and game.run.shop[5].is_empty(),skin+" bag purchase grows coverage through real pointer input")
		await stable(skin+" bag purchase");await shot(skin+"-fixed-lattice")
		await move(at(.5,3.5));button(true);await move(game._sell_rect().get_center());button(false)
		check(game.overlay=="sell_bag",skin+" empty bag release opens sell confirmation")
		game._action("sell_bag_confirm");await stable(skin+" bag removal")
		check(game.run.bags.size()==2,skin+" confirmed removal keeps remaining legal coverage")
		if skin!="chibi":continue
		await tick(18)
		var controls=game.buttons.filter(func(b):return b.action=="bag_style" and b.enabled)
		check(controls.is_empty(),"Q preparation keeps the approved first draft without a legacy style pill")
		var before=snapshot();var disk=game.storage.resume().duplicate(true)
		var skin_before=game.SKIN.current
		for n in 2:
			game._action("bag_style");await tick(18)
			check(snapshot()==before and game.storage.resume()==disk,"bag style toggle preserves gameplay, replay and Storage "+str(n))
			check(game.SKIN.current==skin_before and game._board_transform().is_equal_approx(anchor),"bag style toggle preserves full skin and exact lattice "+str(n))
			await shot("chibi-bag-style-"+str(n))
		var cfg=ConfigFile.new();cfg.load(game.SKIN.preference_path)
		check(cfg.has_section_key("display","bag_style") and cfg.get_value("display","skin")=="chibi","bag style shares only visual.cfg and preserves the skin preference")
		var style=cfg.get_value("display","bag_style")
		game.set_visual_skin("original",true);cfg.load(game.SKIN.preference_path)
		check(cfg.get_value("display","bag_style")==style and cfg.get_value("display","skin")=="original","F6 skin persistence retains independent bag style preference")
		game.set_visual_skin("chibi",true)
	var failures=checks.filter(func(v):return not v.ok).size()
	var f=FileAccess.open("res://build/qa/demo-v51/checks/"+("headless" if DisplayServer.get_name()=="headless" else "native")+"-stable-board.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"));f.close()
	print("V51 STABLE BOARD: ",checks.size()," checks, ",failures," failures")
	game.queue_free();await process_frame;quit(1 if failures else 0)
