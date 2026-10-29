extends SceneTree
var checks=0
var failures=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:
	if not FileAccess.file_exists("res://scripts/ui/items/icon_cooldown.gd"):
		check(false,"cooldown must use icon alpha rather than a separate bar")
		quit(1);return
	var overlay=load("res://scripts/ui/items/icon_cooldown.gd")
	var quad=PackedVector2Array([Vector2(0,0),Vector2(100,0),Vector2(100,80),Vector2(0,80)])
	var uv=PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN])
	var full=overlay.slice(quad,uv,0.0)
	check(full.polygon==quad and full.uv==uv,"zero progress shades complete icon")
	check(overlay.slice(quad,uv,1.0).polygon.is_empty(),"ready icon has no dark overlay")
	for p in [.25,.5,.75]:
		var result=overlay.slice(quad,uv,p)
		check(result.polygon.size()==4,"horizontal sweep retains a valid quad")
		for i in range(result.polygon.size()):
			var point=result.polygon[i]
			check(point.y<=80*(1-p)+.001,"clear region grows upward from bottom")
			check((point/Vector2(100,80)).distance_to(result.uv[i])<.00001,"texture coordinates preserve icon alpha at sliced boundary")
	for angle in [PI*.5,PI,PI*1.5,.137]:
		var transform=Transform2D(angle,Vector2.ONE*1.7,0,Vector2(47,89))
		var turned=transform*quad
		var result=overlay.slice(turned,uv,.43)
		for i in range(result.polygon.size()):
			check(((transform.affine_inverse()*result.polygon[i])/Vector2(100,80)).distance_to(result.uv[i])<.00001,"rotated and swaying icons retain exact alpha UV")
	print("COOLDOWN_V18: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
