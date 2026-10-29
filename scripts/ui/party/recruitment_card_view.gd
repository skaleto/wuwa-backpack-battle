extends Node2D
## Paints one immutable invitation into a small viewport. No gameplay access.
const ART=preload("res://scripts/ui/party/recruitment_art.gd")
const INK=Color("493367")
var model:Dictionary={}
var font:Font
var body_font:Font
var selected=false
var reward_kind=""
const SIZE=Vector2(384,654)
const NAME=Rect2(137,273,193,34)
const ABILITY=Rect2(137,307,193,27)
const BASE=Rect2(43,360,298,73)
const BASE_BONDED=Rect2(43,361,298,55)
const BOND_TITLE=Rect2(45,424,294,28)
const BOND_TEXT=Rect2(49,454,286,52)
const TRADEOFF=Rect2(42,436,300,44)
func show_card(value:Dictionary,title_font:Font,text_font:Font)->void:
	model=value.duplicate(true);font=title_font;body_font=text_font;queue_redraw()
func _draw()->void:
	if model.is_empty() or font==null:return
	var accent=ART.color(model.get("icon_id",model.ability_id))
	draw_texture_rect_region(ART.texture("invitation"),Rect2(0,22,384,632),Rect2(0,70,1006,1456))
	# The portrait is an independent layer above the card's portrait field.
	var portrait=model.get("portrait")
	if portrait:
		preload("res://scripts/ui/portraits/portrait_framing.gd").draw(self,portrait,Rect2(33,2,318,276),model.head_source)
	ART.emblem(self,model.get("icon_id",model.ability_id),Rect2(35,264,96,96))
	ART.text(self,font,model.name,NAME,24,INK)
	ART.text(self,font,model.ability_name,ABILITY,18,accent.darkened(.25))
	var bonded=not str(model.get("bond_name","")).is_empty()
	var short_text=str(model.get("display_base",model.get("base_text","")))
	ART.text(self,body_font,short_text,BASE if not bonded else BASE_BONDED,21 if not bonded else 18,INK)
	if bonded:
		ART.rounded(self,Rect2(37,418,310,94),Color(accent,.13),Color(accent,.37),16)
		ART.text(self,font,"三人 · "+str(model.bond_name),BOND_TITLE,17,accent.darkened(.3))
		ART.text(self,body_font,str(model.get("display_bond",model.bond_text)),BOND_TEXT,14,INK)
	else:
		ART.text(self,body_font,str(model.get("display_tradeoff","")),TRADEOFF,15,Color("85708e"))
		ART.text(self,body_font,"特色物品",Rect2(44,483,298,22),14,Color("87729b"))
	var rewards:Array=model.get("reward_choices",[])
	var list:Array=model.get("supply_icons",[])
	if not rewards.is_empty():list=model.get("reward_icons",[])
	if model.get("gold_fallback",false):
		ART.text(self,font,"入队获得 3 金币",Rect2(55,565,274,37),22,Color("a77735"))
	elif not rewards.is_empty():
		ART.text(self,body_font,"入队礼 · 选一件",Rect2(54,517,276,22),14,Color("806587"))
		for n in list.size():
			var rect=Rect2(52,543+n*29,280,27)
			ART.rounded(self,rect,Color("fff0be") if list[n].kind==reward_kind else Color("e2d4f1"),Color("d4af64") if list[n].kind==reward_kind else Color("c2add9"),8)
			ART.fit(self,list[n].texture,Rect2(rect.position+Vector2(7,2),Vector2(92,23)),list[n].source)
			ART.text(self,body_font,list[n].name,Rect2(rect.position+Vector2(108,1),Vector2(162,26)),13,INK,false)
	else:
		for n in mini(list.size(),3):
			var width=272.0/maxi(1,list.size());var rect=Rect2(56+n*width,547,width-8,61)
			ART.fit(self,list[n].texture,rect,list[n].source)
	if selected:ART.decor(self,"check",Rect2(323,22,55,55))

func reward_at(point:Vector2)->String:
	var choices:Array=model.get("reward_icons",[])
	for n in choices.size():
		if Rect2(52,543+n*29,280,27).has_point(point):return str(choices[n].kind)
	return ""
