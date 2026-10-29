extends RefCounted
## Workbench-only atlas. Caps, icon and edge geometry keep their authored proportions.
const Q=preload('res://scripts/ui/visual_skin.gd')
const A=preload('res://scripts/ui/party/recruitment_art.gd')
const ATLAS='res://assets/ui/workbench/controls.png'
const INK=Color('35283e')
const SOURCES={
 'practice':Rect2(60,90,1418,267),
 'async':Rect2(60,402,1418,263),
 'label':Rect2(94,727,930,202),
 'tool':Rect2(1157,682,280,274)
}
static func face(g,rect:Rect2,kind:String,tint:Color=Color.WHITE)->Rect2:
 var source:Rect2=SOURCES[kind];var texture=Q.texture(ATLAS)
 if kind=='tool':
  g.draw_texture_rect_region(texture,rect,source,tint);return rect.grow(-8)
 var factor=rect.size.y/source.size.y
 var left=minf((350 if kind in ['practice','async'] else 105)*factor,rect.size.x*.39)
 var right=minf(105*factor,rect.size.x*.22)
 var lc=350 if kind in ['practice','async'] else 105
 var sx=[source.position.x,source.position.x+lc,source.end.x-105,source.end.x]
 var dx=[rect.position.x,rect.position.x+left,rect.end.x-right,rect.end.x]
 for n in 3:
  g.draw_texture_rect_region(texture,Rect2(dx[n],rect.position.y,dx[n+1]-dx[n],rect.size.y),Rect2(sx[n],source.position.y,sx[n+1]-sx[n],source.size.y),tint)
 return Rect2(rect.position+Vector2(left+3,3),Vector2(rect.size.x-left-right-6,rect.size.y-6))
static func button(g,rect:Rect2,label:String,action:String,kind:String='label',size:int=19)->void:
 g._button(rect,'',action,true,false)
 var hover=g.motion.hover(action+'@'+str(rect.position),rect.has_point(g.mouse))
 var down=clampf(float(g.motion.presses.get(action,0.0))/.16,0,1)
 var pose=Transform2D(0,Vector2.ONE*(1+hover*.012-down*.02),0,rect.get_center()+Vector2(0,-hover*3+down*3))*Transform2D(0,-rect.get_center())
 g.draw_set_transform_matrix(g.draw_basis*pose)
 var room=face(g,rect,kind,Color(1+hover*.06,1+hover*.06,1+hover*.06))
 A.text(g,g.font,label,room,size,INK)
 if action=='quit':
  var center=rect.get_center();g.draw_line(center-Vector2(9,9),center+Vector2(9,9),INK,4,true);g.draw_line(center+Vector2(-9,9),center+Vector2(9,-9),INK,4,true)
 g.draw_set_transform_matrix(g.draw_basis)
