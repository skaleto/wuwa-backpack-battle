extends SceneTree
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const F=preload("res://scripts/crafting/craft.gd")
var fails=0
var checks=0
func ck(value:bool,label:String):
	checks+=1
	if not value:fails+=1;printerr("FAIL ",label)
func _initialize():
	var inv=I.new()
	for leader in C.selectable_leaders():
		var fresh=inv.new_run(leader,99)
		ck(inv.validate_run(fresh),"legal complete starter "+leader)
		ck(fresh.items.size()==2,"starter pair fits without empty dictionaries "+leader)
	var approved=JSON.parse_string(FileAccess.get_file_as_string("res://data/compat/design/approved-v2.json"))
	for row in approved.items:ck(C.items.has(row.id) and C.items.get(row.id,{}).get("v60",{}).get("active",false),"active approved item "+row.id)
	ck(C.combinations.size()>=18,"18 exact recipes")
	for r in C.combinations:ck(r.has("base") and r.base!=r.target,"explicit base "+str(r.id))
	if C.items.has("nutrition_dense"):
		var run=inv.new_run("jiyan",31);run.items=[inv.make_piece("nutrition","i1")];run.primary=""
		ck(not F.preview(run,"nutrition_dense","i1",inv).ok,"one nutrition cannot fuse with itself")
		var second=inv.make_piece("nutrition","i2");second.x=1;run.items.append(second)
		ck(F.material_status(run,"nutrition_dense","i1",inv)[0].owned==1,"base excluded from second-input count")
		var before=run.duplicate(true);var tx=F.transact(run,"nutrition_dense","i1",inv)
		ck(tx.ok and run.items.size()==1 and run.items[0].kind=="nutrition_dense","two distinct supplies fuse")
		ck(int(run.gold)==int(before.gold),"no hidden crafting fee")
		ck(F.options(before,"i1",inv).size()==1,"nonweapon details expose recipe")
	var source=inv.make_piece("w_broadblade","s");var target=inv.make_piece("turtle","t");target.y=1
	ck(inv.star_links(source,[source,target]).is_empty(),"healing-only cannot match attack stars")
	var original=C.items.turtle.element;C.items.turtle.element="attack"
	ck(inv.star_links(source,[source,target]).is_empty(),"element never qualifies capability stars")
	C.items.turtle.element=original
	print("CONTENT_V60 ",checks," checks, ",fails," failures")
	quit(1 if fails else 0)
