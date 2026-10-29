extends RefCounted
## Fixed battle composition. Preparation coordinates and simulation are untouched.
const ICONS=preload("res://scripts/ui/ability_icons.gd")
const T=preload("res://scripts/ui/ui_theme.gd")
const Q=preload("res://scripts/ui/visual_skin.gd")
const C=preload("res://scripts/data/catalog.gd")
const BOARDS=[Rect2(116,472,528,396),Rect2(796,472,528,396)]
static func actor(side:int)->Rect2:return Rect2(250 if side==0 else 930,132,260,274)
static func center(side:int)->Vector2:return Vector2(380 if side==0 else 1060,278)
static func shield_rect(side:int)->Rect2:return Rect2(center(side)+Vector2(100,82),Vector2.ONE*23)
static func oval(c:CanvasItem,rect:Rect2,color:Color)->void:
	var points=PackedVector2Array()
	for i in 64:points.append(rect.get_center()+Vector2.from_angle(i*TAU/64)*rect.size*.5)
	c.draw_colored_polygon(points,color)
static func stage(c:CanvasItem,alpha:float)->void:
	# Existing authored paper provides a flat cut-paper stage, without 3D shelves.
	for side in 2:
		var x=center(side).x
		oval(c,Rect2(x-172,389,344,34),Color(Q.PLUM,.23*alpha))
		T.surface(c,Rect2(x-170,380,340,32),"panel",alpha,Color("dccbef"))
		oval(c,Rect2(x-72,397,144,13),Color(Q.PLUM,.18*alpha))
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
		var origin=Vector2(128 if side==0 else 808,438)
		g._text(C.characters[build.leader].name,origin,24,Q.LIGHT)
		var ratio=float(state.hp)/maxf(1,float(state.max_hp))
		var smooth=g.motion.smooth("hp"+str(side),ratio)
		bar(g,Rect2(origin+Vector2(108,-17),Vector2(302,13)),ratio,Q.MINT if side==0 else Color("efaaa8"),smooth)
		g._text(str(int(ceil(state.hp))),origin+Vector2(423,-2),19,Q.LIGHT)
		var stamina_ratio=float(state.stamina)/maxf(1,float(state.get("stamina_max",10)))
		bar(g,Rect2(origin+Vector2(108,6),Vector2(302,6)),stamina_ratio,Color("efad81") if stamina_ratio<.25 else Color("85dfc7"))
		ICONS.draw(g,"stamina",Rect2(origin+Vector2(86,0),Vector2(19,19)))
		g._text("%.1f"%float(state.stamina),origin+Vector2(423,14),12,Q.LIGHT)
		if state.shield>0:
			ICONS.draw(g,"shield",shield_rect(side))
			g._text(str(int(state.shield)),at+Vector2(128,101),18,Q.LIGHT)
		var statuses=state.get("statuses",[])
		for n in mini(5,statuses.size()):
			var status=statuses[n];var pos=origin+Vector2(108+n*64,10)
			var key=str(status.get("id",""))
			ICONS.draw(g,key,Rect2(pos,Vector2.ONE*24))
			g._text(str(status.get("stacks",1)),pos+Vector2(27,20),16,Q.LIGHT)
			var remaining=float(status.get("remaining",0))
			if remaining>0:
				# Timed statuses have a ring; hover gives the exact remaining number.
				g.draw_arc(pos+Vector2.ONE*12,12.5,-PI/2,-PI/2+TAU,24,Color(Q.SKY,.8),1.5,true)
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
		var origin=Vector2(128 if side==0 else 808,438)
		var statuses=frame.sides[side].get("statuses",[])
		for n in mini(5,statuses.size()):
			var status=statuses[n];var pos=origin+Vector2(108+n*64,10)
			if Rect2(pos,Vector2(58,29)).has_point(g.mouse) and float(status.get("remaining",0))>0:
				var tip=StyleBoxFlat.new();tip.bg_color=Q.PLUM;tip.set_corner_radius_all(5)
				g.draw_style_box(tip,Rect2(pos+Vector2(0,30),Vector2(42,23)))
				g._text("%.1f"%status.remaining,pos+Vector2(6,47),13,Q.LIGHT)
