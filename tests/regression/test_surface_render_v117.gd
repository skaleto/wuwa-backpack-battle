extends SceneTree
const Q=preload('res://scripts/ui/items/item_quality.gd')
var checks=0
var failures=0
var viewport
var painter
class Painter extends Node2D:
 var diagram=false
 var click_age=-1.0
 var texture:Texture2D
 var quality='heron'
 var lit=false
 var phase=0.0
 var angle=0.0
 var clip_uv=[]
 func _draw():
  draw_rect(Rect2(0,0,220,220),Color(.08,.06,.12))
  if diagram:
   var model={'cells':[Vector2i.ZERO],'markers':[{'cell':Vector2i(1,0),'state':'lit'},{'cell':Vector2i(0,1),'state':'unlit'}],'click_age':click_age}
   preload('res://scripts/ui/items/item_star_diagram.gd').draw(self,model,Rect2(30,30,160,160),0,1)
   return
  draw_set_transform_matrix(Transform2D(angle,Vector2.ONE,0,Vector2(110,110))*Transform2D(0,Vector2(-64,-64)))
  if clip_uv.is_empty():draw_texture(texture,Vector2.ZERO)
  else:
   for uv_shape in clip_uv:
    var points=PackedVector2Array()
    for uv in uv_shape:points.append(uv*texture.get_size())
    draw_polygon(points,PackedColorArray([Color.WHITE]),uv_shape,texture)
  if lit:Q.draw_surface(self,quality,texture,phase,1,clip_uv)
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():
 root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true);call_deferred('test')
func shot():
 painter.queue_redraw();await process_frame;RenderingServer.force_draw(true);await process_frame
 return viewport.get_texture().get_image()
func test():
 if DisplayServer.get_name()=='headless':printerr('This pixel test requires native renderer');quit(1);return
 viewport=SubViewport.new();viewport.size=Vector2i(220,220);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 painter=Painter.new();viewport.add_child(painter)
 # Synthetic alpha fixture: transparent border, central hole, dark linework.
 var source=Image.create(128,128,false,Image.FORMAT_RGBA8);source.fill(Color.TRANSPARENT)
 for y in range(12,116):
  for x in range(12,116):
   if Rect2i(46,46,36,36).has_point(Vector2i(x,y)):continue
   source.set_pixel(x,y,Color.BLACK if x<18 or y<18 or x>109 or y>109 else Color(.22,.45,.65,1))
 var original=source.get_data().duplicate();painter.texture=ImageTexture.create_from_image(source)
 for n in 100:
  var bands=Q.surface_bands('heron',Vector2(128,128),n*.05)
  if not bands.is_empty() and absf(bands[0].center-64)<3:painter.phase=n*.05;break
 for turn in 4:
  painter.angle=turn*PI*.5
  for clipped in [false,true]:
   painter.clip_uv=[PackedVector2Array([Vector2(0,0),Vector2(.5,0),Vector2(.5,1),Vector2(0,1)])] if clipped else []
   painter.lit=false;var base=await shot();painter.lit=true;var glow=await shot()
   var outside_changed=0;var changed=0;var dark_changed=0
   for y in 220:
    for x in 220:
     var a=base.get_pixel(x,y);var b=glow.get_pixel(x,y)
     if a==b:continue
     changed+=1
     if a.is_equal_approx(base.get_pixel(0,0)):outside_changed+=1
     if a.r<.01 and a.g<.01 and a.b<.01:dark_changed+=1
   ck(outside_changed==0,'no light in transparent holes/outside original silhouette, turn '+str(turn)+' clip '+str(clipped))
   ck(dark_changed==0,'painted black linework unchanged')
   ck(changed>30,'real source RGB brightens visibly')
 painter.clip_uv=[];painter.quality='w_sword';painter.lit=false;var low=await shot();painter.lit=true;var low_lit=await shot()
 ck(low.get_data()==low_lit.get_data(),'low quality render stays identical')
 ck(source.get_data()==original,'source pixels never modified')
 painter.diagram=true;painter.click_age=-1;var idle=await shot()
 painter.click_age=.24;var pulse=await shot()
 painter.click_age=.8;var settled=await shot()
 ck(pulse.get_data()!=idle.get_data(),'detail diagram renders an actual timed wave')
 ck(settled.get_data()==idle.get_data(),'detail diagram returns to original core after wave')
 print('SURFACE_RENDER_V117 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
