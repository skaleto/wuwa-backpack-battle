extends RefCounted
const SKIN=preload("res://scripts/ui/visual_skin.gd")
## Wuthering Waves terminal surfaces: quiet graphite, fine white type and gold selection.
## This file owns materials; original character and item textures stay untouched.
const SHELL=Color("202b3a")
const EDGE=Color("657787")
const SHADOW=Color("0d1622")
const LINING=Color("283444")
const FELT=Color("172332")
const PAPER=Color("f0f1ed")
const MUTED=Color("b7c4d0")
const BRASS=Color("dfcfa7")
const JADE=Color("aed4c6")
const ALERT=Color("e7a29d")
const INK=Color("eef1f4")
const DARK=Color("202834")

static func cut(rect: Rect2,corner: float=6.0) -> PackedVector2Array:
	var a=rect.position;var b=rect.end;var k=minf(corner,minf(rect.size.x,rect.size.y)*.3)
	return PackedVector2Array([a+Vector2(k,0),Vector2(b.x-k,a.y),Vector2(b.x,a.y+k),b-Vector2(0,k),b-Vector2(k,0),Vector2(a.x+k,b.y),Vector2(a.x,b.y-k),a+Vector2(0,k)])

static func fade(c: CanvasItem,r: Rect2,a: Color,b: Color,vertical: bool=false) -> void:
	a=tone(a);b=tone(b)
	var points=PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)])
	c.draw_polygon(points,PackedColorArray([a,a,b,b] if vertical else [a,b,b,a]))

static func plate(c: CanvasItem,r: Rect2,fill: Color=SHELL,edge: Color=EDGE,corner: float=6.0) -> void:
	if SKIN.is_chibi():
		surface(c,r,"panel",fill.a);return
	var points=cut(r,minf(corner,6))
	c.draw_colored_polygon(points,fill)
	c.draw_polyline(PackedVector2Array(Array(points)+[points[0]]),Color(edge,edge.a*.5),1,true)
	# One lit edge rather than a bevel, shadow or a second enclosing frame.
	c.draw_line(r.position+Vector2(8,0),Vector2(r.end.x-8,r.position.y),Color(tone(PAPER),fill.a*.19),1,true)

static func cloth(c: CanvasItem,r: Rect2,color: Color=LINING,seam: bool=true) -> void:
	# Kept as an API alias for old callers. No cloth, seams, stitching or rivets.
	fade(c,r,Color(color,color.a*.72),Color(color,color.a*.30))
	if seam:c.draw_line(r.position,Vector2(r.end.x,r.position.y),Color(tone(PAPER),color.a*.12),1,true)

static func pin(c: CanvasItem,p: Vector2,alpha: float=1.0) -> void:
	c.draw_line(p-Vector2(3,0),p+Vector2(3,0),Color(tone(PAPER),alpha*.35),1,true)

static func latch(c: CanvasItem,r: Rect2) -> void:
	plate(c,r,LINING,EDGE,3)

static func contact(_c: CanvasItem,_p: Vector2,_width: float,_alpha: float=.28) -> void:
	# Original illustrations float in the terminal's 2D space, with no fake floor.
	pass

static func rule(c: CanvasItem,a: Vector2,b: Vector2,alpha: float=.24) -> void:
	c.draw_line(a,b,Color(tone(PAPER),alpha),1,true)

static func tone(value:Color)->Color:return SKIN.tone(value)

static func surface(c:CanvasItem,rect:Rect2,name:String="panel",alpha:float=1.0,tint:Color=Color.WHITE)->void:
	var metadata=SKIN.ui_entry(name)
	if (metadata.get("light_surface",false) or name in ["panel","shop_tray"]) and c.has_method("_register_paper_surface"):c._register_paper_surface(rect)
	var path=SKIN.ui_path(name);var texture=SKIN.texture(path)
	if texture==null:return
	var source=SKIN.bounds(path)
	var authored=metadata.get("source_rect",[])
	if authored is Array and authored.size()==4:
		source=Rect2(float(authored[0]),float(authored[1]),float(authored[2]),float(authored[3])).intersection(Rect2(Vector2.ZERO,texture.get_size()))
	if source.size.x<=0 or source.size.y<=0:return
	if name in ["button_round","portrait_frame","battle_button","paper_cell"]:
		var scale_value=rect.size.y/source.size.y if name=="battle_button" else minf(rect.size.x/source.size.x,rect.size.y/source.size.y)
		if name=="portrait_frame":
			# The authored frame is an open ring. Fill its aperture before drawing
			# the unchanged source, with the disk safely inside the outer ink edge.
			c.draw_circle(rect.get_center(),minf(source.size.x,source.size.y)*scale_value*.43,Color(SKIN.NIGHT,alpha))
		c.draw_texture_rect_region(texture,Rect2(rect.get_center()-source.size*scale_value*.5,source.size*scale_value),source,Color(tint,tint.a*alpha))
		return
	var corner=minf(source.size.x,source.size.y)*.18
	var margins=metadata.get("slice_margin",[corner,corner,corner,corner])
	if not margins is Array or margins.size()!=4:margins=[corner,corner,corner,corner]
	var left=clampf(float(margins[0]),0,source.size.x*.49)
	var top=clampf(float(margins[1]),0,source.size.y*.49)
	var right=clampf(float(margins[2]),0,source.size.x*.49)
	var bottom=clampf(float(margins[3]),0,source.size.y*.49)
	# Use authored/alpha bounds and preserve every source patch, including the
	# opaque cream center. No rectangular overpaint can cover the rounded ink edge.
	var max_edge=18.0 if not name.begins_with("button") else minf(24.0,rect.size.y*.44)
	var factor=minf(max_edge/maxf(1,maxf(maxf(left,right),maxf(top,bottom))),minf(rect.size.x/maxf(1,left+right),rect.size.y/maxf(1,top+bottom))*.95)
	var display=[left*factor,top*factor,right*factor,bottom*factor]
	var authored_display=metadata.get("display_margins",[])
	if authored_display is Array and authored_display.size()==4:
		# Screen-space margins keep the native grid aperture exact. A separate
		# battle entry reuses the same art with its compact 12-pixel border.
		for n in 4:display[n]=maxf(0,float(authored_display[n]))
		var fit=minf(1.0,minf(rect.size.x/maxf(1,display[0]+display[2]),rect.size.y/maxf(1,display[1]+display[3]))*.95)
		for n in 4:display[n]*=fit
	var sx=[source.position.x,source.position.x+left,source.end.x-right,source.end.x]
	var sy=[source.position.y,source.position.y+top,source.end.y-bottom,source.end.y]
	var dx=[rect.position.x,rect.position.x+display[0],rect.end.x-display[2],rect.end.x]
	var dy=[rect.position.y,rect.position.y+display[1],rect.end.y-display[3],rect.end.y]
	for y in 3:
		for x in 3:
			if sx[x+1]<=sx[x] or sy[y+1]<=sy[y]:continue
			c.draw_texture_rect_region(texture,Rect2(dx[x],dy[y],dx[x+1]-dx[x],dy[y+1]-dy[y]),Rect2(sx[x],sy[y],sx[x+1]-sx[x],sy[y+1]-sy[y]),Color(tint,tint.a*alpha))

# Runtime color masks retain authored glyph alpha; source PNG files are immutable.
static var glyph_masks:Dictionary={}
static func glyph(c:CanvasItem,name:String,rect:Rect2,alpha:float=1.0,tint:Color=Color.TRANSPARENT)->bool:
	if not SKIN.is_chibi():return false
	var path=SKIN.ui_path("glyph_"+name);var texture=SKIN.texture(path)
	if texture==null:return false
	var source=SKIN.bounds(path)
	if name in ["ghost","book","sell","lock"]:tint=Color.TRANSPARENT
	if tint.a>0:
		if not glyph_masks.has(path):
			var pixels=texture.get_image().get_region(Rect2i(source))
			var ratio=minf(1.0,192.0/maxf(pixels.get_width(),pixels.get_height()))
			pixels.resize(maxi(1,roundi(pixels.get_width()*ratio)),maxi(1,roundi(pixels.get_height()*ratio)),Image.INTERPOLATE_LANCZOS)
			pixels.convert(Image.FORMAT_RGBA8);pixels.clear_mipmaps()
			var bytes=pixels.get_data()
			for n in range(0,bytes.size(),4):bytes[n]=255;bytes[n+1]=255;bytes[n+2]=255
			var mask=Image.create_from_data(pixels.get_width(),pixels.get_height(),false,Image.FORMAT_RGBA8,bytes)
			mask.generate_mipmaps();glyph_masks[path]=ImageTexture.create_from_image(mask)
		texture=glyph_masks[path];source=Rect2(Vector2.ZERO,texture.get_size())
	else:tint=Color.WHITE
	var scale_value=minf(rect.size.x/source.size.x,rect.size.y/source.size.y)
	c.draw_texture_rect_region(texture,Rect2(rect.get_center()-source.size*scale_value*.5,source.size*scale_value),source,Color(tint,tint.a*alpha))
	return true
