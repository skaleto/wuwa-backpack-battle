extends RefCounted
const INFO=preload("res://scripts/ui/items/item_info.gd")
const C=preload("res://scripts/data/catalog.gd")
const T=preload("res://scripts/ui/ui_theme.gd")
const Q=preload("res://scripts/ui/items/item_quality.gd")

const ICONS=preload("res://scripts/ui/ability_icons.gd")
const A=preload("res://scripts/ui/apricot_ui.gd")
const D=preload("res://scripts/ui/items/item_description.gd")

const TREE=preload("res://scripts/crafting/recipe_tree.gd")
const STAR_DIAGRAM=preload("res://scripts/ui/items/item_star_diagram.gd")
const ATLAS_PAINTER=preload("res://scripts/ui/crafting/recipe_atlas_painter.gd")

static func rich_width(g,value:String,size:int)->float:
	var width=0.0;var at=0
	while at<value.length():
		if value[at]=="[" and value.find("]",at)>at:
			at=value.find("]",at)+1;width+=size+3
		else:
			width+=g.font.get_string_size(value[at],HORIZONTAL_ALIGNMENT_LEFT,-1,size).x;at+=1
	return width

static func rich(g,value:String,pos:Vector2,size:int,color:Color)->void:
	var at=0;var x=pos.x
	while at<value.length():
		if value[at]=="[" and value.find("]",at)>at:
			var end=value.find("]",at);var key=value.substr(at+1,end-at-1)
			ICONS.draw(g,key,Rect2(Vector2(x,pos.y-size+2)+g.paint_offset,Vector2(size+2,size+2)),g.paint_alpha)
			x+=size+3;at=end+1
		else:
			var end=value.find("[",at)
			if end<0:end=value.length()
			var part=value.substr(at,end-at);g._text(part,Vector2(x,pos.y),size,color)
			x+=g.font.get_string_size(part,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x;at=end

static func rows(g,values:Array,at:Vector2,width:float,step:float=32,size:int=17,label_color:Color=T.MUTED)->void:
	for n in range(values.size()):
		var pos=at+Vector2(0,n*step);var label=str(values[n][0]);var value=str(values[n][1]);var font_size=size
		while font_size>12 and rich_width(g,label,font_size)+rich_width(g,value,font_size)+12>width:font_size-=1
		if rich_width(g,label,font_size)+rich_width(g,value,font_size)+12>width:
			rich(g,label,pos+Vector2(0,-5),12,T.tone(label_color))
			rich(g,value,pos+Vector2(width-rich_width(g,value,12),10),12,T.tone(T.PAPER))
		else:
			rich(g,label,pos,font_size,T.tone(label_color))
			rich(g,value,pos+Vector2(width-rich_width(g,value,font_size),0),font_size,T.tone(T.PAPER))
		g.draw_line(pos+Vector2(0,14)+g.paint_offset,pos+Vector2(width,14)+g.paint_offset,Color(T.tone(T.EDGE),g.paint_alpha*.16),1,true)

static func chips(g,kind:String,at:Vector2)->void:
	var offset=Vector2.ZERO
	for chip in INFO.type_chips(kind):
		var width=g.font.get_string_size(chip[1],HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+31
		if offset.x+width>300:offset=Vector2(0,offset.y+25)
		g._panel(Rect2(at+offset,Vector2(width,22)),T.tone(T.SHELL),Color(T.tone(T.EDGE),.35),1,7)
		ICONS.draw(g,chip[0],Rect2(at+offset+Vector2(4,2)+g.paint_offset,Vector2(18,18)),g.paint_alpha)
		g._text(chip[1],at+offset+Vector2(25,16),12,T.tone(T.PAPER));offset.x+=width+5

static func frame(g,title:String):
	g.draw_rect(Rect2(0,0,1440,960),Color(T.tone(T.SHADOW),.65*g.paint_alpha))
	g._panel(Rect2(227,116,986,730),T.tone(T.SHELL),T.tone(T.EDGE),1,6)
	g._text(title,Vector2(271,169),25,T.tone(T.PAPER))
	g._button(Rect2(1069,138,97,42),"返回","details_back")
	T.rule(g,Vector2(271,192)+g.paint_offset,Vector2(1168,192)+g.paint_offset,.24*g.paint_alpha)

static func detail_height(g,item:Dictionary)->float:
	var lines=0
	for line in D.effects(item.kind):lines+=A.lines(g,line,316,16).size()
	var star_row=96 if not C.items[item.kind].get("stars",[]).is_empty() else 0
	var requirement=50 if C.items[item.kind].get("strict_signature",false) else 0
	return 160+(45 if not bundle_offer(g).is_empty() else 0)+(48 if not g._shop_recipe_partners().is_empty() else 0)+star_row+requirement+D.stats(item.kind).size()*32+clampf(lines*23+D.effects(item.kind).size()*7+84,130,280)+112

static func bundle_offer(g)->Dictionary:
	if g.detail_origin!="shop" or g.detail_offer_index<0 or g.detail_offer_index>=g.run.get("shop",[]).size():return {}
	var offer=g.run.shop[g.detail_offer_index]
	return offer if offer.get("bundle",[]).size()==2 and offer.get("kind","")==g.detail_item.get("kind","") else {}

static func details(g):
	var item=g.detail_item
	if item.is_empty():return
	var rect=g._detail_card_rect();var at=rect.position
	A.panel(g,rect);A.header(g,Rect2(at+Vector2(10,10),Vector2(rect.size.x-20,50)))
	var name=C.items[item.kind].name
	g._wrapped(name,at+Vector2(23,40),280,20,A.INK,2)
	A.button(g,Rect2(at+Vector2(rect.size.x-48,19),Vector2(31,31)),"×","details_back")
	g._draw_detail_icon(item,Rect2(at+Vector2(35,67),Vector2(rect.size.x-70,64)))
	var d=C.items[item.kind]
	var summary="%d格 · 标价%d"%[d.shape.size(),int(d.price)]
	var bundle=bundle_offer(g)
	if not bundle.is_empty():summary="两件组合 · 合价%d"%g.inventory.purchase_price(g.run,g.detail_offer_index)
	# UIDs are local to a build: enemy, shop and recipe records may reuse i1.
	var owned=g.inventory.find_piece(g.run,item.get("uid","")) if g.detail_origin in ["board","stash","bag","pocket"] else {}
	if owned.get("kind","")==item.kind and owned.has("paid_cost"):
		var basis="估值" if owned.get("cost_basis","") in ["legacy_estimate","mixed"] else "实付"
		summary+=" · %s%d · 卖出%d"%[basis,int(owned.paid_cost),g.inventory.resale_value(owned)]
	g._text(summary,at+Vector2((rect.size.x-g.font.get_string_size(summary,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x)*.5,149),15,A.MUTED)
	var y=160.0
	if not bundle.is_empty():
		var second=str(bundle.bundle[1])
		A.box(g,Rect2(at+Vector2(22,y),Vector2(rect.size.x-44,39)),Color("e4eddf"),Color("aac7b1",.6),12)
		g._draw_icon(second,Rect2(at+Vector2(29,y+3),Vector2(74,33)),0)
		g._text("同时获得 · "+str(C.items[second].name),at+Vector2(111,y+25),14,A.INK)
		y+=45
	var partners=g._shop_recipe_partners()
	if not partners.is_empty():
		A.box(g,Rect2(at+Vector2(22,y),Vector2(rect.size.x-44,42)),Color("e4eddf"),Color("aac7b1",.6),12)
		g._text("合成搭档",at+Vector2(33,y+27),15,A.GOOD)
		for n in mini(3,partners.size()):g._draw_icon(partners[n].kind,Rect2(at+Vector2(115+n*65,y+3),Vector2(60,36)),0)
		y+=48
	for row in D.stats(item.kind):
		A.stat(g,at+Vector2(22,y),rect.size.x-44,row[0],row[1],row[2]);y+=32
	if not C.items[item.kind].get("stars",[]).is_empty():
		star_diagram(g,item,g.detail_origin,Rect2(at+Vector2(22,y),Vector2(rect.size.x-44,90)));y+=96
	if d.get("strict_signature",false):
		TREE.requirement_row(g,item.kind,Rect2(at+Vector2(22,y),Vector2(rect.size.x-44,44)));y+=50
	var effect_bottom=rect.size.y-112
	A.box(g,Rect2(at+Vector2(20,y+6),Vector2(rect.size.x-40,effect_bottom-y-6)),Color("fff0d9",.6),Color("e8bd88",.55),14)
	A.title(g,"口袋效果" if C.is_tag(item.kind,"bag") else "效果",at+Vector2(30,y+31),"bag" if C.is_tag(item.kind,"bag") else "star")
	var clauses=D.effects(item.kind)
	for row in g._item_battle_rows(item,g.detail_origin):clauses.append(str(row[0])+"："+str(row[1]))
	if g._item_waiting(item,g.detail_origin):clauses.append("体力不足，等待恢复。")
	var pages=A.pages(g,clauses,rect.size.x-58,effect_bottom-y-70,16)
	g.detail_page=clampi(g.detail_page,0,pages.size()-1)
	A.text_page(g,pages[g.detail_page],at+Vector2(29,y+45))
	if pages.size()>1:
		A.button(g,Rect2(at+Vector2(rect.size.x-109,effect_bottom-28),Vector2(27,23)),"‹","detail_prev",g.detail_page>0)
		g._text("%d/%d"%[g.detail_page+1,pages.size()],at+Vector2(rect.size.x-76,effect_bottom-11),12,A.MUTED)
		A.button(g,Rect2(at+Vector2(rect.size.x-45,effect_bottom-28),Vector2(27,23)),"›","detail_next",g.detail_page+1<pages.size())
	apricot_chips(g,item.kind,at+Vector2(23,effect_bottom+12),rect.size.x-46)
	var has_recipe=not INFO.recipes(item.kind).is_empty()
	A.button(g,Rect2(at+Vector2(25,rect.size.y-51),Vector2(rect.size.x-50,34)),"合成配方" if has_recipe else "无合成配方","detail_recipes",has_recipe,true)

static func star_diagram(g,item:Dictionary,origin:String,rect:Rect2)->void:
	var model=g._item_star_snapshot(item,origin)
	draw_star_model(g,model,rect)

static func draw_star_model(g,model:Dictionary,rect:Rect2)->void:
	A.box(g,rect,Color("ede2f7",.7),Color("c5addf",.45),12)
	A.title(g,"星位",rect.position+Vector2(10,25),"star",16)
	var x=rect.position.x+12
	for category in model.categories:
		ICONS.draw(g,category,Rect2(Vector2(x,rect.position.y+35)+g.paint_offset,Vector2(20,20)),g.paint_alpha)
		var name=ICONS.label(category);g._text(name,Vector2(x+24,rect.position.y+50),13,A.INK)
		x+=28+g.font.get_string_size(name,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
	if model.matched_count>=0:g._text("已点亮 %d 件"%model.matched_count,rect.position+Vector2(12,76),13,A.MUTED)
	STAR_DIAGRAM.draw(g,model,Rect2(rect.position+Vector2(rect.size.x-145,5)+g.paint_offset,Vector2(135,80)),g.motion.elapsed,g.paint_alpha)

static func apricot_chips(g,kind:String,at:Vector2,width:float)->void:
	var offset=Vector2.ZERO
	for chip in INFO.type_chips(kind):
		var length=g.font.get_string_size(chip[1],HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+32
		if offset.x+length>width:offset=Vector2(0,offset.y+26)
		A.box(g,Rect2(at+offset,Vector2(length,23)),Color("ecdef7"),Color("c5addf"),8)
		ICONS.draw(g,chip[0],Rect2(at+offset+Vector2(4,2)+g.paint_offset,Vector2(20,20)),g.paint_alpha)
		g._text(chip[1],at+offset+Vector2(27,16),12,A.INK);offset.x+=length+5

static func recipes(g):
	draw_atlas(g)

# Game-facing atlas adapter. Values are detached before entering the new view.
static func draw_atlas(g)->void:
	if TREE.focus_kind.is_empty():TREE.open(null,str(g.detail_item.get("kind","")))
	var model=TREE.presentation(TREE.inventory_counts(g.run),TREE.navigation_state(),not TREE.history.is_empty())
	if model.is_empty():return
	if model.result.has_stars:model.result.star_model=g._item_star_snapshot({"kind":model.result.kind,"rotation":0},"recipe").duplicate(true)
	TREE.VIEW.draw(atlas_painter(g),model)

static func atlas_painter(g):
	return ATLAS_PAINTER.new(g.font,{
		"shade":func(rect,color):g.draw_rect(rect,Color(color,color.a*g.paint_alpha)),
		"panel":func(rect):A.panel(g,rect),
		"header":func(rect):A.header(g,rect),
		"box":func(rect,fill,edge,radius):A.box(g,rect,fill,edge,radius),
		"title":func(value,at,icon,size):A.title(g,value,at,icon,size),
		"text":func(value,at,size,color):g._text(value,at,size,color),
		"wrapped":func(value,at,width,size,color,lines):g._wrapped(value,at,width,size,color,lines),
		"icon":func(kind,rect):g._draw_icon(kind,rect,0),
		"glyph":func(kind,rect):ICONS.draw(g,kind,Rect2(rect.position+g.paint_offset,rect.size),g.paint_alpha),
		"button":func(rect,value,id,enabled,primary):A.button(g,rect,value,id,enabled,primary),
		"hit":func(rect,id):g._button(rect,"",id,true,false),
		"stat":func(at,width,label,value,icon,tint):A.stat(g,at,width,label,value,icon,tint),
		"pages":func(clauses,width,height,size):return A.pages(g,clauses,width,height,size),
		"text_page":func(content,at,size):A.text_page(g,content,at,size),
		"star_diagram":func(model,rect):draw_star_model(g,model,rect)
	})

static func apply_atlas_intent(g,request:Dictionary)->void:
	match str(request.get("type","")):
		"close":g.detail_history.clear();g.detail_parent_overlay="";g._close_item_details()
		"details":open_atlas_details(g,str(request.kind),TREE.navigation_state())

static func open_atlas_details(g,kind:String,navigation:Dictionary)->void:
	g.detail_history.append({"item":g.detail_item.duplicate(true),"origin":g.detail_origin,"recipe":g.detail_recipe_index,"base":g.detail_base_index,"atlas_root":navigation.root,"atlas_selected":navigation.selected,"atlas_page":navigation.changes,"atlas_branch":navigation.branches,"atlas_stage":navigation.stages,"atlas_effect":navigation.effects,"atlas_inspected":navigation.inspected,"atlas_navigation":navigation.duplicate(true),"anchor":g.detail_anchor})
	g._open_item_details({"kind":kind,"rotation":0},"recipe")

static func action(g,id:String)->bool:
	if TREE.action(g,id):return true
	match id:
		"details_back":
			if g.overlay=="item_recipes":
				g.overlay="item_details";g.motion.modal_value=0;g.motion.modal_target=0;g.motion.last_overlay=""
			elif not g.detail_history.is_empty():
				var previous=g.detail_history.pop_back()
				g.detail_item=previous.item;g.detail_origin=previous.origin;g.detail_recipe_index=previous.recipe;g.detail_base_index=previous.base;g.overlay="item_recipes"
				if previous.has("atlas_root"):
					TREE.root_kind=previous.atlas_root;TREE.selected=previous.atlas_selected;TREE.change_page=previous.atlas_page;TREE.branch_page=previous.get("atlas_branch",0);TREE.stage_page=previous.get("atlas_stage",0);TREE.effect_page=previous.get("atlas_effect",0);TREE.inspected=previous.get("atlas_inspected","")
					if previous.has("atlas_navigation"):TREE.restore_navigation(previous.atlas_navigation)
					g.detail_anchor=previous.get("anchor",g.detail_anchor)
			else:g._close_item_details()
		"detail_recipes":
			g.overlay="item_recipes";g.detail_recipe_index=0;g.detail_base_index=0
			TREE.history.clear();TREE.open(g,g.detail_item.kind)
		"detail_prev":g.detail_page-=1
		"detail_next":g.detail_page+=1
		"detail_base_prev":g.detail_base_index-=1
		"detail_base_next":g.detail_base_index+=1
		"detail_recipe_prev","detail_recipe_next":
			g.detail_recipe_index+=1 if id.ends_with("next") else -1
			g.detail_base_index=0
			var recipes=INFO.recipes(g.detail_item.kind)
			if g.detail_recipe_index>=0 and g.detail_recipe_index<recipes.size():g.detail_base_index=maxi(0,INFO.bases(recipes[g.detail_recipe_index]).find(g.detail_item.kind))
		"detail_result":
			var recipe=INFO.recipes(g.detail_item.kind)[g.detail_recipe_index]
			g.detail_history.append({"item":g.detail_item.duplicate(true),"origin":g.detail_origin,"recipe":g.detail_recipe_index,"base":g.detail_base_index})
			g._open_item_details({"kind":recipe.target,"rotation":0},"recipe")
		"detail_forge":
			var recipe=INFO.recipes(g.detail_item.kind)[g.detail_recipe_index];var bases=INFO.bases(recipe)
			var kind=bases[posmod(g.detail_base_index,bases.size())]
			for item in g.run.items:
				if item.kind==kind:
					g.forge_base=item.uid;g.forge_options=g.FORGE.options(g.run,item.uid,g.inventory);g.forge_index=0
					for n in range(g.forge_options.size()):
						if g.forge_options[n].target==recipe.target:g.forge_index=n
					g.forge_cache_key="";g.overlay="forge";break
		"detail_use":
			var item=g._piece_by_uid(g.detail_item.get("uid",""))
			if not item.is_empty():g._material_begin(item)
		_:return false
	return true
