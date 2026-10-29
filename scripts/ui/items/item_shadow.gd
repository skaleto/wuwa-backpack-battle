extends RefCounted
## Native contact shadows: original texture pixels and resolution stay intact.
static func draw(canvas:CanvasItem,texture:Texture2D,transform:Transform2D,basis:Transform2D,display_size:Vector2,alpha:float=1.0,elevation:float=0.0) -> void:
	var unit=clampf(maxf(display_size.x,display_size.y)/160.0,.75,4.5)
	var offset=Vector2(1.3,2.3)*unit+Vector2(0,elevation)
	alpha*=1.0-clampf(elevation/40.0,0,.25)
	# A tight black contact silhouette gives depth; the small penumbra softens it.
	for n in 8:
		var delta=offset+Vector2.from_angle(n*TAU/8)*.65*unit
		canvas.draw_set_transform_matrix(basis*Transform2D(0,delta)*transform)
		canvas.draw_texture(texture,Vector2.ZERO,Color(0,0,0,alpha*.055))
	canvas.draw_set_transform_matrix(basis*Transform2D(0,offset)*transform)
	canvas.draw_texture(texture,Vector2.ZERO,Color(0,0,0,alpha*.78))
	canvas.draw_set_transform_matrix(basis)
