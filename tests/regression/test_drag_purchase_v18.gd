extends SceneTree
const G=preload("res://scripts/game.gd")
const S=preload("res://scripts/storage/storage.gd")
var game
var checks=0
var failures=0

func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures+=1;printerr("FAIL: ",label)

func pointer(point: Vector2,down: bool,button: int=MOUSE_BUTTON_LEFT) -> void:
	var ev=InputEventMouseButton.new();ev.position=point;ev.pressed=down;ev.button_index=button
	game._input(ev)

func key(code: int) -> void:
	var ev=InputEventKey.new();ev.keycode=code;ev.pressed=true;game._input(ev)

func reset() -> void:
	game.run=game.inventory.new_run("jiyan",18);game.screen="game"
	game.run.shop[0]={"kind":"whiff","locked":true};game.run.gold=20
	game.dragging={};game.buttons=[];game.overlay="";game.motion.modal_value=0
	game.storage.save(game.run)

func pick() -> void:pointer(game._offer_rect(0).get_center(),true)

func board(x: int,y: int) -> Vector2:
	return game._board_to_screen(G.BOARD+Vector2(x+.5,y+.5)*G.CELL)

func _initialize() -> void:call_deferred("test")

func test() -> void:
	game=G.new();game.storage=S.new("user://qa-v18/drag/");game.muted=true
	root.add_child(game);await process_frame
	reset()
	var before=game.run.duplicate(true)
	var disk=game.storage.resume().duplicate(true)
	pick()
	check(not game.dragging.is_empty(),"shop press begins preview")
	check(game.run==before,"shop press changes no currency, ownership, offer, lock or serial")
	check(game.storage.resume()==disk,"shop press writes no purchase to save")
	pointer(game._offer_rect(0).get_center(),false)
	check(game.run==before and game.dragging.is_empty(),"return to shop cancels without buying")
	reset();before=game.run.duplicate(true);pick();pointer(Vector2(1400,930),false)
	check(game.run==before,"release outside destinations cancels")
	reset();before=game.run.duplicate(true);pick();key(KEY_ESCAPE)
	check(game.run==before and game.dragging.is_empty(),"Escape cancels pending purchase")
	reset();before=game.run.duplicate(true);pick();pointer(board(0,0),false)
	check(game.run.shop[0].is_empty() and game.run.stash.any(func(v):return v.uid==before.primary) and game.run.items.any(func(v):return v.kind=="whiff"),"occupied grid buys the incoming item and stashes the whole overlapping weapon")
	check(game.run.gold==before.gold-int(G.C.items.whiff.price) and game.run.serial==before.serial+1,"occupied-grid purchase charges exactly once")
	reset();before=game.run.duplicate(true);pick();pointer(board(7,5),false)
	check(game.run==before,"unpurchased grid rejects purchase atomically")
	reset();before=game.run.duplicate(true);pick();pointer(board(1,1),false)
	check(game.run.shop[0].is_empty() and game.run.items.size()==before.items.size()+1 and game.run.stash==before.stash,"valid grid release equips and removes offer")
	check(game.run.gold==before.gold-int(G.C.items.whiff.price) and game.run.serial==before.serial+1,"valid release charges exactly once")
	var committed=game.run.duplicate(true);pointer(board(1,1),false)
	check(game.run==committed,"duplicate release cannot charge again")
	check(game.storage.resume().get("gold",-1)==game.run.gold,"committed purchase is saved")
	reset();before=game.run.duplicate(true);pick();pointer(game._stash_mat_rect().get_center(),false)
	check(game.run.shop[0].is_empty() and game.run.stash.size()==1 and game.run.items==before.items,"storage release purchases into storage")
	reset()
	for n in range(6):game.run.stash.append(game.inventory.make_piece("nutrition","full"+str(n)))
	before=game.run.duplicate(true);pick();pointer(game._stash_mat_rect().get_center(),false)
	check(game.run.stash.size()==7 and game.run.gold==before.gold-int(G.C.items.whiff.price) and game.run.shop[0].is_empty(),"V103 seventh storage purchase charges once")
	reset()
	for n in range(6):game.run.stash.append(game.inventory.make_piece("nutrition","full"+str(n)))
	pick();pointer(board(1,1),false)
	check(game.run.shop[0].is_empty() and game.run.stash.size()==6 and game.run.items.size()==3,"full storage still allows direct valid board purchase")
	reset();game.run.gold=0;before=game.run.duplicate(true);pick();pointer(board(1,1),false)
	check(game.run==before,"insufficient currency cannot partially commit")
	reset();before=game.run.duplicate(true);key(KEY_1)
	check(game.run==before and not game.dragging.is_empty(),"keyboard pick also defers purchase")
	key(KEY_ESCAPE)
	reset();game.run.round=2;game.run.roster=["role_1403"];game.run.shop[0]={"kind":"weapon_21030024","locked":false}
	before=game.run.duplicate(true);pick()
	var initial=game.dragging.duplicate(true)
	var anchor=game.drag_offset
	pointer(board(1,1),true,MOUSE_BUTTON_RIGHT)
	check(game.dragging.rotation==1 and game.drag_offset==Vector2i(0,0),"right click rotates horizontal pistol while keeping original pickup offset")
	check(game.run==before,"rotation of a preview does not buy or choose primary")
	for n in range(3):pointer(board(1,1),true,MOUSE_BUTTON_RIGHT)
	check(game.dragging==initial and game.drag_offset==anchor,"four right rotations restore exact preview and anchor")
	key(KEY_R);check(game.dragging.rotation==1,"R and right click share rotation behavior")
	key(KEY_ESCAPE)
	reset();before=game.run.duplicate(true);pick();pointer(game._sell_rect().get_center(),false)
	check(game.run==before,"unbought preview cannot be sold for currency")
	reset();game.run.shop[0]={"kind":"tube","locked":false};game.run.round=2
	var echo=game.inventory.make_piece("whiff","echo");echo.x=1;echo.y=1;game.run.items.append(echo)
	before=game.run.duplicate(true);pick();pointer(board(1,1),false)
	check(game.run.shop[0].is_empty() and game.run.stash.any(func(v):return v.uid=="echo" and v==echo) and game.overlay.is_empty(),"material purchase displaces the whole echo without opening or applying enhancement")
	print("DRAG_V18: ",checks," checks, ",failures," failures")
	game.queue_free();await process_frame;quit(1 if failures else 0)
