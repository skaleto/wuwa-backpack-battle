extends RefCounted
## One generated atlas, shared by type chips, star sentences and combat counters.
const SKIN=preload("res://scripts/ui/visual_skin.gd")
const ORDER=["charge","haste","shield","noise","frost","attack","healing","cleanse","weapon","echo","relic","provision","material","bag","star","break_shield","max_hp","stamina","counter","freeze"]
const LABELS={"charge":"充能","haste":"迅捷","shield":"护盾","noise":"光噪","frost":"霜渐","freeze":"冻结","attack":"攻击","healing":"治疗","cleanse":"净化","weapon":"武器","echo":"声骸","relic":"遗物","provision":"补给","material":"材料","bag":"口袋","star":"星位","break_shield":"削盾"}
const PATH="res://assets/ui/abilities/ability-icons.png"
# Authored atlas rows are not exactly uniform. Explicit padded source regions
# keep the bottom-row silhouettes whole without modifying generated PNG pixels.
const REGIONS=[
	Rect2(61,46,182,228),Rect2(312,42,219,228),Rect2(594,46,211,232),Rect2(868,57,223,217),Rect2(1154,44,209,235),
	Rect2(59,322,196,194),Rect2(307,333,224,197),Rect2(613,321,172,221),Rect2(860,317,244,226),Rect2(1159,307,221,243),
	Rect2(39,576,227,229),Rect2(303,599,238,206),Rect2(582,596,232,202),Rect2(852,580,254,230),Rect2(1146,585,225,224),
	Rect2(43,845,213,216),Rect2(306,859,229,197),Rect2(604,830,189,239),Rect2(865,838,217,229),Rect2(1146,838,221,226)
]
static func normalize(key:String)->String:
	return {"shielding":"shield","heal":"healing","damage":"attack","craft_material":"material"}.get(key,key)
static func supports(key:String)->bool:return normalize(key) in ORDER
static func draw(c:CanvasItem,key:String,rect:Rect2,alpha:float=1)->void:
	var index=ORDER.find(normalize(key))
	if index<0:return
	var texture=SKIN.texture(PATH)
	if texture==null:return
	var source:Rect2=REGIONS[index]
	var size=source.size*minf(rect.size.x/source.size.x,rect.size.y/source.size.y)
	c.draw_texture_rect_region(texture,Rect2(rect.get_center()-size*.5,size),source,Color(1,1,1,alpha))
static func label(key:String)->String:
	return {"max_hp":"生命上限","stamina":"体力","counter":"反击","freeze":"冻结"}.get(key,LABELS.get(normalize(key),key))
