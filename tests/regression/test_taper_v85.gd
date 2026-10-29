extends SceneTree
const L=preload("res://scripts/ui/crafting/craft_link_view.gd")
var checks=0
func ck(ok:bool):
 checks+=1
 assert(ok)
func _initialize():
 var full=Vector2(0,1)
 ck(L.half_width(0,full,true)>L.half_width(.25,full,true))
 ck(L.half_width(.25,full,true)>L.half_width(.5,full,true))
 for n in 21:
  var t=float(n)/20
  ck(is_equal_approx(L.half_width(t,full,true),L.half_width(1-t,full,true)))
 for b in [Vector2(800,0),Vector2(0,800),Vector2(-300,400)]:
  for span in L.spans(Vector2.ZERO,b,false):
   var outer=span.x if span.x==0 else span.y
   var inner=span.y if span.x==0 else span.x
   ck(L.half_width(outer,span,false)>L.half_width(inner,span,false))
   var points=L.ribbon(Vector2.ZERO,b,span,false,1.35)
   ck(points.size()==50)
   for p in points:ck(p.is_finite())
   ck(Geometry2D.triangulate_polygon(points).size()>0)
  ck(Geometry2D.triangulate_polygon(L.ribbon(Vector2.ZERO,b,full,true,1.35)).size()>0)
 print("TAPER_V85 ",checks," checks, 0 failures")
 quit()
