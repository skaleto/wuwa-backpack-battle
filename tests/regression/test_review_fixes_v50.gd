extends SceneTree
const G=preload("res://tests/fixtures/review_fixture_v50.gd")
var OUT="res://build/qa/demo-v50/review-fixes/duration-032/"
var game
var checks:Array=[]
var samples:Array=[]
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="):OUT=arg.trim_prefix("--evidence-dir=").trim_suffix("/")+"/"
	call_deferred("run")
func check(ok:bool,label:String):
	checks.append({"ok":ok,"label":label})
	if not ok:printerr("FAIL ",label)
func tick(n:int=1):
	for i in n:
		game.reset_observations();game._process(1.0/60);game.queue_redraw();await process_frame
		if DisplayServer.get_name()!="headless":RenderingServer.force_draw(true,1.0/60)
func point(x:float,y:float,side:int=0)->Vector2:
	return game._board_to_screen((game.BOARD if side==0 else game.ENEMY_BOARD)+Vector2(x,y)*game.CELL,side)
func move(p:Vector2):
	var ev=InputEventMouseMotion.new();ev.position=p;game._input(ev);await tick()
func button(down:bool,id:int=MOUSE_BUTTON_LEFT):
	var ev=InputEventMouseButton.new();ev.position=game.mouse;ev.pressed=down;ev.button_index=id;game._input(ev)
func key(code:int):
	var ev=InputEventKey.new();ev.keycode=code;ev.pressed=true;game._input(ev);await tick()
func action(id:String,settle:int=16):
	var matches=game.buttons.filter(func(v):return v.action==id and v.enabled)
	check(not matches.is_empty(),"pointer action "+id)
	if matches.is_empty():return
	await move(matches[0].rect.get_center());button(true);button(false);await tick(settle)
func shot(name:String):
	if DisplayServer.get_name()=="headless":return
	# Hold simulation time while the native render thread finishes this sample.
	for i in range(2):
		game.reset_observations();game.queue_redraw();await process_frame;RenderingServer.force_draw(true,1.0/60)
	root.get_texture().get_image().save_png(OUT+name+".png")
func text_at(value:String)->bool:return game.drawn_text.any(func(v):return v.value==value)
func detail_rows()->Array:
	var rect=game._detail_card_rect()
	return game.drawn_text.filter(func(v):return v.pos.x>=rect.position.x+18 and v.pos.x<=rect.end.x-18 and v.pos.y>=rect.position.y+214 and v.pos.y<=rect.position.y+270).map(func(v):return v.value)
func until(time:float):
	for i in range(1800):
		if game.combat_time>=time:return
		await tick()
func run():
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size=Vector2i(1440,960);game=G.new();root.add_child(game);await process_frame;game.set_process(false);game.set_process_input(false)
	await tick(20)
	var before=game.run.duplicate(true)
	await action("forge");await action("forge_confirm");await move(point(.3,.4));await tick(20)
	var first=game.drawn_ghost.corner;var grid=Vector2(game.forge_output.x,game.forge_output.y)
	await shot("01-ghost-before")
	await move(game.mouse+Vector2(11,7))
	check(game.drawn_ghost.corner.is_equal_approx(first+Vector2(11,7)),"rendered forge body follows sub-cell mouse delta continuously")
	check(Vector2(game.forge_output.x,game.forge_output.y)==grid,"only forge footprint remains grid-snapped")
	await shot("02-ghost-subcell")
	var turn_center=game._held_center_screen()
	button(true,MOUSE_BUTTON_RIGHT);button(false,MOUSE_BUTTON_RIGHT);await tick()
	check(game.drag_turn_remaining<0,"forge uses animated center rotation")
	for n in range(10):
		var pose:Transform2D=game.drawn_ghost.pose
		check((pose*game._occupied_center(game._held_source_piece())).is_equal_approx(turn_center),"forge occupied center stays fixed during rotation "+str(n))
		await tick()
	await shot("03-ghost-rotating")
	for n in range(3):button(true,MOUSE_BUTTON_RIGHT);button(false,MOUSE_BUTTON_RIGHT);await tick(20)
	check(game.forge_output.rotation==0 and game.drag_offset==Vector2i.ZERO,"four forge rotations restore shape and original pickup offset")
	await move(point(2.5,.5));button(true);button(false);await tick()
	check(game.run==before and not game.forge_output.is_empty(),"invalid explicit release leaves all ownership and currency intact")
	await key(KEY_ESCAPE);check(game.run==before and game.forge_output.is_empty(),"Esc cancellation remains atomic after rotated preview")
	await action("forge");await action("forge_confirm");await move(point(.5,.5));button(true);button(false);await tick(24)
	check(game.run.items.size()==3 and game.run.serial==5,"legal explicit click commits output once")
	# Exercise a real move away and back to the square base edge.
	await move(point(2.5,.5));button(true);await move(point(3.5,.5));await tick(20);button(false);await tick(20)
	await move(point(3.5,.5));button(true);await move(point(2.5,.5));button(false);await tick(20)
	# Keep presentation expectations independent from live opponent supply policy.
	game.opponent=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/presentation-opponent-v50.json"))
	var prep=game._board_transform()
	await action("battle",0)
	check(game.transition_image==null,"battle entry has no copied whole-screen overlay")
	check(game._board_transform().is_equal_approx(prep),"battle entry starts at the exact preparation board transform")
	var previous:Vector2=game._board_to_screen(game.BOARD)
	var max_jump=0.0
	for n in range(21):
		await tick()
		var player=game.drawn_boards.filter(func(v):return v.side==0)
		var enemy=game.drawn_boards.filter(func(v):return v.side==1)
		check(player.size()==1,"one actual player board draw at entry sample "+str(n))
		var corner:Vector2=game._board_to_screen(game.BOARD)
		max_jump=maxf(max_jump,corner.distance_to(previous));previous=corner
		if n in [0,2,6,10,15,20]:
			samples.append({"tick":n,"active_elapsed":(n+1)/60.0,"entry_progress":game.battle_entry_age,"player_corner":[corner.x,corner.y],"pitch":game._board_transform().get_scale().x*game.CELL,"enemy_corners":enemy.map(func(v):return [v.corner.x,v.corner.y]),"combat_time":game.combat_time,"events":game.event_cursor})
			await shot("entry-%02d"%n)
		if n==2:
			check(game._board_transform().is_equal_approx(prep) and game.combat_time==0 and game.event_cursor==0,"shop retracts before board movement and combat events")
			check(not text_at(game.C.characters[game.opponent.leader].name),"retiring shop does not overlap incoming enemy portrait and HUD")
		if n==6:check(not game._board_transform().is_equal_approx(prep) and game.combat_time==0 and enemy.is_empty(),"same board moves before enemy entry and combat starts")
		if n==15:check(enemy.size()==1 and enemy[0].corner.x>796 and game.combat_time==0,"enemy board enters from the right after player board settles")
		if n==10:
			game._action("pause");var frozen=game._board_transform();var time=game.combat_time;var progress=game.battle_entry_age
			await tick(6);check(game._board_transform()==frozen and game.combat_time==time and game.battle_entry_age==progress,"pause freezes the real board transition and combat")
			game._action("pause")
		if n==18:check(game.battle_entry_age<1.0 and game.combat_time==0,"1x entry is still active at 0.3167 seconds")
		if n==19:check(game.battle_entry_age==1.0 and game.combat_time==0,"1x entry finishes in the first 60 Hz interval after 0.32 seconds, before combat")
	check(max_jump<51,"60 Hz board movement has no jump (max %.2f px)"%max_jump)
	check(is_equal_approx(game._board_transform().get_scale().x*game.CELL,66),"entry settles at battle pitch 66")
	await until(4.5);game.paused=true
	var weapon=game.inventory.primary_weapon(game.run)
	await move(game._battle_item_position(0,weapon.uid));button(true);button(false);await tick(20)
	check(game.overlay=="item_details" and game.detail_item.uid==weapon.uid,"battle item pointer opens existing details by UID")
	var rows=detail_rows()
	print("REVIEW current detail rows: ",rows)
	check(rows.has("本场追击") and rows.has("1 次") and rows.has("耗用印记") and rows.has("1 枚") and rows.has("实际提前") and rows.has("0.5 秒"),"details render only one elapsed chase, one mark, and actual 0.5 second advance")
	check(rows.size()<=6,"current-battle details have at most three label/value rows")
	await shot("04-weapon-current-details")
	await action("details_back");await move(point(2.5,.5));button(true);button(false);await tick(20)
	check(game.detail_item.uid=="i2" and detail_rows().has("0.5 秒"),"triggering echo details show its own elapsed chase advance")
	await shot("05-echo-current-details")
	await action("details_back");await move(point(4.5,.5));button(true);button(false);await tick(20)
	check(game.detail_item.uid=="i4" and not detail_rows().has("0.5 秒"),"unrelated turtle UID does not inherit weapon statistics")
	await action("details_back");game.paused=false;game._action("skip");await tick(24)
	await move(game._battle_item_position(0,weapon.uid));button(true);button(false);await tick(20)
	check(detail_rows().has("3 次") and detail_rows().has("5 枚") and detail_rows().has("1.5 秒"),"result item details expose final per-UID records")
	await shot("06-weapon-result-details")
	game.reset_slice();game.combat={};game.paused=false;game.speed=1;game.run.items=[]
	game.run.bags=[]
	for y in 2:
		for x in 8:game.run.bags.append(game.piece("strip","bag-%d-%d"%[x,y],x,y*3))
	var serial=0
	for cell in [Vector2i(0,0),Vector2i(2,0),Vector2i(4,0),Vector2i(6,0),Vector2i(0,2),Vector2i(2,2),Vector2i(4,2),Vector2i(6,2)]:
		serial+=1;game.run.items.append(game.piece("w_rectifier","i"+str(serial),cell.x,cell.y))
	game.run.primary="i1";game.run.serial=serial;await tick(20);await action("battle",0)
	await tick(4);game._action("speed");await tick(7)
	check(game.battle_entry_age<1.0 and game.combat_time==0,"mid-entry 2x change stays active at 0.1833 real seconds / 0.3 scaled seconds")
	await tick()
	check(game.battle_entry_age==1.0 and game.combat_time==0 and is_equal_approx(game._board_transform().get_scale().x*game.CELL,66),"mid-entry 2x change finishes by 0.2 real seconds with correct final pose, before combat")
	game.speed=1;await until(4.5);game.paused=true
	var waits=game._current_frame().waiting[0]
	var uid=""
	for candidate in waits:
		if waits[candidate]:uid=candidate;break
	check(not uid.is_empty(),"real stamina-starved fixture contains current waiting UID")
	await move(game._battle_item_position(0,uid));await tick(20)
	check(not text_at("体力不足"),"hover has no automatic status card; waiting remains on the actual item")
	await shot("07-waiting-hover")
	button(true);button(false);await tick(20)
	check(game.detail_item.uid==uid and text_at("体力不足"),"clicked waiting UID renders short status in existing details")
	await shot("08-waiting-details")
	# Read the real earlier frame, where that same UID is still cooling down.
	game.combat_time=.1;await tick()
	check(not game._current_frame().waiting[0].get(uid,false) and not text_at("体力不足"),"detail status disappears for the same UID when current frame is not waiting")
	await action("details_back");await move(Vector2(712,820));await tick(20)
	check(not text_at("体力不足"),"no permanent waiting explanation outside active item view")
	var failures=checks.filter(func(v):return not v.ok).size()
	var file=FileAccess.open(OUT+("headless" if DisplayServer.get_name()=="headless" else "native")+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"transition_samples":samples},"\t"));file.close()
	print("V50 REVIEW FIXES: ",checks.size()," checks, ",failures," failures");game.queue_free();await process_frame;quit(1 if failures else 0)
