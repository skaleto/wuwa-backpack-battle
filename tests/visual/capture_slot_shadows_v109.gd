extends SceneTree
## Display-only comparison; hidden native renderer and isolated fixture Storage.
const SKIN=preload("res://scripts/ui/visual_skin.gd")
const T=preload("res://scripts/ui/pockets/terminal_grid.gd")
const OLD=preload("res://build/qa/ui-v109/slot-shadows/before-slots.gd")
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const OUT="res://build/qa/ui-v109/slot-shadows/"
var viewport:SubViewport
func _initialize()->void:
	root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true);call_deferred("run")
func shot(node:CanvasItem,name:String)->void:
	node.queue_redraw();await process_frame;RenderingServer.force_draw(true);await process_frame
	assert(viewport.get_texture().get_image().save_png(OUT+name+".png")==OK)
func run()->void:
	viewport=SubViewport.new();viewport.size=Vector2i(1440,1080);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var game=G.new();viewport.add_child(game);await process_frame
	assert(SKIN.bag_style=="flat","ordinary startup must use the approved bags without a CLI override")
	game.set_process(false);game.set_process_input(false);game.joined_slice();game.hide()
	var sheet=Comparison.new();sheet.bags=game.run.bags.duplicate(true);viewport.add_child(sheet)
	await shot(sheet,"comparison");sheet.queue_free();await process_frame
	viewport.size=Vector2i(1440,960);game.show()
	game.run.items=[game.piece("w_sword","cross1",1,0),game.piece("daily_tea","tea",0,1),game.piece("whiff","echo1",1,1),game.piece("turtle","echo2",2,1),game.piece("heron","echo3",2,2)]
	game.run.primary="cross1";game.mouse=Vector2(25,100);game.hovered={}
	game.paint_alpha=1;game.paint_offset=Vector2.ZERO;game.motion.transition_left=0;game.transition_image=null
	var original=game.run.duplicate(true);assert(game.inventory.validate_run(game.run))
	await shot(game,"flat-game")
	var toggle=InputEventKey.new();toggle.keycode=KEY_F7;toggle.pressed=true
	game._input(toggle);assert(SKIN.bag_style=="fold" and game.run==original)
	await shot(game,"fold-game")
	SKIN.configure([],game.storage.root_path)
	assert(SKIN.bag_style=="fold" and game.run==original,"F7 persists only visual preference")
	game.queue_free();await process_frame
	print("SLOT SHADOWS: ordinary startup flat, F7 fold persists, two native item views, state unchanged");quit()

class Comparison extends Node2D:
	var bags=[]
	var font=preload("res://assets/fonts/body.ttf")
	func _draw()->void:
		draw_rect(Rect2(0,0,1440,1080),Color("373251"))
		var saved=SKIN.bag_style
		for column in 2:
			SKIN.set_bag_style("flat" if column==0 else "fold",false)
			draw_string(font,Vector2(50+column*720,54),"01 薄袋平铺" if column==0 else "02 软布折口",HORIZONTAL_ALIGNMENT_LEFT,-1,30,Color("fff0d7"))
			for row in 2:
				var at=Vector2(50+column*720,150+row*480)
				draw_string(font,at-Vector2(0,35),"调整前" if row==0 else "阴影加深后",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("e4d8f2"))
				T.FORM.draw(self,at,T.form_bags(bags),96,1)
				for bag in bags:
					for cell in T.inventory.occupied(bag):
						var rect=Rect2(at+Vector2(cell)*96,Vector2.ONE*96)
						if row==0:OLD.draw(self,rect,SKIN.CREAM,cell.x+cell.y*3)
						else:T.SLOTS.draw(self,rect,SKIN.CREAM,cell.x+cell.y*3)
		SKIN.set_bag_style(saved,false)
