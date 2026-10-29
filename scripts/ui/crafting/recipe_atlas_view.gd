extends RefCounted
## Detached values in; drawing and navigation intents out. No catalog or game access.
const P=preload("res://scripts/ui/crafting/recipe_atlas_painter.gd")
const A=preload("res://scripts/ui/apricot_ui.gd")
const FRAME=Rect2(100,104,1240,756)

static func draw(p:P,model:Dictionary)->void:
	if model.is_empty():return
	p.shade(Rect2(0,0,1440,960),Color("35305b",.24))
	p.panel(FRAME);p.header(Rect2(112,116,794,65))
	p.title("合成图鉴",Vector2(137,157),"relic",25)
	p.button(Rect2(368,130,32,32),"‹","atlas_root_prev",model.root_previous)
	p.wrapped(model.focus.name,Vector2(415,153),310,18,A.INK,1)
	p.button(Rect2(758,130,32,32),"›","atlas_root_next",model.root_next)
	p.button(Rect2(809,130,85,32),"返回","atlas_history",model.can_back)
	p.box(Rect2(124,190,780,77),Color("fff0d8",.55),Color("c4a9df",.4),15)
	p.icon(model.focus.kind,Rect2(140,198,94,60))
	p.wrapped(model.focus.name,Vector2(251,222),495,20,A.INK,1)
	p.text(model.focus.role,Vector2(252,249),14,A.MUTED)
	p.text("持有 %d"%model.focus.owned,Vector2(800,238),16,A.GOOD if model.focus.owned>0 else A.MUTED)
	p.box(Rect2(132 if model.direction=="outgoing" else 328,312,184,3),Color("c78a51"),Color.TRANSPARENT,1)
	p.button(Rect2(132,278,184,32),"可合成 %d"%model.outgoing_count,"atlas_direction:outgoing",true,model.direction=="outgoing")
	p.button(Rect2(328,278,184,32),"来源配方 %d"%model.incoming_count,"atlas_direction:incoming",true,model.direction=="incoming")
	pager(p,Vector2(799,283),model.option_page,model.option_pages,"atlas_options")
	for n in model.options.size():draw_option(p,model.options[n],Rect2(124,320+n*91,780,84),model.selected_recipe_id)
	if model.options.is_empty():
		p.box(Rect2(124,320,780,266),Color("fff0d8",.3),Color("c4a9df",.4),15)
		p.text("已到这条路线的末端" if model.direction=="outgoing" else "此物品没有合成来源",Vector2(350,435),20,A.MUTED)
	var recipe=model.recipe
	p.box(Rect2(124,600,780,232),Color("fff0d8",.5),Color("c4a9df",.4),15)
	p.header(Rect2(126,602,776,37));p.title("所选配方",Vector2(145,629),"material",19)
	if not recipe.is_empty():
		var inputs=recipe.inputs;var count=inputs.size()+1
		var stride=750.0/count;var slot=minf(200,stride-42)
		for n in count:
			var output=n==inputs.size();var kind=str(recipe.target) if output else str(inputs[n].kind)
			var name=str(recipe.name) if output else str(inputs[n].name)
			var center=Vector2(139+stride*(n+.5),682)
			p.icon(kind,Rect2(center-Vector2(slot*.5,32),Vector2(slot,64)))
			p.wrapped(name,Vector2(center.x-slot*.5,735),slot,15,A.INK,2)
			p.hit(Rect2(center-Vector2(slot*.5,32),Vector2(slot,120)),"atlas_material:"+kind)
			if not output:
				var row=inputs[n];var value="持有 %d / %d"%[row.owned,row.need]
				p.text(value,Vector2(center.x-p.width(value,16)*.5,781),16,A.GOOD if row.owned>=row.need else A.MISSING)
			if n<count-1:p.text("→" if n==count-2 else "+",Vector2(center.x+stride*.5-12,692),28,Color("aa8ed2"))
		if recipe.fee>0:p.text("%d贝币"%recipe.fee,Vector2(150,815),14,A.MUTED)
	p.button(Rect2(697,789,185,32),"返回整备","atlas_close",true,true)
	result_card(p,model.result,model.effect_page,model.change_page)
	p.button(Rect2(1279,137,29,29),"×","atlas_close")

static func draw_option(p:P,row:Dictionary,rect:Rect2,selected_id:String)->void:
	var active=str(row.recipe_id)==selected_id
	p.box(rect,Color("f9ddba",.83) if active else Color("fff1e1",.68),Color("cf9863",.9) if active else Color("c4a9df",.45),14)
	p.icon(row.target,Rect2(rect.position+Vector2(10,8),Vector2(74,62)))
	p.wrapped(row.name,rect.position+Vector2(97,24),440,18,A.INK,1)
	p.wrapped(row.summary,rect.position+Vector2(97,45),555,13,A.MUTED,1)
	var x=rect.position.x+97
	for input in row.inputs:
		var text=str(input.name)+" %d/%d"%[input.owned,input.need]
		p.text(text,Vector2(x,rect.position.y+70),13,A.GOOD if input.owned>=input.need else A.MISSING)
		x+=p.width(text,13)+19
	p.hit(Rect2(rect.position,Vector2(642,84)),"atlas_recipe:"+str(row.recipe_id))
	p.text("材料齐全" if row.complete else "材料未齐",rect.position+Vector2(670,23),13,A.GOOD if row.complete else A.MISSING)
	p.button(Rect2(rect.position+Vector2(650,42),Vector2(116,32)),"继续 %d"%row.next_count if row.next_count>0 else "查看成品","atlas_focus:"+str(row.target))

static func result_card(p:P,result:Dictionary,effect_page:int,change_page:int)->void:
	var rect=Rect2(924,124,392,708);var at=rect.position
	p.panel(rect);p.header(Rect2(at+Vector2(9,9),Vector2(374,44)))
	p.wrapped(result.name,at+Vector2(22,37),310,20,A.INK,1)
	p.icon(result.kind,Rect2(at+Vector2(36,62),Vector2(320,65)))
	var y=139.0
	for row in result.stats:
		p.stat(at+Vector2(22,y),348,row[0],row[1],row[2],A.COST if row[0]=="占格" and str(row[1]).contains("→") else A.INK);y+=32
	if not result.get("star_model",{}).is_empty():
		p.star_diagram(result.star_model,Rect2(at+Vector2(22,y),Vector2(348,90)));y+=96
	var changes=result.changes
	var effects_height=clampf(595-y-(126 if not changes.is_empty() else 0),126,350)
	p.box(Rect2(at+Vector2(20,y+7),Vector2(352,effects_height)),Color("fff0d9",.6),Color("e8bd88",.55),13)
	p.title("效果",at+Vector2(30,y+31))
	var pages=p.pages(result.effects,330,effects_height-65,15)
	var effect_index=clampi(effect_page,0,pages.size()-1)
	p.text_page(pages[effect_index],at+Vector2(30,y+43),15)
	pager(p,at+Vector2(252,y+effects_height-19),effect_index,pages.size(),"atlas_effects")
	y+=effects_height+17
	if not changes.is_empty():
		p.box(Rect2(at+Vector2(20,y),Vector2(352,139)),Color("f6e1d2",.55),Color("e8bd88",.55),13)
		p.title("效果变化",at+Vector2(30,y+25))
		var change_pages=p.pages(changes,330,77,14);var change_index=clampi(change_page,0,change_pages.size()-1)
		p.text_page(change_pages[change_index],at+Vector2(30,y+35),14)
		pager(p,at+Vector2(252,y+113),change_index,change_pages.size(),"atlas_changes")
	var offset=Vector2.ZERO
	for chip in result.chips:
		var length=p.width(chip[1],12)+32
		if offset.x+length>344:offset=Vector2(0,offset.y+26)
		p.box(Rect2(at+Vector2(24,649)+offset,Vector2(length,23)),Color("ecdef7"),Color("c5addf"),8)
		p.glyph(chip[0],Rect2(at+Vector2(28,651)+offset,Vector2(20,20)))
		p.text(chip[1],at+Vector2(51,665)+offset,12,A.INK);offset.x+=length+5

static func pager(p:P,at:Vector2,page:int,total:int,key:String)->void:
	if total<=1:return
	p.button(Rect2(at,Vector2(25,23)),"‹",key+"_prev",page>0)
	p.text("%d/%d"%[page+1,total],at+Vector2(31,16),12,A.MUTED)
	p.button(Rect2(at+Vector2(70,0),Vector2(25,23)),"›",key+"_next",page+1<total)

static func intent(action:String)->Dictionary:
	var prefixes={"atlas_recipe:":"select_recipe","atlas_focus:":"focus","atlas_direction:":"direction","atlas_node:":"select_node","atlas_material:":"material"}
	for prefix in prefixes:
		if action.begins_with(prefix):return {"type":prefixes[prefix],"value":action.trim_prefix(prefix)}
	if action=="atlas_history":return {"type":"back"}
	if action=="atlas_close":return {"type":"close"}
	if action=="atlas_details":return {"type":"details"}
	if action in ["atlas_root_prev","atlas_root_next"]:return {"type":"root","delta":1 if action.ends_with("next") else -1}
	for page in ["options","branches","stages","changes","effects"]:
		if action in ["atlas_"+page+"_prev","atlas_"+page+"_next"]:return {"type":"page","page":page,"delta":1 if action.ends_with("next") else -1}
	return {}
