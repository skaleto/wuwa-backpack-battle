extends RefCounted
## Coverage feedback for the live terminal regions.
const RULES=preload("res://scripts/inventory/pocket_profiles_v129.gd")

static func benefit(canvas: CanvasItem,origin: Vector2,cells: Array,pitch: float,kind: String,alpha: float=1.0) -> void:
	var c: Color=RULES.profile(kind).color
	for cell in cells:
		var rect=Rect2(origin+Vector2(cell)*pitch+Vector2.ONE*5,pitch*Vector2.ONE-Vector2.ONE*10)
		canvas.draw_rect(rect,Color(c,.09*alpha))
		var y=rect.end.y-1
		canvas.draw_line(Vector2(rect.position.x+4,y),Vector2(rect.end.x-4,y),Color(c,.78*alpha),1.5,true)
