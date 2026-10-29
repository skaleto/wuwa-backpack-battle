extends RefCounted
const T=preload("res://scripts/ui/pockets/terminal_grid.gd")

static func bag(kind:String,uid:String,turns:int=0)->Dictionary:
	return {"kind":kind,"uid":uid,"x":0,"y":0,"rotation":turns}

static func touching(a:Dictionary,b:Dictionary,axis:Vector2i,stagger:bool=false)->Array:
	var first=a.duplicate(true);var second=b.duplicate(true)
	var ca=T.inventory.occupied(first);var cb=T.inventory.occupied(second)
	var hi=Vector2i.ONE;var other=Vector2i.ONE
	for c in ca:hi=hi.max(c+Vector2i.ONE)
	for c in cb:other=other.max(c+Vector2i.ONE)
	var limit=hi.y if axis==Vector2i.RIGHT else hi.x
	var length=other.y if axis==Vector2i.RIGHT else other.x
	var shifts=[]
	for shift in range(-length+1,limit):shifts.append(shift)
	shifts.sort_custom(func(x,y):return absi(x)<absi(y) if absi(x)!=absi(y) else x>y)
	var possible=[]
	for shift in shifts:
		var offset=Vector2i(hi.x,shift) if axis==Vector2i.RIGHT else Vector2i(shift,hi.y)
		if cb.any(func(cell):return cell+offset-axis in ca):possible.append(offset)
	assert(not possible.is_empty())
	var move=possible[mini(1,possible.size()-1) if stagger else 0]
	second.x=move.x;second.y=move.y
	# Move the whole example to a positive origin without changing contact.
	var low=Vector2i.ZERO.min(move)
	first.x-=low.x;first.y-=low.y;second.x-=low.x;second.y-=low.y
	return [first,second]
