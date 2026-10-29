extends SceneTree
const FORM=preload("res://scripts/ui/pockets/bag_form.gd")
const T=preload("res://scripts/ui/pockets/terminal_grid.gd")
const I=preload("res://scripts/inventory/inventory.gd")
var checks=0
var failures=0
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:
	var inv=I.new()
	for kind in ["satchel","pouch","strip","corner","travel"]:
		var pixels=Image.load_from_file(FORM.path(kind))
		ck(pixels!=null,"complete illustration exists: "+kind)
		var reference_uv=Vector2.ZERO
		for turns in 4:
			var bag=inv.make_piece(kind,"bag");bag.rotation=turns
			var values=T.form_bags([bag]);var before=values.duplicate(true)
			var ps=FORM.patches(values,80)
			for cell in values[0].cells:
				var center=(Vector2(cell)+Vector2.ONE*.5)*80
				var faces=ps.filter(func(p):return p.rect.has_point(center))
				ck(faces.size()==1,"one complete lining at each cell: "+kind)
				if not faces.is_empty() and pixels:
					var p=faces[0];var f=(center-p.rect.position)/p.rect.size
					var uv=p.uv[0].lerp(p.uv[1],f.x).lerp(p.uv[3].lerp(p.uv[2],f.x),f.y)
					ck(pixels.get_pixelv(Vector2i(uv*Vector2(pixels.get_size()))).a>.9,"lining is painted in the body image: "+kind)
				ck(FORM.hit(center,values,80).is_empty(),"opaque lining does not become an external grab hotspot")
			var opaque_outside=false
			var shared_uv={}
			for p in ps:
				ck(p.rect.size.x>0 and p.rect.size.y>0,"positive drawing area")
				ck(Array(p.uv).all(func(v):return v.x>=0 and v.y>=0 and v.x<=1 and v.y<=1),"UV stays in original image")
				for n in 4:
					var point=p.points[n]
					if shared_uv.has(point):ck(shared_uv[point].is_equal_approx(p.uv[n]),"adjacent portions sample the same illustration continuously")
					shared_uv[point]=p.uv[n]
				if p.inside:continue
				for y in range(int(p.rect.position.y),int(p.rect.end.y),5):
					for x in range(int(p.rect.position.x),int(p.rect.end.x),5):
						var point=Vector2(x,y)
						if Vector2i((point/80).floor()) not in values[0].cells and FORM.hit(point,values,80)=="bag":opaque_outside=true
			ck(opaque_outside,"visible outside parts remain grabbable")
			ck(FORM.hit(Vector2(-200,-200),values,80).is_empty(),"transparent exterior does not grab")
			var body=FORM.bounds(values[0],80)
			var unit=[Vector2(.23,.37),Vector2(.63,.23),Vector2(.77,.63),Vector2(.37,.77)][turns]
			var uv=FORM.uv_at(body.position+unit*body.size,body,FORM.authored_turns(values[0]),kind,80)
			if turns==0:reference_uv=uv
			else:ck(reference_uv.is_equal_approx(uv),"whole artwork rotates with the container")
			ck(values==before,"display projection leaves logical cells unchanged")
	var a=inv.make_piece("satchel","left")
	var b=inv.make_piece("travel","right");b.x=3
	var joined=T.form_bags([a,b]);var original=joined.duplicate(true)
	for p in FORM.patches(joined,80):
		var center=p.rect.get_center();var cell=Vector2i((center/80).floor())
		if cell in joined[0].cells:ck(p.uid=="left","right bag cannot paint into left bag")
		if cell in joined[1].cells:ck(p.uid=="right","left bag cannot paint into right bag")
	for y in [40.0,80.0,120.0]:
		ck(FORM.hit(Vector2(240,y),joined,80).is_empty(),"shared edge cannot create an external grab")
	ck(joined==original,"joining does not merge logical bag identities")
	print("BAG_LAYERS_V105 ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
