extends RefCounted
## Read-only shelf labels and lock sticker. Never receives inventory/run/game.
const C=preload("res://scripts/data/catalog.gd")
const INFO=preload("res://scripts/ui/items/item_info.gd")
const ICONS=preload("res://scripts/ui/ability_icons.gd")
const POCKETS=preload("res://scripts/inventory/pocket_rules_current.gd")
const T=preload("res://scripts/ui/ui_theme.gd")
const PRIORITY=["counter","charge","haste","shield","healing","break_shield","noise","frost","stamina","cleanse","max_hp","attack"]
static func benefits(kind:String,build:Dictionary={"pocket_version":143})->Array:
 if C.is_tag(kind,"bag"):
  var stat=POCKETS.profile(kind,build).stat
  return [{"capacity":["bag","扩容"],"shield":["shield","护盾"],"speed":["haste","加速"],"echo":["echo","声骸增强"],"weapon":["weapon","伤害增强"]}[stat]]
 var chips=INFO.type_chips(kind);var result=[]
 for key in PRIORITY:
  for chip in chips:
   if ICONS.normalize(chip[0])==key:
    result.append([key,"生命" if key=="max_hp" else chip[1]]);break
  if result.size()==2:break
 return result if not result.is_empty() else chips.slice(0,1)
static func plate(canvas:CanvasItem,rect:Rect2,fill:Color,edge:Color,radius:int)->void:
 var style=StyleBoxFlat.new();style.bg_color=fill;style.border_color=edge;style.set_border_width_all(1);style.set_corner_radius_all(radius);style.anti_aliasing=true
 canvas.draw_style_box(style,rect)
static func draw_benefits(canvas:CanvasItem,kind:String,rect:Rect2,font:Font,build:Dictionary={"pocket_version":143})->void:
 var labels=benefits(kind,build);var widths=[];var total=0.0
 for label in labels:
  var w=font.get_string_size(label[1],HORIZONTAL_ALIGNMENT_LEFT,-1,13).x+24
  widths.append(w);total+=w
 total+=(labels.size()-1)*5
 var x=rect.get_center().x-total*.5
 for n in labels.size():
  var chip=Rect2(x,rect.position.y,widths[n],22)
  plate(canvas,chip,Color("f5e6fa",.82),Color("b89bce",.45),8)
  ICONS.draw(canvas,labels[n][0],Rect2(chip.position+Vector2(2,2),Vector2(18,18)))
  canvas.draw_string(font,chip.position+Vector2(22,16),labels[n][1],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("614373"))
  x+=widths[n]+5
static func lock_pose(rect:Rect2,locked:bool,age:float,was_locked:bool)->Dictionary:
 var arrival=1.0-clampf(age/.32,0,1)
 var visible=1.0 if locked else arrival if not was_locked else 0.0
 var scale_value=1.0+sin(clampf(age/.32,0,1)*PI)*.16 if locked else 1.0+.12*(1.0-arrival)
 var size=Vector2(43,42)*scale_value
 return {"rect":Rect2(rect.get_center()-Vector2(3,0)-size*.5+Vector2(0,-11*arrival if locked else -8*(1-arrival)),size),"alpha":visible}
static func draw_lock(canvas:CanvasItem,rect:Rect2,locked:bool,age:float,was_locked:bool,hover:float)->void:
 if not locked:T.glyph(canvas,"lock",rect.grow(-5),.5+.5*hover)
 var pose=lock_pose(rect,locked,age,was_locked)
 if pose.alpha<=.001:return
 var sticker:Rect2=pose.rect;var a=float(pose.alpha)
 plate(canvas,Rect2(sticker.position+Vector2(0,2),sticker.size),Color("77558b",a*.25),Color.TRANSPARENT,10)
 plate(canvas,sticker,Color("fff2c4",a),Color("ad7eae",a),10)
 plate(canvas,sticker.grow(-3),Color("dcc6f2",a),Color("fffdf2",a),8)
 T.glyph(canvas,"lock",sticker.grow(-6),a)
