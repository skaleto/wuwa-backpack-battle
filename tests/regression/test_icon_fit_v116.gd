extends SceneTree
## Native complete-source projection audit. The overlay is evidence only.
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const C=preload("res://scripts/data/catalog.gd")
const P=preload("res://scripts/ui/items/icon_projection.gd")
const GEO=preload("res://scripts/ui/items/art_geometry.gd")
const SKIN=preload("res://scripts/ui/visual_skin.gd")
const CAPACITY=preload("res://tests/fixtures/capacity_fixture_v111.gd")
const OUT="res://build/qa/feedback-v116/icon-fit/"
const BLADES=["weapon_21020086","weapon_21020064","weapon_21010066","weapon_21010056","weapon_21010046","weapon_21020107","weapon_21020096"]
const CHANGES={"weapon_21010046":4,"weapon_21010056":4,"weapon_21010066":4,"weapon_21020064":3,"weapon_21020086":4,"weapon_21020107":4,"weapon_21030015":2,"weapon_21030024":2,"weapon_21030026":2,"weapon_21030034":2,"weapon_21030036":2,"weapon_21030044":2,"weapon_21030045":2,"weapon_21030046":2,"weapon_21030056":2,"weapon_21030064":2,"weapon_21030066":2,"weapon_21030074":2,"weapon_21030084":2,"weapon_21030094":2,"weapon_21030104":2}
const SQUARES=["contract","contract_echo","contract_oath","judgment","field_notes","echo_butterfly"]
const CAPTURE_ITEMS=BLADES+["weapon_21030064","weapon_21030066","weapon_21030104","weapon_21040016","weapon_21040036","weapon_21040056"]+SQUARES+["tube"]
var checks=0
var failures=0
var g
var viewport:SubViewport
var capture=false
var evidence_prefix="current"
var report={"items":[],"long_weapons_below_85_percent":[],"images":[]}

class FootprintOverlay extends Node2D:
	var cells:Array=[]
	var labels:Array=[]
	var caption=""
	var face:Font
	func _draw():
		for rect in cells:draw_rect(rect,Color("593c8c",.7),false,1.0)
		for label in labels:
			draw_string(face,label.at,label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("492e61"))
		draw_style_box(_panel(),Rect2(32,20,1376,38))
		draw_string(face,Vector2(45,45),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("492e61"))
	func _panel()->StyleBoxFlat:
		var value=StyleBoxFlat.new();value.bg_color=Color("fff6df");return value

func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)

func _initialize()->void:
	# Frozen geometry/art audit; new V125 art is checked separately.
	preload("res://tests/fixtures/catalog_fixture_v124.gd").apply()
	root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true)
	capture="--capture" in OS.get_cmdline_user_args()
	if "--before" in OS.get_cmdline_user_args():evidence_prefix="before"
	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("run_tests")

func pair(v:Vector2)->Array:return [v.x,v.y]
func box(r:Rect2)->Array:return [r.position.x,r.position.y,r.size.x,r.size.y]

func run_tests()->void:
	viewport=SubViewport.new();viewport.size=Vector2i(1440,960)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	g=G.new();viewport.add_child(g);await process_frame
	g.set_process(false);g.set_process_input(false)
	var untouched=g.run.duplicate(true)
	var approved_sources={}
	if evidence_prefix!="before":
		var prior=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/data/feedback-v116/icon-fit/before-audit.json"))
		if prior is Dictionary:
			for row in prior.items:approved_sources[row.kind]=row.sha256
	for kind in C.items:
		if C.is_tag(kind,"bag"):continue
		var source=SKIN.item_path(kind)
		var row={"kind":kind,"name":C.items[kind].name,"tags":C.items[kind].tags,"shape":C.items[kind].shape,"source":source,"sha256":preload("res://tests/fixtures/layout.gd").published_text(source).sha256_text() if source.ends_with(".atlas.json") else FileAccess.get_sha256(source),"angle":SKIN.item_angle(kind),"rotations":[]}
		if evidence_prefix!="before":ck(approved_sources.get(kind,"")==row.sha256,kind+" approved source bytes unchanged")
		var reference_scale=0.0
		for turn in 4:
			var fitted=g._projection_for(kind,turn,g.CELL)
			var desc=g._descriptor_for(kind,turn)
			ck(not desc.get("empty",true) and desc.image_size==g.icons[kind].get_size(),kind+" descriptor matches real texture "+str(turn))
			var cells=g.inventory.cells({"kind":kind,"rotation":turn})
			var extent=Vector2.ONE
			for cell in cells:extent=extent.max(Vector2(cell)+Vector2.ONE)
			var length_ratio=fitted.bounds.size[0 if extent.x>=extent.y else 1]/(maxf(extent.x,extent.y)*g.CELL)
			if CHANGES.has(kind) and evidence_prefix!="before":
				ck(cells.size()==CHANGES[kind] and minf(extent.x,extent.y)==1,kind+" audited one-cell reduction "+str(turn))
				ck(length_ratio>=.8,kind+" at least 80 percent long-axis fit "+str(turn))
			if kind in SQUARES and evidence_prefix!="before":
				ck(cells==[Vector2i.ZERO],kind+" individually reviewed square footprint "+str(turn))
			if kind=="tube" and evidence_prefix!="before":
				ck(is_equal_approx(SKIN.item_angle(kind),deg_to_rad(16)),"tube positive clockwise source correction")
				ck(length_ratio>=.95,"tube aligned complete silhouette fills long axis "+str(turn))
			ck(fitted.scale>0 and fitted.position.is_finite(),kind+" finite fit "+str(turn))
			var transform:Transform2D=fitted.transform
			ck(is_equal_approx(transform.x.length(),transform.y.length()),kind+" original aspect "+str(turn))
			ck(absf(transform.x.dot(transform.y))<.0001,kind+" no shear "+str(turn))
			var owned={}
			for cell in cells:owned[cell]=true
			ck(P._contains(desc.validation_points,fitted.position+Vector2(desc.image_center).rotated(desc.angle)*fitted.scale,fitted.scale,owned,g.CELL,0),kind+" full visible alpha inside cells "+str(turn))
			if turn==0:reference_scale=fitted.scale
			else:ck(is_equal_approx(reference_scale,fitted.scale),kind+" rotation invariant scale "+str(turn))
			if kind in BLADES or kind=="tube":
				var source_image=Image.new();source_image.load_png_from_buffer(FileAccess.get_file_as_bytes(source))
				ck(desc==P.descriptor(source_image,SKIN.item_angle(kind)+turn*PI/2,false),kind+" cached exact alpha geometry "+str(turn))
			row.rotations.append({"turn":turn,"occupied_extent":pair(extent),"alpha_bounds":box(desc.bounds),"rendered_bounds":box(fitted.bounds),"scale":fitted.scale,"long_axis_coverage":length_ratio})
		if C.is_tag(kind,"weapon") and row.rotations[0].long_axis_coverage<.85:
			report.long_weapons_below_85_percent.append({"kind":kind,"name":row.name,"coverage":row.rotations[0].long_axis_coverage,"extent":row.rotations[0].occupied_extent})
		report.items.append(row)
	ck(g.run==untouched,"projection and audit do not mutate run")
	if capture:
		for page in ceili(CAPTURE_ITEMS.size()/3.0):
			for turn in 4:await shot(page,turn)
	report["summary"]={"item_count":report.items.size(),"rotation_count":report.items.size()*4,"short_long_weapons":report.long_weapons_below_85_percent.size(),"checks":checks,"failures":failures,"isolated_storage":true,"hidden_unfocusable":true,"pointer_untouched":true,"source_pixels_modified":false,"catalogue_hash":C.catalogue_hash}
	FileAccess.open(OUT+evidence_prefix+"-audit.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	g.queue_free();await process_frame
	print("ICON_FIT_V116 ",checks," checks, ",failures," failures; ",report.items.size()," items, ",report.long_weapons_below_85_percent.size()," short long weapons")
	quit(1 if failures else 0)

func shot(page:int,turn:int)->void:
	g.reset_slice();g.run.round=7;g.run.bags=CAPACITY.full_bags(g.inventory)
	g.run.items=[];g.run.stash=[];g.run.primary="";g.hovered={};g.detail_item={};g.mouse=Vector2(1430,950)
	var overlay=FootprintOverlay.new();overlay.face=g.body_font;viewport.add_child(overlay)
	var labels=[]
	for slot in 3:
		var index=page*3+slot
		if index>=CAPTURE_ITEMS.size():break
		var kind=CAPTURE_ITEMS[index]
		var item=g.piece(kind,"audit"+str(index),1 if turn%2==0 else slot*3,slot*2 if turn%2==0 else 1)
		item.rotation=turn;g.run.items.append(item)
		for cell in g.inventory.occupied(item):
			var p=g._board_to_screen(g.BOARD+Vector2(cell)*g.CELL)
			var q=g._board_to_screen(g.BOARD+(Vector2(cell)+Vector2.ONE)*g.CELL)
			overlay.cells.append(Rect2(p,q-p))
		var at=g._board_to_screen(g.BOARD+Vector2(item.x,item.y)*g.CELL)
		overlay.labels.append({"at":at+Vector2(0,-6),"text":C.items[kind].name})
		labels.append(C.items[kind].name)
	overlay.caption="V116 / "+evidence_prefix+" / "+str(turn*90)+"° / "+", ".join(labels)+" / QA footprint overlay"
	g.queue_redraw();overlay.queue_redraw()
	for n in 3:await process_frame
	RenderingServer.force_draw(true);await process_frame
	var name=evidence_prefix+"-items-"+str(page+1)+"-rotation-"+str(turn*90)+".png"
	ck(viewport.get_texture().get_image().save_png(OUT+name)==OK,"native capture "+name)
	report.images.append(name);overlay.queue_free();await process_frame
