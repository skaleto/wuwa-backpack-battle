extends SceneTree
const T=preload("res://scripts/ui/pockets/terminal_grid.gd")
const SKIN=preload("res://scripts/ui/visual_skin.gd")
const FIX=preload("res://tests/fixtures/bag_trial_fixture_v109.gd")
const BASE=preload("res://tests/visual/capture_bag_joins_v107.gd")
const Q=preload("res://scripts/ui/items/item_quality.gd")
func _initialize()->void:
	root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true);call_deferred("run")
func run()->void:
	var vp=SubViewport.new();vp.size=Vector2i(1680,1770);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
	var sheet=Comparison.new();vp.add_child(sheet)
	await process_frame;RenderingServer.force_draw(true);await process_frame
	assert(vp.get_texture().get_image().save_png("res://build/qa/ui-v109/compare-joins.png")==OK)
	print("V109 native two-style comparison captured");quit()
class Comparison extends BASE.Sheet:
	func _draw()->void:
		draw_rect(Rect2(0,0,1680,1770),Color("373251"))
		var old=SKIN.bag_style
		var examples=[
			["长边贴合 · 小匣旋转 90°",FIX.touching(FIX.bag("satchel","a"),FIX.bag("pouch","b",1),Vector2i.RIGHT)],
			["错位相接 · 两个方向",FIX.touching(FIX.bag("satchel","a",2),FIX.bag("travel","b",1),Vector2i.RIGHT,true)],
			["腰包嵌入 L 形凹口",cases()[7][1]],
			["四袋交汇 · 武器跨袋",cases()[11][1]]
		]
		for column in 2:
			SKIN.set_bag_style("flat" if column==0 else "fold",false)
			var x=44+column*838
			draw_string(font,Vector2(x,60),"01 薄袋平铺" if column==0 else "02 软布折口",HORIZONTAL_ALIGNMENT_LEFT,-1,34,Color("fff0d7"))
			for n in examples.size():
				var panel=Vector2(x,135+n*400)
				draw_string(font,panel,examples[n][0],HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color("e4d8f2"))
				var bags=examples[n][1];var hi=Vector2.ONE;var owners={}
				for b in bags:
					for cell in T.inventory.occupied(b):hi=hi.max(Vector2(cell)+Vector2.ONE);owners[cell]=b.uid
				var pitch=minf(104,290/hi.y);var origin=panel+Vector2((750-hi.x*pitch)*.5,40)
				T.surface(self,origin,bags,pitch)
				if n!=3:continue
				var start=Vector2i(1,0);var rect=Rect2(origin+Vector2(start)*pitch,Vector2(3,1)*pitch)
				assert(owners[start]!=owners[start+Vector2i(2,0)])
				Q.draw(self,"w_sword",rect)
				var path=SKIN.item_path("w_sword");var texture=SKIN.texture(path);var source=SKIN.bounds(path)
				var fit=minf((rect.size.x-8)/source.size.x,(rect.size.y-8)/source.size.y);var size=source.size*fit
				draw_texture_rect_region(texture,Rect2(rect.get_center()-size*.5,size),source)
		SKIN.set_bag_style(old,false)
