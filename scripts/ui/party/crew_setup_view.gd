extends Node2D
## Small preparation workbench. It returns a chosen configuration, never applies it.
const BUTTON=preload("res://scripts/ui/chibi_action_button.gd")
const CLOSE=Rect2(1168,48,224,64)
const ART=preload("res://scripts/ui/party/recruitment_art.gd")
const THEME=preload("res://scripts/ui/ui_theme.gd")
const TITLE=Rect2(480,12,480,145)
const INK=Color("493367")
const LABELS={"link":"串联","volley":"合击","guard":"守护","artisan_return":"取回材料","artisan_star":"新增星位","supply":"定向补给"}
const APPLY={"link":"连接","volley":"配对","guard":"配对","artisan_return":"取回","artisan_star":"确定方向","supply":"刷新"}
var model:Dictionary={}
var font:Font
var body_font:Font
var active=false
var tab=""
var page=0
var selected=-1
var pointer=Vector2(-100,-100)
var hits:Array=[]
var elapsed=0.0
var rejection=0.0
var close_hover=0.0
func open(value:Dictionary,title_font:Font,text_font:Font)->void:
	model=value.duplicate(true);font=title_font;body_font=text_font;active=true;visible=true;z_index=95;elapsed=0;close_hover=0
	var available=tabs()
	if tab not in available:tab=str(available[0]) if not available.is_empty() else ""
	page=0;selected=-1;queue_redraw()
func refresh(value:Dictionary)->void:
	model=value.duplicate(true);selected=-1
	if tab not in tabs():tab=str(tabs()[0]) if not tabs().is_empty() else ""
	page=clampi(page,0,maxi(0,ceili(rows().size()/4.0)-1));queue_redraw()
func close()->void:active=false;visible=false;hits=[]
func tabs()->Array:
	var out=[]
	for key in LABELS:
		var owner="artisan" if key.begins_with("artisan") else key
		if not model.get("options",{}).get(key,[]).is_empty() or (key in ["link","volley","guard","supply"] and model.get("team",[]).any(func(m):return m.ability_id==owner)):out.append(key)
	return out
func rows()->Array:return model.get("options",{}).get(tab,[])
func advance(delta:float)->void:
	if not active:return
	close_hover=move_toward(close_hover,1.0 if CLOSE.has_point(pointer) else 0.0,delta*10)
	elapsed+=delta;rejection=maxf(0,rejection-delta);queue_redraw()
func intent(event:InputEvent)->Dictionary:
	if not active:return {}
	if event is InputEventMouseMotion:pointer=event.position;return {}
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:return {"kind":"close"}
		if event.keycode==KEY_ENTER and selected>=0:return {"kind":"configure","config":rows()[selected].config.duplicate(true)}
	if event is InputEventMouseButton and event.pressed:
		pointer=event.position
		if event.button_index in [MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_WHEEL_UP]:
			page=clampi(page+(1 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -1),0,maxi(0,ceili(rows().size()/4.0)-1));return {}
		if event.button_index!=MOUSE_BUTTON_LEFT:return {}
		for hit in hits:
			if not hit.rect.has_point(pointer):continue
			if hit.kind=="close":return {"kind":"close"}
			if hit.kind=="tab":tab=hit.value;page=0;selected=-1;return {"kind":"click"}
			if hit.kind=="row":selected=hit.value;return {"kind":"click"}
			if hit.kind=="page":page=clampi(page+hit.value,0,maxi(0,ceili(rows().size()/4.0)-1));return {"kind":"click"}
			if hit.kind=="apply" and selected>=0:return {"kind":"configure","config":rows()[selected].config.duplicate(true)}
	return {}
func _draw()->void:
	if not active or font==null:return
	hits=[]
	if model.get("background"):draw_texture_rect(model.background,Rect2(0,0,1440,960),false)
	else:draw_rect(Rect2(0,0,1440,960),Color("57467f"))
	draw_rect(Rect2(0,0,1440,960),Color("453274",.18))
	ART.decor_label(self,font,"title","队伍搭配",TITLE,36,INK)
	var close_rect=CLOSE
	BUTTON.draw(self,font,CLOSE,"返回整备","secondary",close_hover,0,true,elapsed,1,Transform2D.IDENTITY)
	hits.append({"kind":"close","rect":close_rect})
	var team:Array=model.get("team",[])
	for n in team.size():
		var m=team[n];var origin=Vector2(88+n*237,185)
		ART.decor(self,"socket",Rect2(origin+Vector2(25,0),Vector2(144,144)))
		preload("res://scripts/ui/portraits/portrait_framing.gd").draw(self,m.portrait,Rect2(origin+Vector2(40,15),Vector2(114,114)),m.head_source)
		ART.emblem(self,m.get("icon_id",m.ability_id),Rect2(origin+Vector2(135,95),Vector2(50,50)))
		ART.text(self,font,m.name,Rect2(origin+Vector2(-10,154),Vector2(210,32)),25,Color("fff0db"))
		ART.text(self,body_font,m.ability_name,Rect2(origin+Vector2(-10,191),Vector2(210,28)),20,Color("e1d7f6"))
	if team.is_empty():
		ART.decor(self,"socket",Rect2(212,207,150,150),.55)
		ART.text(self,font,"+",Rect2(254,247,66,66),38,Color("fff0db"))
		ART.text(self,body_font,"等待新伙伴",Rect2(90,380,400,32),22,Color("fff0db"))
	_draw_inventory()
	THEME.surface(self,Rect2(588,170,805,712),"panel")
	if model.get("automatic",false):
		_draw_automatic(team)
		return
	var available=tabs()
	for n in available.size():
		var r=Rect2(616+n*minf(150,735.0/maxi(1,available.size())),196,minf(142,727.0/maxi(1,available.size())),47)
		ART.rounded(self,r,Color("bba5df") if available[n]==tab else Color("e7daef"),Color("c0abd7"),14)
		ART.text(self,font,LABELS[available[n]],Rect2(r.position+Vector2(4,11),r.size-Vector2(8,10)),18,INK)
		hits.append({"kind":"tab","rect":r,"value":available[n]})
	var owner="artisan" if tab.begins_with("artisan") else tab
	var focused=team.filter(func(m):return m.ability_id==owner)
	if not focused.is_empty():ART.text(self,body_font,focused[0].base_text,Rect2(628,265,720,65),19,INK,false)
	var options=rows()
	if options.is_empty():
		var message="第 3、6 回合结束后选择伙伴" if team.is_empty() else "本轮定向机会已使用，或暂无可供应目标" if tab=="supply" else "背包中暂无可配对的物品"
		ART.text(self,body_font,message,Rect2(681,464,600,78),23,Color("97819f"))
	for n in mini(4,maxi(0,options.size()-page*4)):
		var i=page*4+n;var row=options[i];var r=Rect2(620,350+n*100,739,89)
		var chosen=i==selected or (selected<0 and row.get("selected",false))
		var hover=r.has_point(pointer)
		if hover:r.position.y-=2
		ART.rounded(self,r,Color("fff3d6") if chosen else Color("eee0ed"),Color("d9ac55") if chosen else Color("d3bddc"),17,2 if chosen else 1)
		var icons:Array=row.get("icons",[])
		for j in mini(2,icons.size()):ART.fit(self,icons[j].texture,Rect2(r.position+Vector2(12+j*80,9),Vector2(74,69)),icons[j].source)
		var left=183 if not icons.is_empty() else 24
		ART.text(self,body_font,row.label,Rect2(r.position+Vector2(left,21),Vector2(r.size.x-left-55,62)),18,INK,false)
		if chosen:ART.decor(self,"check",Rect2(r.end-Vector2(48,65),Vector2(37,37)))
		hits.append({"kind":"row","rect":r,"value":i})
	if options.size()>4:
		for n in 2:
			var r=Rect2(642+n*160,786,62,43)
			ART.rounded(self,r,Color("d4c2e8"),Color.TRANSPARENT,13)
			ART.text(self,font,"‹" if n==0 else "›",Rect2(r.position,r.size),28,INK)
			hits.append({"kind":"page","rect":r,"value":-1 if n==0 else 1})
		ART.text(self,body_font,"%d / %d"%[page+1,ceili(options.size()/4.0)],Rect2(710,796,88,28),17,INK)
	var apply_rect=Rect2(1084,775,272,72)
	ART.decor_label(self,font,"confirm",APPLY.get(tab,"确定"),apply_rect,22,INK,1 if selected>=0 else .45)
	hits.append({"kind":"apply","rect":apply_rect})
	if rejection>0:ART.text(self,body_font,"当前条件已变化",Rect2(942,866,400,32),18,Color("f6c7bd"))
	if team.size()==2 and not team[0].get("bond_name","").is_empty():
		ART.text(self,font,team[0].bond_name,Rect2(68,860,476,34),23,Color("ffe6b1"))
		ART.text(self,body_font,team[0].bond_text,Rect2(55,900,514,55),16,Color("f1e4ff"))

func _draw_inventory()->void:
	var p=model.get("preview",{});var origin=Vector2(67,454);var cell=52.0
	var uids=[]
	if selected>=0 and selected<rows().size():uids=rows()[selected].get("uids",[])
	ART.rounded(self,Rect2(51,438,504,400),Color("9e8fc2",.6),Color("dbd0ed",.6),24)
	for point in p.get("coverage",[]):ART.rounded(self,Rect2(origin+Vector2(point)*cell,Vector2.ONE*(cell-2)),Color("cfbce0"),Color("e8dcef"),8)
	for item in p.get("items",[]):
		var r=Rect2(origin+Vector2(item.position)*cell,Vector2(item.size)*cell)
		if item.uid in uids:ART.rounded(self,r.grow(-2),Color("ffedb8",.55),Color("ffe2a1"),9,2)
		var quarter=int(item.get("rotation",0))%4
		var s=Vector2(r.size.y,r.size.x) if quarter%2 else r.size
		draw_set_transform(r.get_center(),quarter*PI*.5)
		ART.fit(self,item.texture,Rect2(-s*.5+Vector2.ONE*4,s-Vector2.ONE*8),item.source)
		draw_set_transform(Vector2.ZERO)
	ART.guard_thread(self,model.get("link",{}),origin,cell)

func _draw_automatic(team:Array)->void:
	if team.is_empty():
		_draw_empty_slot(Rect2(680,343,620,210),3)
		return
	for n in team.size():
		var m=team[n];var at=Vector2(620,198+n*228)
		ART.rounded(self,Rect2(at,Vector2(738,208)),Color("eee0ed"),Color("d3bddc"),23)
		ART.emblem(self,m.get("icon_id",m.ability_id),Rect2(at+Vector2(14,10),Vector2(70,70)))
		ART.text(self,font,m.name+" · "+m.ability_name,Rect2(at+Vector2(96,24),Vector2(608,40)),26,INK,false)
		ART.text(self,body_font,m.base_text,Rect2(at+Vector2(28,86),Vector2(675,73)),22,INK,false)
		var icons:Array=m.get("supply_icons",[])
		for j in mini(3,icons.size()):ART.fit(self,icons[j].texture,Rect2(at+Vector2(28+j*90,155),Vector2(80,40)),icons[j].source)
		ART.text(self,body_font,"特色供给",Rect2(at+Vector2(300,166),Vector2(180,28)),16,Color("87729b"),false)
	if team.size()==2:
		var m=team[-1]
		ART.rounded(self,Rect2(620,674,738,176),Color("fff0cb"),Color("ddbd79"),22)
		ART.text(self,font,"三人 · "+m.bond_name,Rect2(648,695,680,40),25,INK,false)
		ART.text(self,body_font,m.bond_text,Rect2(648,747,680,88),21,INK,false)
	else:
		_draw_empty_slot(Rect2(680,500,620,210),6)

func _draw_empty_slot(area:Rect2,node:int)->void:
	ART.rounded(self,area,Color("e8e0ee",.58),Color("cbbad9",.7),22)
	var center=Vector2(area.get_center().x,area.position.y+69)
	ART.decor(self,"socket",Rect2(center-Vector2.ONE*49,Vector2.ONE*98),.6)
	ART.text(self,font,"+",Rect2(center-Vector2(20,25),Vector2(40,50)),29,Color("9d88b5"))
	ART.text(self,body_font,empty_slot_label(node),Rect2(area.position+Vector2(28,132),Vector2(area.size.x-56,45)),24,Color("87729b"))

static func empty_slot_label(node:int)->String:return "第 %d 回合结束后招募"%node
