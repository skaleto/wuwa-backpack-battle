extends RefCounted
## Presentation only. Uses the replay clock, never combat RNG or inventory state.
const TRAVEL=.30
const MAX_IMPACTS=18
const FX=preload('res://scripts/ui/battle/vfx_sprites.gd')
const CORE=Color('fffbea')
var impacts:Array=[]

func spawn(position:Vector2,side:int,weapon:String,color:Color,strong:bool=false)->void:
 impacts.append({'position':position,'side':side,'weapon':weapon,'color':color,'strong':strong,'age':0.0,'duration':.68 if strong else .54})
 if impacts.size()>MAX_IMPACTS:impacts.pop_front()

func update(delta:float)->void:
 for impact in impacts:impact.age+=delta
 impacts=impacts.filter(func(i):return i.age<i.duration)

func clear()->void:impacts.clear()

func draw(canvas:CanvasItem)->void:
 for impact in impacts:paper_impact(canvas,impact)

static func streak(c:CanvasItem,at:Vector2,angle:float,length:float,width:float,color:Color)->void:
 if length<1 or width<.15 or color.a<.025:return
 var axis=Vector2.from_angle(angle);var normal=axis.orthogonal()
 c.draw_colored_polygon(PackedVector2Array([at-axis*length*.6,at-normal*width,at+axis*length,at+normal*width]),color)

static func luminous_color(color:Color,kind:String)->Color:
 # Low-saturation neutral damage otherwise turns every effect into cream fog.
 # This is presentation colour only, not an extra elemental gameplay effect.
 if color.s<.22:
  color=Color({'sword':'65d7ff','broadblade':'ffb05c','gauntlet':'ffd06b','pistol':'ffc77e','rectifier':'be9bff','echo':'6ce6ce'}.get(kind,'bca0ff'))
 return Color.from_hsv(color.h,clampf(color.s,.48,.78),1.0)

static func flight_position(kind:String,from:Vector2,to:Vector2,progress:float)->Vector2:
 var lift=0.0
 match kind:
  'sword':lift=18
  'broadblade':lift=34
  'gauntlet':lift=8
  'rectifier':lift=55
  'echo':lift=38
 return from.lerp(to,progress)+Vector2(0,-sin(progress*PI)*lift)

# Tapered crescent, changing aperture/radius over time. The edges fade to
# transparent rather than presenting a rotating rectangular sprite.
static func crescent(c:CanvasItem,at:Vector2,radii:Vector2,start:float,arc:float,rotation:float,width:float,color:Color)->void:
 if color.a<.025 or width<.2 or arc<.06:return
 # Keep the inner ellipse positive even for the first compressed shock frame.
 # Wide glow ribbons otherwise fold through themselves and cannot triangulate.
 width=minf(width,minf(radii.x,radii.y)*1.7)
 var points=PackedVector2Array();var colors=PackedColorArray()
 const STEPS=40
 for edge in [1,-1]:
  for k in range(STEPS+1):
   var u=float(k if edge==1 else STEPS-k)/STEPS
   var taper=pow(sin(u*PI),.65)
   var a=start+arc*u;var normal=Vector2.from_angle(a)
   var p=normal*radii+normal*width*.5*taper*edge
   points.append(at+p.rotated(rotation))
   colors.append(Color(color,color.a*minf(1,taper*2.5)))
 c.draw_polygon(points,colors)

static func wave(c:CanvasItem,at:Vector2,radius:float,flat:float,rotation:float,width:float,tint:Color,alpha:float)->void:
 if radius<2 or alpha<.025:return
 # Leave a deliberate break in the ring, with taper at both tips.
 crescent(c,at,Vector2(radius,radius*flat),.15,TAU-.32,rotation,width*3,Color(tint,alpha*.14))
 crescent(c,at,Vector2(radius,radius*flat),.15,TAU-.32,rotation,width,Color(tint,alpha))
 crescent(c,at,Vector2(radius,radius*flat),.15,TAU-.32,rotation,width*.23,Color(CORE,alpha*.9))

static func trail_ribbon(c:CanvasItem,path:PackedVector2Array,width:float,color:Color)->void:
 var span=path[0].distance_to(path[-1])
 if span<1.0:return
 width=minf(width,span*.45)
 var points=PackedVector2Array();var colors=PackedColorArray()
 for edge in [1,-1]:
  for k in path.size():
   var n=k if edge==1 else path.size()-1-k
   if n==0 and edge==-1:continue
   var u=float(n)/(path.size()-1)
   var tangent=path[mini(n+1,path.size()-1)]-path[maxi(0,n-1)]
   points.append(path[n]+tangent.normalized().orthogonal()*width*u*.5*edge)
   colors.append(Color(color,color.a*pow(u,.7)))
 c.draw_polygon(points,colors)

static func projectile(c:CanvasItem,flight:Dictionary,from:Vector2,to:Vector2)->void:
 var p=clampf(1-float(flight.life)/TRAVEL,0,1)
 var kind=str(flight.get('weapon','rectifier'));var tint=luminous_color(flight.color,kind)
 var strong=bool(flight.get('strong',false));var scale=1.25 if strong else 1.0
 var at=flight_position(kind,from,to,p)
 var angle=(to-flight_position(kind,from,to,maxf(0,p-.04))).angle()
 var launch=pow(1-p,2)
 # The launch is anchored on the triggering item; it is not another hit.
 if launch>.05:
  FX.draw(c,'light_01',from,Vector2(108,64)*scale,Color(tint,launch*.55),angle)
  if kind in ['sword','broadblade']:
   crescent(c,from,Vector2(54,27)*scale,-2.6,2.9,angle,11*launch,Color(CORE,launch*.8))
  elif kind=='pistol':
   FX.draw(c,'muzzle_03',from,Vector2(55,85)*scale,Color(CORE,launch*.85),angle-PI*.5)
  else:wave(c,from,20+p*28,.65,angle,4,tint,launch*.75)
 var trail=PackedVector2Array()
 var tail=.22 if kind=='pistol' else .17
 var tail_start=maxf(0,p-tail)
 for n in range(9):trail.append(flight_position(kind,from,to,lerpf(tail_start,p,n/8.0)))
 if p>.008:
  trail_ribbon(c,trail,13*scale,Color(tint,.28))
  trail_ribbon(c,trail,5*scale,Color(tint.lightened(.3),.78))
  trail_ribbon(c,trail,1.8*scale,Color(CORE,.95))
 FX.draw(c,'light_01',at,Vector2(84,55)*scale,Color(tint,.64),angle)
 match kind:
  'sword','broadblade':
   var heavy=kind=='broadblade'
   var size=Vector2(19,41) if heavy else Vector2(12,29)
   crescent(c,at,size*scale,-1.55,3.1,angle,(12 if heavy else 7)*scale,Color(tint.lightened(.35),.98))
   crescent(c,at,size*scale,-1.55,3.1,angle,2.5,CORE)
  'gauntlet':
   wave(c,at,27*scale,1.25,angle,9,tint,.9)
   streak(c,at,angle,28*scale,6*scale,CORE)
  'pistol':
   streak(c,at,angle,32*scale,4.5*scale,Color(tint.lightened(.3),1))
   streak(c,at,angle,29*scale,1.8*scale,CORE)
  'rectifier':
   FX.draw(c,'star_06',at,Vector2.ONE*44*scale,Color(CORE,.95),p*2)
   for n in 3:
    var orbit=Vector2(10,21)*Vector2.from_angle(p*TAU*1.5+n*TAU/3)
    FX.draw(c,'light_02',at+orbit.rotated(angle),Vector2.ONE*17,Color(tint.lightened(.6),.85))
  _:
   for n in 3:
    var offset=Vector2(-absf(n-1)*8,(n-1)*13).rotated(angle)
    streak(c,at+offset,angle,22*scale,3*scale,Color(CORE,.95-absf(n-1)*.2))

static func slash(c:CanvasItem,at:Vector2,age:float,angle:float,tint:Color,scale:float,heavy:bool)->void:
 var p=clampf(age/.32,0,1)
 var fade=1-smoothstep(.3,1.0,p)
 if fade<.03:return
 var open=1-pow(1-p,3)
 var size=Vector2(98+open*32,44+open*18)*scale
 var center=at+Vector2(-14+open*30,0).rotated(angle)*scale
 var span=1.3+open*2.6
 crescent(c,center,size,-2.4,span,angle,(67 if heavy else 43)*fade*scale,Color(tint,.13*fade))
 crescent(c,center,size,-2.4,span,angle,(44 if heavy else 28)*fade*scale,Color(tint,.92*fade))
 crescent(c,center,size*.98,-2.4,span,angle,(19 if heavy else 11)*fade*scale,Color(CORE,fade))
 # A second narrow edge separates the bright cut from its coloured wake.
 crescent(c,center,size*1.11,-2.3,span*.93,angle,2*scale,Color(tint.lightened(.5),fade*.72))

static func sparks(c:CanvasItem,at:Vector2,age:float,angle:float,tint:Color,scale:float,heavy:bool,kind:String)->void:
 var count=16 if heavy else 11
 for n in count:
  var life=.29+(n%5)*.065
  if age>=life:continue
  var p=age/life;var fade=pow(1-p,1.25)
  var direction=angle+n*2.399963
  var ray=Vector2.from_angle(direction)
  var speed=(155+(n%4)*72)*scale
  var distance=speed*age*(1-age*.66)
  var gravity=Vector2(0,180*age*age)
  var pos=at+ray*(6+distance)+gravity
  var velocity=ray*speed*(1-age*1.32)+Vector2(0,360*age)
  var length=(8+(n%3)*6)*(1-p)*scale
  var color=CORE if n%3!=0 else tint.lightened(.2)
  streak(c,pos,velocity.angle(),length*1.15,2.1*scale*fade,Color(color,fade))
  # Sparse soft glints, not a field of identical star stickers.
  if n%4==0:
   FX.draw(c,'light_02',pos,Vector2.ONE*(21*scale*fade),Color(tint,fade*.7))
  if kind=='rectifier' and n%4==1:
   FX.draw(c,'star_04',pos,Vector2.ONE*(15*fade),Color(CORE,fade),age*2)

static func paper_impact(c:CanvasItem,impact:Dictionary)->void:
 var age=float(impact.age);var duration=float(impact.duration)
 var fade=pow(maxf(0,1-age/duration),1.5)
 if fade<.025:return
 var at:Vector2=impact.position;var kind=str(impact.weapon)
 var tint=luminous_color(impact.color,kind);var strong=bool(impact.strong)
 var heavy=kind in ['broadblade','gauntlet'] or strong
 var scale=1.24 if strong else 1.0
 var angle=-.65 if int(impact.side)==0 else PI+.65
 var flash=maxf(0,1-age/.095)
 # A brief brilliant contact, followed by shaped motion and ballistic sparks.
 FX.draw(c,'light_01',at,Vector2.ONE*(125+age*100)*scale,Color(tint,fade*.56))
 if flash>0:
  FX.draw(c,'star_06',at,Vector2(120,74)*scale*(.65+flash*.35),Color(CORE,flash),angle)
  streak(c,at,angle,65*scale,5*flash*scale,Color(CORE,flash))
 match kind:
  'sword','broadblade':
   slash(c,at,age,angle,tint,scale,kind=='broadblade')
   if heavy and age>.055:
    slash(c,at+Vector2(8,5),age-.055,angle+1.35,tint.lightened(.3),scale*.72,false)
   if kind=='broadblade':
    wave(c,at,22+(1-pow(1-clampf(age/.33,0,1),3))*96,.5,angle,5,tint,fade*.48)
  'gauntlet':
   var open=1-pow(1-clampf(age/.32,0,1),3)
   wave(c,at,18+open*108*scale,.72,angle,17*(1-open)+6,tint,fade*.95)
   if age>.065:
    var q=clampf((age-.065)/.4,0,1)
    wave(c,at,24+q*126*scale,.72,angle,4*(1-q),tint.lightened(.45),(1-q)*.65)
   for n in 6:
    var ray=angle+n*TAU/6
    streak(c,at+Vector2.from_angle(ray)*open*38,ray,(25+open*28)*scale,6*(1-open)+1,Color(CORE,fade*.75))
  'pistol':
   var opening=clampf(age/.16,0,1)
   for n in 5:
    var ray=angle-.9+n*.45
    streak(c,at+Vector2.from_angle(ray)*opening*23,ray,(44-n%2*15)*scale,5*(1-opening)+.6,Color(CORE,fade))
   wave(c,at,12+age*150,.7,angle,4.5,tint,fade*.75)
  'rectifier':
   for n in 2:
    var local=age-n*.06
    if local<0:continue
    var p=clampf(local/.42,0,1)
    var radius=(22+(1-pow(1-p,2))*99)*scale
    crescent(c,at,Vector2(radius,radius*.67),n*PI+age*4,4.8,angle,14*(1-p)+2,Color(tint.lightened(n*.25),pow(1-p,1.3)*.95))
    crescent(c,at,Vector2(radius,radius*.67),n*PI+age*4,4.8,angle,4,Color(CORE,pow(1-p,1.3)*.95))
   FX.draw(c,'light_03',at,Vector2.ONE*(46+age*110)*scale,Color(CORE,fade*.75),age*2)
  _:
   # Three staggered claw cuts make echo attacks distinct from energy orbs.
   for n in 3:
    var local=age-n*.026
    if local<0:continue
    slash(c,at+Vector2((n-1)*14,(n-1)*18),local,angle-.28,tint,scale*.64,false)
 sparks(c,at,age,angle,tint,scale,heavy,kind)
