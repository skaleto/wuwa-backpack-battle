extends RefCounted
## Shared pinned/hover card. Only detached display values and drawing callbacks.
const A=preload("res://scripts/ui/apricot_ui.gd")

static func draw(p:Dictionary,m:Dictionary,rect:Rect2,interactive:bool,page:int=0)->int:
	var at=rect.position
	p.panel.call(rect);p.header.call(Rect2(at+Vector2(10,10),Vector2(rect.size.x-20,50)))
	p.wrapped.call(m.name,at+Vector2(23,40),280,20,A.INK,2)
	if interactive:p.button.call(Rect2(at+Vector2(rect.size.x-48,19),Vector2(31,31)),"×","details_back",true,false)
	p.detail_icon.call(m.item,Rect2(at+Vector2(35,67),Vector2(rect.size.x-70,64)))
	p.text.call(m.summary,at+Vector2((rect.size.x-p.width.call(m.summary,15))*.5,149),15,A.MUTED)
	var y=160.0
	if not m.bundle.is_empty():
		p.box.call(Rect2(at+Vector2(22,y),Vector2(rect.size.x-44,39)),Color("e4eddf"),Color("aac7b1",.6),12)
		p.icon.call(m.bundle.kind,Rect2(at+Vector2(29,y+3),Vector2(74,33)))
		p.text.call("同时获得 · "+m.bundle.name,at+Vector2(111,y+25),14,A.INK);y+=45
	if not m.partners.is_empty():
		p.box.call(Rect2(at+Vector2(22,y),Vector2(rect.size.x-44,42)),Color("e4eddf"),Color("aac7b1",.6),12)
		p.text.call("合成搭档",at+Vector2(33,y+27),15,A.GOOD)
		for n in mini(3,m.partners.size()):p.icon.call(m.partners[n],Rect2(at+Vector2(115+n*65,y+3),Vector2(60,36)))
		y+=48
	for row in m.stats:
		p.stat.call(at+Vector2(22,y),rect.size.x-44,row[0],row[1],row[2]);y+=32
	if not m.stars.is_empty():
		p.stars.call(m.stars,Rect2(at+Vector2(22,y),Vector2(rect.size.x-44,90)));y+=96
	if m.requirement:
		p.requirement.call(m.item.kind,Rect2(at+Vector2(22,y),Vector2(rect.size.x-44,44)));y+=50
	var effect_bottom=rect.size.y-112
	p.box.call(Rect2(at+Vector2(20,y+6),Vector2(rect.size.x-40,effect_bottom-y-6)),Color("fff0d9",.6),Color("e8bd88",.55),14)
	p.title.call("口袋效果" if m.is_bag else "效果",at+Vector2(30,y+31),"bag" if m.is_bag else "star")
	var pages:Array=p.pages.call(m.effects,rect.size.x-58,effect_bottom-y-70,16)
	page=clampi(page,0,pages.size()-1)
	p.text_page.call(pages[page],at+Vector2(29,y+45))
	if pages.size()>1:
		if interactive:p.button.call(Rect2(at+Vector2(rect.size.x-109,effect_bottom-28),Vector2(27,23)),"‹","detail_prev",page>0,false)
		p.text.call("%d/%d"%[page+1,pages.size()],at+Vector2(rect.size.x-76,effect_bottom-11),12,A.MUTED)
		if interactive:p.button.call(Rect2(at+Vector2(rect.size.x-45,effect_bottom-28),Vector2(27,23)),"›","detail_next",page+1<pages.size(),false)
	p.chips.call(m.item.kind,at+Vector2(23,effect_bottom+12),rect.size.x-46)
	if interactive:p.button.call(Rect2(at+Vector2(25,rect.size.y-51),Vector2(rect.size.x-50,34)),"合成配方" if m.has_recipe else "无合成配方","detail_recipes",m.has_recipe,true)
	return page
