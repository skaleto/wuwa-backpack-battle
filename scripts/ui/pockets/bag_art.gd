extends RefCounted
## Display-only art registration. Rectangles describe the usable face in source UV.
## Slots and bag ownership remain exclusively in Inventory.
const LEGACY={
	"satchel":Rect2(.10,.195,.81,.56),"pouch":Rect2(.135,.23,.75,.55),
	"strip":Rect2(.11,.23,.78,.41),"corner":Rect2(.14,.25,.76,.59),
	"travel":Rect2(.17,.25,.66,.43)
}
const PATCHWORK="patchwork_v129"
# Pixel rectangles of the intact generated art: outer hem and usable cloth.
# Runtime UVs crop transparent padding; generated PNG bytes are never repainted.
const PATCHES={
	"satchel":[Vector2(1536,1024),Rect2(102,141,1332,741),Rect2(166,215,1196,593)],
	"pouch":[Vector2(1254,1254),Rect2(123,139,1009,963),Rect2(194,211,864,814)],
	"strip":[Vector2(1024,1536),Rect2(263,39,498,1458),Rect2(319,110,387,1317)],
	"corner":[Vector2(1254,1254),Rect2(113,101,1036,1036),Rect2(180,166,901,904)],
	"travel":[Vector2(1536,1024),Rect2(79,133,1379,745),Rect2(149,210,1236,589)],
	"pocket_single":[Vector2(1254,1254),Rect2(124,138,1005,974),Rect2(260,262,730,708)],
	"pocket_double":[Vector2(1536,1024),Rect2(126,242,1285,490),Rect2(210,326,1110,327)],
	"pocket_long_l":[Vector2(1024,1536),Rect2(76,108,880,1286),Rect2(142,179,747,1147)],
	"pocket_long_j":[Vector2(1024,1536),Rect2(52,76,922,1345),Rect2(118,143,786,1206)]
}
static func patchwork(style:String)->bool:return style==PATCHWORK
static func style_for(style:String,kind:String)->String:
	return PATCHWORK if kind.begins_with("pocket_") else style
static func frame(style:String,kind:String)->Rect2:
	style=style_for(style,kind)
	if not patchwork(style):return Rect2(0,0,1,1)
	var entry=PATCHES[kind]
	return Rect2(entry[1].position/entry[0],entry[1].size/entry[0])
static func joint(style:String,kind:String)->Dictionary:
	style=style_for(style,kind)
	if not patchwork(style):return {}
	var points={"corner":[Vector2(.5,.5),Vector2(605,675)],"pocket_long_l":[Vector2(.5,2.0/3.0),Vector2(477,946)],"pocket_long_j":[Vector2(.5,2.0/3.0),Vector2(542,957)]}
	if not points.has(kind):return {}
	var entry=PATCHES[kind]
	return {"grid":points[kind][0],"uv":(points[kind][1]-entry[1].position)/entry[1].size}
const TRIALS={
	"storybook":{
		"satchel":Rect2(.105,.205,.80,.60),"pouch":Rect2(.125,.20,.76,.69),
		"strip":Rect2(.15,.075,.66,.88),"corner":Rect2(.13,.125,.78,.735),
		"travel":Rect2(.07,.18,.87,.69)
	},
	"flat":{
		"satchel":Rect2(.105,.23,.79,.63),"pouch":Rect2(.12,.23,.76,.67),
		"strip":Rect2(.27,.11,.46,.79),"corner":Rect2(.12,.13,.76,.72),
		"travel":Rect2(.11,.27,.78,.51)
	},
	"fold":{
		"satchel":Rect2(.11,.27,.78,.49),"pouch":Rect2(.18,.235,.64,.52),
		"strip":Rect2(.285,.16,.43,.70),"corner":Rect2(.14,.135,.74,.70),
		"travel":Rect2(.10,.195,.79,.575)
	}
}

static func trial(style:String)->bool:return patchwork(style) or TRIALS.has(style)

static func path(style:String,kind:String)->String:
	style=style_for(style,kind)
	if patchwork(style):return "res://assets/ui/bags-patchwork/body_"+kind+".png"
	if style=="storybook":return "res://assets/ui/bags-storybook/body_"+kind+".png"
	if trial(style):return "res://assets/ui/bags-trials/"+style+"/body_"+kind+".png"
	return "res://assets/ui/"+("bags-soft" if kind=="satchel" else "bags-shaped")+"/body_"+kind+".png"

static func opening(style:String,kind:String)->Rect2:
	style=style_for(style,kind)
	if patchwork(style):
		var entry=PATCHES[kind]
		return Rect2((entry[2].position-entry[1].position)/entry[1].size,entry[2].size/entry[1].size)
	return TRIALS[style][kind] if trial(style) else LEGACY[kind]

static func source_turns(style:String,kind:String)->int:
	style=style_for(style,kind)
	return 3 if kind=="strip" and not trial(style) else 0

static func corner_joint(style:String)->Vector2:
	# A single continuous L illustration; its inner bend aligns with the grid vertex.
	if style=="storybook":return Vector2(.55,.45)
	return Vector2(.43,.55) if style=="flat" else Vector2(.465,.565)

static func slot_tint(style:String,kind:String)->Color:
	style=style_for(style,kind)
	if patchwork(style):
		var shades={"satchel":"7651aa","pouch":"bf8d35","strip":"408f7b","corner":"597eaf","travel":"a3578e"}
		return Color(Color(shades.get(kind,"7651aa")),.29)
	if style!="storybook":return Color.TRANSPARENT
	var tones={"satchel":"64508c","pouch":"b2835e","strip":"448e8b","corner":"607cb2","travel":"a4729e"}
	return Color(Color(tones.get(kind,"64508c")),.27)
