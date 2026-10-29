extends RefCounted
## Read-only archive journal. Returns UI intents, never loads or writes a run.
const T=preload('res://scripts/ui/ui_theme.gd')
const Q=preload('res://scripts/ui/visual_skin.gd')
const C=preload('res://scripts/data/catalog.gd')
const ART=preload('res://scripts/ui/party/recruitment_art.gd')
const BUTTON=preload('res://scripts/ui/chibi_action_button.gd')
const PAGE_SIZE=6
static func text(c,font,value:String,pos:Vector2,size:int=20,color:Color=Q.PLUM,width:float=-1)->void:
	var shown=value
	if width>0:
		while not shown.is_empty() and font.get_string_size(shown,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width:
			shown=shown.substr(0,shown.length()-2)+'…'
	c.draw_string(font,pos,shown,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
static func button(c,font,rect:Rect2,label:String,action:String,m:Dictionary,hits:Array,enabled:bool=true)->void:
	BUTTON.draw(c,font,rect,label,'secondary',1.0 if rect.has_point(m.mouse) else 0.0,0,enabled,m.age,1,Transform2D.IDENTITY)
	hits.append({'rect':rect,'action':action,'enabled':enabled})
static func draw(c:CanvasItem,m:Dictionary,font:Font,portrait:Callable,board:Callable)->Array:
	var hits=[]
	c.draw_rect(Rect2(0,0,1440,960),Color('282447',.77))
	T.surface(c,Rect2(52,105,1336,799),'panel')
	ART.decor_label(c,font,'title','对战记录',Rect2(456,16,528,142),32,Q.PLUM)
	button(c,font,Rect2(1190,128,160,48),'返回','close',m,hits)
	if m.rows.is_empty():
		T.glyph(c,'catalogue',Rect2(640,320,160,160))
		text(c,font,'还没有对战记录',Vector2(605,553),27)
		return hits
	var start=int(m.page)*PAGE_SIZE
	for n in mini(PAGE_SIZE,m.rows.size()-start):
		var index=start+n;var row=m.rows[index];var rect=Rect2(86,193+n*99,414,88)
		var chosen=index==m.selected
		var box=StyleBoxFlat.new();box.bg_color=Color('d3c0ee',.70 if chosen else .25);box.set_corner_radius_all(16)
		box.border_color=Color('b098d9',.85 if chosen else .22);box.set_border_width_all(2 if chosen else 1);c.draw_style_box(box,rect)
		portrait.call(str(row.leaders[0]),Rect2(rect.position+Vector2(13,7),Vector2(67,72)),1.0,true)
		var verdict='胜利' if int(row.winner)==1 else '失败' if int(row.winner)==-1 else '平局'
		var source=' · 玩家' if row.get('pvp_source','')=='player' else ' · 练习补位' if row.get('pvp_source','')=='bot' else ''
		text(c,font,'第 %d 回合'%int(row.round)+source,rect.position+Vector2(95,28),19)
		text(c,font,verdict,rect.position+Vector2(340,28),20,Color('398b79') if int(row.winner)==1 else Color('b26780'))
		var local_time=int(row.get('time',0))+int(Time.get_time_zone_from_system().bias)*60
		var date=Time.get_datetime_string_from_unix_time(local_time).replace('T',' ') if int(row.get('time',0))>0 else '旧记录'
		text(c,font,date.substr(0,16),rect.position+Vector2(95,78),13,Color('857299'))
		var roles=row.leaders.map(func(k):return str(C.characters.get(k,{}).get('name','未知对手')))
		text(c,font,roles[0]+'  ·  '+roles[1],rect.position+Vector2(95,54),16,Q.PLUM,296)
		text(c,font,'%.1f 秒'%float(row.duration) if row.get('replayable',false) else '仅有摘要',rect.position+Vector2(329,78),13,Color('857299'))
		hits.append({'rect':rect,'action':'select:'+str(index),'enabled':true})
	var row=m.rows[clampi(m.selected,0,m.rows.size()-1)]
	T.surface(c,Rect2(526,194,820,584),'character_card')
	var builds:Array=m.record.get('builds',[])
	for side in 2:
		var x=548+side*400
		if C.characters.has(row.leaders[side]):portrait.call(str(row.leaders[side]),Rect2(x,222,80,95),1.0,true)
		text(c,font,'我方' if side==0 else '对方',Vector2(x+95,255),19,Color('857299'))
		text(c,font,str(C.characters.get(row.leaders[side],{}).get('name','未知')),Vector2(x+95,290),25,Q.PLUM,267)
		if builds.size()==2:
			board.call(builds[side],Rect2(x,352,376,293))
		else:text(c,font,'未保存布局',Vector2(x+125,505),21,Color('857299'))
	text(c,font,'第 %d 回合'%int(row.round),Vector2(555,726),22)
	text(c,font,'%.1f 秒'%float(row.duration) if builds.size()==2 else '仅有摘要',Vector2(1200,726),20,Color('857299'))
	button(c,font,Rect2(768,798,336,68),'开始回放' if not m.record.is_empty() else '无法回放','replay',m,hits,not m.record.is_empty())
	button(c,font,Rect2(86,815,132,48),'上一页','previous',m,hits,m.page>0)
	text(c,font,'%d / %d'%[m.page+1,maxi(1,ceili(m.rows.size()/float(PAGE_SIZE)))],Vector2(268,847),20)
	button(c,font,Rect2(368,815,132,48),'下一页','next',m,hits,start+PAGE_SIZE<m.rows.size())
	return hits
static func hit(buttons:Array,at:Vector2)->String:
	for b in buttons:
		if b.enabled and b.rect.has_point(at):return b.action
	return ''
