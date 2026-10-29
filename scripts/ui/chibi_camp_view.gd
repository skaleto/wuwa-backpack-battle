extends RefCounted
## Approved workbench composition, independent live actors/items/actions.
const Q=preload('res://scripts/ui/visual_skin.gd')
const C=preload('res://scripts/data/catalog.gd')
const ART=preload('res://scripts/ui/party/recruitment_art.gd')
const W=preload('res://scripts/ui/workbench_art.gd')
const BACKGROUND='res://assets/ui/workbench/workbench.png'
const HERO=Rect2(172,103,487,516)
const LOADOUT=Rect2(622,367,706,254)
static func tag_rect(index:int)->Rect2:
 return Rect2(28+index*173,690,164,213)
static func entry_rect(mode:String)->Rect2:
 return Rect2(925,665 if mode=='practice' else 810,388,105)
static func reveal(age:float,delay:float,duration:float=.35)->float:
 return 1.0-pow(1.0-clampf((age-delay)/duration,0,1),3)
static func actor(g,role:String,rect:Rect2,alpha:float)->void:
 if alpha<=.001:return
 g.paint_alpha=alpha;g._draw_character(role,rect,false);g.paint_alpha=1.0
static func draw(g)->void:
 g.draw_texture_rect(Q.texture(BACKGROUND),Rect2(0,0,1440,960),false)
 var leader=C.characters[g.selected_leader]
 var enter=reveal(g.camp_age,0)
 # The real text sits on the authored hanging sign; no title baked into the bitmap.
 g.draw_set_transform_matrix(g.draw_basis*Transform2D(-.055,Vector2(275,83)))
 ART.text(g,g.font,str(ProjectSettings.get_setting('application/config/name')),Rect2(-158,-35,322,70),36,W.INK)
 g.draw_set_transform_matrix(g.draw_basis)
 # Sparse window dust follows the light, with no star wallpaper or looping glows.
 for n in 5:
  var at=Vector2(48+fmod(n*87.1,540),175+fmod(n*67.3-g.age*5+2000,330))
  g.draw_circle(at,1.1,Color('fff4cf',(.12+.12*maxf(0,sin(g.age+n)))*enter))
 var arriving=reveal(g.camp_age,.04,.4)
 var swap=smoothstep(0,.23,g.selection_age) if not g.camp_previous_leader.is_empty() else 1.0
 g.draw_set_transform_matrix(g.draw_basis*Transform2D(0,Vector2(1,.12),0,Vector2(416,611)))
 g.draw_circle(Vector2.ZERO,98,Color('4d3552',.17*arriving));g.draw_set_transform_matrix(g.draw_basis)
 if swap<1:actor(g,g.camp_previous_leader,Rect2(HERO.position+Vector2(-10*swap,0),HERO.size),arriving*(1-swap))
 actor(g,g.selected_leader,Rect2(HERO.position+Vector2(10*(1-swap),10*(1-arriving)),HERO.size),arriving*swap)
 ART.text(g,g.font,leader.name,Rect2(57,532,190,34),28,W.INK)
 var opening=leader.get('v60_traits',[["开场",""]])[0]
 ART.text(g,g.font,str(opening[0])+'：'+str(opening[1]),Rect2(57,571,190,28),19,W.INK)
 _loadout(g)
 _portraits(g)
 for mode in ['practice','async']:
  var r=entry_rect(mode)
  W.button(g,r,'人机对战' if mode=='practice' else '在线对战','camp:'+mode+':enter',mode,31)
  var pending=g.camp_saves.get(mode,{})
  var resumable=not pending.is_empty() and pending.get('phase','')!='ending'
  W.button(g,Rect2(1322,r.position.y+6,100,39),'战绩','camp:'+mode+':history','label',18)
  var store=g.practice_storage if mode=="practice" else g.online_storage
  if store.resume_status in ["corrupt","incompatible"]:
   ART.text(g,g.font,"旧进度暂不可读取，开始新局会保留备份",Rect2(r.position.x,r.end.y+2,r.size.x,25),15,W.INK)
  if resumable:
   var who=C.characters.get(pending.get('leader',''),{}).get('name','')
   W.button(g,Rect2(r.position.x+8,r.end.y+1,r.size.x-16,28),'继续 · '+who+' · 第 '+str(pending.get('round',1))+' 回合','camp:'+mode+':resume','label',16)
   W.button(g,Rect2(1322,r.position.y+54,100,39),'新对局','camp:'+mode+':new','label',16)
 W.button(g,Rect2(1346,27,62,62),'','quit','tool')
static func _loadout(g)->void:
 ART.text(g,g.font,'初始装备',Rect2(741,380,320,40),24,W.INK,false)
 var items=g.camp_loadouts.get(g.selected_leader,[])
 var count=items.size()
 var width=620.0/maxi(1,count)
 for n in count:
  var item=items[n];var x=668+n*width;var appear=reveal(g.selection_age,n*.03,.20)
  var r=Rect2(x,440+(1-appear)*4,width-20,113)
  g._draw_icon(item.kind,r,0,1.0,false,true)
  ART.text(g,g.font,C.items[item.kind].name,Rect2(x-5,564,width-10,34),18,W.INK)
static func _portraits(g)->void:
 for n in C.selectable_leaders().size():
  var id=str(C.selectable_leaders()[n]);var r=tag_rect(n);var selected=id==g.selected_leader
  var hover=g.motion.hover('camp-portrait:'+id,r.has_point(g.mouse))
  var down=clampf(float(g.motion.presses.get('choose:'+id,0.0))/.16,0,1)
  var entering=reveal(g.camp_age,.09+n*.035,.32)
  var at=r.position+Vector2(0,10*(1-entering)-hover*4+down*2-(3 if selected else 0))
  var base=Rect2(at+Vector2(2,174),Vector2(160,42))
  W.face(g,base,'label',Color(1.0,.86,.50,entering) if selected else Color(1,1,1,entering))
  var path=Q.portrait_path(id)
  ART.fit(g,Q.texture(path),Rect2(at+Vector2(5,0),Vector2(154,178)),Q.bounds(path),Color(1,1,1,entering))
  ART.text(g,g.font,C.characters[id].name,base.grow(-6),21,Color(W.INK,entering))
  if selected:
   for k in 3:
    var origin=at+Vector2(13+k*13,5+abs(k-1)*6)
    g.draw_line(origin,origin+Vector2((k-1)*5,-11),Color('fff0a1',entering),4,true)
  g._button(r,'','choose:'+id,true,false)
