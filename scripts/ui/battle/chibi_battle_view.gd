extends RefCounted
## Fixed battle composition. Preparation coordinates and simulation are untouched.
const ICONS=preload("res://scripts/ui/ability_icons.gd")
const T=preload("res://scripts/ui/ui_theme.gd")
const Q=preload("res://scripts/ui/visual_skin.gd")
const C=preload("res://scripts/data/catalog.gd")
const STATUS=preload("res://scripts/ui/battle/battle_status_view.gd")
const BOARDS=[Rect2(116,472,528,396),Rect2(796,472,528,396)]
static func actor(side:int)->Rect2:return Rect2(250 if side==0 else 930,100,260,250)
static func center(side:int)->Vector2:return Vector2(380 if side==0 else 1060,246)
static func shield_rect(side:int)->Rect2:return Rect2(center(side)+Vector2(100,82),Vector2.ONE*23)
static func oval(c:CanvasItem,rect:Rect2,color:Color)->void:
	var points=PackedVector2Array()
	for i in 64:points.append(rect.get_center()+Vector2.from_angle(i*TAU/64)*rect.size*.5)
	c.draw_colored_polygon(points,color)
static func stage(c:CanvasItem,alpha:float)->void:
	# Existing authored paper provides a flat cut-paper stage, without 3D shelves.
	for side in 2:
		var x=center(side).x
		oval(c,Rect2(x-172,359,344,34),Color(Q.PLUM,.23*alpha))
		T.surface(c,Rect2(x-170,350,340,32),"panel",alpha,Color("dccbef"))
		oval(c,Rect2(x-72,367,144,13),Color(Q.PLUM,.18*alpha))
		T.surface(c,BOARDS[side].grow(12),"battle_board",alpha)
static func bar(c:CanvasItem,rect:Rect2,ratio:float,color:Color,trail:float=-1)->void:
	var back=StyleBoxFlat.new();back.bg_color=Q.PLUM;back.set_corner_radius_all(6)
	back.set_border_width_all(1);back.border_color=Color("a39bd0")
	c.draw_style_box(back,rect.grow(2))
	var inner=rect.grow(-1)
	if trail>ratio:
		var ghost=StyleBoxFlat.new();ghost.bg_color=Q.CREAM;ghost.set_corner_radius_all(4)
		c.draw_style_box(ghost,Rect2(inner.position,Vector2(inner.size.x*clampf(trail,0,1),inner.size.y)))
	if ratio>.001:
		var fill=StyleBoxFlat.new();fill.bg_color=color;fill.set_corner_radius_all(4)
		c.draw_style_box(fill,Rect2(inner.position,Vector2(inner.size.x*clampf(ratio,0,1),inner.size.y)))
static func draw(g)->void:
	var frame=g._vitals_frame()
	if frame.is_empty():return
	for side in 2:
		var build=g.run if side==0 else g.opponent
		var rect=actor(side);var at=center(side)
		g._draw_character(build.leader,rect,side==1,side)
		g._draw_battle_crew(side,build)
		var state=frame.sides[side]
		var origin=STATUS.origin(side)
		g._text(C.characters[build.leader].name,origin,22,Q.LIGHT)
		T.glyph(g,"heart",Rect2(origin+Vector2(85,-20),Vector2.ONE*20))
		var ratio=float(state.hp)/maxf(1,float(state.max_hp))
		var smooth=g.motion.smooth("hp"+str(side),ratio)
		bar(g,STATUS.health(side),ratio,Q.MINT if side==0 else Color("efaaa8"),smooth)
		g._text("%d/%d"%[ceili(state.hp),ceili(state.max_hp)],origin+Vector2(402,-2),16,Q.LIGHT)
		var stamina_ratio=float(state.stamina)/maxf(1,float(state.get("stamina_max",10)))
		bar(g,STATUS.stamina(side),stamina_ratio,Color("efad81") if stamina_ratio<.25 else Color("85dfc7"))
		ICONS.draw(g,"stamina",Rect2(origin+Vector2(1,5),Vector2(22,22)))
		g._text("体力",origin+Vector2(28,23),15,Q.LIGHT)
		g._text("%.1f/%d"%[float(state.stamina),int(state.get("stamina_max",10))],origin+Vector2(402,23),14,Q.LIGHT)
		if state.shield>0:
			ICONS.draw(g,"shield",shield_rect(side))
			g._text("护盾 "+str(int(state.shield)),at+Vector2(128,101),17,Q.LIGHT)
		for chip in STATUS.chips(side,state.get("statuses",[])):
			var box=StyleBoxFlat.new();box.bg_color=Color("f2bfc9") if chip.negative else Color("c5eee2")
			box.set_corner_radius_all(9);box.border_color=Color("fff5de",.75);box.set_border_width_all(1)
			g.draw_style_box(box,chip.rect)
			g._register_paper_surface(chip.rect)
			ICONS.draw(g,chip.id,Rect2(chip.rect.position+Vector2(2,1),Vector2.ONE*25))
			g._text(chip.label,chip.rect.position+Vector2(29,19),14,Q.PLUM)
			g._text(str(chip.stacks),chip.rect.position+Vector2(79,20),17,Q.PLUM)

	var timer_color=Q.LIGHT
	if g.combat_time-.30>=22:
		timer_color=Color("ffc5b4")
		var pulse=(sin(g.combat_time*TAU*1.5)+1)*.5
		g.draw_circle(Vector2(720,134),34,Color(Q.PLUM,.72))
		g.draw_arc(Vector2(720,134),35+pulse*3,0,TAU,64,Color(timer_color,.4+pulse*.4),2,true)
	g._text("%.1f"%minf(g.combat_time,float(g.combat.duration)),Vector2(695,142),23,timer_color)
	g._draw_battle_controls()

static func draw_status_detail(g)->void:
	var frame=g._vitals_frame()
	if frame.is_empty():return
	for side in 2:
		for chip in STATUS.chips(side,frame.sides[side].get("statuses",[])):
			if not chip.rect.has_point(g.mouse):continue
			var at=chip.rect.position+Vector2(0,-68);at.x=clampf(at.x,8,1090)
			var tip=StyleBoxFlat.new();tip.bg_color=Color("fff1dc");tip.border_color=Color("b69bd8");tip.set_border_width_all(2);tip.set_corner_radius_all(10)
			g.draw_style_box(tip,Rect2(at,Vector2(342,60)))
			g._register_paper_surface(Rect2(at,Vector2(342,60)))
			var title=chip.label+" · "+str(chip.stacks)+" 层"
			if chip.remaining>0:title+=" · %.1f秒"%chip.remaining
			g._text(title,at+Vector2(12,23),17,Q.PLUM)
			g._text(chip.detail,at+Vector2(12,46),13,Q.PLUM)

# Large, fixed hit targets are registered by the scene; only the face animates.
static func control(g,rect:Rect2,label:String,action:String,paused:bool,hover:float,alpha:float)->void:
	T.surface(g,rect,"button_primary",alpha,Color.WHITE*(1.0+hover*.12))
	var ink=Color(Q.LIGHT,alpha)
	var at=rect.position+Vector2(24,30)
	if action=="pause" and not paused:
		for x in [-7,5]:g.draw_line(at+Vector2(x,-10),at+Vector2(x,10),ink,5,true)
	else:
		var offsets=[-8,3] if action=="speed" else [-7]
		for x in offsets:
			g.draw_colored_polygon(PackedVector2Array([at+Vector2(x,-10),at+Vector2(x+12,0),at+Vector2(x,10)]),ink)
		if action=="skip":g.draw_line(at+Vector2(9,-10),at+Vector2(9,10),ink,4,true)
	g._text(label,rect.position+Vector2(43,37),21,ink)
