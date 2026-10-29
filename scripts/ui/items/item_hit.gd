extends RefCounted
## Uses the exact render projection, then a small screen-space alpha tolerance.
var images:Dictionary={}
func contains(g,item:Dictionary,at:Vector2,side:int)->bool:
	if not g._ensure_icon(item.kind):return false
	var path=g.SKIN.item_path(item.kind)
	if not images.has(path):
		if images.size()>=20:images.erase(images.keys()[0])
		images[path]=g.icons[item.kind].get_image()
	var image:Image=images[path]
	var fitted=g._projection_for(item.kind,int(item.rotation),g.CELL)
	var origin=g.BOARD if side==0 else g.ENEMY_BOARD
	var position=g._piece_position(item,origin,side)
	var pose=g._piece_pose(item,position,fitted,side)
	var transform=g._board_transform(side)*pose*Transform2D(0,position)*Transform2D(fitted.transform)
	var inverse=transform.affine_inverse()
	for delta in [Vector2.ZERO,Vector2(3,0),Vector2(-3,0),Vector2(0,3),Vector2(0,-3),Vector2(2,2),Vector2(-2,-2)]:
		var point=Vector2i(inverse*(at+delta))
		if point.x>=0 and point.y>=0 and point.x<image.get_width() and point.y<image.get_height() and image.get_pixelv(point).a>=.20:return true
	return false
