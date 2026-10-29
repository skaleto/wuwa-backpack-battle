extends SceneTree
const OUT="res://build/qa/pockets-v130/native/"
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const T=preload("res://scripts/ui/pockets/terminal_grid.gd")
const SKIN=preload("res://scripts/ui/visual_skin.gd")
const KINDS=["satchel","pouch","strip","corner","travel","pocket_single","pocket_double","pocket_long_l","pocket_long_j"]
var vp:SubViewport
var g
var checks=0
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:printerr("FAIL ",label);quit(1)
func _initialize()->void:
	root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true);call_deferred("capture")
func shot(node:CanvasItem,name:String)->void:
	node.queue_redraw();await process_frame;RenderingServer.force_draw(true);await process_frame
	ck(vp.get_texture().get_image().save_png(OUT+name+".png")==OK,"capture "+name)
func button(at:Vector2,pressed:bool,id:int=MOUSE_BUTTON_LEFT)->void:
	var e=InputEventMouseButton.new();e.position=at;e.button_index=id;e.pressed=pressed;g._input(e)
func move(at:Vector2)->void:
	var e=InputEventMouseMotion.new();e.position=at;g._input(e)
func arrange()->void:
	g.reset_slice();g.run.round=4;g.run.gold=20;g.run.items=[];g.run.stash=[];g.run.primary=""
	g.run.bags=[]
	var coordinates=[Vector2i(0,0),Vector2i(3,0),Vector2i(5,0),Vector2i(6,0),Vector2i(0,2),Vector2i(2,4),Vector2i(0,4),Vector2i(3,2),Vector2i(6,2)]
	for n in KINDS.size():g.run.bags.append(g.piece(KINDS[n],"bag"+str(n),coordinates[n].x,coordinates[n].y))
	g.run.shop=[{"kind":"w_sword","locked":false},{"kind":"daily_tea","locked":false},{"kind":"whiff","locked":false},{"kind":"mat_42310060","locked":false},{"kind":"rocksteady","locked":false},{"kind":"pocket_long_l","locked":false}]
	g.mouse=Vector2(20,100);g.hovered={};g.dragging={};g.overlay="";g.motion.modal_value=0;g.motion.modal_target=0
func capture()->void:
	if DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(OUT)
	vp=SubViewport.new();vp.size=Vector2i(1440,960);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
	g=G.new();vp.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
	ck(SKIN.bag_style=="patchwork_v129","normal startup uses patchwork")
	arrange();ck(g.inventory.validate_run(g.run),"all nine pockets form a legal board")
	await shot(g,"01-empty")
	g.run.items=[g.piece("w_sword","cross",1,0),g.piece("daily_tea","tea",0,1),g.piece("whiff","echo",7,1),g.piece("mat_42310060","flower",0,3)]
	g.run.primary="cross";ck(g.inventory.validate_run(g.run),"items cross pocket boundaries")
	var before=g.run.duplicate(true);await shot(g,"02-preparation");ck(g.run==before,"render is read-only")
	var at=g._board_to_screen(g._item_rect(g.run.items[0],g.BOARD).get_center())
	button(at,true);ck(g.drag_origin=="board" and g.dragging.uid=="cross","weapon has hit priority over bags")
	button(at,true,MOUSE_BUTTON_RIGHT);ck(g.dragging.rotation==1,"right click rotates held item")
	await shot(g,"03-item-held")
	var cancel=InputEventKey.new();cancel.keycode=KEY_ESCAPE;cancel.pressed=true;g._input(cancel)
	arrange()
	var start=g._offer_rect(5).position+Vector2(45,38)
	var end=g._board_to_screen(g.BOARD+Vector2(6.5,5.5)*g.CELL)
	var gold=g.run.gold
	button(start,true);move(end);ck(g.run.gold==gold,"bag purchase remains a preview during drag")
	button(end,true,MOUSE_BUTTON_RIGHT);button(end,false,MOUSE_BUTTON_RIGHT)
	# A shop grab holds the first cell. After rotating, move the occupied
	# centroid onto a legal bottom-right 3x2 footprint before releasing.
	end=g._board_to_screen(g.BOARD+Vector2(6,5)*g.CELL+g._occupied_center(g.dragging))-g.drag_center_offset
	move(end);ck(g._drag_placement_cell()==Vector2i(6,5),"rotated long L preview uses the intended cells")
	for frame in 15:g._process(1.0/60.0)
	await shot(g,"04-long-l-buy-rotated");button(end,false)
	ck(g.run.gold==gold-3 and g.run.bags.size()==10,"rotated long L is purchased on drop")
	ck(g.inventory.validate_run(g.run),"rotated purchase preserves legal board")
	await shot(g,"05-long-l-purchased")
	arrange();g.hide();vp.size=Vector2i(1600,1400)
	var gallery=Gallery.new();vp.add_child(gallery);await shot(gallery,"06-all-shapes");gallery.queue_free();await process_frame
	var joins=Joins.new();vp.add_child(joins);await shot(joins,"07-long-l-rotations");joins.queue_free();await process_frame
	g.queue_free();await process_frame
	FileAccess.open(OUT+"validation.txt",FileAccess.WRITE).store_string("Hidden unfocusable native Godot viewport; independent QA Storage; no OS input. %d checks passed. Nine shapes, cross-pocket items, held-item hit priority/rotation, deferred bag purchase and long-L rotation/drop.\n"%checks)
	print("POCKETS_NATIVE_V130 ",checks," checks passed");quit()
class Gallery extends Node2D:
	var font=preload("res://assets/fonts/body.ttf")
	func _draw()->void:
		draw_rect(Rect2(0,0,1600,1400),Color("494064"))
		var kinds=["satchel","pouch","strip","corner","travel","pocket_single","pocket_double","pocket_long_l","pocket_long_j"]
		var names=["初始 · 6格","护盾 · 4格","加速 · 3格","声骸 · 3格","武器 · 6格","补片 · 1格","两格口袋","长 L · 4格","镜像长 L · 4格"]
		for n in kinds.size():
			var at=Vector2(40+(n%3)*530,50+floori(n/3.0)*455)
			draw_string(font,at+Vector2(0,30),names[n],HORIZONTAL_ALIGNMENT_LEFT,-1,27,Color("fff2db"))
			T.thumbnail(self,Rect2(at+Vector2(40,70),Vector2(360,310)),kinds[n],0,1)
class Joins extends Node2D:
	var font=preload("res://assets/fonts/body.ttf")
	const FIX=preload("res://tests/fixtures/bag_trial_fixture_v109.gd")
	func _draw()->void:
		draw_rect(Rect2(0,0,1600,1400),Color("494064"))
		for turn in 4:
			var at=Vector2(60+(turn%2)*780,60+floori(turn/2.0)*680)
			draw_string(font,at+Vector2(0,30),"长 L 与反长 L · "+str(turn*90)+"°",HORIZONTAL_ALIGNMENT_LEFT,-1,28,Color("fff2db"))
			var bags=FIX.touching(FIX.bag("pocket_long_l","a",turn),FIX.bag("pocket_long_j","b",turn),Vector2i.RIGHT)
			var hi=Vector2.ONE
			for b in bags:
				for cell in T.inventory.occupied(b):hi=hi.max(Vector2(cell)+Vector2.ONE)
			var pitch=minf(110,640/hi.x)
			T.surface(self,at+Vector2(0,110),bags,pitch)
