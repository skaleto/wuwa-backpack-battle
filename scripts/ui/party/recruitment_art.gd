extends RefCounted
## Recruitment's layered artwork; values and texture regions only.
const SKIN=preload("res://scripts/ui/visual_skin.gd")
const ROOT="res://assets/ui/recruitment/"
const COLORS={"link":Color("8a83db"),"volley":Color("df8498"),"guard":Color("64b8ad"),"artisan":Color("dca077"),"supply":Color("dbb565")}
const ORDER=["link","volley","guard","artisan","supply"]
const DECOR={
	"title":Rect2(20,72,780,258),"confirm":Rect2(803,94,625,214),
	"satchel":Rect2(168,349,516,319),"check":Rect2(948,396,271,260),
	"socket":Rect2(260,690,349,356),"charm":Rect2(968,700,288,326)}
static func texture(name:String)->Texture2D:return SKIN.texture(ROOT+name+".png")
static func color(ability:String)->Color:return COLORS.get(ability,Color("8a83db"))
# These are the undecorated cream areas in the source atlas, not texture bounds.
const DECOR_TEXT={"title":Rect2(214,151,408,91),"confirm":Rect2(968,177,300,86),"satchel":Rect2(310,460,280,85)}
static func fitted_rect(area:Rect2,source:Rect2)->Rect2:
	var ratio=minf(area.size.x/source.size.x,area.size.y/source.size.y)
	return Rect2(area.get_center()-source.size*ratio*.5,source.size*ratio)
static func decor_text_rect(name:String,area:Rect2)->Rect2:
	var source:Rect2=DECOR[name];var safe:Rect2=DECOR_TEXT[name]
	var target=fitted_rect(area,source);var ratio=target.size.x/source.size.x
	return Rect2(target.position+(safe.position-source.position)*ratio,safe.size*ratio)
static func fit(c:CanvasItem,tex:Texture2D,area:Rect2,source:Rect2=Rect2(),tint:Color=Color.WHITE)->Rect2:
	if tex==null:return Rect2()
	if not source.has_area():source=Rect2(Vector2.ZERO,tex.get_size())
	var target=fitted_rect(area,source)
	c.draw_texture_rect_region(tex,target,source,tint);return target
static func decor(c:CanvasItem,name:String,area:Rect2,alpha:float=1.0)->void:
	fit(c,texture("decor"),area,DECOR[name],Color(1,1,1,alpha))
static func emblem(c:CanvasItem,ability:String,area:Rect2,alpha:float=1.0)->void:
	var n=ORDER.find(ability)
	if n<0:return
	fit(c,texture("abilities"),area,Rect2(n*434+8,119,418,445),Color(1,1,1,alpha))
static func rounded(c:CanvasItem,rect:Rect2,fill:Color,edge:Color=Color.TRANSPARENT,radius:float=14.0,width:float=1.5)->void:
	var style=StyleBoxFlat.new();style.bg_color=fill;style.border_color=edge
	style.set_corner_radius_all(int(radius));style.set_border_width_all(int(width));style.anti_aliasing=true
	c.draw_style_box(style,rect)
static func cell_center(cells:Array)->Vector2:
	var center=Vector2.ZERO
	for cell in cells:center+=Vector2(cell)+Vector2.ONE*.5
	return center/maxi(1,cells.size())
static func guard_thread(c:CanvasItem,link:Dictionary,origin:Vector2,cell:float)->void:
	if link.get("mode","")!="guard":return
	var a=origin+cell_center(link.get("source_cells",[]))*cell
	var b=origin+cell_center(link.get("target_cells",[]))*cell
	c.draw_line(a,b,Color("a7efd6",.22),6,true)
	c.draw_line(a,b,Color("c6ffe7",.85),2,true)
	for p in [a,b]:
		c.draw_circle(p,5,Color("87cdbb"));c.draw_circle(p,2.5,Color("effff0"))
static func text_layout(font:Font,value:String,area:Rect2,size:int,center:bool=true)->Dictionary:
	var paragraph:TextParagraph
	var fitted=size
	while true:
		paragraph=TextParagraph.new()
		paragraph.width=area.size.x
		paragraph.alignment=HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT
		paragraph.break_flags=TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_GRAPHEME_BOUND
		paragraph.add_string(value,font,fitted)
		if paragraph.get_size().y<=area.size.y and paragraph.get_size().x<=area.size.x or fitted<=1:break
		fitted-=1
	var at=area.position+Vector2(0,(area.size.y-paragraph.get_size().y)*.5)
	return {"paragraph":paragraph,"font_size":fitted,"bounds":Rect2(at,paragraph.get_size())}
static func text(c:CanvasItem,font:Font,value:String,area:Rect2,size:int,color_value:Color,center:bool=true)->void:
	if value.is_empty():return
	var layout=text_layout(font,value,area,size,center)
	layout.paragraph.draw(c.get_canvas_item(),layout.bounds.position,color_value)
static func decor_label(c:CanvasItem,font:Font,name:String,value:String,area:Rect2,size:int,color_value:Color,alpha:float=1.0)->void:
	decor(c,name,area,alpha)
	text(c,font,value,decor_text_rect(name,area),size,Color(color_value,alpha))
