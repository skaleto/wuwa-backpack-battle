extends RefCounted
## Pure 2D terminal backdrop, adapted from the captured original game catalogue.
const T=preload("res://scripts/ui/ui_theme.gd")
const L=preload("res://scripts/ui/chibi_layout.gd")
const SKIN=preload("res://scripts/ui/visual_skin.gd")
const TRAVEL=preload("res://scripts/ui/pockets/travel_decor.gd")
const BASE=T.SHELL
const PALE=T.PAPER
const GOLD=T.BRASS
const CYAN=T.INK

static func backdrop(c: CanvasItem,phase: String,age: float,alpha: float=1.0) -> void:
	if SKIN.is_chibi():
		if c.has_method("_clear_paper_surfaces"):c._clear_paper_surfaces()
		var background=SKIN.texture(SKIN.ui_path("background"))
		if background:c.draw_texture_rect(background,Rect2(0,0,1440,960),false,Color(1,1,1,alpha))
		else:c.draw_rect(Rect2(0,0,1440,960),Color(SKIN.NIGHT,alpha))
		T.fade(c,Rect2(220,100,1000,720),Color(SKIN.NIGHT,.10*alpha),Color(SKIN.PLUM,.02*alpha))
		if phase=="shop":
			T.surface(c,L.BOARD_FRAME,"board_frame",alpha)
			preload("res://scripts/ui/apricot_ui.gd").shop(c,L.SHOP,alpha)
			T.surface(c,L.STASH_FRAME,"stash",alpha)
			_travel_details(c,age,alpha)
			if c.has_method("_register_paper_surface"):
				c._register_paper_surface(Rect2(L.BOARD_FRAME.position,Vector2(L.BOARD_FRAME.size.x,70)))
				c._register_paper_surface(Rect2(L.STASH_FRAME.position,Vector2(L.STASH_FRAME.size.x,48)))
		elif phase!="camp":
			preload("res://scripts/ui/battle/chibi_battle_view.gd").stage(c,alpha)
		return
	c.draw_texture_rect(SKIN.texture(SKIN.ui_path("background")),Rect2(0,0,1440,960),false,Color(1,1,1,alpha))
	# Retain the bright lower fog. Only control rails receive a local dark scrim.
	T.fade(c,Rect2(0,0,1440,112),Color(T.tone(T.SHADOW),.46*alpha),Color(T.tone(T.SHADOW),0),true)
	T.fade(c,Rect2(0,740,1440,220),Color(T.tone(T.SHADOW),0),Color(T.tone(T.SHADOW),.64*alpha),true)
	for n in range(12):
		var at=Vector2(110+fmod(n*137.4,1220),130+fmod(n*79.1-age*(1+n%3)*1.1,620))
		c.draw_circle(at, .65 if n%3 else 1.0,Color(T.tone(T.PAPER),(.13+sin(age*.6+n)*.07)*alpha))
	if phase=="camp":
		pass
		return
	if phase=="shop":
		pass
		T.fade(c,Rect2(1046,178,350,605),Color(T.tone(T.SHADOW),.55*alpha),Color(T.tone(T.SHADOW),.22*alpha))
		T.rule(c,Vector2(1046,218),Vector2(1380,218),.24*alpha)
		T.rule(c,Vector2(337,211),Vector2(989,211),.24*alpha)
		T.fade(c,Rect2(335,772,650,72),Color(T.tone(T.SHADOW),.40*alpha),Color(T.tone(T.SHADOW),.20*alpha))
		T.rule(c,Vector2(335,772),Vector2(985,772),.3*alpha)
	else:
		for x in [207,932]:
			T.fade(c,Rect2(x,126,336,118),Color(T.tone(T.SHADOW),.40*alpha),Color(T.tone(T.SHADOW),0))

static func _travel_details(c:CanvasItem,age:float,alpha:float)->void:
	TRAVEL.draw(c,age,alpha)

static func tool(canvas: CanvasItem, rect: Rect2, kind: String, hover: float, press: float, selected: bool = false, enabled: bool = true) -> void:
	if SKIN.is_chibi():
		var h=hover if enabled else 0.0
		var face=rect.grow(-3+h*1.5);face.position.y+=press*2-h*2
		var side=minf(face.size.x,face.size.y)
		T.surface(canvas,Rect2(face.get_center()-Vector2.ONE*side*.5,Vector2.ONE*side),"button_round",1.0 if enabled else .4,Color("b8d5ff").lerp(Color.WHITE,h*.7) if kind=="refresh" else Color(1+h*.12,1+h*.12,1+h*.12,1))
		T.glyph(canvas,kind,Rect2(face.get_center()-Vector2.ONE*side*.27,Vector2.ONE*side*.54),1.0 if enabled else .4,SKIN.LIGHT)
		if selected:canvas.draw_arc(face.get_center(),minf(face.size.x,face.size.y)*.49,0,TAU,48,SKIN.CORAL,2,true)
		return
	var pos = rect.get_center()+Vector2(0,press*2)
	var radius = minf(rect.size.x, rect.size.y) * .36
	var color = T.tone(T.BRASS) if selected else T.tone(T.PAPER)
	if not enabled: color = Color(T.tone(T.MUTED),.35)
	var body=rect.grow(-3)
	if kind == "launch":
		T.plate(canvas,body,Color("c5a267").lightened(hover*.06),Color("e3c997"),14)
		for n in range(5):
			var x=pos.x+(n-2)*8
			var h=7 if n%2==0 else 15
			canvas.draw_line(Vector2(x,pos.y-h),Vector2(x,pos.y+h),T.tone(T.SHADOW),3,true)
		return
	canvas.draw_circle(pos,minf(body.size.x,body.size.y)*.43,Color(T.tone(T.SHADOW),.45))
	if selected or hover>.02:
		canvas.draw_circle(pos,minf(body.size.x,body.size.y)*.43,Color(T.tone(T.PAPER),.07+hover*.06))
	if selected:canvas.draw_line(body.position+Vector2(13,body.size.y-4),body.end-Vector2(13,4),T.tone(T.BRASS),3,true)
	canvas.draw_arc(pos,minf(body.size.x,body.size.y)*.43,0,TAU,48,Color(T.tone(T.PAPER),.20+hover*.30),1,true)
	var w = 1.5 + press * .3
	match kind:
		"move":
			for y in range(2):
				for x in range(2):
					canvas.draw_rect(Rect2(pos + Vector2(x * 12 - 13, y * 12 - 13), Vector2(9, 9)), color, false, w)
			canvas.draw_line(pos + Vector2(10, 12), pos + Vector2(19, 12), color, w, true)
			canvas.draw_line(pos + Vector2(19, 12), pos + Vector2(15, 8), color, w, true)
			canvas.draw_line(pos + Vector2(19, 12), pos + Vector2(15, 16), color, w, true)
		"relay":
			var points = [pos + Vector2(-16, 10), pos + Vector2(0, -12), pos + Vector2(16, 10)]
			canvas.draw_polyline(PackedVector2Array(points), color, w, true)
			for point in points: canvas.draw_circle(point, 4, color)
		"sell":
			canvas.draw_arc(pos, 17, -PI * .3, PI * 1.42, 40, color, w, true)
			canvas.draw_line(pos + Vector2(-6, 0), pos + Vector2(6, 0), color, w, true)
			canvas.draw_line(pos + Vector2(5, -16), pos + Vector2(12, -16), color, w, true)
			canvas.draw_line(pos + Vector2(12, -16), pos + Vector2(12, -9), color, w, true)
		"book":
			canvas.draw_polyline(PackedVector2Array([pos + Vector2(-17, -15), pos + Vector2(-4, -12), pos + Vector2(0, -8), pos + Vector2(4, -12), pos + Vector2(17, -15), pos + Vector2(17, 13), pos + Vector2(4, 13), pos + Vector2(0, 17), pos + Vector2(-4, 13), pos + Vector2(-17, 13), pos + Vector2(-17, -15)]), color, w, true)
			canvas.draw_line(pos + Vector2(0, -8), pos + Vector2(0, 17), color, w, true)
		"refresh":
			canvas.draw_arc(pos, 17, -.2, TAU - .8, 40, color, w, true)
			var end = pos + Vector2.from_angle(-.8) * 17
			canvas.draw_line(end, end + Vector2(-8, 0), color, w, true)
			canvas.draw_line(end, end + Vector2(0, 8), color, w, true)
		"menu":
			for n in range(3): canvas.draw_line(pos + Vector2(-15, (n - 1) * 9), pos + Vector2(15, (n - 1) * 9), color, w, true)
		"ghost":
			canvas.draw_circle(pos, 15, Color(color, .09))
			canvas.draw_arc(pos, 16, -.6, PI * 1.8, 36, color, w, true)
			for n in range(3):
				var h = 9 if n == 1 else 5
				canvas.draw_line(pos + Vector2((n - 1) * 7, -h), pos + Vector2((n - 1) * 7, h), color, w, true)
