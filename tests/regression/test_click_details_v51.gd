extends SceneTree
## Pointer-level regression. Observations are the visible text/icon draw calls,
## never the private animation curve or gesture-classification implementation.
class ObservedGame extends "res://tests/fixtures/playable_fixture_v50.gd":
	var visible_text:Array=[]
	var detail_draws:Array=[]
	var featured_kind=""
	func _draw():
		visible_text.clear();detail_draws.clear();super._draw()
	func _text(value:String,pos:Vector2,size:int,color:Color)->void:
		visible_text.append(value);super._text(value,pos,size,color)
	func _draw_icon(kind:String,rect:Rect2,rotation_value:int,alpha:float=1.0,selected:bool=false)->void:
		if overlay=="item_details" and rect.size.x>260 and rect.size.y>120:detail_draws.append(rect)
		if overlay=="catalogue" and rect.size.x>500 and rect.size.y>300:featured_kind=kind
		super._draw_icon(kind,rect,rotation_value,alpha,selected)

var game
var checks:Array=[]
var out="res://build/qa/demo-v51/checks/"
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
func close():
	game._action("details_back");await tick(18)
func shot(name:String):
	if DisplayServer.get_name()=="headless":return
	game.queue_redraw();await process_frame;RenderingServer.force_draw(true)
	root.get_texture().get_image().save_png("res://build/qa/demo-v51/after/"+name+".png")
func run():
	DirAccess.make_dir_recursive_absolute(out);DirAccess.make_dir_recursive_absolute("res://build/qa/demo-v51/after/")
	root.size=Vector2i(1440,960);game=ObservedGame.new();root.add_child(game);await process_frame
	game.set_process(false);game.set_process_input(false)
	for skin in ["original","chibi"]:
		game.reset_slice();game.set_visual_skin(skin,false);game.motion.modal_value=0;game.motion.modal_target=0
		await move(at(2.5,.5));await tick(75)
		check(game.hovered.get("item",{}).get("uid","")=="i2",skin+" actual item is hovered")
		check(game.visible_text.has(game.C.items.whiff.name),skin+" 1.25s item hover renders the item detail card")
		await shot(skin+"-hover-details")
		await move(game._prep_actor_rect().get_center());await tick(75)
		check(not game.visible_text.any(func(t):return str(t).begins_with("60 能量")),skin+" leader hover renders no automatic skill card")
		await move(at(.5,.5));await shot(skin+"-click-before")
		var before=game.run.duplicate(true);var saved=game.storage.resume().duplicate(true)
		button(true)
		check(game.dragging.get("uid","")=="i1" and game.run==before,skin+" press immediately lifts a real item without mutation")
		var held=game._held_pose();await move(game.mouse+Vector2(3,2))
		check(game._held_pose().origin.is_equal_approx(held.origin+Vector2(3,2)),skin+" held body follows sub-cell mouse motion")
		button(false);await tick(3)
		check(game.overlay=="item_details" and game.detail_item.get("uid","")=="i1",skin+" short release opens selected vertical detail")
		check(game.run==before and game.storage.resume()==saved,skin+" inspection changes no ownership, economy or save")
		if not game.detail_draws.is_empty():
			var raised:Rect2=game.detail_draws[-1];await shot(skin+"-click-mid")
			await tick(11)
			var settled:Rect2=game.detail_draws[-1]
			check(raised.get_center().y<settled.get_center().y-.5 and settled.get_center().y-raised.get_center().y<=4,skin+" visible detail illustration lifts by at most four pixels")
			check(raised.size.x>settled.size.x and is_equal_approx(raised.size.x/settled.size.x,raised.size.y/settled.size.y),skin+" bounce preserves illustration proportions")
			await shot(skin+"-click-settled");await tick(35)
			check(game.detail_draws[-1].is_equal_approx(settled),skin+" selected illustration settles instead of wobbling forever")
		else:check(false,skin+" detail illustration was rendered")
		game._action("detail_recipes");await tick(18)
		check(game.overlay=="item_recipes" and game.visible_text.has("合成配方"),skin+" click details retains recipe access")
		game._action("details_back");await close()
		await move(at(.5,.5));button(true);await tick(70);button(false);await tick(18)
		check(game.overlay=="item_details" and game.detail_item.get("uid","")=="i1" and game.run==before,skin+" stationary long hold inspects without placement")
		await close();game.run.shop[0]={"kind":"whiff","locked":true};game.run.gold=20
		before=game.run.duplicate(true);await move(game._offer_rect(0).position+Vector2(80,40));button(true);await tick(75);button(false);await tick(18)
		check(game.overlay=="item_details" and game.detail_origin=="shop" and game.run==before,skin+" stationary shop long hold inspects without buying")
		await close();await move(game._offer_rect(0).position+Vector2(80,40));button(true);await move(Vector2(1410,938));button(false);await tick(18)
		check(game.run==before and game.dragging.is_empty() and game.overlay.is_empty(),skin+" dragged release outside cancels atomically")
		await move(game._offer_rect(0).position+Vector2(80,40));button(true);await move(game._stash_mat_rect().get_center())
		button(true,MOUSE_BUTTON_RIGHT);button(false,MOUSE_BUTTON_RIGHT);await tick(18)
		check(game.dragging.rotation==1 and game.run==before,skin+" right rotation remains an uncommitted preview")
		button(false);await tick(18)
		check(game.run.shop[0].is_empty() and game.run.stash.size()==before.stash.size()+1 and game.run.gold==before.gold-int(game.C.items.whiff.price),skin+" legal rotated drag purchase commits exactly once")
		game.catalogue_focus=0;game._action("catalogue");await tick(18)
		var featured=game.featured_kind;before=game.run.duplicate(true)
		await move(Vector2(310,250));await tick(70)
		check(game.overlay=="catalogue" and game.featured_kind==featured,skin+" catalogue hover leaves selected illustration and attributes unchanged")
		button(true);button(false);await tick(18)
		var kinds=game.C.items.keys().filter(func(k):return not game.C.is_tag(k,"bag"))
		check(game.overlay=="item_details" and game.detail_item.kind==kinds[1] and game.run==before,skin+" catalogue thumbnail click selects and opens explicit details without mutation")
		game.overlay="";await tick(18)
	var failures=checks.filter(func(v):return not v.ok).size()
	var f=FileAccess.open(out+("headless" if DisplayServer.get_name()=="headless" else "native")+"-click-details.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"));f.close()
	print("V51 CLICK DETAILS: ",checks.size()," checks, ",failures," failures")
	game.queue_free();await process_frame;quit(1 if failures else 0)
