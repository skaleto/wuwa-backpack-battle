extends SceneTree
const T=preload("res://scripts/ui/pockets/terminal_grid.gd")
const F=preload("res://scripts/ui/pockets/bag_form.gd")
const S=preload("res://scripts/ui/visual_skin.gd")
const FIX=preload("res://tests/fixtures/bag_trial_fixture_v109.gd")
const KINDS=["satchel","pouch","strip","corner","travel","pocket_single","pocket_double","pocket_long_l","pocket_long_j"]
var checks=0
var failures=0
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:
	ck(S.bag_style=="patchwork_v129","patchwork is the normal default")
	for kind in KINDS:
		var pixels=Image.load_from_file(F.path(kind))
		ck(pixels!=null and pixels.get_format()==Image.FORMAT_RGBA8,"real RGBA art "+kind)
		ck(S.bag_path(kind)==F.path(kind),"all asset consumers share current pocket art "+kind)
		if pixels==null:continue
		for turn in 4:
			var bags=T.form_bags([FIX.bag(kind,"a",turn)]);var before=bags.duplicate(true)
			var patches=F.patches(bags,80);var body=F.bounds(bags[0],80);var hues=[]
			for cell in bags[0].cells:
				var point=(Vector2(cell)+Vector2.ONE*.5)*80
				var faces=patches.filter(func(p):return p.rect.has_point(point))
				ck(faces.size()==1,"single continuous face per cell "+kind)
				var p=faces[0];var uv=p.uv[0].lerp(p.uv[1],.5).lerp(p.uv[3].lerp(p.uv[2],.5),.5)
				var color=pixels.get_pixelv(Vector2i(uv*Vector2(pixels.get_size())))
				ck(color.a>.9,"opaque usable lining "+kind);hues.append(color.h)
			for hue in hues:ck(absf(hue-hues[0])<.07,"whole pocket has one hue including L foot "+kind)
			for y in int(body.size.y/80):
				for x in int(body.size.x/80):
					var cell=Vector2i(x,y)
					if cell in bags[0].cells:continue
					var at=(Vector2(cell)+Vector2.ONE*.5)*80
					ck(patches.all(func(p):return not p.rect.has_point(at)),"no art mesh fills empty notch "+kind)
					ck(F.hit(at,bags,80).is_empty(),"empty notch cannot grab "+kind)
			var vertices={}
			for p in patches:
				ck(p.rect.size.x>0 and p.rect.size.y>0,"positive faces")
				for n in 4:
					ck(p.uv[n].x>=0 and p.uv[n].y>=0 and p.uv[n].x<=1 and p.uv[n].y<=1,"source UV in bounds")
					if vertices.has(p.points[n]):ck(vertices[p.points[n]].is_equal_approx(p.uv[n]),"continuous shared vertices")
					vertices[p.points[n]]=p.uv[n]
			ck(bags==before,"drawing leaves logical shapes intact")
	for a in KINDS:
		for b in KINDS:
			for turn in 4:
				var bags=T.form_bags(FIX.touching(FIX.bag(a,"a",turn),FIX.bag(b,"b",(turn+1)%4),Vector2i.RIGHT,turn%2==0));var owners={}
				for bag in bags:
					for cell in bag.cells:owners[cell]=bag.uid
				for p in F.patches(bags,56):
					var cell=Vector2i((p.rect.get_center()/56).floor())
					ck(not owners.has(cell) or owners[cell]==p.uid,"a hem never paints over its neighbor")
	seed(129);var expected=randi();seed(129)
	F.patches(T.form_bags([FIX.bag("pocket_long_j","a")]),80)
	ck(randi()==expected,"visuals use no gameplay randomness")
	check_fallbacks()
	print("POCKET_ART_V129 ",checks," checks, ",failures," failures");quit(1 if failures else 0)

func check_fallbacks()->void:
	# Comparison launchers still allow current shops. New shapes need their
	# matching cropped UV frame and concave geometry under every older style.
	for style in ["flat","fold","storybook","paper","patchwork"]:
		S.set_bag_style(style,false)
		for kind in KINDS.slice(5):
			var pixels=Image.load_from_file(F.path(kind))
			for turn in 4:
				var bags=T.form_bags([FIX.bag(kind,"a",turn)])
				var patches=F.patches(bags,80)
				for cell in bags[0].cells:
					for x in [.1,.5,.9]:
						for y in [.1,.5,.9]:
							var at=(Vector2(cell)+Vector2(x,y))*80
							var faces=patches.filter(func(p):return p.rect.has_point(at))
							ck(faces.size()==1,"fallback single face "+style+kind)
							if faces.size()!=1:continue
							var p=faces[0];var f=(at-p.rect.position)/p.rect.size
							var uv=p.uv[0].lerp(p.uv[1],f.x).lerp(p.uv[3].lerp(p.uv[2],f.x),f.y)
							ck(pixels.get_pixelv(Vector2i(uv*Vector2(pixels.get_size()))).a>.9,"fallback opaque lining "+style+kind)
				var body=F.bounds(bags[0],80)
				for y in int(body.size.y/80):
					for x in int(body.size.x/80):
						if Vector2i(x,y) in bags[0].cells:continue
						var at=(Vector2(x,y)+Vector2.ONE*.5)*80
						ck(patches.all(func(p):return not p.rect.has_point(at)),"fallback open notch "+style+kind)
	S.set_bag_style("patchwork_v129",false)
