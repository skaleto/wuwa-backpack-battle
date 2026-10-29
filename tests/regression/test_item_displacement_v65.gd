extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const S=preload("res://scripts/storage/storage.gd")
var inventory=I.new()
var checks=0
var failures=0

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)

func piece(kind:String,uid:String,x:int=0,y:int=0,rotation:int=0)->Dictionary:
	var p=inventory.make_piece(kind,uid);p.x=x;p.y=y;p.rotation=rotation;return p

func fixture()->Dictionary:
	var run=inventory.new_run("jiyan",65)
	run.round=4;run.gold=30;run.items=[];run.stash=[];run.primary="";run.relay=[];run.shop=[{},{},{},{},{},{}]
	run.bags=[]
	for y in [0,2,4]:
		for x in [0,3]:run.bags.append(piece("satchel","bag-%s-%s"%[x,y],x,y))
		run.bags.append(piece("pouch","bag-6-%s"%y,6,y))
	return run

func fill_stash(run:Dictionary,count:int)->void:
	for n in count:run.stash.append(piece("nutrition","stored-%s"%n))

func moved(p:Dictionary,x:int,y:int,rotation:int=-1)->Dictionary:
	var next=p.duplicate(true);next.x=x;next.y=y
	if rotation>=0:next.rotation=rotation
	return next

func ids(items:Array)->Array:return items.map(func(p):return p.uid)

func _initialize()->void:
	owned_displacement()
	purchase_displacement()
	capacity_and_atomic_rejection()
	rotated_and_irregular_cells()
	pure_preview_and_storage()
	print("ITEM_DISPLACEMENT_V65: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

func owned_displacement()->void:
	var run=fixture()
	var source=piece("tube","source",5,4)
	source.provenance={"round":2,"note":"preserved"}
	var target=piece("whiff","target",1,1);target.level=2;target.tuning="fast";target.provenance={"round":1}
	var untouched=piece("nutrition","untouched",4,2)
	run.items=[source,target,untouched]
	var before=run.duplicate(true)
	var destination=moved(source,1,1)
	check(not inventory.can_place(destination,run.items,run.bags),"strict can_place still rejects overlapping cells")
	check(inventory.place(run,destination),"owned board item displaces an overlapping item")
	check(ids(run.items)==["untouched","source"] and run.stash==[target],"whole target moves to stash with metadata and source leaves old position")
	check(inventory.find_piece(run,"source")==destination,"moving item retains identity and metadata")
	check(run.gold==before.gold and run.serial==before.serial,"owned displacement changes no currency or serial")
	check(inventory.validate_run(run),"owned displacement is valid save data")
	run=fixture();source=piece("tube","self",1,1);run.items=[source]
	check(inventory.place(run,moved(source,2,1)) and run.stash.is_empty(),"self overlap is excluded from displacement")
	check(inventory.place(run,moved(source,2,1,1)) and run.stash.is_empty(),"self rotation overlapping old cells does not stash itself")
	run=fixture();source=piece("tube","incoming");run.stash=[source]
	var first=piece("whiff","first",0,0);var second=piece("nutrition","second",1,0)
	run.items=[first,second]
	check(inventory.place(run,source) and run.stash==[first,second],"one incoming item displaces every overlapping whole item")
	run=fixture();run.items=[piece("w_broadblade","primary",0,0),piece("whiff","relay",0,1)]
	run.primary="primary";run.relay=["primary","relay"];run.stash=[piece("tube","incoming")]
	check(inventory.valid_relay(run,run.relay),"relay cleanup fixture starts with a valid relay")
	check(inventory.place(run,run.stash[0]) and run.primary.is_empty() and run.relay.is_empty(),"displaced primary and relay references are cleaned")
	run=fixture();source=piece("tube","incoming");run.stash=[source]
	run.items=[piece("whiff","target")];run.pending_gifts=[piece("nutrition","gift")];run.pending_rearrange=[piece("nutrition","rearrange")]
	check(inventory.place(run,source) and ids(run.stash)==["target","gift","rearrange"],"pending entries fill remaining slots after displacement in existing order")
	check(run.pending_gifts.is_empty() and run.pending_rearrange.is_empty(),"claimed pending items are not duplicated")

func purchase_displacement()->void:
	var run=fixture();var first=piece("whiff","first",0,0);var second=piece("nutrition","second",1,0)
	run.items=[first,second];run.shop[0]={"kind":"tube","locked":true}
	var before=run.duplicate(true)
	var purchased=inventory.purchase_at(run,0,piece("tube","shop-preview"),"board")
	check(not purchased.is_empty(),"board purchase can replace multiple occupied cells")
	check(run.stash==[first,second] and run.items==[purchased],"purchase stashes both full targets and equips the purchased item")
	check(run.gold==before.gold-inventory.purchase_price(before,0) and run.serial==before.serial+1 and run.shop[0].is_empty(),"displacing purchase charges and consumes offer exactly once")
	check(purchased.get("uid","")=="i"+str(before.serial+1),"purchase preview identity is replaced with allocated owned UID")
	check(inventory.validate_run(run),"displacing purchase produces valid save data")
	var committed=run.duplicate(true)
	check(inventory.purchase_at(run,0,piece("tube","shop-preview"),"board").is_empty() and run==committed,"duplicate purchase cannot charge or displace again")
	run=fixture();run.shop[0]={"kind":"whiff","locked":false};fill_stash(run,6)
	check(not inventory.purchase_at(run,0,piece("whiff","preview",3,3),"board").is_empty() and run.stash.size()==6,"full stash allows direct purchase onto free cells despite transient seventh item")
	run=fixture();fill_stash(run,5);run.items=[piece("nutrition","target")];run.shop[0]={"kind":"whiff","locked":false}
	check(not inventory.purchase_at(run,0,piece("whiff","preview"),"board").is_empty() and run.stash.size()==6,"purchase uses exactly the one available displacement slot")

func capacity_and_atomic_rejection()->void:
	var run=fixture();var source=piece("tube","incoming");run.stash=[source];fill_stash(run,5)
	run.items=[piece("whiff","target")]
	check(inventory.place(run,source) and run.stash.size()==6 and "target" in ids(run.stash),"incoming stash item frees its own slot before displacement capacity check")
	run=fixture();source=piece("tube","incoming");run.stash=[source];fill_stash(run,5)
	run.items=[piece("whiff","first"),piece("nutrition","second",1,0)]
	var before=run.duplicate(true)
	check(inventory.place(run,source) and run.stash.size()==7 and "first" in ids(run.stash) and "second" in ids(run.stash),"V103 all displaced targets retained beyond six")
	run=fixture();source=piece("tube","source",3,3);run.items=[source,piece("whiff","target")];fill_stash(run,6)
	before=run.duplicate(true)
	check(inventory.place(run,moved(source,0,0)) and run.stash.size()==7 and "target" in ids(run.stash),"V103 board source can displace beyond six")
	run=fixture();run.items=[piece("whiff","target")];fill_stash(run,6);run.shop[0]={"kind":"tube","locked":true}
	before=run.duplicate(true)
	check(not inventory.purchase_at(run,0,piece("tube","preview"),"board").is_empty() and run.stash.size()==7 and run.gold==before.gold-inventory.purchase_price(before,0) and run.serial==before.serial+1 and run.shop[0].is_empty(),"V103 displacement beyond six charges exactly once and retains target")
	run=fixture();source=piece("tube","incoming");run.stash=[source];run.bags=[piece("satchel","bag")];run.items=[piece("whiff","target",2,0)]
	before=run.duplicate(true)
	check(not inventory.place(run,moved(source,2,0)) and run==before,"partly uncovered footprint rejects before displacing covered target")
	run=fixture();source=piece("tube","incoming");run.stash=[source];run.items=[piece("whiff","target",7,0)]
	before=run.duplicate(true)
	check(not inventory.place(run,moved(source,7,0)) and run==before,"partly outside footprint rejects before displacing in-bounds target")
	run=fixture();run.bags=[];source=piece("whiff","incoming");run.stash=[source];before=run.duplicate(true)
	check(not inventory.place(run,source) and run==before,"no purchased bags cannot accept an item")
	run=fixture();source=piece("tube","incoming");run.stash=[source];run.items=[piece("whiff","target")]
	var invalid=source.duplicate(true);invalid.rotation=4;before=run.duplicate(true)
	check(not inventory.place(run,invalid) and run==before,"invalid piece metadata rejects atomically")
	invalid=source.duplicate(true);invalid.uid="unowned"
	check(not inventory.place(run,invalid) and run==before,"unowned placement cannot displace owned items")
	run=fixture();run.gold=0;run.shop[0]={"kind":"tube","locked":true};run.items=[piece("whiff","target")];before=run.duplicate(true)
	check(inventory.purchase_at(run,0,piece("tube","preview"),"board").is_empty() and run==before,"unaffordable displacement purchase preserves complete state")
	run=fixture();before=run.duplicate(true)
	check(not inventory.place(run,moved(run.bags[0],1,0)) and run==before,"bag overlap still rejects and never enters item displacement")
	var invalid_layout=fixture();invalid_layout.items=[piece("whiff","one"),piece("nutrition","two")]
	check(not inventory.validate_run(invalid_layout),"validator continues rejecting persisted overlapping items")
	var fit=inventory.first_fit(piece("tube","auto"),[piece("nutrition","occupant")],fixture().bags)
	check(not fit.is_empty() and Vector2i.ZERO not in inventory.occupied(fit),"autofit continues avoiding occupied cells")
	run=fixture();run.items=[piece("nutrition","base"),piece("nutrition","material",1,0),piece("whiff","occupant",3,0)];before=run.duplicate(true)
	var craft=I.FORGE.transact(run,"nutrition_dense","base",inventory,{"x":3,"y":0,"rotation":0})
	check(not craft.ok and run==before,"craft output collision remains strict and cannot stash an unrelated occupant")

func rotated_and_irregular_cells()->void:
	var run=fixture();var source=piece("tube","incoming",2,1,1);run.stash=[source]
	var first=piece("whiff","first",2,1);var second=piece("nutrition","second",2,2);var beside=piece("nutrition","beside",3,1)
	run.items=[first,second,beside]
	check(inventory.place(run,source) and run.stash==[first,second] and "beside" in ids(run.items),"rotated footprint displaces only the two occupied vertical cells")
	# Exercise a concave shape through the supported footprint catalogue seam.
	# Current live item shapes are rectangles; this avoids changing the catalogue.
	inventory.footprint_catalogue={"tube":I.C.items.tube.duplicate(true)}
	inventory.footprint_catalogue.tube.shape=[[0,0],[0,1],[1,1]]
	run=fixture();source=piece("tube","incoming",1,1);run.stash=[source]
	var in_hole=piece("nutrition","hole",2,1);var touched=piece("whiff","touched",2,2)
	run.items=[in_hole,touched]
	check(inventory.place(run,source) and run.stash==[touched] and "hole" in ids(run.items),"concave source uses actual cells and preserves item in bounding-box hole")
	run=fixture();source=piece("nutrition","incoming",2,2);run.stash=[source]
	var concave=piece("tube","concave",1,1,1);run.items=[concave]
	check(inventory.place(run,source) and run.stash.is_empty(),"rotated concave target bounding-box hole is not an overlap")
	run=fixture();source=piece("nutrition","incoming",1,2);run.stash=[source];run.items=[concave]
	check(inventory.place(run,source) and run.stash==[concave],"one actual cell overlap displaces the entire rotated concave target")
	inventory.footprint_catalogue={}

func pure_preview_and_storage()->void:
	check(inventory.has_method("placement_preview"),"pure placement_preview API exists")
	if not inventory.has_method("placement_preview"):return
	var run=fixture();var source=piece("tube","incoming");run.stash=[source];run.items=[piece("whiff","target")]
	run.pending_gifts=[piece("nutrition","gift")]
	var before=run.duplicate(true);var original=source.duplicate(true)
	var preview=inventory.placement_preview(run,source)
	check(preview.ok and run==before and source==original,"owned preview is pure for source run and piece")
	check(ids(preview.displaced)==["target"] and preview.error.is_empty(),"owned preview names every whole displaced item")
	check(inventory.place(run,source) and preview.run==run and preview.piece==inventory.find_piece(run,"incoming"),"owned preview includes exact pending and final commit state")
	preview.run.stash[0].x=7
	check(run.stash[0].x==0,"preview result cannot alias committed input data")
	run=fixture();run.items=[piece("whiff","target")];run.shop[0]={"kind":"tube","locked":true};before=run.duplicate(true)
	source=piece("tube","shop-preview")
	preview=inventory.placement_preview(run,source,0)
	check(preview.ok and run==before and preview.run.gold==before.gold-inventory.purchase_price(before,0) and preview.run.serial==before.serial+1,"purchase preview includes exact price and allocated serial without mutation")
	var purchased=inventory.purchase_at(run,0,source,"board")
	check(preview.run==run and preview.piece==purchased and ids(preview.displaced)==["target"],"purchase preview and commit are deeply identical")
	var storage=S.new("user://qa-v65/item-displacement/")
	storage.save(run)
	check(storage.resume()==run,"displacement survives isolated save and reload including identities and metadata")
	run=fixture();run.items=[piece("whiff","target")];fill_stash(run,6);run.shop[0]={"kind":"tube","locked":true};before=run.duplicate(true)
	preview=inventory.placement_preview(run,source,0)
	check(preview.ok and run==before and ids(preview.displaced)==["target"] and preview.run.stash.size()==7,"V103 preview of seventh item is readonly and records exact displacement")
	check(not inventory.purchase_at(run,0,source,"board").is_empty() and run==preview.run,"V103 preview exactly matches committed purchase beyond six")
	run=fixture();run.items=[piece("whiff","target")];run.shop[0]={"kind":"tube","locked":true};run.gold=0;before=run.duplicate(true)
	preview=inventory.placement_preview(run,source,0)
	check(not preview.ok and preview.error=="金币不足" and preview.run==before and run==before,"unaffordable preview reports the balance failure without mutation")
