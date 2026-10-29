extends RefCounted
## One complete-width bust crop for all Q portraits. Original PNG stays intact.
static func head_source(bounds:Rect2)->Rect2:
	return Rect2(bounds.position,Vector2(bounds.size.x,bounds.size.y*.78))

static func fitted(area:Rect2,source:Rect2)->Rect2:
	if not area.has_area() or not source.has_area():return Rect2()
	var size=source.size*minf(area.size.x/source.size.x,area.size.y/source.size.y)
	return Rect2(area.get_center()-size*.5,size)

static func draw(c:CanvasItem,texture:Texture2D,area:Rect2,source:Rect2,tint:Color=Color.WHITE)->void:
	if texture==null:return
	var target=fitted(area,source)
	if not target.has_area():return
	# Fade only the lower shoulder edge, never hair tips or the sides of a face.
	var solid=.84
	c.draw_texture_rect_region(texture,Rect2(target.position,target.size*Vector2(1,solid)),Rect2(source.position,source.size*Vector2(1,solid)),tint)
	var top=target.position+Vector2(0,target.size.y*solid)
	var uv_top=(source.position+Vector2(0,source.size.y*solid))/texture.get_size()
	var uv_end=source.end/texture.get_size()
	c.draw_polygon(PackedVector2Array([top,Vector2(target.end.x,top.y),target.end,Vector2(target.position.x,target.end.y)]),PackedColorArray([tint,tint,Color(tint,0),Color(tint,0)]),PackedVector2Array([uv_top,Vector2(uv_end.x,uv_top.y),uv_end,Vector2(uv_top.x,uv_end.y)]),texture)
