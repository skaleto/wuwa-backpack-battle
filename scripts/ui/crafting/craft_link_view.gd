extends RefCounted
## Recipe tethers only: distant pairs have two tapered ends and a genuinely empty middle.
## Logical adjacency joins the beam; complete owned ingredients control gold.
static func palette(materials_complete:bool)->Dictionary:
	return {"core":Color("ffe28a"),"edge":Color("ffb62e")} if materials_complete else {"core":Color("a1fff4"),"edge":Color("21c9db")}
static func spans(a:Vector2,b:Vector2,joined:bool)->Array:
	if a.distance_to(b)<1:return []
	if joined:return [Vector2(0,1)]
	var reach=minf(.29,96.0/a.distance_to(b))
	return [Vector2(0,reach),Vector2(1-reach,1)]
static func point(a:Vector2,b:Vector2,t:float)->Vector2:
	return a.lerp(b,t)
# Half-width tapers from each item's center; distant ends taper independently.
static func half_width(t:float,span:Vector2,joined:bool)->float:
	if joined:return .8+2.2*pow(absf(2*t-1),2)
	var inward=inverse_lerp(span.x,span.y,t) if span.x==0 else inverse_lerp(span.y,span.x,t)
	return .1+2.9*pow(1-clampf(inward,0,1),1.4)
static func ribbon(a:Vector2,b:Vector2,span:Vector2,joined:bool,scale:float)->PackedVector2Array:
	var normal=Vector2(-(b-a).y,(b-a).x).normalized()
	var points=PackedVector2Array()
	for side in [1.0,-1.0]:
		for n in 25:
			var t=lerpf(span.x,span.y,float(n if side>0 else 24-n)/24)
			points.append(point(a,b,t)+normal*half_width(t,span,joined)*scale*side)
	return points
static func draw(canvas:CanvasItem,link:Dictionary,elapsed:float)->void:
	var a:Vector2=link.from;var b:Vector2=link.to
	var joined=bool(link.adjacent)
	var warm=bool(link.get("materials_complete",false))
	var colorset=palette(warm)
	var color:Color=colorset.core;var edge:Color=colorset.edge
	var emphasis=float(link.get("emphasis",1.0))
	var pulse=.86+.10*sin(elapsed*2.3)
	for span in spans(a,b,joined):
		# Nested variable-width ribbons replace a constant-width polyline.
		for layer in [{"scale":2.2,"color":edge,"alpha":.10},{"scale":1.25,"color":edge,"alpha":.78},{"scale":.60,"color":color,"alpha":.95}]:
			var colors=PackedColorArray()
			for side in [1,-1]:
				for n in 25:
					var progress=float(n if side>0 else 24-n)/24
					var fade=1.0
					if not joined:
						var inward=progress if span.x==0 else 1-progress
						fade=1-smoothstep(.45,1,inward)
					colors.append(Color(layer.color,fade*emphasis*pulse*float(layer.alpha)))
			canvas.draw_polygon(ribbon(a,b,span,joined,float(layer.scale)),colors)
	for endpoint in [a,b]:
		canvas.draw_circle(endpoint,5,Color(edge,.22*emphasis))
		canvas.draw_circle(endpoint,2.4,Color(color,.85*emphasis))
	if warm:
		var travel=fposmod(elapsed*.36,1.0)
		# Gold can be distant too: never draw travelling light in its hidden middle.
		if not spans(a,b,joined).any(func(span):return travel>=span.x and travel<=span.y):return
		var bead=point(a,b,travel)
		canvas.draw_circle(bead,3,Color(color,.12*emphasis))
		canvas.draw_circle(bead,1.4,Color("fff0ae",.86*emphasis))
