extends SceneTree
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const B=preload("res://scripts/battle/battle.gd")
const PRESENT=preload("res://scripts/ui/items/item_presentation_v75.gd")
const PRACTICE=preload("res://scripts/shop/practice_budget.gd")
var failures=0
var checks=0
func ck(ok,label):
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
	ck(C.combinations.size()>=160,"deeper graph contains at least nineteen additional recipes")
	var outcomes={}
	for recipe in C.combinations.filter(func(r):return r.base=="weapon_21020074"):outcomes[recipe.target]=true
	ck(outcomes.keys().size()==3,"Feijing has exactly three distinct outcomes across all input alternatives")
	ck(C.combinations.filter(func(r):return r.target=="weapon_21010076").size()>=2,"Qianban has alternative recipes")
	ck(C.items.weapon_21020076.has("v124"),"terminal charged blade has explicit combination profile")
	ck(C.SIMULATION_VERSION=="resonance-v128","simulation is versioned")
	if not C.items.weapon_21020076.has("v124"):
		print("STRATEGY_V124 ",checks," checks, ",failures," failures");quit(1);return
	var seen={}
	for r in C.combinations:
		ck(not seen.has(r.id),"unique recipe "+r.id);seen[r.id]=true
		ck(C.items.has(r.base) and C.items.has(r.target) and r.materials.all(func(k):return C.items.has(k)),"referenced items "+r.id)
		ck(not reaches(r.target,r.base,{}),"acyclic "+r.id)
		for material in r.materials:ck(not reaches(r.target,material,{}),"material edge acyclic "+r.id)
	for kind in C.items:
		if not C.items[kind].has("v124"):continue
		var p=C.items[kind].v124
		ck(not p.ownExtra.is_empty() and not p.starText.is_empty(),"core effects describe own and star rules "+kind)
		ck(C.items[kind].stars.size()>=2,"core has meaningful star placement "+kind)
		ck(is_equal_approx(C.items[kind].damage,p.damage) and is_equal_approx(C.items[kind].cooldown,p.cd),"AI and card numeric projections are current "+kind)
		ck(PRACTICE.route_match(kind,C.items[kind].route),"practice route follows current role "+kind)
	ck(PRESENT.chips("weapon_21040034").any(func(c):return c[0]=="counter") and PRESENT.chips("weapon_21040034").any(func(c):return c[0]=="shielding"),"Steel exposes actual counter and shield abilities")
	ck(PRESENT.choice_summary("weapon_21020106").contains("不同★声骸") and PRESENT.choice_summary("weapon_21020045").contains("推进一件★武器") and PRESENT.choice_summary("weapon_21020086").contains("附霜"),"branch labels expose the three different partner requirements")
	print("STRATEGY_V124 ",checks," checks, ",failures," failures");quit(1 if failures else 0)
func reaches(from:String,to:String,seen:Dictionary)->bool:
	if from==to:return true
	if seen.has(from):return false
	seen[from]=true
	for r in C.combinations:
		if (r.base==from or from in r.materials) and reaches(r.target,to,seen):return true
	return false
