extends RefCounted
## Value-only presentation and input intents. No run, inventory or save access.
const T=preload("res://scripts/ui/ui_theme.gd")
const SKIN=preload("res://scripts/ui/visual_skin.gd")
const LINK=preload("res://scripts/ui/crafting/craft_link_view.gd")
const GRID=preload("res://scripts/ui/pockets/frequency_grid.gd")
var entries:Array=[]
var cache_key=""
var pressed:Dictionary={}
var pressed_key=""
func active(m:Dictionary)->bool:return m.active
func refresh(m:Dictionary)->void:
	if not active(m):entries=[];cache_key="";return
	if m.key==cache_key:return
	cache_key=m.key;entries=m.entries.duplicate(true)
	var used:Array=[];var groups={}
	for entry in entries:
		if not groups.has(entry.base_uid):groups[entry.base_uid]=[]
		groups[entry.base_uid].append(entry)
	for uid in groups:
		var group=groups[uid]
		var block=_badge_rect(m,uid,used,Vector2(132,group.size()*52-6))
		used.append(block)
		for n in group.size():group[n].rect=Rect2(block.position+Vector2(0,n*52),Vector2(132,46))

func _badge_rect(m:Dictionary,base_uid:String,used:Array,size:Vector2)->Rect2:
	var bounds:Rect2=m.board_bounds.grow(-5)
	var body=m.item_rects[base_uid]
	# Prefer a corner beside the source; if occupied, use the closest free patch.
	var points:Array=[Vector2(body.end.x-size.x,body.end.y-5),Vector2(body.position.x,body.end.y-5),Vector2(body.end.x-5,body.position.y+8),Vector2(body.position.x,body.position.y-size.y+5)]
	for y in range(int(bounds.position.y),int(bounds.end.y-size.y)+1,24):
		for x in range(int(bounds.position.x),int(bounds.end.x-size.x)+1,32):points.append(Vector2(x,y))
	var best=Rect2();var cost=INF
	for point in points:
		var rect=Rect2(Vector2(clampf(point.x,bounds.position.x,bounds.end.x-size.x),clampf(point.y,bounds.position.y,bounds.end.y-size.y)),size)
		var score=rect.get_center().distance_to(body.get_center())
		for occupied in used:
			if rect.grow(3).intersects(occupied):score+=100000+rect.intersection(occupied).get_area()
		for uid in m.item_rects:
			var item_box=m.item_rects[uid].grow(-8)
			if rect.intersects(item_box):score+=rect.intersection(item_box).get_area()*2
		if score<cost:cost=score;best=rect
	return best

func hit(m:Dictionary,point:Vector2)->Dictionary:
	refresh(m)
	for entry in entries:
		if entry.rect.has_point(point):return entry
	return {}

func draw(canvas:CanvasItem,m:Dictionary,paint:Dictionary)->void:
	refresh(m)
	if entries.is_empty():return
	paint.basis.call()
	var hovered=hit(m,m.mouse)
	if not hovered.is_empty():
		# Both the consumed inputs and the exact landing are visible without text.
		paint.basis.call(m.board_transform)
		for uid in m.occupied:
			if uid not in hovered.consumed:continue
			for cell in m.occupied[uid]:
				canvas.draw_circle(m.board_origin+(Vector2(cell)+Vector2.ONE*.5)*m.cell,m.cell*.34,Color("fff0b4",.14))
		var out=hovered.output
		if not hovered.ok:
			paint.basis.call()
			var full=StyleBoxFlat.new();full.bg_color=Color("d88889",.12);full.border_color=Color("dd9b96",.60);full.set_border_width_all(2);full.set_corner_radius_all(12)
			canvas.draw_style_box(full,m.stash_bounds)
		elif hovered.get("destination","board")=="stash":
			paint.basis.call()
			var slot:Rect2=m.stash_rects.get(int(hovered.stash_index),m.stash_bounds)
			var glow=StyleBoxFlat.new();glow.bg_color=Color("ffe8a6",.17);glow.border_color=Color("ffe8a6",.70);glow.set_border_width_all(2);glow.set_corner_radius_all(12)
			canvas.draw_style_box(glow,slot)
			if m.stash_rects.has(int(hovered.stash_index)):paint.icon.call(out.kind,slot.grow(-3),int(out.rotation),.70)
		else:
			GRID.footprint(canvas,m.board_origin+Vector2(out.x,out.y)*m.cell,hovered.cells,m.cell,Color("ffe7a0",.25),true)
			paint.piece.call(out,m.board_origin,.78)
			paint.basis.call()

	for entry in entries:
		var over=entry.rect.has_point(m.mouse)
		var down=not pressed.is_empty() and entry.base_uid==pressed.base_uid and entry.target==pressed.target and over
		var rect:Rect2=entry.rect
		var visual=Rect2(rect.position+Vector2(0,1 if down else -1 if over else 0),rect.size)
		if SKIN.is_chibi():
			T.surface(canvas,visual,"button",1.0,Color(1.10,1.07,1.0) if over else Color.WHITE)
		else:
			T.plate(canvas,visual,T.SHELL.lightened(.12 if over else .04),T.BRASS,8)
		paint.icon.call(entry.target,Rect2(visual.position+Vector2(7,5),Vector2(76,36)),0,1.0 if entry.ok else .42)
		paint.text.call("合成",visual.position+Vector2(88,29),17,SKIN.PLUM if SKIN.is_chibi() else T.PAPER)
		# A soft sparkle distinguishes an actionable upgrade from item ownership.
		var light=(.65+.15*sin(m.elapsed*2.6)) if entry.ok else .20
		paint.star.call(visual.position+Vector2(9,7),4,Color("fff3b8",light),true)

func input(m:Dictionary,event:InputEvent)->Dictionary:
	if not active(m):pressed={};return {"handled":false}
	if not pressed.is_empty() and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		pressed={};return {"handled":true}
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed and not pressed.is_empty():
		pressed={};return {"handled":true}
	if not event is InputEventMouseButton or event.button_index!=MOUSE_BUTTON_LEFT:return {"handled":false}
	if event.pressed:
		var entry=hit(m,event.position)
		if entry.is_empty():return {"handled":false}
		pressed=entry.duplicate(true);pressed_key=cache_key
		return {"handled":true,"pressed":true}
	if pressed.is_empty():return {"handled":false}
	var entry=pressed;pressed={};refresh(m)
	if cache_key!=pressed_key or not entry.rect.has_point(event.position):return {"handled":true}
	return {"handled":true,"request":entry}

func matching_offers(m:Dictionary)->Array:
	return m.matching_offers if m.guidance_active else []
func links(m:Dictionary)->Array:
	if not m.guidance_active or m.dragging_bag:return []
	var result:Array=[];var seen={}
	for entry in m.relations:
		var key=JSON.stringify(entry.uids)
		if seen.has(key):continue
		seen[key]=true
		var link=entry.duplicate(true)
		link.from=m.endpoints[entry.base_uid];link.to=m.endpoints[entry.material_uid]
		link.status="ready" if link.ready else "potential"
		link.emphasis=1.0 if m.focus.is_empty() or m.focus in entry.uids else .45
		result.append(link)
	return result

func draw_links(canvas:CanvasItem,m:Dictionary,paint:Dictionary)->void:
	paint.basis.call()
	for link in links(m):LINK.draw(canvas,link,m.elapsed)

func draw_offer_hint(canvas:CanvasItem,m:Dictionary,paint:Dictionary,index:int,rect:Rect2)->void:
	if index not in matching_offers(m):return
	var center=rect.get_center()
	var tint=LINK.palette(false) # A visible shop offer is not an owned ingredient.
	canvas.draw_circle(center,minf(rect.size.x,rect.size.y)*.36,Color(tint.core,.10))
	canvas.draw_arc(center,minf(rect.size.x,rect.size.y)*.38,.15,PI-.15,24,Color(tint.edge,.60),1.5,true)
	paint.star.call(rect.position+Vector2(14,16),4,Color(tint.core,.90),true)
