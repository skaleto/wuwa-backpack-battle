extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const F=preload("res://scripts/crafting/craft.gd")
const C=preload("res://scripts/data/catalog.gd")
var inv=I.new()
var forge=F.new()
var checks=0
var failures=0
func ck(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():call_deferred("run_tests")
func piece(kind:String,uid:String,x:int,y:int):
	var item=inv.make_piece(kind,uid);item.x=x;item.y=y;return item
func fixture():
	var r=inv.new_run("aemeath",19);r.round=2;r.items=[];r.stash=[];r.bags=[];r.primary="i1";r.serial=20
	for y in range(0,6,2):
		for x in range(0,8,2):r.bags.append(piece("pouch","b%d-%d"%[x,y],x,y))
	r.items=[piece("w_sword","i1",0,0),piece("mat_43020011","i2",2,1)]
	return r
func ready(r):return forge.call("ready_options",r,inv)
func commit(r,c):return forge.call("commit_ready",r,c,inv)
func run_tests():
	if not forge.has_method("ready_options"):
		ck(false,"board must expose immediately usable recipes without opening forge")
		quit(1);return
	var r=fixture();var before=r.duplicate(true)
	ck(inv.validate_run(r),"fixture is legal")
	var choices=ready(r)
	ck(choices.size()==1 and choices[0].target=="weapon_21020044","Zhenhai + inert droplet visibly offers Bugui")
	ck(r==before,"discovering ready crafts never mutates run")
	if choices.is_empty():quit(1);return
	var chosen=choices[0].duplicate(true)
	var outcome=commit(r,chosen)
	ck(outcome.ok and r.items.size()==1 and r.items[0].kind==chosen.target,"one commit consumes exact pair and creates target")
	ck(r.items[0].x==chosen.output.x and r.items[0].y==chosen.output.y and r.items[0].rotation==chosen.output.rotation,"commit matches preview landing")
	ck(r.gold==before.gold and r.stash==before.stash and r.shop==before.shop,"no fee or unrelated inventory change")
	ck(r.primary==r.items[0].uid and inv.validate_run(r),"primary follows new weapon")
	before=r.duplicate(true)
	ck(not commit(r,chosen).ok and r==before,"double click cannot duplicate output or consume again")
	r=fixture();r.items[1].x=5;r.items[1].y=4;before=r.duplicate(true)
	ck(ready(r).is_empty(),"nonadjacent material does not advertise readiness")
	ck(not commit(r,chosen).ok and r==before,"stale button cannot consume moved material")
	r=fixture();r.stash=[r.items.pop_back()]
	ck(ready(r).is_empty(),"stored material is not ready")
	r=fixture();r.round=1
	ck(ready(r).is_empty(),"round gate preserved")
	r=fixture();r.phase="battle"
	ck(ready(r).is_empty(),"no crafting during auto battle")
	r=fixture();r.items.append(piece("mat_42300100","i3",0,1))
	choices=ready(r)
	ck(choices.size()==2,"two valid branches remain independently selectable")
	for choice in choices:
		var branch=r.duplicate(true);var result=commit(branch,choice)
		ck(result.ok and branch.items.size()==2,"branch consumes only its own partner")
		ck(branch.items.any(func(v):return v.uid==("i3" if choice.target=="weapon_21020044" else "i2")),"other branch material remains owned")
	# Fill every cell not occupied by the two inputs; crafted blade is longer.
	r=fixture()
	for y in I.HEIGHT:
		for x in I.WIDTH:
			var p=piece("mat_42300100","fill%d-%d"%[x,y],x,y)
			if inv.can_place(p,r.items,r.bags):r.items.append(p)
	ck(inv.validate_run(r),"full board fixture legal")
	ck(ready(r).filter(func(v):return v.target=="weapon_21020044").is_empty(),"cannot advertise output with no legal space")
	# Cover all active recipes through the same new entry point.
	for recipe in C.combinations:
		r=fixture();r.items=[piece(recipe.base,"i1",0,0)];r.primary="i1" if C.is_tag(recipe.base,"weapon") else "";r.round=recipe.round_min
		r.stash=[piece(recipe.materials[0],"i2",0,0)]
		ck(F.place_material(r,recipe.target,"i1",recipe.materials[0],inv).ok,"place recipe input "+recipe.id)
		var matching=ready(r).filter(func(v):return v.target==recipe.target)
		ck(matching.size()==1,"direct candidate for "+recipe.id)
		if not matching.is_empty():ck(commit(r,matching[0]).ok and inv.validate_run(r),"direct transaction for "+recipe.id)
	print("INLINE_CRAFT_V69 ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
