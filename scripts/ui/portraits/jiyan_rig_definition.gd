extends RefCounted
## Source-space rig authoring data; no image processing or replacement artwork.
const SOURCE="res://art_sources/research/armory-v6/local/roles/jiyan-portrait.webp"
const SIZE=Vector2(1400,1374)
const STEP=24.0
const BONES=[
	["anchor","",Vector2.ZERO],
	["pelvis","anchor",Vector2(660,600)],
	["chest","pelvis",Vector2(670,445)],
	["head","chest",Vector2(690,233)],
	["hair_root","head",Vector2(755,229)],
	["hair_mid","hair_root",Vector2(857,360)],
	["hair_tip","hair_mid",Vector2(975,516)],
	["arm","chest",Vector2(804,381)],
	["forearm","arm",Vector2(807,510)],
	["sleeve","chest",Vector2(820,448)],
	["sleeve_tip","sleeve",Vector2(977,516)],
	["coat_left","pelvis",Vector2(565,615)],
	["coat_left_tip","coat_left",Vector2(436,870)],
	["coat_right","pelvis",Vector2(708,658)],
	["coat_right_tip","coat_right",Vector2(956,812)],
	["ribbon","pelvis",Vector2(810,649)],
	["wind_left","anchor",Vector2(416,714)],
	["wind_tip","wind_left",Vector2(234,877)],
	["wind_right","anchor",Vector2(1012,267)]
]
const LENGTHS={"idle":3.6,"ready":.6,"attack":.52,"hit":.32,"intro":.9}
const PRIORITY={"idle":0,"ready":1,"attack":2,"hit":3,"intro":4}
const HAIR=[Vector2(738,168),Vector2(856,213),Vector2(971,307),Vector2(1110,474),Vector2(1122,641),Vector2(1032,670),Vector2(924,549),Vector2(839,392),Vector2(775,291)]
const SLEEVE=[Vector2(807,438),Vector2(933,446),Vector2(1160,495),Vector2(1137,577),Vector2(920,618),Vector2(850,543)]
const ARM=[Vector2(818,461),Vector2(865,478),Vector2(835,577),Vector2(810,650),Vector2(736,640),Vector2(746,579),Vector2(790,560)]
const LEFT_COAT=[Vector2(555,530),Vector2(580,650),Vector2(537,797),Vector2(516,1026),Vector2(447,1108),Vector2(314,1120),Vector2(352,908),Vector2(397,778)]
const RIGHT_COAT=[Vector2(655,579),Vector2(800,698),Vector2(1014,747),Vector2(1229,797),Vector2(1240,954),Vector2(1044,1043),Vector2(865,976),Vector2(715,837)]
const LEGS=[Vector2(596,654),Vector2(693,654),Vector2(739,745),Vector2(757,904),Vector2(807,1110),Vector2(814,1294),Vector2(682,1294),Vector2(655,1070),Vector2(638,948),Vector2(540,883),Vector2(519,786)]

static func band(value: float,a: float,b: float,c: float,d: float) -> float:
	return smoothstep(a,b,value)*(1-smoothstep(c,d,value))

static func region(p: Vector2,points: Array,feather: float=48) -> float:
	if Geometry2D.is_point_in_polygon(p,PackedVector2Array(points)):return 1.0
	var distance=INF
	for n in range(points.size()):
		distance=minf(distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,points[n],points[(n+1)%points.size()])))
	return 1-smoothstep(0,feather,distance)

static func layer(weights: Dictionary,mask: float,added: Dictionary) -> void:
	if mask<=0:return
	for key in weights:weights[key]*=1-mask
	for key in added:weights[key]=float(weights.get(key,0))+mask*float(added[key])

static func chain(value: float,first: String,second: String) -> Dictionary:
	var blend=clampf(value,0,1)
	return {first:1-blend,second:blend}

static func weights_at(p: Vector2) -> Dictionary:
	var weights={"anchor":1.0}
	var wind=band(p.x,20,80,410,540)*band(p.y,550,650,1050,1140)
	layer(weights,wind,chain((p.y-740)/180,"wind_left","wind_tip"))
	layer(weights,band(p.x,935,1000,1280,1330)*band(p.y,90,160,400,470),{"wind_right":1.0})
	var body=band(p.x,478,567,823,885)*(1-smoothstep(590,940,p.y))*smoothstep(95,135,p.y)
	layer(weights,body,{"chest":1.0})
	var hair=region(p,HAIR,56)
	if p.y<400:layer(weights,hair,chain((p.y-240)/160,"hair_root","hair_mid"))
	else:layer(weights,hair,chain((p.y-400)/190,"hair_mid","hair_tip"))
	layer(weights,region(p,LEFT_COAT),chain((p.y-685)/335,"coat_left","coat_left_tip"))
	layer(weights,region(p,RIGHT_COAT),chain((p.x-790)/325,"coat_right","coat_right_tip"))
	layer(weights,band(p.x,760,820,1050,1115)*band(p.y,580,625,675,710),{"ribbon":1.0})
	layer(weights,region(p,SLEEVE,72),chain((p.x-845)/220,"sleeve","sleeve_tip"))
	layer(weights,region(p,ARM,32),{"forearm":1.0})
	# Keep the waist attached to the torso rather than the nearby coat tails.
	var waist=band(p.x,572,610,715,751)*band(p.y,455,490,620,660)
	layer(weights,waist,{"chest":1.0})
	# Legs are the fixed support of this portrait pose. Clothing around them can move.
	layer(weights,region(p,LEGS,18)*smoothstep(635,710,p.y),{"anchor":1.0})
	# Facial features all share one rigid transform; no squash or separate eye motion.
	var face=band(p.x,555,587,777,810)*band(p.y,65,96,282,324)
	layer(weights,face,{"head":1.0})
	var ranked=weights.keys().filter(func(k):return weights[k]>.00001)
	ranked.sort_custom(func(a,b):return weights[a]>weights[b])
	var result={};var total=0.0
	for key in ranked.slice(0,4):total+=float(weights[key])
	for key in ranked.slice(0,4):result[key]=float(weights[key])/total
	return result

static func pulse(t: float,points: Array) -> float:
	for n in range(1,points.size()):
		if t<=points[n].x:
			var p=smoothstep(points[n-1].x,points[n].x,t)
			return lerpf(points[n-1].y,points[n].y,p)
	return float(points[-1].y)

static func pose(clip: String,time: float) -> Dictionary:
	var result={}
	for bone in BONES:result[bone[0]]={"offset":Vector2.ZERO,"angle":0.0}
	if clip=="idle":
		var phase=time*TAU/3.6
		result.chest.offset=Vector2(.16*sin(phase),-.65*sin(phase))
		result.chest.angle=.017*sin(phase)
		result.head.angle=-.022*sin(phase)+.014*sin(phase-.35)
		for entry in [["hair_root",.65,.4],["hair_mid",.85,.75],["hair_tip",1.05,1.1],["sleeve",.65,.65],["sleeve_tip",1.0,1.0],["coat_left",.48,.65],["coat_left_tip",.85,1.0],["coat_right",.55,.4],["coat_right_tip",.95,.85],["ribbon",.8,1.2],["wind_left",.35,.8],["wind_tip",.6,1.2],["wind_right",.65,.7]]:
			result[entry[0]].angle=float(entry[1])*1.8*sin(phase-float(entry[2]))
		return result
	var p=clampf(time/float(LENGTHS[clip]),0,1)
	if clip=="hit":
		var recoil=pulse(p,[Vector2(0,0),Vector2(.2,1),Vector2(.55,.35),Vector2(1,0)])
		result.anchor.offset=Vector2(-18*recoil,0)
		return result
	var strength=pulse(p,[Vector2(0,0),Vector2(.14,-.18),Vector2(.35,1),Vector2(.65,.3),Vector2(1,0)])
	var follow=pulse(p,[Vector2(0,0),Vector2(.20,0),Vector2(.48,1),Vector2(.80,-.17),Vector2(1,0)])
	match clip:
		"ready":
			result.chest.offset=Vector2(0,-3.5*sin(p*PI))
			result.head.angle=-.7*sin(p*PI)
		"attack":
			result.anchor.offset=Vector2(14*strength,0)
			result.chest.angle=.45*strength
			result.chest.offset=Vector2(2*strength,-strength)
			result.head.angle=-.6*strength
			result.arm.angle=.5*strength
			result.forearm.angle=-.6*strength
		"intro":
			result.chest.angle=1.7*strength
			result.chest.offset=Vector2(5*strength,-5*strength)
			result.head.angle=-.8*strength
			result.wind_left.angle=-1.1*follow
			result.wind_tip.angle=-1.7*follow
			result.wind_right.angle=1.4*follow
			follow*=1.3
	for entry in [["hair_root",-.4],["hair_mid",-.8],["hair_tip",-1.1],["sleeve",.7],["sleeve_tip",1.4],["coat_left",-.5],["coat_left_tip",-1.0],["coat_right",.7],["coat_right_tip",1.1],["ribbon",.9]]:
		result[entry[0]].angle=float(entry[1])*follow
	return result
