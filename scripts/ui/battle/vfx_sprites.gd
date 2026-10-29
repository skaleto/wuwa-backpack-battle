extends RefCounted
## Authored CC0 particle art, transformed as a textured quad in the caller's
## existing canvas space. No emitters, random state or gameplay writes.
static var textures:Dictionary={}
static func texture(key:String)->Texture2D:
	if not textures.has(key):
		var image=Image.load_from_file("res://assets/vfx/kenney/"+key+".png")
		# These greyscale particles include authored alpha. Lift RGB to white while
		# retaining that coverage so ordinary canvas blending never paints black
		# mist. Native image operations avoid a pixel loop on the first attack.
		if image!=null:
			image.convert(Image.FORMAT_RGBA8)
			image.adjust_bcs(1.0,0.0,1.0)
			image.adjust_bcs(2.1,1.0,1.0)
		textures[key]=ImageTexture.create_from_image(image) if image!=null else null
	return textures[key]

static func draw(c:CanvasItem,key:String,center:Vector2,size:Vector2,tint:Color,angle:float=0.0)->void:
	if tint.a<.008 or minf(size.x,size.y)<.5:return
	var tex=texture(key)
	if tex==null:return
	var points=PackedVector2Array()
	for v in [Vector2(-.5,-.5),Vector2(.5,-.5),Vector2(.5,.5),Vector2(-.5,.5)]:
		points.append(center+(v*size).rotated(angle))
	c.draw_colored_polygon(points,tint,PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]),tex)
