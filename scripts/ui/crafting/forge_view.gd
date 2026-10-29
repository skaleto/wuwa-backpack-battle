extends RefCounted
## Recipe presentation is separate from the transaction and never consumes items.
const INFO=preload("res://scripts/ui/items/item_info.gd")
const PANEL=preload("res://scripts/ui/items/item_panel.gd")
const C=preload("res://scripts/data/catalog.gd")
const F=preload("res://scripts/crafting/craft.gd")
const T=preload("res://scripts/ui/ui_theme.gd")
const Q=preload("res://scripts/ui/items/item_quality.gd")

static func centered(g,text: String,rect: Rect2,size: int,color: Color) -> void:
	var width=g.font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	g._text(text,Vector2(rect.get_center().x-width/2,rect.position.y),size,color)

static func arrow(g,from: Vector2,to: Vector2,color: Color) -> void:
	var off=g.paint_offset;var tint=Color(color,g.paint_alpha)
	g.draw_line(from+off,to+off,tint,2,true)
	var d=from.direction_to(to)
	for angle in [-.55,.55]:g.draw_line(to+off-d.rotated(angle)*11,to+off,tint,2,true)

static func name(g,kind: String,at: Vector2,width: float,size: int=18) -> void:
	if kind=="mat_43020041":
		centered(g,"海蚀嵌合体",Rect2(at,Vector2(width,0)),size,T.tone(T.PAPER))
		centered(g,"型号 210",Rect2(at+Vector2(0,23),Vector2(width,0)),14,T.tone(T.MUTED))
	else:g._wrapped(C.items[kind].name,at,width,size,T.tone(T.PAPER),2)

static func footprint(g,kind: String,at: Vector2) -> void:
	for cell in C.items[kind].shape:
		var rect=Rect2(at+Vector2(cell[0],cell[1])*9+g.paint_offset,Vector2(7,7))
		g.draw_rect(rect,Color(Q.color(kind),g.paint_alpha*.8))

static func draw(g) -> void:
	g.draw_rect(Rect2(0,0,1440,960),Color(T.tone(T.SHADOW),.78*g.paint_alpha))
	g._panel(Rect2(160,125,1120,710),T.tone(T.SHELL),T.tone(T.EDGE),1,6)
	g._text("合成",Vector2(210,185),32,T.tone(T.PAPER))
	g._button(Rect2(1130,151,96,44),"返回","close")
	g._text("",Vector2(333,183),17,T.tone(T.MUTED))
	T.rule(g,Vector2(210,213)+g.paint_offset,Vector2(1230,213)+g.paint_offset,.24*g.paint_alpha)
	var base=g._piece_by_uid(g.forge_base)
	var weapons=g.run.items.filter(func(v):return C.combinations.any(func(r):return F.accepts_base(r,v.kind)))
	if base.is_empty() or base not in g.run.items:
		base=weapons[0] if not weapons.is_empty() else {};g.forge_base=base.get("uid","")
	if base.is_empty():g._text("背包中暂无合成基底",Vector2(465,453),23,T.tone(T.PAPER));return
	var cache_key=g.forge_base+JSON.stringify(g.run)
	if g.forge_cache_key!=cache_key:
		g.forge_options=F.options(g.run,g.forge_base,g.inventory);g.forge_cache_key=cache_key
	g._text("投入",Vector2(226,245),16,T.tone(T.MUTED))
	g._draw_icon(base.kind,Rect2(218,278,178,96),int(base.rotation))
	g._text("×1",Vector2(374,277),16,T.tone(T.PAPER))
	name(g,base.kind,Vector2(216,403),190,18)
	footprint(g,base.kind,Vector2(245,452))
	g._text("将消耗",Vector2(312,460),15,T.tone(T.MUTED))
	g._button(Rect2(227,480,64,34),"‹","forge_base_prev",weapons.size()>1)
	g._button(Rect2(328,480,64,34),"›","forge_base_next",weapons.size()>1)
	if g.forge_options.is_empty():g._text("已是最终成品",Vector2(626,341),27,Q.color(base.kind));return
	g.forge_index=clampi(g.forge_index,0,g.forge_options.size()-1)
	var target=g.forge_options[g.forge_index].target;var def=C.items[target]
	var outcome=F.preview(g.run,target,g.forge_base,g.inventory)
	var rows=F.material_status(g.run,target,g.forge_base,g.inventory)
	g._text("+",Vector2(415,336),29,T.tone(T.MUTED))
	for n in range(rows.size()):
		var row=rows[n];var kind=row.kind
		var x=458+(3-rows.size())*66+n*132
		var ready=int(row.near)>=int(row.required)
		g._draw_icon(kind,Rect2(x+9,278,100,94),0)
		g._text("×%d"%row.required,Vector2(x+99,277),16,T.tone(T.PAPER))
		name(g,kind,Vector2(x,403),124,16)
		var status="已相邻 %d/%d"%[mini(row.near,row.required),row.required] if ready else "储物箱 · %d"%row.stash if row.stash>0 else "背包中 · 未相邻" if row.owned>0 else "缺少 %d 个"%maxi(0,row.required-row.owned)
		centered(g,status,Rect2(x,461,124,0),14,T.tone(T.JADE) if ready else T.tone(T.ALERT))
		if row.owned<row.required:
			var offer=g.run.shop.find_custom(func(v):return v.get("kind","")==kind)
			var price=g.inventory.purchase_price(g.run,offer) if offer>=0 else int(row.price)
			var can_buy=C.is_tag(kind,"craft_material") and offer>=0 and g.run.gold>=price and g.inventory.shop_eligible(g.run,kind)
			g._button(Rect2(x,480,124,34),"购买 %d"%price,"forge_buy:"+kind,can_buy)
		elif not ready:g._button(Rect2(x,480,124,34),"摆放","forge_place:"+kind)
		else:centered(g,"✓ 已就绪",Rect2(x,504,124,0),16,T.tone(T.JADE))
		if n<rows.size()-1:g._text("+",Vector2(x+122,336),20,T.tone(T.MUTED))
	arrow(g,Vector2(865,325),Vector2(912,325),T.tone(T.BRASS))
	g._text("成品",Vector2(944,245),16,T.tone(T.MUTED))
	g._draw_icon(target,Rect2(939,270,272,112),0)
	name(g,target,Vector2(944,412),272,24)
	footprint(g,target,Vector2(945,453))
	g._text("占 %d 格"%def.shape.size(),Vector2(1014,461),15,T.tone(T.MUTED))
	g._button(Rect2(944,480,60,34),"‹","forge_prev",g.forge_index>0)
	centered(g,"%d / %d"%[g.forge_index+1,g.forge_options.size()],Rect2(1006,504,140,0),16,T.tone(T.PAPER))
	g._button(Rect2(1150,480,60,34),"›","forge_next",g.forge_index<g.forge_options.size()-1)
	T.rule(g,Vector2(210,545)+g.paint_offset,Vector2(1230,545)+g.paint_offset,.2*g.paint_alpha)
	g._text("",Vector2(217,575),17,T.tone(T.MUTED))
	var basis=Transform2D(0,Vector2.ONE*.40,0,Vector2(219,593)+g.paint_offset-g.BOARD*.40)
	g._basis(basis);g._draw_board(g.run,g.BOARD,0)
	# The mini-board shows real positions, with candidate neighbours as dots.
	for cell in g.inventory.coverage(g.run.bags):
		if g.run.items.any(func(item):return cell in g.inventory.occupied(item)):continue
		if g.inventory.occupied(base).any(func(v):return absi(cell.x-v.x)+absi(cell.y-v.y)==1):
			g.draw_circle(g.BOARD+(Vector2(cell)+Vector2.ONE*.5)*g.CELL,6,Color(T.tone(T.JADE),g.paint_alpha*(.5+.15*sin(g.age*4))))
	g._basis()
	g._text("合成后",Vector2(467,580),19,Q.color(target))
	var changes=INFO.recipe_changes(base.kind,target)
	PANEL.rows(g,(changes+INFO.effects(target)).slice(0,5),Vector2(467,619),733,27,16)
	if def.get("strict_signature",false):
		var owners=def.signature_owner_ids.map(func(id):return C.roster.get(id,{}).get("name",id))
		g._text("专武关联："+" / ".join(owners),Vector2(467,747),16,T.tone(T.BRASS))
	var reason="✓ 材料与空间就绪" if outcome.ok else outcome.reason
	g._wrapped(reason,Vector2(213,791),710,18,T.tone(T.JADE) if outcome.ok else T.tone(T.ALERT),2)
	g._button(Rect2(974,768,247,46),"选择落点" if outcome.ok else "条件未满足","forge_confirm",outcome.ok,true,T.tone(T.BRASS))
