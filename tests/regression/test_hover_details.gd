extends SceneTree
## Pointer-level checks: the transient card shares the explicit details drawing path.
class ObservedGame extends "res://tests/fixtures/playable_fixture_v50.gd":
	var detail_draws:Array=[]
	var sounds:Array=[]
	var text_calls:Array=[]
	func _draw():
		detail_draws.clear();text_calls.clear();super._draw()
	func _text(value:String,pos:Vector2,size:int,color:Color)->void:
		text_calls.append(value);super._text(value,pos,size,color)
	func _draw_detail_icon(item:Dictionary,rect:Rect2)->void:
		detail_draws.append({"kind":item.kind,"rect":rect});super._draw_detail_icon(item,rect)
	func _sound(id:String,weapon:String="")->void:sounds.append(id)

var game
var failures=0
var checks=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func tick(n:int=1):
	for i in n:
		game._process(1.0/60);game.queue_redraw();await process_frame
func move(at:Vector2):
	var event=InputEventMouseMotion.new();event.position=at;game._input(event)
func button(pressed:bool,which:int=MOUSE_BUTTON_LEFT):
	var event=InputEventMouseButton.new();event.position=game.mouse;event.button_index=which;event.pressed=pressed;game._input(event)
func at(x:float,y:float)->Vector2:return game._board_to_screen(game.BOARD+Vector2(x,y)*game.CELL)
func shown(kind:String)->bool:return game.detail_draws.any(func(row):return row.kind==kind)
func run():
	root.size=Vector2i(1440,960);game=ObservedGame.new();root.add_child(game);await process_frame
	game.set_process(false);game.set_process_input(false)
	game.reset_slice();game.motion.modal_value=0;game.motion.modal_target=0
	var before=game.run.duplicate(true);var saved=game.storage.resume().duplicate(true)
	var selection=game.detail_item.duplicate(true);var stars=game.star_click_uid
	game.sounds.clear()
	move(at(2.5,.5));await tick(10)
	check(game.detail_draws.is_empty(),"brief hover waits before showing details")
	await tick(7)
	check(shown("whiff"),"board dwell displays the shared full details card")
	var preview_text=game.text_calls.duplicate()
	check(game.overlay.is_empty() and game.detail_item==selection and game.star_click_uid==stars,"hover leaves overlay, pinned selection and star click untouched")
	check(game.run==before and game.storage.resume()==saved and game.sounds.is_empty(),"hover does not mutate run, save or audio")
	check(not game.buttons.any(func(b):return str(b.action).begins_with("detail")),"transient card registers no clickable controls")
	game._notification(Node.NOTIFICATION_WM_MOUSE_EXIT);await tick(20)
	check(game.detail_draws.is_empty(),"leaving the game window clears hover without a final mouse motion")
	move(Vector2(1410,938));await tick()
	check(game.detail_draws.is_empty(),"leaving immediately dismisses transient details")
	move(at(2.5,.5));await tick(10);move(at(.5,.5));await tick(10)
	check(game.detail_draws.is_empty(),"switching items restarts the dwell instead of inheriting elapsed time")
	move(at(2.5,.5));await tick(17);button(true);await tick()
	check(game.detail_draws.is_empty() and not game.dragging.is_empty(),"press immediately suppresses hover and lifts original item")
	button(false);await tick()
	check(game.overlay=="item_details" and game.detail_item.uid=="i2","click pins original hovered item")
	check(preview_text.all(func(value):return game.text_calls.has(value)),"pinned details retain every text value rendered by the full hover card")
	move(at(.5,.5));await tick(20)
	check(game.detail_item.uid=="i2" and shown("whiff"),"hovering another item cannot replace pinned details")
	game._action("detail_recipes");await tick()
	check(game.overlay=="item_recipes","pinned card retains recipe navigation")
	game.overlay="";game.motion.modal_value=0;game.motion.modal_target=0;game.motion.last_overlay=""
	game.run.shop[0]={"kind":"whiff","locked":true}
	move(game._offer_rect(0).position+Vector2(80,40));await tick(17)
	check(shown("whiff"),"shop item supports dwell preview")
	button(true);move(Vector2(1410,938));button(true,MOUSE_BUTTON_RIGHT);await tick()
	check(game.detail_draws.is_empty() and game.dragging.rotation==1,"right rotation during drag stays available and suppresses preview")
	button(false);await tick()
	game.run.stash=[game.piece("whiff","stash-hover",0,0)]
	move(game._stash_rect(0).get_center());await tick(17)
	check(shown("whiff"),"stash item supports dwell preview")
	game._action("menu");await tick(20)
	check(game.detail_draws.is_empty(),"menu suppresses transient details without mouse motion")
	game.reset_slice();game.motion.modal_value=0;game.motion.modal_target=0;game.motion.last_overlay=""
	game._start_battle();game.battle_entry_age=1.0
	move(game._detail_source_rect(game.run.items[1],"board").get_center());await tick(17)
	check(shown("whiff"),"battle board item supports dwell preview")
	var battle_time=game.combat_time
	var battle_run=game.run.duplicate(true);var battle_save=game.storage.resume().duplicate(true)
	await tick(17)
	check(game.combat_time>battle_time and not game.paused and game.overlay.is_empty(),"transient details do not pause the battle clock")
	check(game.run==battle_run and game.storage.resume()==battle_save,"battle hover changes neither frozen run nor saved battle")
	var enemy=game.opponent.items[0]
	move(game._detail_source_rect(enemy,"enemy").get_center());await tick(17)
	check(shown(enemy.kind) and game.hovered.origin=="enemy","enemy battle item supports dwell preview")
	game.queue_free();await process_frame
	print("HOVER DETAILS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
