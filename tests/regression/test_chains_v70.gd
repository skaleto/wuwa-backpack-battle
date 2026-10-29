extends SceneTree
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const F=preload("res://scripts/crafting/craft.gd")
const B=preload("res://scripts/battle/battle.gd")
var inv=I.new();var checks=0;var failures=0
func ck(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func piece(kind,uid,x,y):
	var p=inv.make_piece(kind,uid);p.x=x;p.y=y;return p
func fixture():
	var r=inv.new_run("aemeath",19);r.round=6;r.items=[];r.stash=[];r.bags=[];r.primary="";r.serial=20
	for y in range(0,6,2):
		for x in range(0,8,2):r.bags.append(piece("pouch","b%d-%d"%[x,y],x,y))
	return r
func _initialize():call_deferred("run_tests")
func run_tests():
	var old=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/data/ui-v70/before/catalog.json"))
	for kind in old.items:
		if old.items[kind].get("v60",{}).get("active",false):ck(C.items[kind]==old.items[kind],"preserve prior active mechanics "+kind)
	var incoming={}
	for recipe in C.combinations:
		ck(not incoming.has(recipe.target),"unique incoming target "+recipe.target);incoming[recipe.target]=recipe
		ck(recipe.materials.size()==1,"each direct pair has one partner")
	for initial in old.recipes:
		ck(C.combinations.any(func(r):return r.base==initial.target),"every old path can continue: "+initial.target)
	var roots=[]
	for recipe in C.combinations:
		if not incoming.has(recipe.base) and recipe.base not in roots:roots.append(recipe.base)
	var finished=[]
	for recipe in C.combinations:
		if C.combinations.any(func(r):return r.base==recipe.target):continue
		var chain=[recipe];var visited=[recipe.target];var cursor=recipe.base
		while incoming.has(cursor):
			ck(cursor not in visited,"no cycle")
			if cursor in visited:break
			visited.append(cursor);chain.push_front(incoming[cursor]);cursor=incoming[cursor].base
		ck(chain.size()>=2,"at least two real fusions before terminal")
		var run=fixture();run.items=[piece(cursor,"base",0,0)];run.primary="base" if C.is_tag(cursor,"weapon") else ""
		for edge in chain:
			var base=run.items[0];var identity=inv.next_identity(run)
			run.stash=[piece(edge.materials[0],identity.uid,0,0)];run.serial=identity.serial
			ck(F.place_material(run,edge.target,base.uid,edge.materials[0],inv).ok,"real material placement "+edge.id)
			var result=F.transact(run,edge.target,base.uid,inv)
			ck(result.ok and inv.validate_run(run) and run.items.size()==1,"sequential atomic craft "+edge.id)
			if not result.ok:break
		ck(run.items[0].kind==recipe.target,"terminal reached "+recipe.target)
		var combat=B.new().simulate(run,inv.practice(6,5),99,false)
		ck(float(combat.duration)>0 and combat.totals[0].damage>=0,"new terminal participates in real battle "+recipe.target)
		finished.append(recipe.target)
	print("CHAINS_V70 ",checks," checks, ",failures," failures; ",finished.size()," terminal paths")
	quit(1 if failures else 0)
