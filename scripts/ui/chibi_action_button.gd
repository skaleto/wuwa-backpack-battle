extends RefCounted
## Presentation only: authored cloth faces, live text, stable input elsewhere.
const SKIN=preload('res://scripts/ui/visual_skin.gd')
const START=Rect2(82,831,374,92)
const RESUME=Rect2(476,848,210,64)
static func style_for(action:String)->String:
 return 'start' if action in ['start','camp:practice:enter'] else 'team' if action in ['crew','camp:async:enter'] else 'secondary'
static func geometry(rect:Rect2,style:String)->Dictionary:
 var entry=SKIN.ui_entry('action_'+style)
 var s=entry.source_rect;var source=Rect2(s[0],s[1],s[2],s[3]);var cap=entry.horizontal_caps
 var factor=minf(rect.size.y/source.size.y,rect.size.x/(cap[0]+cap[1]+40.0))
 var left=cap[0]*factor;var right=cap[1]*factor
 return {'source':source,'caps':cap,'left':left,'right':right,'text':Rect2(rect.position+Vector2(left+5,0),Vector2(maxf(1,rect.size.x-left-right-10),rect.size.y))}
static func pose(rect:Rect2,style:String,hover:float,down:float,enabled:bool,time:float)->Transform2D:
 var h=clampf(hover,0,1) if enabled else 0.0;var d=clampf(down,0,1) if enabled else 0.0
 var idle=sin(time*1.8)*1.2 if style=='start' and enabled else 0.0
 return Transform2D(0,Vector2.ONE*(1+h*.015-d*.025),0,rect.get_center()+Vector2(0,idle-h*3.5+d*3.5))*Transform2D(0,-rect.get_center())
static func font_size(font:Font,label:String,room:Rect2,style:String)->int:
 var size=29 if style=='start' else 22 if style=='team' else 21 if room.size.y>=60 else 18 if room.size.y>=40 else 16
 while size>12 and font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>room.size.x:size-=1
 return size
static func draw(canvas:CanvasItem,font:Font,rect:Rect2,label:String,style:String,hover:float,down:float,enabled:bool,time:float,alpha:float,basis:Transform2D)->void:
 var texture=SKIN.texture(SKIN.ui_path('action_'+style))
 if texture==null:return
 var layout=geometry(rect,style);var source:Rect2=layout.source
 var sx=[source.position.x,source.position.x+layout.caps[0],source.end.x-layout.caps[1],source.end.x]
 var dx=[rect.position.x,rect.position.x+layout.left,rect.end.x-layout.right,rect.end.x]
 canvas.draw_set_transform_matrix(basis*pose(rect,style,hover,down,enabled,time))
 var opacity=alpha*(1.0 if enabled else .45)
 var brightness=1.0+clampf(hover,0,1)*.06 if enabled else 1.0
 for n in 3:
  canvas.draw_texture_rect_region(texture,Rect2(dx[n],rect.position.y,dx[n+1]-dx[n],rect.size.y),Rect2(sx[n],source.position.y,sx[n+1]-sx[n],source.size.y),Color(brightness,brightness,brightness,opacity))
 var text_rect:Rect2=layout.text
 var size=font_size(font,label,text_rect,style)
 var width=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
 var at=text_rect.get_center()+Vector2(-width*.5,(font.get_ascent(size)-font.get_descent(size))*.5)
 # Cream edge separates the dark lettering from woven fabric without a web border.
 canvas.draw_string(font,at+Vector2(0,1),label,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color('fff7df',opacity*.75))
 canvas.draw_string(font,at,label,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color('503447' if style=='start' else '354e54' if style=='team' else '493665',opacity))
 canvas.draw_set_transform_matrix(basis)
