extends SceneTree
const T=preload("res://scripts/ui/pockets/terminal_grid.gd")
const FIX=preload("res://tests/fixtures/bag_trial_fixture_v109.gd")
const C=preload("res://scripts/ui/pockets/bag_contacts.gd")
var tag="after"
func _initialize()->void:
	root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true)
	for arg in OS.get_cmdline_user_args():
		if arg=="--before":tag="before"
	call_deferred("capture")
func capture()->void:
	if DisplayServer.get_name()=="headless":quit(2);return
	var vp=SubViewport.new();vp.size=Vector2i(1600,2040);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
	var view=Joins.new();vp.add_child(view)
	await process_frame;RenderingServer.force_draw(true);await process_frame
	var im=vp.get_texture().get_image()
	var out="res://build/qa/pockets-v130/";DirAccess.make_dir_recursive_absolute(out)
	im.save_png(out+tag+"-joins.png")
	# Same-hue cloth must not make a ruler-sharp brightness cut. Sample the
	# join itself, between the independent slot impressions, in four rotations.
	var jumps=[]
	for n in 4:
		var bags=view.layouts[n];var edge=C.segments(T.form_bags(bags))[0]
		var center=view.origins[n]+(edge.a+edge.b)*.5*view.pitch
		var normal=Vector2.RIGHT if edge.a.x==edge.b.x else Vector2.DOWN
		var a=im.get_pixelv(Vector2i(center-normal*1.5));var b=im.get_pixelv(Vector2i(center+normal*1.5))
		jumps.append(maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))))
	var ok=jumps.all(func(v):return v<.06)
	FileAccess.open(out+tag+"-metrics.json",FileAccess.WRITE).store_string(JSON.stringify({"jumps":jumps,"continuous_same_hue":ok},"\t"))
	print("SOFT_SEAMS_NATIVE ",jumps," ","PASS" if ok else "FAIL")
	quit(0 if ok else 1)
class Joins extends Node2D:
	var font=preload("res://assets/fonts/body.ttf")
	var layouts=[];var origins=[];var pitch=86.0
	func _init()->void:
		for n in 8:
			layouts.append(FIX.touching(FIX.bag("pocket_long_l" if n<4 else "satchel","a",n%4),FIX.bag("pocket_long_j" if n<4 else "pouch","b",n%4),Vector2i.RIGHT,n>=4))
			origins.append(Vector2(60+(n%2)*790,100+floori(n/2.0)*340))
		layouts.append([{"kind":"satchel","uid":"a","x":0,"y":0},{"kind":"pouch","uid":"b","x":3,"y":0},{"kind":"travel","uid":"c","x":0,"y":2},{"kind":"corner","uid":"d","x":3,"y":2}])
		layouts.append([{"kind":"pocket_single","uid":"a","x":0,"y":0},{"kind":"pocket_long_l","uid":"b","x":1,"y":0},{"kind":"pocket_double","uid":"c","x":0,"y":3}])
		layouts.append([{"kind":"pocket_long_l","uid":"a","x":0,"y":0},{"kind":"pocket_long_j","uid":"b","x":2,"y":0}])
		layouts.append([{"kind":"pocket_long_l","uid":"a","x":0,"y":0},{"kind":"pocket_long_j","uid":"b","x":3,"y":0}])
		for n in range(8,12):origins.append(Vector2(60+(n%2)*790,100+floori(n/2.0)*340))
	func _draw()->void:
		draw_rect(Rect2(0,0,1600,2040),Color("494064"))
		for n in layouts.size():
			var title=("长 L + 反长 L" if n<4 else "异色错位拼接")+" · "+str(n%4*90)+"°" if n<8 else ["四袋交点","单格 + 长 L + 双格","长 L 拼合","移开后恢复外沿"][n-8]
			draw_string(font,origins[n]-Vector2(0,25),title,HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color("fff2db"))
			T.surface(self,origins[n],layouts[n],pitch if n<8 else 65)
