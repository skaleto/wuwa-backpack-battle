extends SceneTree
const G=preload("res://scripts/game.gd")
const S=preload("res://scripts/storage/storage.gd")
var game
var failures=0
var checks=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func piece(kind: String,x: int,y: int,id: String,turn: int=0) -> Dictionary:
	var p=game.inventory.make_piece(kind,id);p.x=x;p.y=y;p.rotation=turn;return p
func reset() -> void:
	game.run=game.inventory.new_run("jiyan",26);game.screen="game";game.overlay="";game.bag_mode=false;game.relay_mode=false;game.dragging={};game.buttons=[];game.capacity_pan_left=0;game.motion.modal_value=0
	game.run.items=[];game.run.bags=[piece("satchel",0,0,"b1"),piece("pouch",3,0,"b2")];game.run.primary=""
func pointer(at: Vector2,down: bool,button: int=MOUSE_BUTTON_LEFT) -> void:
	var ev=InputEventMouseButton.new();ev.position=at;ev.pressed=down;ev.button_index=button;game._input(ev)
func board(x: float,y: float) -> Vector2:return game._board_to_screen(G.BOARD+Vector2(x,y)*G.CELL)
func _initialize() -> void:call_deferred("test")
func test() -> void:
	game=G.new();game.storage=S.new("user://qa-pockets-v26-tests/");game.muted=true;root.add_child(game);await process_frame
	game._action("start")
	check(game.run.bags[0].x==2 and game.run.bags[0].y==2 and game.inventory.validate_run(game.run),"fresh UI run starts centrally on the fixed canvas with legal items")
	reset();var before=game.run.duplicate(true)
	var handle_point=game._bag_handle(game.run.bags[1]).get_center()
	var original_transform=game._board_transform()
	pointer(handle_point,true);pointer(handle_point,false)
	check(game.run==before and game.overlay=="item_details","click inspects pocket without moving it")
	game.overlay="";game.motion.modal_value=0
	game.bag_mode=true
	check(game._board_transform()==original_transform,"normal and arrange modes share one coordinate mapping")
	game.bag_mode=false
	pointer(game._bag_handle(game.run.bags[1]).get_center(),true)
	check(game.drag_origin=="bag" and game.dragging.get("uid","")=="b2","visible grip directly drags a pocket without mode")
	check(game.run==before,"pickup is read-only")
	if not game.dragging.is_empty():
		pointer(board(.5,2.5),false)
		var moved=game.run.bags.filter(func(b):return b.uid=="b2")[0]
		check(moved.x==0 and moved.y==2,"pocket can be reassembled below starter")
		check(game.storage.resume().get("bags",[])==game.run.bags,"reassembled pockets persist")
	reset();pointer(board(4.5,1.5),true)
	check(game.dragging.get("uid","")=="b2","empty pocket cell directly grabs pocket")
	game.dragging={}
	reset();game.run.items=[piece("whiff",3,0,"echo")];game.run.primary="echo"
	pointer(board(3.5,.5),true)
	check(game.dragging.get("uid","")=="echo","item body still grabs item rather than pocket")
	game.dragging={}
	var inv=game.inventory
	reset();game.run.items=[piece("w_rectifier",2,0,"cross")];game.run.primary="cross"
	for n in range(6):game.run.stash.append(piece("nutrition",0,0,"s"+str(n)))
	before=game.run.duplicate(true)
	check(inv.place(game.run,game.run.bags[1].duplicate(true)) and game.run==before,"same-position pocket drop never ejects crossing items with full stash")
	reset();game.run.items=[piece("whiff",3,0,"echo")];game.run.primary="echo"
	var move=game.run.bags[1].duplicate(true);move.x=0;move.y=2;move.rotation=1
	check(inv.place(game.run,move),"pocket rotates and moves with contained echo")
	check(game.run.items[0].rotation==1 and inv.occupied(game.run.items[0]).all(func(c):return c in inv.occupied(move)),"contained item follows same rigid transform")
	before=game.run.duplicate(true);move.x=0;move.y=0
	check(not inv.place(game.run,move) and game.run==before,"overlap rejects atomically")
	move.x=6;move.y=4
	check(inv.place(game.run,move),"disconnected placement commits legally")
	before=game.run.duplicate(true)
	move.x=8
	check(not inv.place(game.run,move) and game.run==before,"out-of-bounds rejects atomically")
	check(not game.readable_icons_enabled,"original weapon proportions restored by default")
	check(game._ensure_icon("w_sword"),"selected weapon texture loads lazily")
	check(game.icons.w_sword is Texture2D if game.SKIN.is_chibi() else game.icons.w_sword is CompressedTexture2D,"selected skin uses its own weapon texture")
	for kind in G.C.items:
		if not G.C.items[kind].get("combat_v15",false):continue
		for turn in range(4):
			var display=game._projection_for(kind,turn,G.CELL)
			check(display.get("aspect",Vector2.ONE).is_equal_approx(Vector2.ONE),"original aspect "+kind+str(turn))
	check(inv.has_method("pocket_bonus"),"space bonuses available to UI and combat")
	if inv.has_method("pocket_bonus"):
		await effect_checks()
	print("POCKETS V26: ",checks," checks; ",failures," failures")
	game.queue_free();await process_frame;quit(1 if failures else 0)
func effect_checks() -> void:
	var inv=game.inventory
	reset();game.run.bags=[piece("strip",0,0,"fast",1),piece("satchel",0,1,"base")]
	var w=piece("w_sword",0,0,"w");game.run.items=[w];game.run.primary="w"
	check(is_equal_approx(inv.modifiers(w,[w],game.run).speed,.1),"weapon fully on acceleration pocket has ten percent shorter cooldown")
	var ctx=game.engine.begin(game.run,game.run,26)
	check(is_equal_approx(ctx.timers[0].w,float(G.C.items.w_sword.cooldown)*.9),"actual first cooldown includes pocket effect")
	w.y=1
	check(is_zero_approx(inv.modifiers(w,[w],game.run).speed),"moving weapon away removes bonus")
	reset();game.run.bags=[piece("satchel",0,0,"base"),piece("strip",3,0,"fast")]
	w=piece("w_rectifier",2,0,"w");game.run.items=[w];game.run.primary="w"
	check(is_equal_approx(inv.modifiers(w,[w],game.run).speed,.05),"cross-pocket item receives proportional bonus")
	reset();game.run.bags=[piece("corner",0,0,"echo-bag"),piece("pouch",1,0,"shield-bag")]
	# Use independent legal placements below for each effect.
	game.run.bags=[piece("corner",0,0,"echo-bag")]
	var e=piece("whiff",0,0,"e");game.run.items=[e];game.run.primary=""
	check(is_equal_approx(inv.modifiers(e,[e],game.run).multiplier,1.15),"echo amplification affects real modifier")
	check(is_equal_approx(inv.modifiers(piece("w_sword",0,1,"w"),[],game.run).multiplier,1),"echo pocket does not amplify weapon")
	game.run.bags=[piece("travel",0,0,"weapon-bag")];w=piece("w_sword",0,0,"w");game.run.items=[w];game.run.primary="w"
	check(is_equal_approx(inv.modifiers(w,[w],game.run).multiplier,1.08),"weapon pocket damage bonus")
	game.run.bags=[piece("pouch",0,0,"shield-bag")];game.run.items=[e];game.run.primary=""
	ctx=game.engine.begin(game.run,game.run,26)
	check(is_equal_approx(ctx.states[0].shield,2),"one occupied shield cell grants two real opening shield")
	game.run.items=[];ctx=game.engine.begin(game.run,game.run,26)
	check(is_zero_approx(ctx.states[0].shield),"empty shield pocket grants no shield")
	game.run.items=[piece("lamp",0,0,"lamp"),piece("whiff",1,0,"e")]
	ctx=game.engine.begin(game.run,game.run,26)
	check(ctx.states[0].get("content",{}).get("lamp_stacks",0)==1,"opening shield can safely trigger existing lamp trait")
	game.run.bags=[piece("corner",0,0,"echo-bag")];game.run.items=[e]
	ctx=game.engine.begin(game.run,game.run,26)
	game.engine.activate(ctx,0,e,1.0,false,"relay_attack")
	check(ctx.events.any(func(ev):return ev.kind=="pocket_trigger" and ev.uid=="echo-bag" and ev.target_uid=="e"),"amplified relay has matching pocket feedback")
	# A weapon case rewards its direct activation, not pre-existing derived mechanic budgets.
	game.run.bags=[piece("travel",0,0,"weapon-bag")];w=piece("w_rectifier",0,0,"w");game.run.items=[w];game.run.primary="w"
	ctx=game.engine.begin(game.run,game.run,26)
	game.engine.add_hit(ctx,0,w,10,1,false,"coordinated")
	check(is_equal_approx(ctx.totals[0].damage,10),"weapon case does not silently rebudget derived coordination")
	reset();game.run.bags=[piece("travel",0,0,"b1"),piece("strip",3,0,"b2"),piece("pouch",3,3,"b3")]
	game.run.items=[piece("w_sword",0,0,"w"),piece("whiff",3,0,"e")];game.run.primary="w"
	var foe=inv.new_run("yinlin",31)
	var f=game.engine.simulate(game.run,foe,33);var r=game.engine.simulate(foe,game.run,33)
	check(f.winner==-r.winner and is_equal_approx(f.frames[-1].sides[0].hp,r.frames[-1].sides[1].hp),"pocket effects remain side symmetric")
	check(f.events.any(func(v):return v.kind=="pocket_trigger"),"real activations identify contributing pockets in replay")
