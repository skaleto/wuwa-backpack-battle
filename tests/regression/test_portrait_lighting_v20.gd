extends SceneTree
const L=preload("res://scripts/ui/portraits/portrait_lighting.gd")
var checks=0
var failures=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:
	var lighting=L.new()
	# Deliberately asymmetrical solid foot and faint trailing effect.
	var image=Image.create(100,100,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT)
	for y in range(12,85):
		for x in range(64,78):image.set_pixel(x,y,Color.WHITE)
	for y in range(86,100):image.set_pixel(3,y,Color(1,1,1,.1))
	var foot=L.foot_anchor(image,Rect2i(0,0,100,100))
	check(foot.x>.64 and foot.x<.78,"anchor follows actual footwear, not art-box center")
	check(is_equal_approx(foot.y,.85),"translucent effects cannot pull contact below the foot")
	check(L.foot_anchor(image,Rect2i(0,0,0,0)).is_finite(),"empty art has safe contact fallback")
	var texture=ImageTexture.create_from_image(image)
	var before=image.get_data().hex_encode().sha256_text()
	lighting.prepare("synthetic",texture,Rect2(0,0,100,100))
	var entry=lighting.surfaces.synthetic
	var first=entry.mesh[0]
	lighting.prepare("synthetic",texture,Rect2(0,0,100,100))
	check(lighting.surfaces.synthetic.mesh[0]==first,"static lighting mesh is cached, not rebuilt each frame")
	for flipped in [false,true]:
		var arrays=entry.mesh[1 if flipped else 0].surface_get_arrays(0)
		for uv in arrays[Mesh.ARRAY_TEX_UV]:check(uv.x>=0 and uv.x<=1 and uv.y>=0 and uv.y<=1,"lighting samples only existing source pixels")
		for col in arrays[Mesh.ARRAY_COLOR]:check(col.a==1 and minf(col.r,minf(col.g,col.b))>.84 and maxf(col.r,maxf(col.g,col.b))<1.04,"surface lighting preserves alpha and avoids overpainting")
	check(texture.get_image().get_data().hex_encode().sha256_text()==before,"preparation never modifies original image pixels")
	var local=lighting.local_foot("synthetic",Rect2(-50,-100,100,100))
	check(local.x>14 and local.x<28,"asymmetric local contact stays aligned")
	var reflected=Transform2D(0,Vector2(-1,1),0,Vector2.ZERO)*local
	check(is_equal_approx(reflected.x,-local.x) and is_equal_approx(reflected.y,local.y),"opponent flip mirrors contact without moving it vertically")
	for id in ["jiyan","yinlin","verina","encore","sanhua","camellya"]:
		var art=load("res://art_sources/research/armory-v6/local/roles/"+id+"-portrait.webp")
		var bounds=Rect2(art.get_image().get_used_rect())
		lighting.prepare(id,art,bounds)
		var value=Vector2(lighting.surfaces[id].foot)
		check(value.x>=0 and value.x<=1 and value.y>.85 and value.y<=1,"actual leader foot has a valid source-space position: "+id)
		print(id," contact ",value)
	print("PORTRAIT_V20: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
