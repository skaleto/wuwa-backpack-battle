extends RefCounted
## Exact 63-cell tiling, using only existing bag definitions.
static func full_bags(inv)->Array:
	var bags=[]
	for y in range(0,6,2):
		for x in range(0,9,3):
			var b=inv.make_piece("travel","cap%d-%d"%[x,y]);b.x=x;b.y=y;bags.append(b)
	for x in range(0,9,3):
		var b=inv.make_piece("strip","cap%d-6"%x);b.x=x;b.y=6;b.rotation=1;bags.append(b)
	return bags
