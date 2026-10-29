extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const T=preload("res://scripts/ui/pockets/terminal_grid.gd")
const OLD=preload("res://build/qa/ui-v103/before/terminal_grid.gd")
const OUT="res://build/qa/ui-v103/after/"
var game
var viewport
func _initialize()->void:
	root.hide();root.unfocusable=true
	AudioServer.set_bus_mute(0,true)
	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("run")
func shot(name:String)->void:
	game.paint_alpha=1;game.paint_offset=Vector2.ZERO
	game.motion.transition_left=0;game.transition_image=null
	game.queue_redraw();await process_frame
	RenderingServer.force_draw(true);await process_frame
	assert(viewport.get_texture().get_image().save_png(OUT+name+".png")==OK)
func pointer(at:Vector2,down:bool,button:int=MOUSE_BUTTON_LEFT)->void:
	var e=InputEventMouseButton.new();e.position=at;e.pressed=down;e.button_index=button
	game._input(e)
func run()->void:
	viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport);game=G.new();viewport.add_child(game)
	await process_frame
	game.set_process(false);game.set_process_input(false)
	game.joined_slice()
	game.run.shop=[{"kind":"w_sword","locked":false},{"kind":"daily_tea","locked":false},{"kind":"turtle","locked":false},{"kind":"daily_tea","locked":false},{"kind":"whiff","locked":false},{"kind":"travel","locked":false}]
	game.run.round=4;game.run.gold=30
	var kinds=["daily_tea","whiff","turtle","heron","w_sword","thundering","pouch","strip","corner","travel","w_broadblade","daily_tea","w_rectifier","whiff","turtle","pouch"]
	game.run.stash=[]
	for n in kinds.size():game.run.stash.append(game.piece(kinds[n],"stored-%d"%n,0,0))
	game._set_stash_page(0)
	assert(game.inventory.validate_run(game.run))
	game.mouse=Vector2(25,100);game.hovered={}
	await shot("01-joined-materials-storage")
	var before=game.run.duplicate(true)
	pointer(game._stash_mat_rect().get_center(),true,MOUSE_BUTTON_WHEEL_DOWN)
	assert(game._stash_current_page()==1 and game.run==before)
	await shot("02-storage-page-two")
	var target=game._stash_rect(7).get_center()
	pointer(target,true);pointer(target,false)
	game.motion.modal_value=1
	assert(game.detail_item.get("uid","")=="stored-7")
	await shot("03-page-two-details")
	game._close_item_details();game.motion.modal_value=0;game.motion.modal_target=0
	game._set_stash_page(0)
	game.queue_redraw();await process_frame;await process_frame
	# Buy through real press/release into the storage area.
	var shop=game._offer_rect(4).get_center()
	pointer(shop,true)
	var move=InputEventMouseMotion.new();move.position=game._stash_mat_rect().get_center()
	game._input(move);pointer(move.position,false);game._process(.8)
	print("PURCHASE_CAPTURE stash=",game.run.stash.size()," page=",game._stash_current_page()," overlay=",game.overlay," toast=",game.toast)
	assert(game.run.stash.size()==17 and game._stash_current_page()==2)
	await shot("04-purchase-reveals-new-page")
	game.fusion_view.finish()
	# Dedicated material comparison uses the same production native draw path.
	game.visible=false
	var sample=MaterialSamples.new();viewport.add_child(sample)
	await process_frame;RenderingServer.force_draw(true);await process_frame
	assert(viewport.get_texture().get_image().save_png(OUT+"05-material-comparison.png")==OK)
	sample.queue_free();game.queue_free();await process_frame
	await create_timer(1.0).timeout
	var log=FileAccess.open(OUT+"capture-complete.txt",FileAccess.WRITE)
	log.store_string("5 native stills. Joined bag materials and crossing items; 17 stored items, real wheel page and selection, real shop purchase reveals last page. Hidden unfocusable SubViewport; Dummy audio; independent QA Storage.")
	quit()

class MaterialSamples extends Node2D:
	var font=preload("res://assets/fonts/body.ttf")
	func _draw()->void:
		draw_rect(Rect2(0,0,1440,960),Color("29264d"))
		draw_string(font,Vector2(48,66),"背包外形 · 原生渲染对照",HORIZONTAL_ALIGNMENT_LEFT,-1,30,Color("f6ebd4"))
		draw_string(font,Vector2(48,109),"上：之前的格盘　下：不同容器的包口、扣件、提手与材质",HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color("c7bdec"))
		var kinds=["satchel","pouch","strip","corner","travel"]
		var labels=["绒面背包","防护匣","拉链腰包","编织袋","加固装备袋"]
		for n in 5:
			var x=40+n*280
			var rotation=1 if kinds[n]=="strip" else 0
			OLD.thumbnail(self,Rect2(x,170,240,240),kinds[n],rotation,1)
			T.thumbnail(self,Rect2(x,560,240,240),kinds[n],rotation,1)
			draw_string(font,Vector2(x+8,475),labels[n],HORIZONTAL_ALIGNMENT_LEFT,240,23,Color("f6ebd4"))
			draw_string(font,Vector2(x+8,850),labels[n],HORIZONTAL_ALIGNMENT_LEFT,240,23,Color("f6ebd4"))
