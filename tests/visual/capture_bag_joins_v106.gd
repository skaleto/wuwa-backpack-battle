extends SceneTree
const T=preload("res://scripts/ui/pockets/terminal_grid.gd")
const SKIN=preload("res://scripts/ui/visual_skin.gd")
const Q=preload("res://scripts/ui/items/item_quality.gd")
const OUT="res://build/qa/ui-v106/joins/"
var viewport:SubViewport
func _initialize()->void:
	root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true)
	DirAccess.make_dir_recursive_absolute(OUT);call_deferred("run")
func run()->void:
	viewport=SubViewport.new();viewport.size=Vector2i(1800,1420);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	for with_items in [false,true]:
		var sheet=Sheet.new();sheet.with_items=with_items;viewport.add_child(sheet)
		await process_frame;RenderingServer.force_draw(true);await process_frame
		var suffix="items" if with_items else "empty"
		assert(viewport.get_texture().get_image().save_png(OUT+"joined-"+suffix+".png")==OK)
		sheet.queue_free();await process_frame
	FileAccess.open(OUT+"complete.txt",FileAccess.WRITE).store_string("12 arrangements; 10 different-type pairs, staggered join, four-bag junction; identical empty/item views; actual native renderer; no game/save or input.\n")
	quit()

class Sheet extends Node2D:
	var font=preload("res://assets/fonts/body.ttf")
	var with_items=false
	func bag(kind:String,uid:String,x:int,y:int,rotation:int=0)->Dictionary:
		return {"kind":kind,"uid":uid,"x":x,"y":y,"rotation":rotation}
	func cases()->Array:
		return [
			["软背包 ＋ 硬匣",[bag("satchel","a",0,0),bag("pouch","b",3,0)]],
			["软背包 ＋ 腰包（横向）",[bag("satchel","a",0,0),bag("strip","b",0,2,1)]],
			["软背包 ＋ 编织袋（旋转）",[bag("satchel","a",0,0),bag("corner","b",3,0,2)]],
			["软背包 ＋ 束口袋",[bag("satchel","a",0,0),bag("travel","b",3,0)]],
			["硬匣 ＋ 腰包",[bag("pouch","a",0,0),bag("strip","b",2,0)]],
			["硬匣 ＋ 编织袋",[bag("pouch","a",0,0),bag("corner","b",2,0)]],
			["硬匣 ＋ 束口袋（旋转）",[bag("pouch","a",0,0,1),bag("travel","b",2,0,1)]],
			["腰包 ＋ 编织袋（嵌入凹口）",[bag("corner","a",0,2),bag("strip","b",1,0)]],
			["腰包 ＋ 束口袋",[bag("travel","a",0,0),bag("strip","b",3,0)]],
			["编织袋 ＋ 束口袋",[bag("corner","a",0,0),bag("travel","b",2,0)]],
			["局部相接 · 两个拐角",[bag("satchel","a",0,0),bag("pouch","b",3,1)]],
			["四袋交汇 · 横跨接缝",[bag("pouch","a",0,0),bag("satchel","b",2,0),bag("travel","c",0,2),bag("corner","d",3,2)]]
		]
	func _draw()->void:
		draw_rect(Rect2(0,0,1800,1420),Color("373251"))
		draw_string(font,Vector2(42,55),"不同容器拼接 · "+("物品跨袋" if with_items else "空袋接缝"),HORIZONTAL_ALIGNMENT_LEFT,-1,30,Color("fff0d7"))
		var examples=cases()
		for n in examples.size():
			var panel=Vector2(36+(n%3)*594,95+int(n/3)*325)
			draw_string(font,panel+Vector2(0,24),"%02d  "%[n+1]+examples[n][0],HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("e4d8f2"))
			var bags=examples[n][1];var occupied={};var hi=Vector2.ONE
			for b in bags:
				for cell in T.inventory.occupied(b):
					assert(not occupied.has(cell));occupied[cell]=true;hi=hi.max(Vector2(cell)+Vector2.ONE)
			var pitch=minf(74,210/hi.y)
			var origin=panel+Vector2((550-hi.x*pitch)*.5,65)
			T.surface(self,origin,bags,pitch)
			if with_items:
				# Place an actual sword across a valid straight run, preferring mixed owners.
				var owners={}
				for b in bags:
					for cell in T.inventory.occupied(b):owners[cell]=b.uid
				var start=Vector2i(-1,-1);var rotation=0
				for axis in [Vector2i.RIGHT,Vector2i.DOWN]:
					for cell in owners:
						if owners.has(cell+axis) and owners.has(cell+axis*2) and (owners[cell]!=owners[cell+axis] or owners[cell]!=owners[cell+axis*2]):
							start=cell;rotation=0 if axis==Vector2i.RIGHT else 1;break
					if start.x>=0:break
				assert(start.x>=0,"Every arrangement must allow an actual cross-bag item")
				if start.x>=0:
					var size=Vector2(3,1) if rotation==0 else Vector2(1,3)
					var rect=Rect2(origin+Vector2(start)*pitch,size*pitch)
					Q.draw(self,"w_sword",rect)
					draw_set_transform(rect.get_center(),rotation*PI*.5)
					var path=SKIN.item_path("w_sword");var texture=SKIN.texture(path);var source=SKIN.bounds(path)
					var scale_value=minf((3*pitch-8)/source.size.x,(pitch-8)/source.size.y)
					var image_size=source.size*scale_value
					draw_texture_rect_region(texture,Rect2(-image_size*.5,image_size),source)
					draw_set_transform(Vector2.ZERO)
