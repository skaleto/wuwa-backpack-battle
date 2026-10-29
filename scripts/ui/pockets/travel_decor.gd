extends RefCounted
## Passive layered ornaments for the approved travel layout. No input or run state.
const SKIN=preload("res://scripts/ui/visual_skin.gd")
const T=preload("res://scripts/ui/ui_theme.gd")
const L=preload("res://scripts/ui/chibi_layout.gd")

static func draw(c:CanvasItem,age:float,alpha:float=1.0)->void:
	if not SKIN.is_chibi():return
	var board=_response(c,"board",L.BOARD)
	var shop=_response(c,"shop",L.SHOP)
	var stash=_response(c,"stash",L.STASH)
	# The base PNGs have no baked latches, plaque, corner card, flowers or tags.
	# Every moving detail is sampled independently from the untouched source atlas.
	for index in 2:
		var y=195.0 if index==0 else 490.0
		var lift=Vector2(board.y*.6,-board.x*.65-board.y*.7)
		_sprite(c,"travel_loop",Rect2(247,y,48,52),alpha,lift,board.y*.012)
		_sprite(c,"glyph_travel",Rect2(254,y+14,26,24),alpha*.9,lift+Vector2(0,-board.x*.4),board.y*.018)
		_sprite(c,"travel_hinge",Rect2(939,y+12,17,72),alpha,Vector2(board.y*.3,0))
	_sprite(c,"glyph_travel",Rect2(294,131,30,30),alpha,Vector2(0,-board.x*.8-board.y))
	# A sewn hanging star belongs to the loop, outside the playable grid.
	var star_shift=Vector2(board.x*.4+board.y*1.0,board.y*.8)
	c.draw_line(Vector2(261,239),Vector2(257,263)+star_shift,Color("dfbd79",alpha*.78),1.2,true)
	_sprite(c,"travel_star",Rect2(248,257,19,20),alpha,star_shift,board.y*.07)
	# Mint ribbon and plaque are separate, with a third layer for the cat face.
	T.surface(c,Rect2(Vector2(1120,125)+Vector2(0,-shop.y*.55),Vector2(185,38)),"travel_ribbon",alpha,Color("e7ddff"))
	_sprite(c,"travel_plaque",Rect2(1138,118,108,52),alpha,Vector2(0,-shop.x*.6-shop.y*.8))
	_sprite(c,"glyph_travel",Rect2(1168,123,48,39),alpha,Vector2(0,-shop.x*1.2-shop.y*1.25),shop.y*.02)
	_sprite(c,"travel_star",Rect2(1370,179,24,27),alpha,Vector2(shop.y*.5,-shop.x*.55),shop.y*.025)
	_sprite(c,"travel_flowers",Rect2(1350,622,72,104),alpha,Vector2(shop.x*.35,-shop.y*.7),shop.y*.025)
	# The cream title label is fixed so the live title never drifts away from it.
	T.surface(c,Rect2(282,695,152,46),"travel_label",alpha)
	_sprite(c,"glyph_travel",Rect2(293,704,27,27),alpha,Vector2(0,-stash.x*.75-stash.y))
	_sprite(c,"travel_tag",Rect2(258,743,27,54),alpha,Vector2(-stash.y*.55,stash.x*.3),stash.y*.035)
	_sprite(c,"travel_charm",Rect2(933,739,35,72),alpha,Vector2(stash.y*.8,stash.x*.3),-stash.y*.05)
	# Printed four-point stars are material motifs, distinct from five-point slots.
	for at in [Vector2(1011,211),Vector2(1368,239),Vector2(1015,645),Vector2(1358,615)]:
		_print(c,at,5.5,Color("b6a0c7",alpha*(.30+shop.x*.045)))
	_print(c,Vector2(278,810),5,Color("f7dfc3",alpha*.58))
	_print(c,Vector2(946,807),4.5,Color("f7dfc3",alpha*.52))

static func _response(c:CanvasItem,key:String,area:Rect2)->Vector2:
	var motion=c.get("motion")
	if motion==null:return Vector2.ZERO
	var pointer=c.get("mouse")
	var over=pointer is Vector2 and area.has_point(pointer) and str(c.get("overlay")).is_empty()
	var hover=motion.hover("travel_decor:"+key,over)
	var event_response=0.0
	for event in motion.events:
		if str(event.get("kind","")) not in ["coin","land","link","fusion"]:continue
		var point=event.get("pos",Vector2.ZERO)
		var target=event.get("to",Vector2.ZERO)
		if not area.has_point(point) and not area.has_point(target):continue
		var elapsed=float(event.get("age",-1))
		if elapsed<0:continue
		var progress=clampf(elapsed/maxf(.01,float(event.get("duration",.48))),0,1)
		event_response+=sin(progress*TAU*1.2)*pow(1-progress,2)
	return Vector2(hover,clampf(event_response,-1,1))

static func _sprite(c:CanvasItem,name:String,rect:Rect2,alpha:float,offset:Vector2=Vector2.ZERO,angle:float=0)->void:
	var entry=SKIN.ui_entry(name)
	var texture=SKIN.texture(SKIN.ui_path(name))
	if texture==null:return
	var authored=entry.get("source_rect",[])
	var source=SKIN.bounds(SKIN.ui_path(name)) if authored.size()!=4 else Rect2(authored[0],authored[1],authored[2],authored[3])
	if not source.has_area():return
	var size=source.size*minf(rect.size.x/source.size.x,rect.size.y/source.size.y)
	var basis=c.get("draw_basis")
	if not basis is Transform2D:basis=Transform2D.IDENTITY
	c.draw_set_transform_matrix(basis*Transform2D(angle,Vector2.ONE,0,rect.get_center()+offset))
	c.draw_texture_rect_region(texture,Rect2(-size*.5,size),source,Color(1,1,1,alpha))
	c.draw_set_transform_matrix(basis)

static func _print(c:CanvasItem,at:Vector2,radius:float,color:Color)->void:
	var points=PackedVector2Array([at+Vector2(0,-radius),at+Vector2(radius*.3,-radius*.3),at+Vector2(radius,0),at+Vector2(radius*.3,radius*.3),at+Vector2(0,radius),at+Vector2(-radius*.3,radius*.3),at+Vector2(-radius,0),at+Vector2(-radius*.3,-radius*.3)])
	c.draw_colored_polygon(points,color)
