extends RefCounted
## Two authored layers animate independently; selling remains a preparation transaction.
const Q=preload("res://scripts/ui/visual_skin.gd")
const T=preload("res://scripts/ui/ui_theme.gd")
const PATH="res://assets/ui/shop-recycle/chest-atlas.png"
const LID=Rect2(20,170,980,365)
const BODY=Rect2(20,860,980,580)
static func accepts(held:Dictionary,origin:String)->bool:
 return not held.is_empty() and origin in ["board","stash","bag"]
static func pose(rect:Rect2,openness:float)->Dictionary:
 var t=smoothstep(0,1,clampf(openness,0,1))
 var body=Rect2(rect.position+Vector2(13,31),Vector2(rect.size.x-26,55))
 var lid=Rect2(body.position+Vector2(-1,-10-24*t),Vector2(body.size.x+2,31-7*t))
 return {"body":body,"lid":lid}
static func draw(c:CanvasItem,text:Callable,rect:Rect2,openness:float,price:int,owned:bool)->void:
 var p=pose(rect,openness);var texture=Q.texture(PATH)
 if texture:
  c.draw_texture_rect_region(texture,p.body,BODY)
  c.draw_texture_rect_region(texture,p.lid,LID)
 if owned and openness>.03:
  var glow=StyleBoxFlat.new();glow.bg_color=Color("ffedaf",.15*openness);glow.border_color=Color("f7d982",.75*openness);glow.set_border_width_all(2);glow.set_corner_radius_all(14)
  c.draw_style_box(glow,rect.grow(1))
  T.glyph(c,"coin",Rect2(rect.position+Vector2(34,81),Vector2.ONE*23))
  text.call("+"+str(price),rect.position+Vector2(61,100),20,Q.PLUM)
 else:
  text.call("回收箱",rect.position+Vector2(34,100),18,Q.PLUM)
