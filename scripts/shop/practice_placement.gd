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
		# Moving one item cannot change any pair between two other items.
		# Reuse that fixed score while preserving candidate order and strict ties.
		var fixed_score=current-touching_score(item.uid,run.items,geometry,eligible)
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
					var candidate_score=fixed_score+touching_score(item.uid,run.items,geometry,eligible)
					if candidate_score>best_score:
						best=item.duplicate(true);best.merge({"x":x,"y":y,"rotation":rotation},true)
						best_score=candidate_score;best_geometry=geometry[item.uid]
		geometry[item.uid]=best_geometry
		if best_score>current:
			if inv.place(run,best):current=best_score

static func score(items:Array,geometry:Dictionary,eligible:Dictionary)->int:
	var total=0
	for source in items:
		for item in items:
			total+=pair_score(source.uid,item.uid,geometry,eligible)
	return total

static func touching_score(uid:String,items:Array,geometry:Dictionary,eligible:Dictionary)->int:
	var total=0
	for item in items:
		total+=pair_score(uid,item.uid,geometry,eligible)
		if item.uid!=uid:total+=pair_score(item.uid,uid,geometry,eligible)
	return total

static func pair_score(source:String,target:String,geometry:Dictionary,eligible:Dictionary)->int:
	if not eligible.get(source+":"+target,false):return 0
	var points=geometry[source].stars
	if points.is_empty():return 0
	for cell in geometry[target].cells:
		if cell in points:return 1
	return 0
