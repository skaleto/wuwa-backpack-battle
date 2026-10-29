extends SceneTree
const T=preload("res://scripts/ui/pockets/terminal_grid.gd")
const F=preload("res://scripts/ui/pockets/bag_fine_seams.gd")
const FIX=preload("res://tests/fixtures/bag_trial_fixture_v109.gd")
const KINDS=["satchel","pouch","strip","corner","travel","pocket_single","pocket_double","pocket_long_l","pocket_long_j"]
var checks=0
var failures=0
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:
	var pixels=Image.new();pixels.load_png_from_buffer(FileAccess.get_file_as_bytes(F.TEXTURE))
	ck(pixels!=null and pixels.get_format()==Image.FORMAT_RGBA8,"unaltered generated RGBA cloth loaded")
	for a in KINDS:
		for b in KINDS:
			for turn in 4:
				var bags=T.form_bags(FIX.touching(FIX.bag(a,"a",turn),FIX.bag(b,"b",(turn+1)%4),Vector2i.RIGHT,turn%2==0))
				var before=bags.duplicate(true);var model=F.layout(bags,80);var owner={}
				for bag in bags:
					for cell in bag.cells:owner[cell]=bag.uid
				ck(model.faces.size()==owner.size(),"one face per owned cell")
				for face in model.faces:
					ck(face.uid==owner[face.cell],"ownership stays local")
					var at=(Vector2(face.cell)+Vector2.ONE*.5)*80
					ck(Geometry2D.is_point_in_polygon(at,face.polygon),"rounding never removes an occupied centre")
					for point in face.polygon:
						var uv=F.cloth_uv(point,80)
						ck(uv.x>=0 and uv.y>=0 and uv.x<1 and uv.y<1,"UV remains in original image")
				for rim in model.rims:
					ck(not owner.has(rim.cell+F.GRID.DIRECTIONS[rim.side]),"no thick rim on a shared edge")
				for seam in model.seams:ck(seam.negative!=seam.positive,"creases only divide different bags")
				var reversed=bags.duplicate(true);reversed.reverse()
				ck(F.layout(reversed,80).seams==model.seams,"joining independent of array order")
				ck(bags==before,"layout is read only")
	var four=T.form_bags([{"kind":"pocket_single","uid":"a","x":0,"y":0},{"kind":"pocket_single","uid":"b","x":1,"y":0},{"kind":"pocket_single","uid":"c","x":0,"y":1},{"kind":"pocket_single","uid":"d","x":1,"y":1}])
	ck(F.layout(four,80).seams.size()==4,"four-way join has four creases and no duplicate")
	var removed=four.slice(0,1)
	ck(F.layout(removed,80).rims.size()==4 and F.layout(removed,80).seams.is_empty(),"removing neighbor immediately restores exterior rim")
	var long_l=T.form_bags([FIX.bag("pocket_long_l","a")])
	ck(F.layout(long_l,80).faces.all(func(p):return not Geometry2D.is_point_in_polygon(Vector2(120,40),p.polygon)),"long L notch stays visibly empty")
	ck(T.form_hit(Vector2(-2,40),long_l,80).is_empty(),"old invisible outside trim cannot steal input")
	seed(130);var expected=randi();seed(130)
	for n in 40:F.meshes(long_l,40+n)
	ck(F.cache.size()<=F.LIMIT,"geometry cache bounded")
	ck(randi()==expected,"projection consumes no gameplay RNG")
	print("FINE_SEAMS_V130 ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
