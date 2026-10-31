extends RefCounted
## Pure projection and presentation; no settlement or persistence side effects.
const P=preload("res://scripts/run/run_progression.gd")
const T=preload("res://scripts/ui/ui_theme.gd")
const SKIN=preload("res://scripts/ui/visual_skin.gd")
const CUP=Vector2(388,50)
const HEART=Vector2(685,50)
const STEP=31.0
const CHANGE_TIME=1.1
static func model(run:Dictionary,combat:Dictionary,age:float,replaying:bool=false)->Dictionary:
 var limits=P.display_limits(run)
 var result=run.get("phase","")=="result" and not replaying and combat.has("winner")
 var delta=P.result_delta(int(combat.get("winner",0))) if result else {"wins":0,"losses":0}
 var before=int(run.get("wins",0));var hearts=maxi(0,int(limits.losses)-int(run.get("losses",0)))
 return {"wins":mini(limits.wins,before+(delta.wins if age>=CHANGE_TIME else 0)),"hearts":maxi(0,hearts-(delta.losses if age>=CHANGE_TIME else 0)),"before_wins":before,"before_hearts":hearts,"win_limit":int(limits.wins),"heart_limit":int(limits.losses),"delta":delta,"result":result,"age":maxf(0,age)}
static func hud(c:CanvasItem,text:Callable,m:Dictionary)->void:
 for n in m.win_limit:
  var filled=n<m.wins
  var rect=Rect2(CUP+Vector2(n*STEP,0)-Vector2.ONE*15,Vector2.ONE*30)
  T.glyph(c,"victory",rect,1.0 if filled else .35,Color.TRANSPARENT if filled else Color("d9cde7"))
 text.call("奖杯  %d / %d"%[m.wins,m.win_limit],Vector2(439,83),17,SKIN.LIGHT)
 for n in m.heart_limit:
  var filled=n<m.hearts
  T.glyph(c,"heart",Rect2(HEART+Vector2(n*STEP,0)-Vector2.ONE*16,Vector2.ONE*32),1.0 if filled else .5,Color.TRANSPARENT if filled else Color("9d91b0"))
 text.call("生命  %d / %d"%[m.hearts,m.heart_limit],Vector2(674,83),17,SKIN.LIGHT)
static func reward(c:CanvasItem,text:Callable,m:Dictionary)->void:
 if not m.result:return
 var age=float(m.age);var won=m.delta.wins>0
 var center=Vector2(720,536)
 text.call("奖杯 +1" if won else "生命 −1",Vector2(655,641),30,SKIN.LIGHT)
 if won:
  var pop=clampf(age/.22,0,1)
  var scale_value=1.0+sin(pop*PI)*.22
  var travel=smoothstep(.65,CHANGE_TIME,age)
  var end=CUP+Vector2(mini(m.before_wins,m.win_limit-1)*STEP,0)
  var at=center.lerp(end,travel)+Vector2(0,-sin(travel*PI)*70)
  var size=lerpf(132,30,travel)*scale_value*minf(1,pop*1.7)
  if age<.65:
   var burst=clampf(age/.65,0,1)
   for n in 12:
    var ray=Vector2.from_angle(n*TAU/12-PI/2)
    var at_spark=center+ray*lerpf(36,83,burst)
    c.draw_line(at_spark,at_spark+ray*12*(1-burst),Color("fff0af",1-burst),3,true)
  if age<CHANGE_TIME:T.glyph(c,"victory",Rect2(at-Vector2.ONE*size*.5,Vector2.ONE*size))
  elif age<1.45:
   var fade=1-smoothstep(CHANGE_TIME,1.45,age)
   for n in 8:
    var ray=Vector2.from_angle(n*TAU/8)
    c.draw_circle(end+ray*lerpf(14,32,1-fade),2.8*fade,Color("fff2b3",fade))
  else:T.glyph(c,"victory",Rect2(center-Vector2.ONE*53,Vector2.ONE*106),.9)
 else:
  if age<.4:
   var size=126*(.8+.2*sin(clampf(age/.4,0,1)*PI*.5))
   T.glyph(c,"heart",Rect2(center-Vector2.ONE*size*.5,Vector2.ONE*size))
  elif age<1.15:
   _broken_heart(c,center,clampf((age-.4)/.75,0,1))
  else:T.glyph(c,"heart",Rect2(center-Vector2.ONE*49,Vector2.ONE*98),.55,Color("ada0bd"))
static func _broken_heart(c:CanvasItem,center:Vector2,t:float)->void:
 var path=SKIN.ui_path("glyph_heart");var texture=SKIN.texture(path)
 if texture==null:return
 var source=SKIN.bounds(path)
 var seam=[Vector2(.5,0),Vector2(.45,.27),Vector2(.56,.48),Vector2(.44,.64),Vector2(.5,1)]
 for side in 2:
  var shape:Array=[Vector2(0,0),Vector2(0,1)] if side==0 else [Vector2(1,1),Vector2(1,0)]
  var cut=seam.duplicate();if side==0:cut.reverse()
  shape.append_array(cut)
  var points=PackedVector2Array();var uv=PackedVector2Array()
  var direction=-1 if side==0 else 1
  for v in shape:
   points.append(center+((v-Vector2.ONE*.5)*126).rotated(direction*t*.48)+Vector2(direction*t*42,-sin(t*PI)*13+t*t*40))
   uv.append((source.position+v*source.size)/texture.get_size())
  c.draw_polygon(points,PackedColorArray([Color(1,1,1,1-t)]),uv,texture)
