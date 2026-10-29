extends RefCounted
## Original-art landmarks are authored per portrait, in its original pixel space.
const J=preload("res://scripts/ui/portraits/jiyan_rig_definition.gd")
const IDS=["jiyan","yinlin","verina","encore","sanhua","camellya"]
const LENGTHS={"idle":3.6,"ready":.6,"attack":.52,"hit":.32,"intro":.9}
const PRIORITY={"idle":0,"ready":1,"attack":2,"hit":3,"intro":4}
const PROFILES={
	"yinlin":{"width":1071,"hip":Vector2(521,589),"chest":Vector2(529,405),"head":Vector2(547,303),"face":Rect2(471,203,151,124),"breath":4.6,"phase":.2,
		"hair_l":[Vector2(449,466),Vector2(417,589),Vector2(377,709),Vector2(361,989),Vector2(176,989),Vector2(186,772),Vector2(284,603)],
		"hair_r":[Vector2(617,285),Vector2(710,316),Vector2(748,485),Vector2(859,663),Vector2(859,1018),Vector2(680,1012),Vector2(727,755),Vector2(652,486)],
		"cloth_l":[Vector2(418,624),Vector2(477,680),Vector2(464,860),Vector2(494,1032),Vector2(426,1015),Vector2(394,812)],
		"cloth_r":[Vector2(581,639),Vector2(612,722),Vector2(652,964),Vector2(586,941),Vector2(563,811)],
		"legs":[Vector2(493,666),Vector2(558,647),Vector2(590,810),Vector2(567,1163),Vector2(580,1311),Vector2(501,1340),Vector2(488,1080),Vector2(470,818)],
		"prop":Rect2(687,653,72,102),"prop_pivot":Vector2(715,655)},
	"verina":{"width":1233,"hip":Vector2(565,651),"chest":Vector2(602,399),"head":Vector2(596,321),"face":Rect2(508,176,159,158),"breath":5.8,"phase":1.0,
		"hair_l":[Vector2(520,367),Vector2(520,449),Vector2(397,539),Vector2(314,578),Vector2(351,718),Vector2(256,799),Vector2(114,785),Vector2(94,482),Vector2(360,450)],
		"hair_r":[Vector2(690,329),Vector2(747,321),Vector2(815,452),Vector2(950,499),Vector2(1126,471),Vector2(1126,832),Vector2(919,884),Vector2(824,832),Vector2(834,689),Vector2(781,574)],
		"cloth_l":[Vector2(423,570),Vector2(456,667),Vector2(377,761),Vector2(321,810),Vector2(192,894),Vector2(152,882),Vector2(192,768)],
		"cloth_r":[Vector2(643,615),Vector2(703,658),Vector2(734,841),Vector2(900,1006),Vector2(840,1035),Vector2(690,957),Vector2(644,847)],
		"legs":[Vector2(399,685),Vector2(519,718),Vector2(639,739),Vector2(596,1037),Vector2(484,1337),Vector2(364,1372),Vector2(330,1323),Vector2(460,963),Vector2(495,793),Vector2(349,967),Vector2(290,1168),Vector2(175,1243),Vector2(64,1146),Vector2(177,976)],
		"prop":Rect2(752,650,123,120),"prop_pivot":Vector2(770,680)},
	"encore":{"width":955,"hip":Vector2(473,642),"chest":Vector2(487,486),"head":Vector2(486,436),"face":Rect2(422,340,127,108),"breath":4.8,"phase":2.1,
		"hair_l":[Vector2(427,416),Vector2(427,543),Vector2(375,656),Vector2(323,633),Vector2(296,574),Vector2(379,474)],
		"hair_r":[Vector2(552,369),Vector2(620,432),Vector2(694,523),Vector2(729,653),Vector2(655,670),Vector2(590,601),Vector2(564,468)],
		"cloth_l":[Vector2(391,626),Vector2(461,696),Vector2(419,777),Vector2(348,778),Vector2(299,728)],
		"cloth_r":[Vector2(506,660),Vector2(580,676),Vector2(624,772),Vector2(607,812),Vector2(526,774)],
		"legs":[Vector2(375,742),Vector2(529,754),Vector2(552,892),Vector2(591,1038),Vector2(562,1113),Vector2(518,1085),Vector2(471,956),Vector2(517,1138),Vector2(444,1170),Vector2(415,994),Vector2(402,869)],
		"prop":Rect2(234,357,181,205),"prop_pivot":Vector2(400,539),"prop2":Rect2(539,482,118,135),"prop2_pivot":Vector2(551,605)},
	"sanhua":{"width":1012,"hip":Vector2(525,563),"chest":Vector2(538,390),"head":Vector2(550,290),"face":Rect2(479,168,134,129),"breath":3.8,"phase":.7,
		"hair_l":[Vector2(479,206),Vector2(509,263),Vector2(491,341),Vector2(464,329),Vector2(446,247)],
		"hair_r":[Vector2(615,212),Vector2(658,216),Vector2(663,290),Vector2(621,320),Vector2(613,271)],
		"cloth_l":[Vector2(416,617),Vector2(477,629),Vector2(450,820),Vector2(461,989),Vector2(381,1011),Vector2(100,875),Vector2(159,777),Vector2(22,780),Vector2(91,709),Vector2(248,650)],
		"cloth_r":[Vector2(624,572),Vector2(662,646),Vector2(653,867),Vector2(628,1069),Vector2(590,1102),Vector2(610,847)],
		"legs":[Vector2(456,753),Vector2(618,772),Vector2(605,1025),Vector2(572,1352),Vector2(511,1382),Vector2(479,1248),Vector2(478,1036)],
		"prop":Rect2(693,209,98,181),"prop_pivot":Vector2(701,380),
		"rigid":[Vector2(129,516),Vector2(169,514),Vector2(859,1054),Vector2(878,1093),Vector2(831,1103),Vector2(147,571)]},
	"camellya":{"width":881,"hip":Vector2(475,530),"chest":Vector2(443,357),"head":Vector2(428,221),"face":Rect2(374,103,132,122),"breath":5.3,"phase":1.8,
		"hair_l":[Vector2(365,191),Vector2(372,247),Vector2(276,331),Vector2(121,491),Vector2(67,595),Vector2(171,690),Vector2(352,745),Vector2(386,884),Vector2(341,950),Vector2(294,927),Vector2(309,817),Vector2(90,748),Vector2(12,585),Vector2(18,489),Vector2(179,290)],
		"hair_r":[Vector2(541,317),Vector2(619,355),Vector2(735,443),Vector2(785,540),Vector2(735,620),Vector2(690,701),Vector2(814,692),Vector2(826,754),Vector2(731,811),Vector2(629,770),Vector2(598,688),Vector2(698,548),Vector2(657,455)],
		"cloth_l":[Vector2(342,506),Vector2(396,565),Vector2(384,687),Vector2(308,737),Vector2(230,707),Vector2(198,618)],
		"cloth_r":[Vector2(552,502),Vector2(639,526),Vector2(675,613),Vector2(645,657),Vector2(596,641)],
		"legs":[Vector2(414,609),Vector2(546,612),Vector2(586,803),Vector2(562,1119),Vector2(573,1380),Vector2(496,1384),Vector2(489,1088),Vector2(383,1289),Vector2(314,1289),Vector2(302,1164),Vector2(471,895)],
		"prop":Rect2(136,475,148,95),"prop_pivot":Vector2(268,510)}
}

static func source(id: String) -> String:return "res://art_sources/research/armory-v6/local/roles/"+id+"-portrait.webp"
static func size_for(id: String) -> Vector2:return J.SIZE if id=="jiyan" else Vector2(PROFILES[id].width,1400)
static func bones_for(id: String) -> Array:
	if id=="jiyan":return J.BONES
	var p=PROFILES[id]
	return [["anchor","",Vector2.ZERO],["pelvis","anchor",p.hip],["chest","pelvis",p.chest],["head","chest",p.head],
		["hair_left","head",p.head],["hair_left_tip","hair_left",Vector2(p.hip.x-140,p.hip.y+40)],
		["hair_right","head",p.head],["hair_right_tip","hair_right",Vector2(p.hip.x+170,p.hip.y+20)],
		["cloth_left","pelvis",p.hip],["cloth_left_tip","cloth_left",Vector2(p.hip.x-90,p.hip.y+180)],
		["cloth_right","pelvis",p.hip],["cloth_right_tip","cloth_right",Vector2(p.hip.x+110,p.hip.y+180)],
		["prop","chest",p.prop_pivot],["prop2","chest",p.get("prop2_pivot",p.prop_pivot)]]

static func rectangle_weight(at: Vector2,rect: Rect2) -> float:
	return J.region(at,[rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)],35)

static func weights_at(id: String,at: Vector2) -> Dictionary:
	if id=="jiyan":return J.weights_at(at)
	var p=PROFILES[id];var w={"anchor":1.0}
	J.layer(w,1-smoothstep(p.hip.y-45,p.hip.y+240,at.y),{"chest":1.0})
	for entry in [["hair_l","hair_left","hair_left_tip"],["hair_r","hair_right","hair_right_tip"],["cloth_l","cloth_left","cloth_left_tip"],["cloth_r","cloth_right","cloth_right_tip"]]:
		var is_hair=str(entry[0]).begins_with("hair")
		var start=float(p.head.y)+170 if is_hair else float(p.hip.y)+70
		J.layer(w,J.region(at,p[entry[0]],64),J.chain((at.y-start)/250.0,entry[1],entry[2]))
	J.layer(w,J.region(at,p.legs,32),{"anchor":1.0})
	if p.has("rigid"):J.layer(w,J.region(at,p.rigid,20),{"anchor":1.0})
	J.layer(w,rectangle_weight(at,p.prop),{"prop":1.0})
	if p.has("prop2"):J.layer(w,rectangle_weight(at,p.prop2),{"prop2":1.0})
	J.layer(w,rectangle_weight(at,p.face),{"head":1.0})
	var keys=w.keys().filter(func(k):return w[k]>.00001)
	keys.sort_custom(func(a,b):return w[a]>w[b])
	var result={};var total=0.0
	for key in keys.slice(0,4):total+=float(w[key])
	for key in keys.slice(0,4):result[key]=float(w[key])/total
	return result

static func pose(id: String,clip: String,time: float) -> Dictionary:
	if id=="jiyan":return J.pose(clip,time)
	var result={};var profile=PROFILES[id]
	for b in bones_for(id):result[b[0]]={"offset":Vector2.ZERO,"angle":0.0}
	if clip=="idle":
		var phase=time*TAU/3.6+float(profile.phase)
		result.chest.offset=Vector2(.22*sin(phase),-float(profile.breath)*.14*sin(phase))
		result.head.angle=.045*sin(phase-.25)
		for e in [["hair_left",1.0,.25],["hair_left_tip",1.45,.7],["hair_right",-.9,.6],["hair_right_tip",-1.35,1.1],["cloth_left",.8,.8],["cloth_left_tip",1.15,1.2],["cloth_right",-.75,.5],["cloth_right_tip",-1.1,1.0]]:
			result[e[0]].angle=float(e[1])*sin(phase-float(e[2]))
		# Small hair mass needs less torque; Encore's plush toys stay internally rigid.
		if id=="sanhua":
			for key in ["hair_left","hair_left_tip","hair_right","hair_right_tip"]:result[key].angle*=.45
		if id=="encore":result.prop.angle=.65*sin(phase-.4);result.prop2.angle=-.55*sin(phase-.75)
		return result
	var p=clampf(time/float(LENGTHS[clip]),0,1)
	var strength=J.pulse(p,[Vector2(0,0),Vector2(.15,-.12),Vector2(.38,1),Vector2(.70,.18),Vector2(1,0)])
	if clip=="hit":
		var recoil=J.pulse(p,[Vector2(0,0),Vector2(.2,1),Vector2(.55,.35),Vector2(1,0)])
		result.anchor.offset=Vector2(-18*recoil,0)
		return result
	result.anchor.offset=Vector2(14*strength,0) if clip=="attack" else Vector2(0,-4*sin(p*PI))
	result.head.angle=-.55*strength
	for key in ["hair_left_tip","hair_right_tip","cloth_left_tip","cloth_right_tip"]:result[key].angle=.8*strength
	return result
