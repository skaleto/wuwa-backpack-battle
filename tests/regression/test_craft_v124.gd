extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const C=preload("res://scripts/data/catalog.gd")
const F=preload("res://scripts/crafting/craft.gd")
const H=preload("res://scripts/crafting/craft_handler.gd")
const CAP=preload("res://tests/fixtures/capacity_fixture_v111.gd")
const TARGET="weapon_21020024"
var inv=I.new();var checks=0;var failures=0;var saves=0
func ck(ok,label):
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func saved(_run):saves+=1
func piece(kind,uid,x=0,y=0):
	var item=inv.make_piece(kind,uid);item.x=x;item.y=y;return item
func fixture(wide=true):
	var run=inv.new_run("aemeath",124);run.serial=200;run.shop=[{},{},{},{},{},{}]
	if wide:run.bags=CAP.full_bags(inv)
	run.items=[piece("w_sword","i1"),piece("whiff","i2",0,1),piece("mat_43020011","i3",2,1)]
	run.primary="i1";run.stash=[];return run
func explicit_preview(run,recipe_id):
	return Callable(F,"preview").callv([run,TARGET,"i1",inv,{},recipe_id])
func _initialize():
	var original=C.combinations
	var template=original.filter(func(r):return r.target==TARGET)[0]
	var first=template.duplicate(true);first.id="V124_test_a"
	var second=template.duplicate(true);second.id="V124_test_b";second.base="w_broadblade";second.materials=["nutrition"]
	var alternative=template.duplicate(true);alternative.id="V124_test_c";alternative.materials=["mat_43020011"]
	C.combinations=[first,second,alternative]
	var run=fixture();var before=run.duplicate(true)
	ck(inv.validate_run(run),"legal multi-recipe fixture")
	var automatic=F.preview(run,TARGET,"i1",inv)
	ck(automatic.ok,"multiple recipes to one target accept the selected base")
	ck(automatic.get("recipe_id","")==first.id and automatic.consumed==["i1","i2"],"automatic choice uses first complete adjacent recipe deterministically")
	var other=fixture();other.items=[piece("w_broadblade","i1"),piece("nutrition","i2",0,1)]
	var broad=F.preview(other,TARGET,"i1",inv)
	ck(broad.ok and broad.get("recipe_id","")==second.id and broad.consumed==["i1","i2"],"same target resolves a different exact base kind")
	var only_second=fixture();only_second.items=only_second.items.filter(func(v):return v.uid!="i2")
	var available=F.preview(only_second,TARGET,"i1",inv)
	ck(available.ok and available.get("recipe_id","")==alternative.id and available.consumed==["i1","i3"],"automatic choice skips unavailable first alternative")
	var options=F.display_options(run,inv)
	ck(options.size()==2,"same base and output with distinct ingredients display separate choices")
	ck(options.map(func(v):return v.get("recipe_id","")).has(first.id) and options.map(func(v):return v.get("recipe_id","")).has(alternative.id),"display choices preserve recipe identity")
	var relations=F.relationships(run,inv)
	ck(relations.size()==2 and relations.all(func(v):return v.ready and not v.get("recipe_id","").is_empty()),"both exact alternative relationships can be ready")
	var choices=F.options(only_second,"i1",inv)
	ck(choices.size()==2 and choices.filter(func(v):return v.ok).size()==1,"base options report each alternative availability independently")
	ck(run==before,"all automatic queries leave source state unchanged")
	# Guard calls to the new optional argument so the first red run reports
	# behavioral failures, not parser errors from the old method signatures.
	if automatic.has("recipe_id"):
		check_explicit(run,first,alternative)
		check_stale(run,alternative)
		check_storage(first)
		check_relation_identity(run,first)
	C.combinations=original
	print("CRAFT_V124 ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
func check_explicit(run,first,alternative):
	var before=run.duplicate(true)
	var chosen=explicit_preview(run,alternative.id)
	ck(chosen.ok and chosen.recipe_id==alternative.id and chosen.consumed==["i1","i3"],"explicit alternative binds its precise material instance")
	var missing=run.duplicate(true);missing.items=missing.items.filter(func(v):return v.uid!="i3")
	var absent=explicit_preview(missing,alternative.id)
	ck(not absent.ok and absent.get("recipe_id","")==alternative.id,"missing explicit alternative cannot switch to available recipe")
	ck(not explicit_preview(run,"not-a-recipe").ok,"unknown recipe id is rejected")
	ck(not explicit_preview(run,"V124_test_b").ok,"explicit alternative for another base is rejected")
	var status=Callable(F,"material_status").callv([run,TARGET,"i1",inv,alternative.id])
	ck(status.size()==1 and status[0].kind=="mat_43020011" and status[0].near==1,"explicit material query reflects selected alternative")
	var stored=run.duplicate(true);stored.items=stored.items.filter(func(v):return v.uid!="i3");stored.stash=[piece("mat_43020011","i3")]
	var stored_before=stored.duplicate(true)
	var material=Callable(H,"material_plan").callv([stored,TARGET,"i1","mat_43020011",inv,alternative.id])
	ck(material.ok and material.item.uid=="i3" and material.get("recipe_id","")==alternative.id,"material plan moves the selected recipe ingredient")
	ck(stored==stored_before,"material planning is read-only")
	var automatic_material=H.material_plan(stored,TARGET,"i1","mat_43020011",inv)
	ck(automatic_material.ok and automatic_material.get("recipe_id","")==alternative.id and automatic_material.item.uid=="i3","legacy material placement infers the alternative from the requested ingredient")
	var misplaced=Callable(H,"material_plan").callv([stored,TARGET,"i1","whiff",inv,alternative.id])
	ck(not misplaced.ok and stored==stored_before,"material plan rejects ingredient from another alternative")
	ck(run==before,"explicit queries preserve inventory, RNG, money, identity and catalogue")
	var candidate=F.display_options(run,inv).filter(func(v):return v.recipe_id==alternative.id)[0]
	var result=F.commit_ready(run,candidate,inv,saved)
	ck(result.ok and result.recipe_id==alternative.id,"selected alternative commits through authoritative plan")
	ck(run.items.any(func(v):return v.uid=="i2") and not run.items.any(func(v):return v.uid in ["i1","i3"]),"selected alternative consumes only its exact instances")
	ck(inv.validate_run(run) and saves==1,"chosen recipe persists once with legal state")
	var committed=run.duplicate(true)
	ck(not F.commit_ready(run,candidate,inv,saved).ok and run==committed and saves==1,"duplicate selected recipe confirmation is atomic")
func check_stale(_run,alternative):
	var run=fixture();var candidate=F.display_options(run,inv).filter(func(v):return v.recipe_id==alternative.id)[0]
	var mutated=run.duplicate(true);mutated.items.filter(func(v):return v.uid=="i3")[0].uid="replacement"
	var before=mutated.duplicate(true);var count=saves
	ck(not F.commit_ready(mutated,candidate,inv,saved).ok and mutated==before and saves==count,"same-kind replacement cannot satisfy stale exact confirmation")
	mutated=run.duplicate(true);mutated.items=mutated.items.filter(func(v):return v.uid!="i3");before=mutated.duplicate(true)
	var without_stamp=candidate.duplicate(true);without_stamp.erase("source")
	ck(not F.commit_ready(mutated,without_stamp,inv,saved).ok and mutated==before and saves==count,"even unstamped legacy confirmation cannot switch explicit recipe")
	var tampered=candidate.duplicate(true);tampered.recipe_id="V124_test_a";before=run.duplicate(true)
	ck(not F.commit_ready(run,tampered,inv,saved).ok and run==before and saves==count,"changed recipe id cannot switch the previewed input pair")
	C.combinations=C.combinations.filter(func(v):return v.id!=alternative.id)
	ck(not F.commit_ready(run,candidate,inv,saved).ok and run==before and saves==count,"removed recipe rejects preview even when run stamp is unchanged")
	C.combinations.append(alternative)
func check_storage(first):
	var run=fixture(false);run.items=run.items.filter(func(v):return v.uid!="i3")
	for n in 107:run.stash.append(piece("nutrition","stored"+str(n)))
	var before=run.duplicate(true);var preview=explicit_preview(run,first.id)
	ck(preview.ok and preview.get("destination","")=="stash" and preview.stash_index==107,"selected output falls back to unlimited stash when board cannot fit")
	ck(run==before,"stash fallback preview is read-only")
	var candidate=F.display_options(run,inv)[0];var count=saves
	var result=F.commit_ready(run,candidate,inv,saved)
	ck(result.ok and run.stash.size()==108 and run.items.is_empty() and saves==count+1,"fallback consumes exact inputs and saves once beyond one hundred stored items")
	ck(inv.validate_run(run),"fallback output remains legal")
func check_relation_identity(run,first):
	var same_pair=first.duplicate(true);same_pair.id="V124_test_same_pair"
	C.combinations.append(same_pair)
	var fresh=fixture();var before=fresh.duplicate(true)
	var facts=F.recipe_relations(fresh,inv).filter(func(v):return v.material_uid=="i2")
	ck(facts.size()==2 and facts[0].recipe_id!=facts[1].recipe_id,"relationship identity includes recipe id even for identical inputs and target")
	var pair=F.pair_recipes(fresh,fresh.items[0],fresh.items[1],inv)
	ck(pair.size()==2 and pair.all(func(v):return not v.get("recipe_id","").is_empty()),"pair queries preserve distinct recipe ids")
	ck(F.display_options(fresh,inv).size()==3,"display deduplication retains alternative recipe identity")
	ck(fresh==before,"relationship and display queries have no side effects")
