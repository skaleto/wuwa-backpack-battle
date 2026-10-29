extends RefCounted
const C=preload("res://scripts/data/catalog.gd")
const COLORS=[Color("51dc8e"),Color("43b6ff"),Color("b278ff"),Color("ffca48"),Color("ff586c")]
static func color(kind: String) -> Color:
	var def=C.items.get(kind,{})
	return COLORS[clampi(int(def.get("craft_tier",def.get("rarity",1)))-1,0,4)]
static func _tier(kind:String)->int:
	var def=C.items.get(kind,{})
	return int(def.get("craft_tier",def.get("rarity",1)))

static func surface_bands(kind:String,size:Vector2,time:float)->Array:
	# Geometry is in original texture coordinates. The source texture itself
	# masks every band, including transparent gaps and painted dark linework.
	if C.is_tag(kind,"bag") or _tier(kind)<4 or size.x<=0 or size.y<=0:return []
	var phase=fposmod(time/(3.8 if _tier(kind)==4 else 3.2)+float(kind.hash()&255)/255.0,1.0)
	if phase>.56:return []
	var width=size.x*.20
	var center=lerpf(-width,size.x+width,phase/.56)
	var result=[]
	for n in 12:
		var left=clampf(center-width+width*2*n/12.0,0,size.x)
		var right=clampf(center-width+width*2*(n+1)/12.0,0,size.x)
		if right<=left:continue
		result.append({"left":left,"right":right,"center":center,"width":width})
	return result

static func _surface_alpha(x:float,band:Dictionary)->float:
	return pow(maxf(0.0,1.0-absf(x-band.center)/band.width),1.7)

static func draw_surface(canvas:CanvasItem,kind:String,texture:Texture2D,time:float,alpha:float=1.0,clip_uv:Array=[])->void:
	# Caller supplies the same image-to-canvas transform as the original art.
	# Optional UV polygons preserve the board renderer's occupied-cell clipping.
	var size=texture.get_size()
	for band in surface_bands(kind,size,time):
		var strip=PackedVector2Array([Vector2(band.left,0),Vector2(band.right,0),Vector2(band.right,size.y),Vector2(band.left,size.y)])
		var polygons=[strip]
		if not clip_uv.is_empty():
			polygons=[]
			for uv_shape in clip_uv:
				var shape=PackedVector2Array()
				for uv in uv_shape:shape.append(uv*size)
				polygons.append_array(Geometry2D.intersect_polygons(strip,shape))
		for polygon in polygons:
			var uvs=PackedVector2Array();var colors=PackedColorArray()
			for point in polygon:
				uvs.append(point/size)
				# Brighten the painted RGB rather than putting white sprites on it.
				var strength=_surface_alpha(point.x,band)*alpha*(.60 if _tier(kind)>=5 else .48)
				colors.append(Color(1.85,1.85,1.85,strength))
			canvas.draw_polygon(polygon,colors,uvs,texture)

static func draw(canvas: CanvasItem,kind: String,rect: Rect2,alpha: float=1.0,_time:float=-1.0) -> void:
	if C.is_tag(kind,"bag"):return
	# Soft elliptical light has no item border and never changes picking geometry.
	var center=rect.get_center()+Vector2(0,rect.size.y*.13)
	var radius=rect.size*Vector2(.52,.47)
	var tint=color(kind)
	for layer in 2:
		var reach=radius*(1.0 if layer==0 else .62)
		var strength=.62 if layer==0 else .24
		canvas.draw_texture_rect(glow_texture(),Rect2(center-reach,reach*2),false,Color(tint,alpha*strength))

static var _glow:GradientTexture2D
static func glow_texture()->GradientTexture2D:
	if _glow==null:
		var ramp=Gradient.new();ramp.colors=PackedColorArray([Color.WHITE,Color(1,1,1,0)])
		_glow=GradientTexture2D.new();_glow.gradient=ramp;_glow.width=128;_glow.height=128
		_glow.fill=GradientTexture2D.FILL_RADIAL;_glow.fill_from=Vector2(.5,.5);_glow.fill_to=Vector2(1,.5)
	return _glow
