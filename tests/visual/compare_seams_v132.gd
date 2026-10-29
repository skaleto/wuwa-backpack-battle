extends SceneTree
const OUT="res://build/qa/pockets-v132/"
func _initialize()->void:
	root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true);call_deferred("capture")
func capture()->void:
	if DisplayServer.get_name()=="headless":quit(2);return
	var vp=SubViewport.new();vp.size=Vector2i(1680,1030);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
	vp.add_child(Comparison.new())
	await process_frame;RenderingServer.force_draw(true);await process_frame
	vp.get_texture().get_image().save_png(OUT+"reference-comparison.png")
	print("REFERENCE_COMPARISON_V132 captured");quit()
class Comparison extends Node2D:
	const T=preload("res://scripts/ui/pockets/terminal_grid.gd")
	const OLD=preload("res://build/qa/pockets-v132/before/bag_fine_seams.gd")
	const F=preload("res://scripts/ui/pockets/bag_fine_seams.gd")
	const FONT=preload("res://assets/fonts/body.ttf")
	var reference=preload("res://assets/ui/seams/seam-reference.png")
	const BAGS=[{"uid":"a","kind":"satchel","x":0,"y":0},{"uid":"b","kind":"pouch","x":3,"y":1}]
	func _ready()->void:
		for n in 2:
			var clip=Control.new();clip.position=Vector2(580+n*550,466);clip.size=Vector2(500,500);clip.clip_contents=true
			var detail=Detail.new();detail.old=n==0;detail.position=Vector2(-500,0);detail.scale=Vector2.ONE*2.5
			clip.add_child(detail);add_child(clip)
	func _bag(at:Vector2,pitch:float,old:bool)->void:
		T.placement_grid(self,at,Vector2i(5,3),pitch)
		var pieces=T.form_bags(BAGS)
		if old:OLD.draw(self,at,pieces,pitch,1)
		else:F.draw(self,at,pieces,pitch,1)
		for bag in pieces:
			for cell in bag.cells:
				T.SLOTS.draw(self,Rect2(at+Vector2(cell)*pitch,Vector2.ONE*pitch),Color.WHITE,cell.x+3*cell.y,1,false,T.FORM.ART.slot_tint("patchwork_v129",bag.kind))
	func _draw()->void:
		draw_rect(Rect2(0,0,1680,1030),Color("494064"))
		for n in 3:
			var x=30+n*550
			draw_string(FONT,Vector2(x,52),["确认的效果图","修改前 · 实际绘制","现在 · 实际绘制"][n],HORIZONTAL_ALIGNMENT_LEFT,-1,27,Color("fff2db"))
			if n==0:draw_texture_rect_region(reference,Rect2(x,85,500,300),Rect2(845,195,500,300))
			else:_bag(Vector2(x,85),100,n==1)
		draw_string(FONT,Vector2(30,438),"接触端头放大",HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color("fff2db"))
		# Reference and runtime use approximately the same 100-pixel cell pitch.
		draw_texture_rect_region(reference,Rect2(30,466,500,500),Rect2(1045,195,200,200))
	class Detail extends Node2D:
		var old=false
		func _draw()->void:
			# Enlarge the actual 100px mesh, not a second larger-pitch mesh.
			var p=100.0;var pieces=T.form_bags(Comparison.BAGS)
			T.placement_grid(self,Vector2.ZERO,Vector2i(5,3),p)
			if old:OLD.draw(self,Vector2.ZERO,pieces,p,1)
			else:F.draw(self,Vector2.ZERO,pieces,p,1)
			for bag in pieces:
				for cell in bag.cells:T.SLOTS.draw(self,Rect2(Vector2(cell)*p,Vector2.ONE*p),Color.WHITE,cell.x+3*cell.y,1,false,T.FORM.ART.slot_tint("patchwork_v129",bag.kind))
