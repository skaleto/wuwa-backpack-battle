extends SceneTree
const C = preload("res://scripts/data/catalog.gd")
const I = preload("res://scripts/inventory/inventory.gd")
const F = preload("res://scripts/crafting/craft.gd")
var inv=I.new()
var failures = 0
var checks = 0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize() -> void:
	var weapons=C.items.values().filter(func(v):return "weapon" in v.tags)
	check(weapons.size()==124,"all 124 weapons retained")
	check(weapons.all(func(v):return v.has("craft_tier") and v.has("route")),"all weapons have explicit tier and route")
	check(C.combinations.size()==114,"every non-entry weapon has a recipe")
	check(C.characters.size()==6,"all six attributes have a starting leader")
	check(FileAccess.file_exists("res://scripts/crafting/craft.gd"),"transactional forge exists")
	transactions()
	all_recipes()
	print("RESULT ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

func arena(leader: String="jiyan") -> Dictionary:
	var r=inv.new_run(leader,8);r.items=[];r.stash=[];r.round=4;r.gold=99;r.bags=[];r.shop=[{},{},{},{},{},{}]
	for n in range(5):r.bags.append(inv.first_fit(inv.make_piece("satchel","b"+str(n)),[],r.bags))
	return r
func put(r: Dictionary,kind: String,x: int,y: int) -> Dictionary:
	var id=inv.next_identity(r);r.serial=id.serial
	var piece=inv.make_piece(kind,id.uid);piece.x=x;piece.y=y;r.items.append(piece);return piece
func transactions() -> void:
	var r=arena();var base=put(r,"w_broadblade",0,0);r.primary=base.uid
	var recipe=C.combinations.filter(func(v):return v.type=="broadblade" and int(v.input_tier)==2)[0]
	var before=r.duplicate(true)
	check(not F.transact(r,recipe.target,base.uid,inv).ok and r==before,"missing material fails without mutation")
	check(F.buy_material(r,recipe.materials[0],inv),"deterministic material purchase")
	var mat=r.stash[0].duplicate(true);mat.x=0;mat.y=1
	check(inv.place(r,mat),"material can equip as a normal item")
	before=r.duplicate(true)
	var tx=F.preview(r,recipe.target,base.uid,inv)
	check(tx.ok and r==before,"forge preview pure and has output position")
	var old_serial=int(r.serial);var old_gold=int(r.gold)
	var result=F.transact(r,recipe.target,base.uid,inv)
	check(result.ok and int(r.serial)==old_serial+1 and r.gold==old_gold,"one UID allocated, no hidden forge fee")
	check(r.primary==result.output.uid and r.items.all(func(v):return v.uid!=base.uid and v.uid!=mat.uid),"exact inputs consumed and primary inherited")
	before=r.duplicate(true)
	check(not F.transact(r,recipe.target,base.uid,inv).ok and r==before,"stale confirmation cannot consume twice")
	var final=arena();var core=C.items.keys().filter(func(k):return C.is_tag(k,"weapon") and C.items[k].weapon_type=="broadblade" and int(C.items[k].craft_tier)==4)[0]
	base=put(final,core,0,0);final.primary=base.uid
	var cap=C.combinations.filter(func(v):return v.target=="verdant")[0]
	for n in range(cap.materials.size()):put(final,cap.materials[n],n,1)
	check(F.preview(final,"verdant",base.uid,inv).ok,"owner-leader signature recipe reachable")
	final.leader="yinlin";before=final.duplicate(true)
	check(not F.transact(final,"verdant",base.uid,inv).ok and final==before,"unowned signature rejected atomically")
	final.leader="jiyan";final.round=3;before=final.duplicate(true)
	check(not F.transact(final,"verdant",base.uid,inv).ok and final==before,"terminal stage gated to round four")
	final.round=4
	result=F.transact(final,"verdant",base.uid,inv)
	check(result.ok and result.saved_cells>=1 and inv.validate_run(final),"terminal craft saves real cells and remains legal")
	var p=final.items[0];p.x=7;p.y=5;final.items=[p];before=final.duplicate(true)
	check(not F.transact(final,"verdant",p.uid,inv).ok and final==before,"illegal ownership/geometry rejected before mutation")
	for target in C.items.keys().filter(func(k):return C.items[k].get("craft_only",false)):
		check(not inv.shop_eligible(arena(),target),"signature never sold randomly "+target)
	for leader in C.characters:
		check(inv.validate_run(inv.new_run(leader,8)),"new leader legal "+leader)

func all_recipes() -> void:
	for recipe in C.combinations:
		var leader="jiyan"
		if not recipe.owners.is_empty():
			var owner=recipe.owners[0];var element=C.roster[owner].element
			leader=C.characters.keys().filter(func(k):return C.characters[k].element==element)[0]
		var r=arena(leader)
		if not recipe.owners.is_empty() and C.characters[leader].roster_id!=recipe.owners[0]:
			r.roster=[recipe.owners[0]];r.supports=r.roster.duplicate();r.recruited_round=2
		var kinds=C.items.keys().filter(func(k):return C.is_tag(k,"weapon") and C.items[k].weapon_type==recipe.type and int(C.items[k].craft_tier)==int(recipe.input_tier))
		var base=put(r,kinds[0],0,0);r.primary=base.uid
		for kind in recipe.materials:
			var piece=inv.make_piece(kind,"placeholder");var found={}
			for y in range(I.HEIGHT):
				for x in range(I.WIDTH):
					piece.x=x;piece.y=y
					if inv.can_place(piece,r.items,r.bags) and inv.adjacent(base,piece):found=piece.duplicate(true);break
				if not found.is_empty():break
			check(not found.is_empty(),"ingredient placement exists "+recipe.target)
			if not found.is_empty():put(r,kind,found.x,found.y)
		var original=r.duplicate(true)
		var result=F.preview(r,recipe.target,base.uid,inv)
		check(result.ok and r==original,"all recipes achievable without destroying preview "+recipe.target)
		if result.ok:
			check(inv.validate_run(result.run),"every recipe output legal "+recipe.target)
			if int(C.items[recipe.target].craft_tier)==5:check(result.saved_cells>=1,"each terminal frees capacity "+recipe.target)
		var investment=int(C.items[base.kind].price)
		for kind in recipe.materials:investment+=int(C.items[kind].price)
		check(int(floor(float(C.items[recipe.target].price)*.5))<investment,"no immediate crafting resale arbitrage "+recipe.target)
