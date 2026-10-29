extends RefCounted
## Values only: the controller supplies real shape, rotated stars and match states.
const STAR=preload("res://scripts/ui/items/chibi_effect_star.gd")
static func layout(model:Dictionary,rect:Rect2)->Dictionary:
	var low=Vector2i(100,100);var high=Vector2i(-100,-100)
	var cells=model.cells+model.markers.map(func(m):return m.cell)
	if cells.is_empty():return {"cells":[],"stars":[]}
	for cell in cells:
		low=Vector2i(mini(low.x,cell.x),mini(low.y,cell.y));high=Vector2i(maxi(high.x,cell.x),maxi(high.y,cell.y))
	var dimensions=Vector2(high-low+Vector2i.ONE)
	var pitch=minf(23,minf(rect.size.x/dimensions.x,rect.size.y/dimensions.y))
	var origin=rect.get_center()-dimensions*pitch*.5
	var result={"cells":[],"stars":[]}
	for cell in model.cells:result.cells.append(Rect2(origin+Vector2(cell-low)*pitch+Vector2.ONE,Vector2.ONE*(pitch-2)))
	for marker in model.markers:
		result.stars.append({"center":origin+(Vector2(marker.cell-low)+Vector2.ONE*.5)*pitch,"radius":pitch*.38,"state":marker.state})
	return result
static func draw(canvas:CanvasItem,model:Dictionary,rect:Rect2,age:float,alpha:float)->void:
	var positions=layout(model,rect)
	for cell in positions.cells:
		var style=StyleBoxFlat.new();style.bg_color=Color("c8b0e3",alpha)
		style.border_color=Color("fff0f6",alpha*.8);style.set_border_width_all(1);style.set_corner_radius_all(4)
		canvas.draw_style_box(style,cell)
	for index in positions.stars.size():
		var star=positions.stars[index]
		STAR.draw(canvas,star.center,star.radius,star.state,age,alpha,float(model.get("click_age",-1.0)),index)
