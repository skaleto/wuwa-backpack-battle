extends SceneTree
const G=preload("res://tests/fixtures/playable_fixture_v50.gd")
var game
var checks=[]
var OUT="res://build/qa/demo-v50/skins/"
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="):OUT=arg.trim_prefix("--evidence-dir=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("run")
func check(ok:bool,label:String):
	checks.append({"ok":ok,"label":label})
	if not ok:printerr("FAIL ",label)
func at(x:float,y:float)->Vector2:return game._board_to_screen(game.BOARD+Vector2(x,y)*game.CELL)
func pointer(p:Vector2,down:bool,button:int=MOUSE_BUTTON_LEFT):
	var event=InputEventMouseButton.new();event.position=p;event.pressed=down;event.button_index=button;game._input(event)
func key(code:int):
	var event=InputEventKey.new();event.keycode=code;event.pressed=true;game._input(event)
func run():
	root.size=Vector2i(1440,960);game=G.new();root.add_child(game);await process_frame;game.set_process(false);game.set_process_input(false)
	for skin in ["original","chibi"]:
		game.reset_slice();game.set_visual_skin(skin,false);game.run.items=[game.piece("w_rectifier","cross",2,0)];game.run.stash=[];game.run.primary="cross"
		game.run.bags=[game.piece("satchel","b1",0,0),game.piece("pouch","b2",3,0)];game.capacity_pan_left=0;game.buttons=[];game.motion.modal_value=0
		var before=game.run.duplicate(true);var pose=game._board_transform()
		pointer(at(4.5,1.5),true)
		check(game.drag_origin=="bag" and game.dragging.get("uid","")=="b2",skin+" visible empty region grabs independent bag")
		check(game.run==before and game._board_transform()==pose,skin+" pickup leaves state and board coordinate mapping unchanged")
		pointer(at(4.5,1.5),true,MOUSE_BUTTON_RIGHT)
		check(game.dragging.rotation==1 and game.run==before,skin+" right button rotates pending bag only")
		key(KEY_ESCAPE);check(game.run==before and game.dragging.is_empty(),skin+" bag cancel is atomic")
		pointer(at(4.5,1.5),true);pointer(at(1.5,3.5),false)
		var moved=game.run.bags.filter(func(b):return b.uid=="b2")[0]
		check(moved.x==0 and moved.y==2,skin+" bag separates and rejoins along a different edge")
		var all=game.run.items+game.run.stash
		check(all.size()==1 and all[0].uid=="cross" and all[0].kind=="w_rectifier",skin+" crossing item stays one complete owned object")
		var after=game.run.duplicate(true)
		pointer(at(1.5,3.5),true);pointer(at(8.5,5.5),false)
		check(game.run==after,skin+" out-of-bounds release is atomic")
		game.queue_redraw();await process_frame
		if DisplayServer.get_name()!="headless":RenderingServer.force_draw(true);await process_frame
		game.storage.save(game.run)
		check(game.storage.resume().get("bags",[])==game.run.bags,skin+" bag arrangement persists in QA namespace")
	var failures=checks.filter(func(v):return not v.ok).size()
	var file=FileAccess.open(OUT+"pocket-input.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"));file.close()
	print("SKIN POCKET INPUT: ",checks.size()," checks, ",failures," failures");game.queue_free();await process_frame;quit(1 if failures else 0)
