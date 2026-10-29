extends SceneTree
## Preview only: no production changes, game scene, save writes or OS input.
const OUT="res://build/qa/pockets-v132/unjoined-preview/"
func _initialize()->void:
	root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true);call_deferred("capture")
func capture()->void:
	if DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(OUT)
	var vp=SubViewport.new();vp.size=Vector2i(1500,1460);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
	var board=Comparison.new();vp.add_child(board)
	await process_frame;RenderingServer.force_draw(true);await process_frame
	assert(vp.get_texture().get_image().save_png(OUT+"comparison.png")==OK)
	print("UNJOINED_PREVIEW captured: standalone full hems; production renderer unchanged")
	quit()
class Comparison extends Node2D:
	const T=preload("res://scripts/ui/pockets/terminal_grid.gd")
	const F=preload("res://scripts/ui/pockets/bag_fine_seams.gd")
	const SKIN=preload("res://scripts/ui/visual_skin.gd")
	const FONT=preload("res://assets/fonts/body.ttf")
	var layouts=[
		[{"uid":"a","kind":"satchel","x":0,"y":0},{"uid":"b","kind":"pouch","x":3,"y":1}],
		[{"uid":"a","kind":"pocket_long_l","x":0,"y":0},{"uid":"b","kind":"pocket_long_j","x":2,"y":0}],
		[{"uid":"a","kind":"satchel","x":0,"y":0},{"uid":"b","kind":"pouch","x":3,"y":0},{"uid":"c","kind":"travel","x":0,"y":2},{"uid":"d","kind":"pouch","x":3,"y":2}]
	]
	func _surface(at:Vector2,bags:Array,independent:bool)->void:
		var pieces=T.form_bags(bags);var before=pieces.duplicate(true)
		T.placement_grid(self,at,Vector2i(5,4),100)
		if independent:
			# Each bag is drawn exactly as when placed alone. No neighbor information
			# is supplied, so no shared-edge compression or contact-corner resizing runs.
			for bag in pieces:F.draw(self,at,[bag],100,1)
		else:F.draw(self,at,pieces,100,1)
		for bag in pieces:
			for cell in bag.cells:T.SLOTS.draw(self,Rect2(at+Vector2(cell)*100,Vector2.ONE*100),Color.WHITE,cell.x+3*cell.y,1,false,T.FORM.ART.slot_tint("patchwork_v129",bag.kind))
		assert(before==pieces)
	func _draw()->void:
		draw_rect(Rect2(0,0,1500,1460),Color("494064"))
		for column in 2:
			var x=75+column*750
			draw_string(FONT,Vector2(x,55),["当前 · 接触边经过处理","试验 · 完整袋子直接贴放"][column],HORIZONTAL_ALIGNMENT_LEFT,-1,29,Color("fff2db"))
			for row in 3:
				var at=Vector2(x,125+row*440)
				draw_string(FONT,at-Vector2(0,20),["异色错位","同色长 L 拼合","四袋交点 · 跨袋摆放"][row],HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("ead7ff"))
				_surface(at,layouts[row],column==1)
				if row==2:
					var path=SKIN.item_path("w_sword");var texture=SKIN.texture(path)
					if texture!=null:
						var src=SKIN.bounds(path);var size=Vector2(330,330*src.size.y/src.size.x)
						draw_texture_rect_region(texture,Rect2(at+Vector2(145,145)-size*.5+Vector2(150,0),size),src)
