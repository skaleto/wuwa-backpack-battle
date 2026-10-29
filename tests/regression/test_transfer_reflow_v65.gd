extends SceneTree
## Consecutive real drags must share one displayed stash layout, including flights.
const OUT="res://build/qa/ui-v65/native-input/"
class ObservedGame extends "res://tests/fixtures/travel_fixture_v64.gd":
	var icon_calls:Array=[]
	var checkpoints:Array=[]
	var transfer_only=false
	var slot_queries:Array=[]
	func _draw():
		icon_calls.clear();checkpoints.clear();slot_queries.clear()
		if transfer_only:
			_basis();_draw_stash_transfers()
		else:super._draw()
		checkpoints.append({"basis":draw_basis,"alpha":paint_alpha,"offset":paint_offset})
	func _draw_icon(kind:String,rect:Rect2,rotation_value:int,alpha:float=1.0,selected:bool=false)->void:
		icon_calls.append({"kind":kind,"rect":rect,"alpha":alpha})
		super._draw_icon(kind,rect,rotation_value,alpha,selected)
	func _draw_drag():
		super._draw_drag()
		checkpoints.append({"basis":draw_basis,"alpha":paint_alpha,"offset":paint_offset})
	func _stash_rect(index:int)->Rect2:
		if transfer_only:slot_queries.append(index)
		return super._stash_rect(index)

var game
var checks=0
var failures=0
func _initialize():call_deferred("test")
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func button(at:Vector2,down:bool):
	var e=InputEventMouseButton.new();e.position=at;e.pressed=down;e.button_index=MOUSE_BUTTON_LEFT;game._input(e)
func move(at:Vector2):
	var e=InputEventMouseMotion.new();e.position=at;game._input(e)
func key(code:int):
	var e=InputEventKey.new();e.keycode=code;e.pressed=true;game._input(e)
func board()->Vector2:return game._board_to_screen(game.BOARD+Vector2.ONE*game.CELL*.5)
func redraw():
	game.queue_redraw();await process_frame
	if DisplayServer.get_name()!="headless":RenderingServer.force_draw(true);await process_frame
func shot(name:String):
	await redraw()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+name+".png")
func reset(skin:String):
	game.transfer_only=false
	game.reset_slice();game._clear_feedback();game.set_visual_skin(skin,false);game.buttons=[]
	game.motion.modal_value=0;game.motion.modal_target=0;game.motion.last_overlay=""
	game.run.items=[game.piece("w_sword","target",0,0)];game.run.primary="target"
	game.run.stash=[game.piece("turtle","stored",0,0)]
	game.run.shop[1]={"kind":"whiff","locked":false};game.run.gold=20
func replace_first():
	button(game._offer_rect(1).get_center(),true);move(board());button(game.mouse,false)
func begin_follow_on():
	button(game._stash_rect(0).get_center(),true);move(board())
func stash_swords()->Array:
	return game.icon_calls.filter(func(v):return v.kind=="w_sword" and v.rect.position.y>680)
func test():
	DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1440,960)
	game=ObservedGame.new();root.add_child(game);await process_frame
	game.set_process(false);game.set_process_input(false)
	for skin in ["chibi","original"]:
		reset(skin);replace_first()
		check(game.stash_transfer.flights.size()==1,skin+" first replacement queues one transfer")
		var saved_run=game.run.duplicate(true)
		var flight=game.stash_transfer.flights[0]
		flight.age=.339
		begin_follow_on()
		var preview=game._item_drop_preview()
		check(preview.ok and preview.run.stash[0].uid=="target" and preview.run.stash[1].kind=="whiff",skin+" next preview shifts the flying item to slot zero")
		await shot(skin+"-07-rapid-preview")
		var swords=stash_swords()
		check(swords.size()==1 and swords[0].rect.get_center().distance_to(game._stash_rect(0).get_center())<5,skin+" existing flight approaches displayed slot zero without duplication")
		check(game.icon_calls.any(func(v):return v.kind=="whiff" and v.rect==game._stash_rect(1).grow(-3) and is_equal_approx(v.alpha,.4)),skin+" next displaced ghost occupies its own slot one")
		check(game.run==saved_run,skin+" follow-on drawing preserves the committed run")
		check(game.checkpoints.all(func(v):return v.basis==Transform2D.IDENTITY and v.alpha==1.0 and v.offset==Vector2.ZERO),skin+" drag and frame restore transform alpha and offset")
		# Isolate only the transfer draw to observe which slot its settle cue uses.
		flight.age=.36;game.transfer_only=true;await redraw()
		check(game.slot_queries==[0] and game.icon_calls.is_empty(),skin+" settle cue uses preview slot zero without replaying the icon")
		game.transfer_only=false;await shot(skin+"-08-rapid-settle")
		swords=stash_swords()
		check(swords.size()==1 and swords[0].rect==game._stash_rect(0).grow(-3),skin+" landed survivor appears once in preview slot zero")
		key(KEY_ESCAPE)
		check(game.run==saved_run and game.dragging.is_empty(),skin+" cancel preserves the prior committed displacement")
		game.transfer_only=true;await redraw()
		check(game.slot_queries==[1],skin+" cancel restores the settle cue to committed slot one")
		game.transfer_only=false;await redraw();swords=stash_swords()
		check(swords.size()==1 and swords[0].rect==game._stash_rect(1).grow(-3),skin+" cancel restores the stored survivor to committed slot one")
		game.stash_transfer.update(.2,game.run.stash.map(func(v):return v.uid),"")
		check(game.stash_transfer.flights.is_empty(),skin+" completed transfer expires")
		# Commit the follow-on while both displacements can still be in flight.
		reset(skin);replace_first();game.stash_transfer.flights[0].age=.339
		var previous_flight=game.stash_transfer.flights[0].duplicate(true)
		begin_follow_on();preview=game._item_drop_preview();button(game.mouse,false)
		check(game.run==preview.run,skin+" rapid follow-on release commits the displayed arrangement")
		check(game.stash_transfer.flights.size()==2 and game.stash_transfer.flights[0]==previous_flight,skin+" follow-on queues only the new displacement and retains prior flight state")
		await shot(skin+"-09-rapid-commit");swords=stash_swords()
		check(swords.size()==1 and swords[0].rect.get_center().distance_to(game._stash_rect(0).get_center())<5,skin+" prior flight remains at the new committed slot")
		game.stash_transfer.update(.6,game.run.stash.map(func(v):return v.uid),"");await redraw()
		check(game.stash_transfer.flights.is_empty() and game.inventory.validate_run(game.run),skin+" both transfers settle with valid inventory")
		# A player can re-grab a committed target before the visual flight lands.
		reset(skin);replace_first()
		var old=game.stash_transfer.flights[0].piece.duplicate(true)
		game.run.stash[-1].rotation=3
		check(game.stash_transfer.flights[0].piece==old,skin+" flight retains an independent original snapshot")
		button(game._stash_rect(1).get_center(),true)
		game.stash_transfer.update(0,game.run.stash.map(func(v):return v.uid),str(game.dragging.get("uid","")))
		check(game.stash_transfer.flights.is_empty(),skin+" grabbing a transfer target clears its flight")
		key(KEY_ESCAPE)
	print("TRANSFER_REFLOW_V65: ",checks," checks, ",failures," failures")
	game.queue_free();await process_frame;quit(1 if failures else 0)
