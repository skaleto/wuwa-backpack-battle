extends Node2D
## Layered invitation stage. Owns animation/selection only; returns input intents.
const ART=preload("res://scripts/ui/party/recruitment_art.gd")
const CARD=preload("res://scripts/ui/party/recruitment_card_view.gd")
const DISSOLVE=preload("res://scripts/ui/party/recruitment_dissolve.gdshader")
const SIZE=Vector2(1440,960)
const TITLE=Rect2(470,16,500,150)
const CONFIRM=Rect2(490,844,460,105)
const SATCHEL=Rect2(24,807,238,142)
const CARD_POSITIONS=[Vector2(128,170),Vector2(528,170),Vector2(928,170)]
const INK=Color("493367")
const JOIN_DURATION=1.15
var model:Dictionary={}
var font:Font
var body_font:Font
var cards:Array=[]
var layers:Array=[]
var selected=-1
var hovered=-1
var elapsed=0.0
var join_time=-1.0
var selected_reward=""
var pointer=Vector2(-100,-100)
var foreground:Node2D
var peek=false
var peek_page=0
var active=false
var arrived=false
var reduced_motion=false

func _ready()->void:
	z_index=90
	foreground=Node2D.new();foreground.z_index=10;add_child(foreground)
	foreground.draw.connect(_draw_foreground)
	visible=false

func open(value:Dictionary,title_font:Font,text_font:Font)->void:
	clear()
	model=value.duplicate(true);font=title_font;body_font=text_font
	active=true;visible=true;elapsed=0;selected=-1;hovered=-1;join_time=-1;arrived=false;peek=false;peek_page=0
	for n in model.get("cards",[]).size():
		var port=SubViewport.new();port.size=Vector2i(CARD.SIZE);port.transparent_bg=true
		port.render_target_update_mode=SubViewport.UPDATE_ALWAYS;port.gui_disable_input=true
		add_child(port)
		var painter=CARD.new();port.add_child(painter);painter.show_card(model.cards[n],font,body_font)
		var sprite=Sprite2D.new();sprite.centered=false;sprite.texture=port.get_texture()
		var material_value=ShaderMaterial.new();material_value.shader=DISSOLVE;sprite.material=material_value
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;add_child(sprite)
		cards.append({"viewport":port,"painter":painter,"sprite":sprite,"material":material_value,"lift":0.0})
	advance(0)

func clear()->void:
	for entry in cards:
		entry.sprite.queue_free();entry.viewport.queue_free()
	cards=[];model={};active=false;visible=false;peek=false;arrived=false

func interactive()->bool:return active and join_time<0 and (elapsed>=1.1 or reduced_motion)

func advance(delta:float)->void:
	if not active:return
	elapsed+=delta
	if join_time>=0:join_time+=delta
	for n in cards.size():
		var entry=cards[n]
		var t=1.0 if reduced_motion else clampf((elapsed-.25-n*.12)/.48,0,1)
		var rise=1-pow(1-t,3)
		var wanted=-4.0 if selected==n else -2.0 if hovered==n else 0.0
		entry.lift=move_toward(entry.lift,wanted,delta*36)
		entry.sprite.position=CARD_POSITIONS[n]+Vector2(0,(1-rise)*72+entry.lift)
		entry.sprite.modulate=Color(1,1,1,t)
		entry.material.set_shader_parameter("chosen",1.0 if selected==n else 0.0)
		if join_time>=0:
			if selected==n:
				entry.material.set_shader_parameter("dissolve",clampf((join_time-.08)/.72,0,1))
			else:
				entry.sprite.modulate.a=1-smoothstep(0,.35,join_time)
				entry.sprite.position.y+=smoothstep(0,.35,join_time)*18
		entry.sprite.visible=not peek
	if join_time>=JOIN_DURATION:arrived=true
	queue_redraw()
	if foreground:foreground.queue_redraw()

func confirm_fact()->void:
	# The caller invokes this only after a successful domain commit.
	if not interactive() or selected<0:return
	join_time=0;peek=false

func select(index:int)->void:
	if not interactive() or index<0 or index>=cards.size():return
	selected=index;selected_reward=""
	if model.cards[index].get("gold_fallback",false):selected_reward="gold"
	for n in cards.size():
		cards[n].painter.selected=n==selected;cards[n].painter.reward_kind="";cards[n].painter.queue_redraw()
	queue_redraw()

func can_confirm()->bool:
	if not interactive() or selected<0 or peek:return false
	return model.cards[selected].get("reward_choices",[]).is_empty() or not selected_reward.is_empty()

func input_intent(event:InputEvent)->Dictionary:
	if not active:return {}
	if event is InputEventMouseMotion:
		pointer=event.position;hovered=-1
		if interactive() and not peek:
			for n in cards.size():
				if Rect2(cards[n].sprite.position,CARD.SIZE).has_point(pointer):hovered=n
		return {}
	if not interactive():return {}
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE and peek:peek=false;return {"kind":"click"}
		if event.keycode in [KEY_1,KEY_2,KEY_3] and not peek:select(event.keycode-KEY_1);return {"kind":"click"}
		if event.keycode==KEY_ENTER and can_confirm():return confirmation()
	if event is InputEventMouseButton and event.pressed:
		pointer=event.position
		if peek:
			if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:peek_page+=1
			elif event.button_index==MOUSE_BUTTON_WHEEL_UP:peek_page=maxi(0,peek_page-1)
			elif event.button_index==MOUSE_BUTTON_LEFT and (Rect2(1120,120,150,50).has_point(pointer) or not Rect2(155,105,1130,700).has_point(pointer)):peek=false
			return {"kind":"click"}
		if event.button_index!=MOUSE_BUTTON_LEFT:return {}
		if SATCHEL.has_point(pointer):peek=true;peek_page=0;return {"kind":"click"}
		if CONFIRM.has_point(pointer) and can_confirm():return confirmation()
		for n in cards.size():
			var rect=Rect2(cards[n].sprite.position,CARD.SIZE)
			if rect.has_point(pointer):
				if selected!=n:select(n)
				var reward=cards[n].painter.reward_at(pointer-rect.position)
				if not reward.is_empty():
					selected_reward=reward;cards[n].painter.reward_kind=reward;cards[n].painter.queue_redraw()
				return {"kind":"click"}
	return {}

func confirmation()->Dictionary:
	return {"kind":"confirm","role_id":model.cards[selected].role_id,"reward":selected_reward}

func _draw()->void:
	if not active or font==null:return
	var bg=model.get("background")
	if bg:draw_texture_rect(bg,Rect2(Vector2.ZERO,SIZE),false)
	draw_rect(Rect2(Vector2.ZERO,SIZE),Color("453274",.21))
	for n in 20:
		var p=Vector2(60+fmod(n*241.0,1320),170+fmod(n*129.0-elapsed*5,620))
		var a=.10+.08*sin(elapsed*1.8+n)
		draw_circle(p,1.5 if n%3 else 2.5,Color("ffedbb",a))
	ART.decor_label(self,font,"title","伙伴招募",TITLE,38,INK)
	ART.text(self,body_font,"第 %d 回合结束"%int(model.get("node",3)),Rect2(520,155,400,30),21,Color("fff1d8"))
	_draw_team()
	_draw_milestones()
	if selected>=0 and join_time<0:
		var highlight=Rect2(cards[selected].sprite.position+Vector2(17,24),Vector2(352,619))
		for n in range(4,0,-1):ART.rounded(self,highlight.grow(n*2),Color.TRANSPARENT,Color("ffdc8b",.10 if n>1 else .95),29+n,2)
	var alpha=1.0 if can_confirm() else .65
	if join_time>=0:alpha*=1-smoothstep(0,.25,join_time)
	var button=CONFIRM
	if button.has_point(pointer) and can_confirm():button.position.y-=2
	ART.decor_label(self,font,"confirm","邀请入队",button,30,INK,alpha)
	if join_time<0:ART.decor_label(self,font,"satchel","查看背包",SATCHEL,22,INK)
	if int(model.get("node",3))==3:
		ART.text(self,body_font,"第 6 回合 · 三人羁绊",Rect2(1092,865,297,31),19,Color("f8e7c9"))
	else:
		ART.text(self,body_font,"新伙伴 · 新组合",Rect2(1102,865,277,31),19,Color("f8e7c9"))

func _draw_team()->void:
	var team:Array=model.get("team",[])
	for n in 3:
		var center=Vector2(78+n*94,81)
		ART.decor(self,"socket",Rect2(center-Vector2.ONE*42,Vector2.ONE*84),1.0 if n<team.size() else .6)
		if n<team.size():_portrait(self,team[n],Rect2(center-Vector2.ONE*31,Vector2.ONE*62))
		else:ART.text(self,font,"+",Rect2(center-Vector2(16,22),Vector2(32,44)),32,Color("ddd2f4"))

func _draw_milestones()->void:
	var node=int(model.get("node",3))
	draw_line(Vector2(1186,78),Vector2(1300,78),Color("b0a0dd"),3,true)
	for n in 2:
		var center=Vector2(1170+n*140,78);var lit=node>=(3+n*3)
		draw_circle(center,30,Color("a39ad5") if lit else Color("65518d"))
		draw_arc(center,30,0,TAU,40,Color("fbe4ad") if lit else Color("b0a0c9"),2,true)
		ART.text(self,font,str(3+n*3),Rect2(center-Vector2(20,20),Vector2(40,40)),27,Color("fff2d5"))
		ART.text(self,body_font,"二人" if n==0 else "三人",Rect2(center+Vector2(-43,36),Vector2(86,30)),17,Color("e7dcf9"))

func _draw_foreground()->void:
	if not active:return
	if peek:_draw_backpack(foreground);return
	var opening=1.0 if reduced_motion else smoothstep(.02,.62,elapsed)
	var curtain_x=lerpf(-24,-796,opening)
	var curtain=ART.texture("curtain")
	if curtain:
		for side in 2:
			foreground.draw_set_transform(Vector2.ZERO if side==0 else Vector2(1440,0),0,Vector2(1 if side==0 else -1,1))
			# Each side is one complete layer; sliding never stretches or repeats folds.
			foreground.draw_texture_rect_region(curtain,Rect2(curtain_x,-10,760,990),Rect2(80,0,960,1402))
		foreground.draw_set_transform(Vector2.ZERO)
	if join_time>=0 and selected>=0:
		_draw_arrival(foreground)

func _draw_arrival(c:CanvasItem)->void:
	var card=cards[selected]
	var start:Vector2=card.sprite.position+Vector2(192,145)
	var target=Vector2(78+model.get("team",[]).size()*94,81)
	var travel=smoothstep(.3,1.05,join_time)
	var head=start.lerp(target,travel)+Vector2(0,-sin(travel*PI)*95)
	for n in 45:
		var delay=float(n%9)*.022;var t=clampf((join_time-.08-delay)/.77,0,1)
		if t<=0 or t>=1:continue
		var edge=Vector2(float((n*71)%330)+28,float((n*97)%580)+25)
		var origin:Vector2=card.sprite.position+edge
		var point=origin.lerp(head,t)+Vector2(sin(n*1.7+t*4)*16,-sin(t*PI)*(18+n%7*5))
		var a=sin(t*PI)
		c.draw_circle(point,5*a,Color("ffe4a0",a*.12))
		c.draw_circle(point,(1+n%3*.6)*a,Color("fff4d8",a))
	var scale_value=lerpf(90.0,62.0,travel)
	var alpha=smoothstep(.15,.38,join_time)
	ART.decor(c,"socket",Rect2(head-Vector2.ONE*(scale_value*.63),Vector2.ONE*scale_value*1.26),alpha)
	_portrait(c,model.cards[selected],Rect2(head-Vector2.ONE*scale_value*.5,Vector2.ONE*scale_value),alpha)
	if travel>.92:
		c.draw_arc(target,38+sin((travel-.92)/.08*PI)*7,0,TAU,40,Color("ffe7ac",(1-travel)*8),2,true)

func _portrait(c:CanvasItem,entry:Dictionary,area:Rect2,alpha:float=1)->void:
	if entry.get("portrait")==null:return
	preload("res://scripts/ui/portraits/portrait_framing.gd").draw(c,entry.portrait,area,entry.head_source,Color(1,1,1,alpha))

func _draw_backpack(c:CanvasItem)->void:
	c.draw_rect(Rect2(Vector2.ZERO,SIZE),Color("302447",.62))
	ART.rounded(c,Rect2(155,105,1130,700),Color("ede5f5"),Color("b4a4d8"),28,3)
	ART.text(c,font,"当前背包",Rect2(194,127,440,44),28,INK,false)
	ART.rounded(c,Rect2(1120,120,142,49),Color("d4c6ec"),Color("b4a4d8"),18)
	ART.text(c,font,"返回选人",Rect2(1131,130,120,30),20,INK)
	var preview=model.get("preview",{})
	var cell=68.0;var origin=Vector2(192,205)
	for y in 7:
		for x in 9:ART.rounded(c,Rect2(origin+Vector2(x,y)*cell,Vector2.ONE*(cell-3)),Color("a69bc4",.18),Color.TRANSPARENT,9)
	for p in preview.get("coverage",[]):ART.rounded(c,Rect2(origin+Vector2(p)*cell,Vector2.ONE*(cell-3)),Color("c4b6df"),Color("e9e1f1"),9)
	for item in preview.get("items",[]):
		var rect=Rect2(origin+Vector2(item.position)*cell,Vector2(item.size)*cell)
		_draw_item(c,item,rect.grow(-6))
	ART.text(c,font,"储物",Rect2(865,201,260,40),23,INK,false)
	var stash:Array=preview.get("stash",[])
	peek_page=clampi(peek_page,0,maxi(0,ceili(stash.size()/12.0)-1))
	for n in mini(12,maxi(0,stash.size()-peek_page*12)):
		var at=Rect2(855+(n%3)*124,256+int(n/3)*103,112,91)
		ART.rounded(c,at,Color("dbd0eb"),Color("c1b1db"),15)
		_draw_item(c,stash[peek_page*12+n],at.grow(-9))
	if stash.size()>12:ART.text(c,body_font,"%d / %d"%[peek_page+1,ceili(stash.size()/12.0)],Rect2(913,701,240,28),18,INK)

func _draw_item(c:CanvasItem,item:Dictionary,rect:Rect2)->void:
	if item.get("texture")==null:return
	var quarter=int(item.get("rotation",0))%4
	var area=rect
	if quarter%2:area=Rect2(rect.get_center()-Vector2(rect.size.y,rect.size.x)*.5,Vector2(rect.size.y,rect.size.x))
	c.draw_set_transform(rect.get_center(),quarter*PI*.5)
	ART.fit(c,item.texture,Rect2(area.position-rect.get_center(),area.size),item.source)
	c.draw_set_transform(Vector2.ZERO)
