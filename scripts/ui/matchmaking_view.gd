extends RefCounted
## Presentation only. No progress claims, matching state or network ownership.
const A=preload('res://scripts/ui/party/recruitment_art.gd')
const Q=preload('res://scripts/ui/visual_skin.gd')
const F=preload('res://scripts/ui/portraits/portrait_framing.gd')
const W=preload('res://scripts/ui/workbench_art.gd')
static func draw(c:CanvasItem,font:Font,role:String,clock:float)->void:
	c.draw_rect(Rect2(0,0,1440,960),Color('292348',.68))
	var frame=Rect2(475,265,490,405)
	A.rounded(c,frame.grow(5),Color('30254f',.25),Color.TRANSPARENT,32)
	A.rounded(c,frame,Color('faf0dc'),Color('baa0d5'),28,3)
	W.face(c,Rect2(555,285,330,66),'label')
	A.text(c,font,'寻找对手',Rect2(580,294,280,44),30,W.INK)
	for n in 2:
		var pos=Vector2(592+n*256,457)
		A.rounded(c,Rect2(pos-Vector2(69,86),Vector2(138,172)),Color('e6dbf1'),Color('c4a9d9'),20,2)
		if n==0:
			var path=Q.portrait_path(role)
			F.draw(c,Q.texture(path),Rect2(pos-Vector2(64,83),Vector2(128,164)),F.head_source(Q.bounds(path)))
		else:
			A.text(c,font,'?',Rect2(pos-Vector2(50,72),Vector2(100,138)),78,Color('9d85bb'))
	for n in 3:
		var t=clock*4-n*.7
		c.draw_circle(Vector2(698+n*22,453-4*sin(t)),4.5,Color('b49bcf',.5+.4*(sin(t)*.5+.5)))
	A.text(c,font,'在线对战',Rect2(570,576,300,42),21,Color('877094'))
