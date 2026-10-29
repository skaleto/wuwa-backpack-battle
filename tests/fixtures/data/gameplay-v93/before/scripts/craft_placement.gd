extends RefCounted
## Consumed cells are freed; other items are never displaced. Storage is the fallback.
## This policy does not decide whether a recipe exists.
static func nearest_fit(piece:Dictionary,items:Array,bags:Array,space)->Dictionary:
	var origin=Vector2(piece.x,piece.y);var best={};var best_score=INF
	for turn in 4:
		var rotation=posmod(int(piece.rotation)+turn,4)
		for y in space.HEIGHT:
			for x in space.WIDTH:
				var score=origin.distance_squared_to(Vector2(x,y))*4+turn*.1
				if score>=best_score:continue
				var candidate=piece.duplicate(true);candidate.merge({"x":x,"y":y,"rotation":rotation},true)
				if space.can_place(candidate,items,bags):best=candidate;best_score=score
	return best
static func footprint(piece:Dictionary,items:Array,bags:Array,space)->Dictionary:
	var result={"blocked":[],"valid":[]};var taken:Array=[]
	for item in items:taken.append_array(space.occupied(item))
	var cover=space.coverage(bags)
	for cell in space.occupied(piece):
		if not space.in_bounds(cell) or cell not in cover or cell in taken:result.blocked.append(cell)
		else:result.valid.append(cell)
	return result

# Automatic output placement is board-first, then one real storage slot.
# Explicit player-selected board positions remain strict and never relocate.
static func automatic(piece:Dictionary,items:Array,bags:Array,stash_count:int,stash_limit:int,space)->Dictionary:
	if space.can_place(piece,items,bags):return {"ok":true,"output":piece,"destination":"board"}
	var fitted=nearest_fit(piece,items,bags,space)
	if not fitted.is_empty():return {"ok":true,"output":fitted,"destination":"board"}
	if stash_count>=stash_limit:return {"ok":false,"error":"stash_full"}
	var stored=piece.duplicate(true);stored.x=0;stored.y=0
	return {"ok":true,"output":stored,"destination":"stash","stash_index":stash_count}
