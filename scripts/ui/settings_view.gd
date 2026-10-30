extends RefCounted
## Display and hit geometry only; audio routing/persistence belong to the scene.
const T=preload("res://scripts/ui/ui_theme.gd")
const Q=preload("res://scripts/ui/visual_skin.gd")
const PANEL=Rect2(340,130,760,700)
const CHANNELS=["music","effects"]
static func slider(channel:String)->Rect2:
 return Rect2(420,332 if channel=="music" else 469,550,36)
static func draw(g,prefs,focus:String="")->void:
 var a=g.paint_alpha
 g.draw_rect(Rect2(0,0,1440,960),Color(Q.PLUM,.62*a))
 T.surface(g,PANEL,"detail_panel",a)
 g._text("设置",Vector2(403,204),35,Q.PLUM)
 g._button(Rect2(883,157,168,54),"返回","settings:back")
 for channel in CHANNELS:
  var r=slider(channel);var muted=prefs.is_muted(channel)
  var ink=Color(Q.PLUM,a);var color=Color("8abfad") if channel=="music" else Color("ac8ed4")
  var at=Vector2(431,r.position.y-42)
  _sound_icon(g,at,channel,ink)
  g._text("背景音乐" if channel=="music" else "音效",Vector2(466,r.position.y-32),26,Q.PLUM)
  g._button(Rect2(905,r.position.y-71,136,48),"已关闭" if muted else "已开启","settings:toggle:"+channel)
  var start=r.position+Vector2(0,18);var end=start+Vector2(r.size.x,0)
  g.draw_line(start+Vector2(0,2),end+Vector2(0,2),Color("b7a0c7",a),15,true)
  g.draw_line(start,end,Color("dbcee6",a),12,true)
  for edge in [start,end]:g.draw_circle(edge,6,Color("dbcee6",a))
  var amount=prefs.volume(channel)
  if amount>0:g.draw_line(start,start.lerp(end,amount),Color(color,a*(.4 if muted else 1.0)),12,true)
  var knob=start.lerp(end,amount)
  if focus==channel:g.draw_arc(knob,19,0,TAU,40,Color(color,a),2,true)
  g.draw_circle(knob+Vector2(0,3),14,Color("85619f",.35*a))
  g.draw_circle(knob,14,Color(Q.CREAM,a));g.draw_arc(knob,14,0,TAU,40,Color(color,a),2,true)
  g.draw_circle(knob+Vector2(-3,-4),4,Color(1,1,1,.8*a))
  g._text(str(roundi(amount*100))+"%",Vector2(992,r.position.y+26),21,Q.PLUM)
 g.draw_line(Vector2(404,565),Vector2(1040,565),Color("b49bcf",.38*a),1.5,true)
 g._text("索拉里斯大乱斗",Vector2(410,613),27,Q.PLUM)
 g._text("试玩版 · V138",Vector2(860,613),20,Q.PLUM)
 g._text("鸣潮题材非官方二创 · 使用 Godot 引擎制作",Vector2(410,655),20,Q.PLUM)
 g._text("原作角色与素材权利归原权利人所有。",Vector2(410,689),18,Color("78658b"))
 g._button(Rect2(785,730,254,54),"恢复默认音量","settings:reset")
static func _sound_icon(g,at:Vector2,channel:String,ink:Color)->void:
 if channel=="music":
  g.draw_line(at+Vector2(0,6),at+Vector2(0,-16),ink,3,true)
  g.draw_line(at+Vector2(0,-16),at+Vector2(16,-20),ink,4,true)
  g.draw_line(at+Vector2(16,-20),at+Vector2(16,2),ink,3,true)
  g.draw_circle(at+Vector2(-4,7),6,ink);g.draw_circle(at+Vector2(12,3),6,ink)
 else:
  g.draw_colored_polygon(PackedVector2Array([at+Vector2(-12,-5),at+Vector2(-5,-5),at+Vector2(3,-12),at+Vector2(3,12),at+Vector2(-5,5),at+Vector2(-12,5)]),ink)
  for radius in [10,17]:g.draw_arc(at+Vector2(1,0),radius,-.8,.8,16,ink,2.5,true)
