extends RefCounted
## Surface identity only. No inventory, bonuses, input, RNG or save access.
const SKIN=preload("res://scripts/ui/visual_skin.gd")
const PROFILES={
	"satchel":{"surface":"bag_suede","name":"短绒","light":.12,"shade":.055},
	"pouch":{"surface":"bag_leather","name":"软皮","light":.15,"shade":.065},
	"strip":{"surface":"bag_satin","name":"缎布","light":.19,"shade":.055},
	"corner":{"surface":"bag_canvas","name":"帆布","light":.11,"shade":.045},
	"travel":{"surface":"bag_webbing","name":"织带","light":.12,"shade":.055}
}

static func profile(kind:String)->Dictionary:
	var value=PROFILES.get(kind,PROFILES.satchel).duplicate()
	value.path=SKIN.ui_path(value.surface)
	return value

static func coordinates(point:Vector2,bounds:Rect2,turns:int,pitch:float)->Vector2:
	# Invert the bag's normalized quarter turn. Shared vertices use the same
	# source coordinate; grain follows the whole bag, never restarts per cell.
	var local=point-bounds.position
	match posmod(turns,4):
		1:local=Vector2(local.y,bounds.size.x-local.x)
		2:local=bounds.size-local
		3:local=Vector2(bounds.size.y-local.y,local.x)
	return local/(maxf(pitch,.001)*8.0)

static func tint(kind:String,fill:Color,point:Vector2,bounds:Rect2,alpha:float)->Color:
	var p=PROFILES.get(kind,PROFILES.satchel)
	var across=(point-bounds.position)/bounds.size.max(Vector2.ONE)
	var depth=clampf(across.x*.22+across.y*.78,0,1)
	return Color(fill.lightened(p.light).lerp(fill.darkened(p.shade),depth),alpha)
