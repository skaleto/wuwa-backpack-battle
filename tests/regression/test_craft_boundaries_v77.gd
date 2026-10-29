extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const C=preload("res://scripts/data/catalog.gd")
const F=preload("res://scripts/crafting/craft.gd")
const FIX=preload("res://tests/fixtures/craft_fixture_v75.gd")
class CountingInventory extends I:
	var validation_calls=0
	var unlock_calls=0
	func craft_unlocked(run:Dictionary,kind:String)->bool:
		unlock_calls+=1
		return super.craft_unlocked(run,kind)
	func validate_run(raw:Variant)->bool:
		validation_calls+=1
		return super.validate_run(raw)
var failures=0
var checks=0
var saves=0
func ck(ok,label):
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func saved(_run):saves+=1
func _initialize():
	var files=["recipe_book","craft_rules","craft_placement","craft_handler","run_session","item_space"]
	for file in files:ck(preload("res://tests/fixtures/layout.gd").exists("res://scripts/"+file+".gd"),"module boundary exists: "+file)
	if failures:print("CRAFT_BOUNDARIES_V77 ",checks," checks, ",failures," failures");quit(1);return
	var facade=load("res://scripts/crafting/craft.gd")
	var book=load("res://scripts/crafting/recipe_book.gd")
	var session=load("res://scripts/run/run_session.gd")
	var inv=CountingInventory.new()
	var recipe=C.combinations[0]
	var r=FIX.make(inv,recipe.target)
	r.items=[inv.make_piece(recipe.base,"i1")];r.stash=[inv.make_piece(recipe.materials[0],"i2")]
	r.primary="i1" if C.is_tag(recipe.base,"weapon") else ""
	r.golden_acquired=C.is_tag(recipe.base,"golden") or C.is_tag(recipe.materials[0],"golden")
	F.place_material(r,recipe.target,"i1",recipe.materials[0],inv)
	var before=r.duplicate(true)
	var known=book.pairs(C.combinations,recipe.base,recipe.materials[0])
	ck(known.any(func(v):return v.target==recipe.target),"recipe facts need no live run")
	inv.validation_calls=0
	var no_pair=r.duplicate(true);no_pair.items=no_pair.items.filter(func(v):return v.uid=="i1")
	inv.unlock_calls=0
	facade.recipe_relations(no_pair,inv)
	ck(inv.unlock_calls==0,"no matching pair avoids unrelated eligibility work during drag")
	var facts=facade.recipe_relations(r,inv)
	ck(inv.validation_calls==0,"pure relationship facts do not validate an entire run")
	var no_space=r.duplicate(true);no_space.bags=[]
	ck(facade.recipe_relations(no_space,inv)==facts,"recipe and adjacency facts independent of output space or global validation")
	inv.validation_calls=0
	F.relationships(r,inv)
	ck(inv.validation_calls==1,"enriched relationship view validates source once, never constructs/validates transaction copies")
	var plan=F.preview(r,recipe.target,"i1",inv)
	ck(r==before and plan.ok,"planning leaves state, serial, money and RNG untouched")
	var changed=r.duplicate(true);changed.gold+=1;var changed_before=changed.duplicate(true)
	var stale=session.commit(changed,plan,inv.validate_run,saved)
	ck(not stale.ok and changed==changed_before and saves==0,"stale state cannot apply or persist a prepared plan")
	var invalid=plan.duplicate(true);invalid.run.gold=-1
	ck(not session.commit(r,invalid,inv.validate_run,saved).ok and r==before and saves==0,"final validation rejects an invalid candidate before any write")
	var rejected=F.transact(r,recipe.target,"i1",inv,{"x":8,"y":5,"rotation":0},saved)
	ck(not rejected.ok and r==before and saves==0,"failed placement neither commits nor calls persistence")
	var candidate=F.ready_options(r,inv).filter(func(v):return v.target==recipe.target)[0]
	var replaced=r.duplicate(true)
	replaced.items.filter(func(v):return v.uid=="i2")[0].uid="replacement"
	var replaced_before=replaced.duplicate(true)
	ck(not F.commit_ready(replaced,candidate,inv,saved).ok and replaced==replaced_before and saves==0,"same-kind replacement never substitutes the confirmed material instance")
	var result=session.commit(r,plan,inv.validate_run,saved)
	ck(result.ok and saves==1 and r==plan.run,"one application commits the exact planned run and persists once")
	ck(result.changes.consumed.size()==2 and result.changes.created==[result.output],"result contains independent animation facts")
	before=r.duplicate(true)
	ck(not session.commit(r,plan,inv.validate_run,saved).ok and r==before and saves==1,"duplicate apply does not consume, allocate or persist twice")
	result.changes.created[0].kind="animation-only"
	ck(r==before,"presentation data cannot mutate committed inventory")
	plan.run.items[0].kind="preview-only"
	result.output.paid_cost=999
	ck(r==before,"committed state shares no mutable piece dictionaries with plan or response")
	# A migration geometry instance cannot contaminate live geometry.
	var historical=I.new();var original=inv.cells(inv.make_piece(recipe.base,"shape"))
	historical.footprint_catalogue={recipe.base:C.items[recipe.base].duplicate(true)}
	historical.footprint_catalogue[recipe.base].shape=[[0,0]]
	ck(historical.cells(historical.make_piece(recipe.base,"shape"))==[Vector2i.ZERO] and inv.cells(inv.make_piece(recipe.base,"shape"))==original,"historical geometry stays instance-local")
	# Architecture guards: renderer has no authority over recipes, run or persistence.
	var view=FileAccess.get_file_as_string("res://scripts/crafting/inline_craft.gd")
	for forbidden in ["g.run","g.inventory","g.storage","commit_ready(","transact(","craft.gd"]:
		ck(not view.contains(forbidden),"view has no domain/write dependency: "+forbidden)
	for file in ["recipe_book","craft_rules","craft_placement","item_space"]:
		var source=preload("res://tests/fixtures/layout.gd").read("res://scripts/"+file+".gd")
		for forbidden in ["game.gd","inventory.gd","FileAccess","storage.gd","Node2D"]:
			ck(not source.contains(forbidden),file+" does not depend on "+forbidden)
	print("CRAFT_BOUNDARIES_V77 ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
