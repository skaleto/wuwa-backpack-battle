extends RefCounted
## Concrete atlas drawing port. It owns no game, run, inventory or navigation.
var _font:Font
var _drawing:Dictionary
func _init(font:Font,drawing:Dictionary):
	_font=font;_drawing=drawing
func width(value:String,size:int)->float:return _font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
func shade(rect:Rect2,color:Color):_drawing.shade.call(rect,color)
func panel(rect:Rect2):_drawing.panel.call(rect)
func header(rect:Rect2):_drawing.header.call(rect)
func box(rect:Rect2,fill:Color,edge:Color=Color.TRANSPARENT,radius:int=12):_drawing.box.call(rect,fill,edge,radius)
func title(value:String,at:Vector2,icon:String="star",size:int=18):_drawing.title.call(value,at,icon,size)
func text(value:String,at:Vector2,size:int,color:Color):_drawing.text.call(value,at,size,color)
func wrapped(value:String,at:Vector2,width:float,size:int,color:Color,lines:int=0):_drawing.wrapped.call(value,at,width,size,color,lines)
func icon(kind:String,rect:Rect2):_drawing.icon.call(kind,rect)
func glyph(kind:String,rect:Rect2):_drawing.glyph.call(kind,rect)
func button(rect:Rect2,value:String,id:String,enabled:bool=true,primary:bool=false):_drawing.button.call(rect,value,id,enabled,primary)
func hit(rect:Rect2,id:String):_drawing.hit.call(rect,id)
func stat(at:Vector2,width:float,label:String,value:String,icon:String,tint:Color):_drawing.stat.call(at,width,label,value,icon,tint)
func pages(clauses:Array,width:float,height:float,size:int)->Array:return _drawing.pages.call(clauses,width,height,size)
func text_page(content:Array,at:Vector2,size:int):_drawing.text_page.call(content,at,size)
func star_diagram(model:Dictionary,rect:Rect2):_drawing.star_diagram.call(model,rect)
