extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const T=preload("res://scripts/ui/pockets/terminal_grid.gd")
const OLD=preload("res://build/qa/ui-v105/before/terminal_grid.gd")
const SKIN=preload("res://scripts/ui/visual_skin.gd")
const Q=preload("res://scripts/ui/items/item_quality.gd")
const FORM=preload("res://scripts/ui/pockets/bag_form.gd")
const SLOTS=preload("res://scripts/ui/pockets/bag_slots.gd")
const OUT="res://build/qa/ui-v105/after/"
var game
var viewport
func _initialize()->void:
	root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true)
	DirAccess.make_dir_recursive_absolute(OUT);call_deferred("run")
func shot(name:String)->void:
	game.paint_alpha=1;game.paint_offset=Vector2.ZERO;game.motion.transition_left=0;game.transition_image=null
	game.queue_redraw();await process_frame;RenderingServer.force_draw(true);await process_frame
	assert(viewport.get_texture().get_image().save_png(OUT+name+".png")==OK)
func run()->void:
	viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport);game=G.new();viewport.add_child(game);await process_frame
	game.set_process(false);game.set_process_input(false);game.joined_slice()
	game.run.shop=[{"kind":"w_sword","locked":false},{"kind":"daily_tea","locked":false},{"kind":"turtle","locked":false},{"kind":"daily_tea","locked":false},{"kind":"whiff","locked":false},{"kind":"corner","locked":false}]
	game.run.round=4;game.run.gold=22
	game.run.items=[game.piece("w_sword","cross1",1,0),game.piece("daily_tea","tea",0,1),game.piece("whiff","echo1",1,1),game.piece("turtle","echo2",2,1),game.piece("heron","echo3",2,2)]
	game.run.stash=[game.piece("w_rectifier","stored",0,0),game.piece("daily_tea","stored2",0,0)]
	game.run.primary="cross1";game.mouse=Vector2(25,100);game.hovered={}
	assert(game.inventory.validate_run(game.run))
	await shot("01-preparation")
	var original=game.run.items.duplicate(true)
	game.run.items=[]
	await shot("02-empty-containers")
	game.run.items=original
	var at=game._board_to_screen(game._item_rect(game.run.items[0],game.BOARD).get_center())
	var press=InputEventMouseButton.new();press.position=at;press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true
	game._input(press)
	await shot("03-grabbed-item")
	game.visible=false
	var sample=Comparison.new();sample.bags=game.run.bags.duplicate(true);sample.items=original;viewport.add_child(sample)
	await process_frame;RenderingServer.force_draw(true);await process_frame
	assert(viewport.get_texture().get_image().save_png(OUT+"04-comparison.png")==OK)
	sample.queue_free()
	var layers=Layers.new();viewport.add_child(layers)
	await process_frame;RenderingServer.force_draw(true);await process_frame
	assert(viewport.get_texture().get_image().save_png(OUT+"05-layers.png")==OK)
	layers.queue_free();game.queue_free();await process_frame
	await create_timer(.7).timeout
	FileAccess.open(OUT+"capture-complete.txt",FileAccess.WRITE).store_string("5 native captures. Real item sprites over shared bag geometry; UI, empty containers, grabbed item, V104/V105 comparison and independent layer breakdown. Isolated QA storage; hidden unfocusable viewport; Dummy audio.")
	quit()

class Comparison extends Node2D:
	var font=preload("res://assets/fonts/body.ttf")
	var bags=[];var items=[]
	func _draw()->void:
		draw_rect(Rect2(0,0,1440,960),Color("373251"))
		draw_string(font,Vector2(48,58),"完整袋体与格位 · 实际渲染对照",HORIZONTAL_ALIGNMENT_LEFT,-1,28,Color("fff0d7"))
		for n in 2:
			var origin=Vector2(70+n*710,150);var pitch=79.0
			draw_string(font,origin-Vector2(0,36),"之前：包边拼接＋平面填色" if n==0 else "现在：完整袋体＋独立格位",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("e4d8f2"))
			if n==0:OLD.surface(self,origin,bags,pitch)
			else:T.surface(self,origin,bags,pitch)
			for item in items:
				var rect=Rect2(origin+Vector2(item.x,item.y)*pitch,Vector2(3 if item.kind=="w_sword" else 2 if item.kind=="heron" else 1,2 if item.kind=="heron" else 1)*pitch)
				Q.draw(self,item.kind,rect)
				var texture=SKIN.texture(SKIN.item_path(item.kind));var source=SKIN.bounds(SKIN.item_path(item.kind))
				var scale_value=minf((rect.size.x-7)/source.size.x,(rect.size.y-7)/source.size.y)
				var size=source.size*scale_value
				draw_texture_rect_region(texture,Rect2(rect.get_center()-size*.5,size),source)
		draw_string(font,Vector2(48,586),"完整袋体共用柔和旅行收纳画法；内部叠放浅格位",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("e4d8f2"))
		var kinds=["satchel","pouch","strip","corner","travel"]
		var labels=["软背包","防护匣","腰包","编织袋","装备袋"]
		for n in 5:
			var x=45+n*280
			T.thumbnail(self,Rect2(x,650,225,190),kinds[n],1 if n==2 else 0,1)
			draw_string(font,Vector2(x+60,907),labels[n],HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("fff0d7"))

class Layers extends Node2D:
	var font=preload("res://assets/fonts/body.ttf")
	func _draw()->void:
		draw_rect(Rect2(0,0,1440,960),Color("373251"))
		draw_string(font,Vector2(50,63),"先画完整的袋子，再叠格位",HORIZONTAL_ALIGNMENT_LEFT,-1,34,Color("fff0d7"))
		var bag={"kind":"satchel","uid":"sample","x":0,"y":0,"rotation":0}
		for n in 3:
			var at=Vector2(65+n*470,220);var pitch=105.0
			var labels=["完整袋体：外形＋内衬","格位层：浅阴影","叠放后：放入实际物品"]
			draw_string(font,at-Vector2(0,80),labels[n],HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("e4d8f2"))
			if n==0:FORM.draw(self,at,T.form_bags([bag]),pitch,1)
			elif n==1:
				draw_rect(Rect2(at,Vector2(315,210)),Color("b9a8cf"))
				for y in 2:
					for x in 3:SLOTS.draw(self,Rect2(at+Vector2(x,y)*pitch,Vector2.ONE*pitch),Color("b9a8cf"),x+3*y)
			else:
				T.surface(self,at,[bag],pitch)
				for spec in [["w_sword",Rect2(at,Vector2(315,105))],["daily_tea",Rect2(at+Vector2(0,105),Vector2.ONE*105)],["whiff",Rect2(at+Vector2(105,105),Vector2.ONE*105)]]:
					var rect:Rect2=spec[1];Q.draw(self,spec[0],rect)
					var texture=SKIN.texture(SKIN.item_path(spec[0]));var source=SKIN.bounds(SKIN.item_path(spec[0]))
					var size=source.size*minf((rect.size.x-10)/source.size.x,(rect.size.y-10)/source.size.y)
					draw_texture_rect_region(texture,Rect2(rect.get_center()-size*.5,size),source)
		draw_string(font,Vector2(50,570),"同一画法下的五种容器",HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color("fff0d7"))
		for n in 5:
			var kind=["satchel","pouch","strip","corner","travel"][n]
			T.thumbnail(self,Rect2(50+n*280,670,220,170),kind,1 if kind=="strip" else 0,1)
			draw_string(font,Vector2(95+n*280,916),["软背包","防护匣","腰包","折角袋","装备袋"][n],HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("e4d8f2"))
