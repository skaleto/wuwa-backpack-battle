extends SceneTree
class ObservedGame extends "res://tests/fixtures/playable_fixture_v50.gd":
	var dim_drawn=false
	@warning_ignore("native_method_override")
	func draw_rect(rect:Rect2,color:Color,filled:bool=true,width:float=-1.0,antialiased:bool=false)->void:
		if overlay=="item_details" and rect==Rect2(0,0,1440,960) and color.a<.9:dim_drawn=true
		super.draw_rect(rect,color,filled,width,antialiased)
var game
var checks=[]
func _initialize():
	DirAccess.make_dir_recursive_absolute("user://qa-reports/")
	call_deferred("run")
func check(ok:bool,label:String):
	checks.append({"ok":ok,"label":label})
	if not ok:printerr("FAIL ",label)
func tick(n:int=1):
	for i in n:
		game._process(1.0/60);game.queue_redraw();await process_frame
		if DisplayServer.get_name()!="headless":RenderingServer.force_draw(true)
func move(at:Vector2):
	var ev=InputEventMouseMotion.new();ev.position=at;game._input(ev);await tick()
func press(down:bool):
	var ev=InputEventMouseButton.new();ev.position=game.mouse;ev.button_index=MOUSE_BUTTON_LEFT;ev.pressed=down;game._input(ev)
func at(x:float,y:float)->Vector2:return game._board_to_screen(game.BOARD+Vector2(x,y)*game.CELL)
func shot(name:String):
	if DisplayServer.get_name()=="headless":return
	game.queue_redraw();await process_frame;RenderingServer.force_draw(true)
	root.get_texture().get_image().save_png("user://qa-reports/"+name+".png")
func run():
	root.size=Vector2i(1440,960);game=ObservedGame.new();root.add_child(game);await process_frame;game.set_process(false);game.set_process_input(false)
	for skin in ["chibi","original"]:
		game.reset_slice();game.set_visual_skin(skin,false);game.motion.modal_value=0;game.motion.modal_target=0
		game.run.items=[game.piece("w_sword","cross",2,0)];game.run.primary="cross"
		var target=Vector2.ZERO
		for y in range(3,77):
			var point=at(3,float(y)/80)
			if not game._item_body_at(point).is_empty() and not game._edge_bag(point).is_empty():target=point;break
		check(target!=Vector2.ZERO,skin+" actual body intersects visible bag seam")
		if target!=Vector2.ZERO:
			game.motion.land("0cross")
			var landed_target=target+Vector2(0,game.motion.landing_y("0cross")*game._board_transform().get_scale().y)
			check(game._item_body_at(landed_target).get("uid","")=="cross",skin+" alpha hit follows actual landing render pose")
			game.motion.landings.clear()
			await move(target);check(game.hovered.get("item",{}).get("uid","")=="cross",skin+" body hover beats bag edge")
			press(true);check(game.drag_origin=="board" and game.dragging.get("uid","")=="cross",skin+" body press beats bag edge")
			press(false);await tick(15)
			check(game.overlay=="item_details" and game.detail_item.uid=="cross",skin+" release opens the item card")
			check(not game.dim_drawn,skin+" card does not dim full screen")
			await shot(skin+"-anchored-card")
			var recipe=game.buttons.filter(func(b):return b.action=="detail_recipes" and b.enabled)
			check(not recipe.is_empty(),skin+" card recipe action is reachable")
			if not recipe.is_empty():
				await move(recipe[0].rect.get_center());press(true);press(false);await tick(18)
				check(game.overlay=="item_recipes",skin+" real pointer opens recipe viewer")
			game.overlay="";game.motion.modal_value=0;game.motion.modal_target=0;game.motion.last_overlay=""
		game.reset_slice();game.run.items[1].x=0;game.run.items[1].y=2;game.motion.modal_value=0;game.motion.modal_target=0;await tick(2)
		await move(at(.5,.5));var before=game.run.duplicate(true);press(true);await tick(60);press(false);await tick(2)
		check(game.overlay=="item_details" and game.run==before,skin+" long stationary press only inspects")
		await move(at(.5,2.5));press(true);press(false);await tick(2)
		check(game.overlay=="item_details" and game.detail_item.uid=="i2",skin+" clicking another item switches card")
		await move(Vector2(1420,930));press(true);press(false);await tick(2)
		check(game.overlay.is_empty(),skin+" outside click dismisses card")
		game.run.items=[];game.run.primary="";game.run.bags=[game.piece("satchel","b1",0,0),game.piece("pouch","b2",3,0)]
		await move(at(3.5,.5));press(true);await move(at(6.5,4.5));press(false);await tick(18)
		check(game.run.bags.any(func(b):return b.uid=="b2" and b.x==6 and b.y==4),skin+" disconnected drag succeeds")
		check(game.storage.resume().get("bags",[])==game.run.bags,skin+" disconnected drag persists")
		await shot(skin+"-separate-paper")
		var separate=game.run.duplicate(true);await move(at(6.5,4.5));press(true);await move(at(.5,.5));await shot(skin+"-invalid-red-held");press(false);await tick()
		check(game.run==separate and game.toast_timer==0 and game.overlay.is_empty(),skin+" invalid overlap restores silently")
		await shot(skin+"-invalid-red-release")
		for origin in ["board","shop"]:
			game.reset_slice();game.run.items=[game.piece("w_rectifier","i1",0,0)];game.run.stash=[];game.run.gold=50;game.motion.modal_value=0
			for n in 6:game.run.stash.append(game.piece("tea","full-stash-%d"%n,0,0))
			game.run.shop[0]={"kind":"w_rectifier","locked":false}
			var source=at(.5,.5) if origin=="board" else game._offer_rect(0).get_center()
			await move(source);press(true);var full_stash=game.run.duplicate(true)
			await move(game._stash_mat_rect().get_center());await tick(2)
			check(not game._stash_drop_projection().has_area() and game.run==full_stash,skin+" "+origin+" V103 readonly seventh arrival preview has no false rejection")
			await shot(skin+"-full-stash-held-"+origin)
			var requests=int(game.audio_diagnostics().requested.get("reject",0));press(false);await tick()
			check(game.run.stash.size()==7 and game.overlay.is_empty() and game.toast_timer==0,skin+" "+origin+" V103 seventh storage arrival preserves ownership without text")
			check(int(game.audio_diagnostics().requested.get("reject",0))==requests and game._stash_current_page()==1,skin+" "+origin+" V103 next page is revealed without false rejection")
			await shot(skin+"-full-stash-"+origin)
		game._open_item_details(game.inventory.make_piece("whiff","edge"),"catalogue");game.detail_anchor=Rect2(1410,920,20,20)
		check(Rect2(8,8,1424,944).encloses(game._detail_card_rect()),skin+" bottom right card avoids screen edge")
	var failures=checks.filter(func(v):return not v.ok).size()
	var f=FileAccess.open("user://qa-reports/interaction-v53-"+("headless" if DisplayServer.get_name()=="headless" else "native")+".json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"audio_event_dispatch":game.audio_diagnostics()},"\t"));f.close()
	print("V53 INTERACTION ",checks.size()," checks ",failures," failures");game.queue_free();await process_frame;quit(1 if failures else 0)
