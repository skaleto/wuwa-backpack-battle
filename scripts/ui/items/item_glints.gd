extends RefCounted
## Deterministic display-time particles rooted in original painted silhouettes.
## Precomputed alpha anchors avoid runtime texture readbacks or pixel scanning.
const C=preload('res://scripts/data/catalog.gd')
const SKIN=preload('res://scripts/ui/visual_skin.gd')
const VFX=preload('res://scripts/ui/battle/vfx_sprites.gd')
const GOLD_PARTICLES=7
const RED_PARTICLES=11
static var anchors:Dictionary=JSON.parse_string(FileAccess.get_file_as_string('res://assets/ui/stars/glint-anchors.json'))
static func particles(kind:String,size:Vector2,time:float,clip_uv:Array=[])->Array:
	if time<0 or C.is_tag(kind,'bag') or not anchors.has(kind):return []
	var tier=int(C.items.get(kind,{}).get('craft_tier',C.items.get(kind,{}).get('rarity',1)))
	if tier<4:return []
	var entry=anchors[kind]
	if SKIN.item_path(kind).trim_prefix('res://')!=entry.path or Vector2(entry.size[0],entry.size[1])!=size:return []
	var result=[];var points=entry.points
	if points.is_empty():return result
	var extent=maxf(size.x,size.y)
	for index in (GOLD_PARTICLES if tier==4 else RED_PARTICLES):
		var phase=time/(1.3 if tier==4 else 1.05)+index*.173+float(kind.hash()&255)/255.0
		var t=fposmod(phase,1.0)
		var opacity=smoothstep(0,.07,t)*(1-smoothstep(.67,.98,t))
		if opacity<.01:continue
		var pick=posmod(int(floor(phase))*17+index*11+(kind.hash()&127),points.size())
		var point=points[pick];var uv=Vector2(point[0],point[1]);var normal=Vector2(point[2],point[3])
		if not clip_uv.is_empty() and not clip_uv.any(func(poly):return Geometry2D.is_point_in_polygon(uv,poly)):continue
		var start=uv*size
		var drift=normal*(.006+.029*t)+Vector2(.007*sin(t*PI+index),-.018*t*t)
		var position=start+drift*extent
		var trail=PackedVector2Array()
		if index%3==0:
			trail=PackedVector2Array([start+drift*extent*.25,start+drift*extent*.63,position])
		var color=Color(point[4],point[5],point[6]).lerp(Color('fff5d3' if tier==4 else 'fff1f3'),.63)
		result.append({'anchor':start,'position':position,'trail':trail,'size':extent*(.042 if index%2 else .070)*(1-.32*t),'alpha':opacity*.96,'color':color,'angle':t*.9+index,'sprite':'spark_04' if index%3==0 else 'light_02' if index%2 else 'star_04'})
	return result
static func draw(canvas:CanvasItem,kind:String,size:Vector2,time:float,alpha:float=1,clip_uv:Array=[])->void:
	for p in particles(kind,size,time,clip_uv):
		# Soft source bloom and short taper follow the painted edge, never a box.
		if not p.trail.is_empty():
			canvas.draw_polyline(p.trail,Color(p.color,p.alpha*alpha*.28),maxf(1,p.size*.21),true)
			canvas.draw_polyline(p.trail,Color('fff9e6',p.alpha*alpha*.80),maxf(.6,p.size*.055),true)
		if p.sprite=='star_04':VFX.draw(canvas,'light_03',p.position,Vector2.ONE*p.size*1.75,Color(p.color,p.alpha*alpha*.27))
		VFX.draw(canvas,p.sprite,p.position,Vector2.ONE*p.size,Color(p.color,p.alpha*alpha),p.angle)
