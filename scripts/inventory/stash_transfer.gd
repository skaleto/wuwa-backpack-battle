extends RefCounted
## Display-only value inputs. No scene, inventory or run access.
const DURATION=.38
const SETTLE=.20
const GRID=preload("res://scripts/ui/pockets/frequency_grid.gd")
var flights:Array=[]
func clear()->void:flights.clear()
func enqueue(transfers:Array)->void:
	for transfer in transfers:
		flights=flights.filter(func(v):return v.piece.uid!=transfer.piece.uid)
		var flight=transfer.duplicate(true);flight.age=0.0;flights.append(flight)
func update(delta:float,stored_uids:Array,held_uid:String)->void:
	for flight in flights:flight.age+=delta
	flights=flights.filter(func(v):return v.age<DURATION+SETTLE and v.piece.uid!=held_uid and v.piece.uid in stored_uids)
func in_flight(uid:String)->bool:
	return flights.any(func(v):return v.piece.uid==uid and v.age<DURATION+SETTLE)
func draw_preview(canvas:CanvasItem,model:Dictionary,paint:Dictionary)->void:
	if model.has("rejected_rect"):
		canvas.draw_rect(model.rejected_rect,Color("df8177",.30));return
	for ghost in model.get("ghosts",[]):
		paint.basis.call(model.basis)
		GRID.footprint(canvas,ghost.at,ghost.cells,model.cell_size,Color("e8c279",.27),false)
		paint.basis.call(Transform2D.IDENTITY)
		if not ghost.has("slot"):continue
		var slot=StyleBoxFlat.new();slot.bg_color=Color("f2d49b",.19);slot.set_border_width_all(1);slot.set_corner_radius_all(6);slot.border_color=Color("fff0c3",.78)
		canvas.draw_style_box(slot,ghost.slot)
		paint.icon.call(ghost.kind,ghost.slot,ghost.rotation,.40)
# Ballistic visual pose with acceleration and a damped landing bounce.
# The target is supplied each frame so rapid stash reflow cannot duplicate items.
static func pose(from:Rect2,target:Rect2,age:float,direction:float=1.0)->Dictionary:
	var t=clampf(age/DURATION,0,1)
	var center:Vector2
	var angle:float
	var size=from.size.lerp(target.size,minf(1,t*1.8))
	if age<DURATION:
		var delta=target.get_center()-from.get_center()
		var gravity=1800.0
		var velocity_y=(delta.y-.5*gravity*DURATION*DURATION)/DURATION
		center=from.get_center()+Vector2(delta.x*t,velocity_y*age+.5*gravity*age*age)
		angle=direction*.16*sin(PI*t)
	else:
		var u=clampf((age-DURATION)/SETTLE,0,1)
		center=target.get_center()+Vector2(0,-9*4*u*(1-u))
		angle=direction*.07*sin(u*TAU)*(1-u)
	return {"rect":Rect2(center-size*.5,size),"angle":angle}
func draw(canvas:CanvasItem,targets:Dictionary,paint:Dictionary)->void:
	for flight in flights:
		var piece=flight.piece
		if not targets.has(piece.uid):continue
		var target:Rect2=targets[piece.uid]
		var direction=1.0 if posmod(str(piece.uid).hash(),2)==0 else -1.0
		var current=pose(flight.from,target,float(flight.age),direction)
		var center:Vector2=current.rect.get_center()
		paint.basis.call(Transform2D(current.angle,center)*Transform2D(0,-center))
		paint.icon.call(piece.kind,current.rect,int(piece.rotation),1.0)
		paint.basis.call(Transform2D.IDENTITY)
