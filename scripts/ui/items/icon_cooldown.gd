extends RefCounted
## Clip a second, shaded drawing of the original texture. Its alpha stays intact:
## no rectangle can appear outside the weapon silhouette or across empty cells.
const PROJECTION=preload("res://scripts/ui/items/icon_projection.gd")

static func slice(points: PackedVector2Array,uv: PackedVector2Array,progress: float,sweep: Rect2=Rect2()) -> Dictionary:
	var result={"polygon":PackedVector2Array(),"uv":PackedVector2Array()}
	if points.size()<3 or progress>=1.0:return result
	if progress<=0.0:return {"polygon":points,"uv":uv}
	if not sweep.has_area():
		var low=points[0];var high=points[0]
		for p in points:low=low.min(p);high=high.max(p)
		sweep=Rect2(low,high-low)
	var cutoff=sweep.end.y-sweep.size.y*clampf(progress,0,1)
	for n in range(points.size()):
		var previous=posmod(n-1,points.size())
		var a=points[previous];var b=points[n]
		var inside_a=a.y<=cutoff;var inside_b=b.y<=cutoff
		if inside_a!=inside_b:
			var weight=(cutoff-a.y)/(b.y-a.y)
			result.polygon.append(a.lerp(b,weight))
			result.uv.append(uv[previous].lerp(uv[n],weight))
		if inside_b:result.polygon.append(b);result.uv.append(uv[n])
	return result

static func draw(canvas: CanvasItem,texture: Texture2D,cells: Array,origin: Vector2,pitch: float,fitted: Dictionary,pose: Transform2D,full_art: bool,progress: float,alpha: float) -> void:
	if progress>=1 or alpha<=0:return
	var size=texture.get_size()
	var patches: Array=[]
	if full_art:
		var transform: Transform2D=fitted.transform
		patches.append({"polygon":transform*PackedVector2Array([Vector2.ZERO,Vector2(size.x,0),size,Vector2(0,size.y)]),"uv":PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN])})
	else:patches=PROJECTION._clip_patches(size,cells,pitch,fitted)
	var bounds: Rect2=fitted.get("bounds",Rect2(Vector2.ZERO,Vector2.ONE*pitch))
	var low=Vector2(INF,INF);var high=Vector2(-INF,-INF)
	for p in [bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)]:
		var turned=pose*(origin+p);low=low.min(turned);high=high.max(turned)
	for patch in patches:
		var points=PackedVector2Array()
		for p in patch.polygon:points.append(pose*(origin+p))
		var clipped=slice(points,patch.uv,progress,Rect2(low,high-low))
		if clipped.polygon.size()>=3:
			canvas.draw_polygon(clipped.polygon,PackedColorArray([Color(.12,.19,.22,alpha*.70)]),clipped.uv,texture)
