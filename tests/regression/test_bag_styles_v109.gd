extends SceneTree
const SKIN=preload("res://scripts/ui/visual_skin.gd")
const FORM=preload("res://scripts/ui/pockets/bag_form.gd")
const T=preload("res://scripts/ui/pockets/terminal_grid.gd")
const FIX=preload("res://tests/fixtures/bag_trial_fixture_v109.gd")
const CONTACTS=preload("res://scripts/ui/pockets/bag_contacts.gd")
const KINDS=["satchel","pouch","strip","corner","travel"]
var checks=0
var failures=0
var layouts=0
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:
	run_styles(["flat","fold"])

func run_styles(styles:Array)->void:
	var old=SKIN.bag_style
	SKIN.set_bag_style("patchwork",false)
	var normal=FORM.path("satchel")
	for style in styles:
		ck(SKIN.set_bag_style(style,false),"accept approved bag trial: "+style)
		if SKIN.bag_style!=style:continue
		ck(FORM.path("satchel")!=normal,"trial selects its real bag illustration")
		var bag={"kind":"satchel","uid":"a","x":0,"y":0,"rotation":0}
		var other={"kind":"pouch","uid":"b","x":3,"y":0,"rotation":0}
		var values=T.form_bags([bag,other]);var before=values.duplicate(true)
		var owner={}
		for b in values:
			for cell in b.cells:owner[cell]=b.uid
		var offset=FORM._joining_offset(Vector2(240,80),"a",owner,80)
		var expected_offset=Vector2.ZERO if style=="flat" else Vector2(-3.2,0) if style=="storybook" else Vector2(-9.6,0)
		ck(offset.is_equal_approx(expected_offset),"shared lip compression follows its art family")
		FORM.patches(values,80)
		ck(values==before,"trial projection does not change cells or identity")
		for kind in KINDS:check_bag(style,kind)
		for kind in KINDS:
			for other_kind in KINDS:
				for a in 4:
					for b in 4:
						for axis in [Vector2i.RIGHT,Vector2i.DOWN]:
							for stagger in [false,true]:
								check_contact(FIX.touching(FIX.bag(kind,"a",a),FIX.bag(other_kind,"b",b),axis,stagger))
		# A genuinely empty L notch must not become a grab hotspot in any rotation.
		for turn in 4:
			var corner=T.form_bags([FIX.bag("corner","l",turn)])
			for x in 2:
				for y in 2:
					if Vector2i(x,y) not in corner[0].cells:
						ck(FORM.hit((Vector2(x,y)+Vector2.ONE*.5)*80,corner,80).is_empty(),"L notch remains transparent: "+style)
		seed(109);var expected=randi();seed(109)
		SKIN.set_bag_style(style,false);FORM.patches(values,80)
		ck(randi()==expected,"art projection consumes no gameplay RNG")
	ck(FORM.masks.size()==styles.size()*5,"alpha hit masks isolated by all requested image paths")
	SKIN.set_bag_style(old,false)
	print("BAG_STYLES ",styles," ",checks," checks, ",layouts," touching layouts, ",failures," failures")
	quit(1 if failures else 0)

func check_bag(style:String,kind:String)->void:
	var pixels=Image.load_from_file(FORM.path(kind))
	ck(pixels!=null,"actual trial art exists: "+style+"/"+kind)
	if pixels==null:return
	var reference=Vector2.ZERO
	for turn in 4:
		var values=T.form_bags([FIX.bag(kind,"bag",turn)])
		var ps=FORM.patches(values,80);var vertices={}
		for p in ps:
			for n in 4:
				if vertices.has(p.points[n]):ck(vertices[p.points[n]].is_equal_approx(p.uv[n]),"continuous source image at mesh vertex")
				vertices[p.points[n]]=p.uv[n]
		for cell in values[0].cells:
			var center=(Vector2(cell)+Vector2.ONE*.5)*80
			var faces=ps.filter(func(p):return p.rect.has_point(center))
			ck(faces.size()==1,"each actual cell has one bag face")
			var p=faces[0];var uv=p.uv[0].lerp(p.uv[1],.5).lerp(p.uv[3].lerp(p.uv[2],.5),.5)
			ck(pixels.get_pixelv(Vector2i(uv*Vector2(pixels.get_size()))).a>.9,"all cell centers have opaque lining "+style+"/"+kind)
			ck(FORM.hit(center,values,80).is_empty(),"bag outline cannot preempt item interior")
		var body=FORM.bounds(values[0],80)
		var unit=[Vector2(.23,.37),Vector2(.63,.23),Vector2(.77,.63),Vector2(.37,.77)][turn]
		var uv=FORM.uv_at(body.position+unit*body.size,body,FORM.authored_turns(values[0]),kind,80)
		if turn==0:reference=uv
		else:ck(reference.is_equal_approx(uv),"whole bag rotates around its logical bounding box")
		var grab=false
		for p in ps:
			if p.inside:continue
			for x in [0.25,0.5,0.75]:
				for y in [0.25,0.5,0.75]:
					var point=p.rect.position+p.rect.size*Vector2(x,y)
					if FORM.hit(point,values,80)=="bag":grab=true
		ck(grab,"visible outside edges remain grabbable "+style+"/"+kind)

func check_contact(bags:Array)->void:
	layouts+=1
	var original=bags.duplicate(true);var values=T.form_bags(bags);var owner={}
	for b in values:
		for cell in b.cells:
			ck(not owner.has(cell),"contact has no occupied overlap");owner[cell]=b.uid
	ck(not CONTACTS.segments(values).is_empty(),"fixture has a full shared edge, not just diagonal corners")
	for p in FORM.patches(values,80):
		var cell=Vector2i((p.rect.get_center()/80).floor())
		ck(not owner.has(cell) or p.uid==owner[cell],"bag decoration cannot overpaint another bag cell")
	ck(bags==original,"all contacts preserve bag position, rotation and identity")
