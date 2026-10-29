extends RefCounted
## Value-only drawing and hit targets. No game, inventory, simulation or run access.
const T=preload("res://scripts/ui/ui_theme.gd")
const Q=preload("res://scripts/ui/visual_skin.gd")
const ICONS=preload("res://scripts/ui/ability_icons.gd")
const PANEL=Rect2(66,91,1308,788)
const ITEMS=Rect2(98,288,535,440)
const EVENTS=Rect2(668,243,668,504)
const TRACK=Rect2(268,902,688,20)
const ROW_COUNT=11
const EVENT_COUNT=12
const METRICS=[["damage","伤害","attack"],["heal","治疗","healing"],["shield","获盾","shield"],["stars","联动","star"],["advance","推进","speed"],["activations","发动","attack"],["stamina","回耐","stamina"]]
static func text(c:CanvasItem,font:Font,value:String,at:Vector2,size:int=18,color:Color=Q.PLUM,width:float=-1)->void:
	var shown=value
	if width>0:
		while not shown.is_empty() and font.get_string_size(shown,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width:
			shown=shown.substr(0,shown.length()-2)+"…"
	c.draw_string(font,at,shown,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
static func chip(c:CanvasItem,font:Font,rect:Rect2,label:String,action:String,mouse:Vector2,buttons:Array,selected:bool=false,enabled:bool=true)->void:
	var tint=Color("c8b5ed") if selected else Color.WHITE
	var over=rect.has_point(mouse) and enabled
	T.surface(c,rect.grow(1.1 if over else 0),"button",1 if enabled else .45,tint.lightened(.10) if over else tint)
	var w=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x
	text(c,font,label,rect.get_center()+Vector2(-w*.5,6),17,Q.PLUM if enabled else Color("9f93b2"))
	buttons.append({"rect":rect,"action":action,"enabled":enabled})
static func draw(c:CanvasItem,m:Dictionary,font:Font,icon:Callable)->Array:
	var buttons=[];var mouse:Vector2=m.mouse
	if m.panel:
		c.draw_rect(Rect2(0,0,1440,960),Color("201d44",.45))
		T.surface(c,PANEL,"panel")
		T.surface(c,Rect2(88,109,1264,64),"button")
		T.glyph(c,"catalogue",Rect2(106,123,35,35))
		text(c,font,"战斗记录",Vector2(153,149),27)
		text(c,font,"第 %d 回合  ·  %.1f 秒"%[m.round,m.duration],Vector2(365,147),18,Color("77608f"))
		chip(c,font,Rect2(1225,123,101,35),"关闭","close",mouse,buttons)
		chip(c,font,Rect2(98,193,114,38),"我方","side:0",mouse,buttons,m.side==0)
		chip(c,font,Rect2(219,193,114,38),"对方","side:1",mouse,buttons,m.side==1)
		text(c,font,m.leader,Vector2(354,218),20)
		for n in METRICS.size():
			var spec=METRICS[n]
			chip(c,font,Rect2(98+n*77,244,72,32),spec[1],"metric:"+spec[0],mouse,buttons,m.metric==spec[0])
		var rows:Array=m.rows;var start=int(m.item_page)*ROW_COUNT
		var largest=1.0
		for row in rows:largest=maxf(largest,float(row[m.metric]))
		for n in mini(ROW_COUNT,maxi(0,rows.size()-start)):
			var row:Dictionary=rows[start+n];var rect=Rect2(ITEMS.position+Vector2(0,n*40),Vector2(535,38))
			var selected=row.uid==m.focus
			if selected or rect.has_point(mouse):
				var box=StyleBoxFlat.new();box.bg_color=Color("d6c6ef",.72 if selected else .36);box.set_corner_radius_all(8);c.draw_style_box(box,rect)
			if not row.kind.is_empty():icon.call(row.kind,Rect2(rect.position+Vector2(6,0),Vector2(51,36)),0)
			elif not row.get("crew_ability","").is_empty():preload("res://scripts/ui/party/recruitment_art.gd").emblem(c,row.crew_ability,Rect2(rect.position+Vector2(14,4),Vector2.ONE*28))
			else:ICONS.draw(c,row.get("ability_icon","shield" if row.name!="疲劳" else "attack"),Rect2(rect.position+Vector2(16,6),Vector2.ONE*24))
			text(c,font,row.name,rect.position+Vector2(66,24),16,Q.PLUM,227)
			var bar=Rect2(rect.position+Vector2(307,16),Vector2(140*float(row[m.metric])/largest,7))
			if bar.size.x>0:
				var fill=StyleBoxFlat.new();fill.bg_color=Color("c69563") if m.metric=="damage" else Color("88b5ac");fill.set_corner_radius_all(4);c.draw_style_box(fill,bar)
			var value=str(int(row[m.metric])) if m.metric in ["stars","activations"] else "%.1f"%float(row[m.metric])
			text(c,font,value,rect.position+Vector2(464,24),18)
			buttons.append({"rect":rect,"action":"item:"+row.uid,"enabled":true})
		chip(c,font,Rect2(100,739,68,31),"‹","items_prev",mouse,buttons,false,m.item_page>0)
		text(c,font,"%d / %d"%[int(m.item_page)+1,maxi(1,ceili(rows.size()/float(ROW_COUNT)))],Vector2(181,762),16)
		chip(c,font,Rect2(258,739,68,31),"›","items_next",mouse,buttons,false,start+ROW_COUNT<rows.size())
		text(c,font,"实际挡伤 %.1f"%float(m.absorbed),Vector2(378,761),17)
		text(c,font,"时间线",Vector2(673,219),22)
		chip(c,font,Rect2(978,192,107,35),"全部事件","all_events",mouse,buttons,m.all_events)
		chip(c,font,Rect2(1095,192,113,35),"双方","both",mouse,buttons,m.timeline_side<0)
		chip(c,font,Rect2(1218,192,112,35),"仅本方","one_side",mouse,buttons,m.timeline_side>=0)
		var events:Array=m.events;var offset=int(m.event_offset)
		for n in mini(EVENT_COUNT,maxi(0,events.size()-offset)):
			var event:Dictionary=events[offset+n]
			var rect=Rect2(EVENTS.position+Vector2(0,n*42),Vector2(EVENTS.size.x,40))
			var now=event.id==m.selected_event
			if now or rect.has_point(mouse):
				var box=StyleBoxFlat.new();box.bg_color=Color("e3cba3",.5 if now else .22);box.set_corner_radius_all(7);c.draw_style_box(box,rect)
			c.draw_circle(rect.position+Vector2(7,19),3,Color("79bba8") if event.side==0 else Color("d991a3"))
			text(c,font,"%.1f"%event.time,rect.position+Vector2(19,25),16)
			if not event.kind.is_empty():icon.call(event.kind,Rect2(rect.position+Vector2(65,2),Vector2(43,36)),0)
			text(c,font,event.name,rect.position+Vector2(119,15),13,Color("816d98"),505)
			text(c,font,event.text,rect.position+Vector2(119,34),16,Q.PLUM,505)
			buttons.append({"rect":rect,"action":"event:"+str(event.id),"enabled":true})
		chip(c,font,Rect2(674,755,66,29),"‹","events_prev",mouse,buttons,false,offset>0)
		text(c,font,"%d–%d / %d"%[mini(offset+1,events.size()),mini(offset+EVENT_COUNT,events.size()),events.size()],Vector2(755,777),15)
		chip(c,font,Rect2(899,755,66,29),"›","events_next",mouse,buttons,false,offset+EVENT_COUNT<events.size())
		var focus:Dictionary=m.focus_row
		if not focus.is_empty():
			text(c,font,focus.name,Vector2(103,814),18,Q.PLUM,330)
			text(c,font,str(focus.get("position_label","")),Vector2(103,844),16,Color("816d98"))
			var detail="发动 %d   强化 %d   星效 %d   推进 %.2f秒   回耐 %.1f"%[focus.activations,focus.enhanced,focus.stars,focus.advance,focus.get("stamina",0)]
			text(c,font,detail,Vector2(440,814),16)
			text(c,font,"充能 +%.0f    迅捷 +%.0f    光噪 +%.0f    霜渐 +%.0f    削盾 %.1f"%[focus.charge,focus.haste,focus.noise,focus.frost,focus.break_shield],Vector2(440,844),16,Color("816d98"))
		else:
			text(c,font,"我方输出 %.1f   ·   对方输出 %.1f"%[m.damage[0],m.damage[1]],Vector2(103,827),19)
			text(c,font,"治疗 %.1f / %.1f   ·   获盾 %.1f / %.1f"%[m.heal[0],m.heal[1],m.shield[0],m.shield[1]],Vector2(639,827),18,Color("816d98"))
	# Same transport in the record and on-field view; lives below both boards.
	T.surface(c,Rect2(85,879,1270,72),"panel")
	chip(c,font,Rect2(104,897,39,35),"‹","step_back",mouse,buttons)
	chip(c,font,Rect2(150,897,63,35),"暂停" if m.playing else "重播" if m.time>=m.duration else "播放","play",mouse,buttons)
	chip(c,font,Rect2(220,897,39,35),"›","step_next",mouse,buttons)
	var line=Rect2(TRACK.position+Vector2(0,8),Vector2(TRACK.size.x,4))
	c.draw_rect(line,Color("c6b7d5"));c.draw_rect(Rect2(line.position,Vector2(line.size.x*m.time/maxf(.1,m.duration),4)),Color("b68ccc"))
	for marker in m.markers:
		var x=TRACK.position.x+TRACK.size.x*float(marker)/maxf(.1,m.duration)
		c.draw_line(Vector2(x,TRACK.position.y+6),Vector2(x,TRACK.position.y+16),Color("ad8bc0",.38),1)
	var knob=Vector2(TRACK.position.x+TRACK.size.x*m.time/maxf(.1,m.duration),TRACK.get_center().y)
	c.draw_circle(knob,8,Color("c7a5e0"));c.draw_circle(knob,4,Color("fff1ce"))
	text(c,font,"%.1f / %.1f"%[m.time,m.duration],Vector2(976,921),15)
	chip(c,font,Rect2(1078,897,61,35),"×"+str(m.speed),"speed",mouse,buttons)
	chip(c,font,Rect2(1147,897,109,35),"返回战斗" if m.panel else "数据日志","panel",mouse,buttons)
	chip(c,font,Rect2(1264,897,73,35),"返回","close",mouse,buttons)
	return buttons
static func hit(buttons:Array,at:Vector2)->String:
	for button in buttons:
		if button.enabled and button.rect.has_point(at):return str(button.action)
	return ""
