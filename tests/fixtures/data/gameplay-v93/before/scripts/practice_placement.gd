extends RefCounted
## A local geometry cache for one arrangement pass. No gameplay state persists.
const C=preload("res://scripts/data/catalog.gd")

static func arrange(inv,run:Dictionary)->void:
	var covered:Dictionary={}
	for cell in inv.coverage(run.bags):covered[cell]=true
	var geometry:Dictionary={}
	for item in run.items:
		geometry[item.uid]={"cells":inv.occupied(item),"stars":inv.stars(item)}
	var eligible:Dictionary={}
	for source in run.items:
		for target in run.items:eligible[source.uid+":"+target.uid]=inv.star_eligible(source,target)
	var current=score(run.items,geometry,eligible)
	for item in run.items.duplicate(true):
		var blocked:Dictionary={}
		for other in run.items:
			if other.uid!=item.uid:
				for cell in geometry[other.uid].cells:blocked[cell]=true
		var best=item.duplicate(true);var best_score=current
		var original=geometry[item.uid]
		var best_geometry=original
		for rotation in 4:
			var rotated=item.duplicate(true);rotated.merge({"x":0,"y":0,"rotation":rotation},true)
			var cells=inv.cells(rotated);var stars=inv.stars(rotated)
			for y in inv.HEIGHT:
				for x in inv.WIDTH:
					var offset=Vector2i(x,y);var occupied:Array=[];var valid=true
					for cell in cells:
						var placed=cell+offset
						if not inv.in_bounds(placed) or not covered.has(placed) or blocked.has(placed):valid=false;break
						occupied.append(placed)
					if not valid or occupied.is_empty():continue
					var points=stars.map(func(cell):return cell+offset)
					geometry[item.uid]={"cells":occupied,"stars":points}
					var candidate_score=score(run.items,geometry,eligible)
					if candidate_score>best_score:
						best=item.duplicate(true);best.merge({"x":x,"y":y,"rotation":rotation},true)
						best_score=candidate_score;best_geometry=geometry[item.uid]
		geometry[item.uid]=best_geometry
		if best_score>current:
			if inv.place(run,best):current=best_score

static func score(items:Array,geometry:Dictionary,eligible:Dictionary)->int:
	var total=0
	for source in items:
		var points=geometry[source.uid].stars
		if points.is_empty():continue
		for item in items:
			if not eligible.get(source.uid+":"+item.uid,false):continue
			for cell in geometry[item.uid].cells:
				if cell in points:total+=1;break
	return total
