extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const C=preload("res://scripts/data/catalog.gd")
const F=preload("res://scripts/crafting/craft.gd")
const FIX=preload("res://tests/fixtures/craft_fixture_v75.gd")
const BASELINE="res://tests/fixtures/craft_v76_behavior.json"
var inv=I.new()
var fixture_inv=preload("res://scripts/compat/migration_pre_v113_inventory.gd").new()
func visible(value:Dictionary)->Dictionary:
	var result={}
	for key in ["ok","target","reason","materials","consumed","output","saved_cells","run","base_uid","material_uid","uids","ready","adjacent","blocked","valid"]:
		if value.has(key):result[key]=value[key].duplicate(true) if value[key] is Dictionary or value[key] is Array else value[key]
	# V83 changes prices/openings only; normalize the catalogue identity in the
	# copied craft result so all 680 unchanged spatial/material outcomes stay exact.
	if result.has("run") and result.run.get("pool_mode","full")=="full":result.run.erase("pool_mode")
	if result.has("run"):result.run.catalogue_hash=preload("res://scripts/compat/catalogue_fingerprints.gd").text(FileAccess.get_file_as_string("res://data/compat/catalog-v82.json"))
	return result
func _initialize():
	# Frozen prior rules; V125 replacements covered by ecosystem suites.
	preload("res://tests/fixtures/catalog_fixture_v124.gd").apply()
	# V116 deliberately shrinks 27 footprints. This suite verifies the original
	# 680 outcomes with frozen V82 geometry injected into today's craft pipeline;
	# current geometry is separately exercised by content/icon/migration suites.
	var frozen_space=JSON.parse_string(FileAccess.get_file_as_string("res://data/compat/catalog-v82.json")).items
	inv.footprint_catalogue=frozen_space;fixture_inv.footprint_catalogue=frozen_space
	# V124 adds alternate branches and redirects three recipes. The original
	# 680 snapshots describe the frozen 136-recipe forest, not those new rules.
	var saved_recipes=C.combinations.duplicate(true)
	C.combinations.clear()
	C.combinations.append_array(JSON.parse_string(FileAccess.get_file_as_string("res://data/compat/catalog-v82.json")).recipes)
	var records={};var comparison_keys={};var early_cases=0;var invalid_early=0;var failures=0
	for recipe in C.combinations.filter(func(r):return not str(r.id).begins_with("V114_")):
		# V113 changes qualification and the seeded shelf, not material/spatial
		# outcomes. Recreate the frozen input with historical eligibility, then
		# exercise every preview/placement/relationship through current Inventory.
		var r=FIX.make(fixture_inv,recipe.target)
		var base=inv.make_piece(recipe.base,"i1");base.paid_cost=2
		var mat=inv.make_piece(recipe.materials[0],"i2");mat.paid_cost=3
		r.items=[base];r.stash=[mat];r.primary="i1" if C.is_tag(base.kind,"weapon") else ""
		r.golden_acquired=C.is_tag(base.kind,"golden") or C.is_tag(mat.kind,"golden")
		var cases={"stored":r.duplicate(true)}
		F.place_material(r,recipe.target,"i1",mat.kind,inv)
		cases.ready=r.duplicate(true)
		var gated=r.duplicate(true);gated.round=maxi(1,recipe.round_min-1);cases.gated=gated
		var missing=r.duplicate(true);missing.items=missing.items.filter(func(v):return v.uid=="i1");cases.missing=missing
		var blocked=r.duplicate(true);blocked.bags=[];cases.invalid=blocked
		for name in cases:
			var state=cases[name]
			var preview=F.preview(state,recipe.target,"i1",inv)
			var explicit=F.preview(state,recipe.target,"i1",inv,{"x":8,"y":5,"rotation":0})
			var relations=F.relationships(state,inv).map(func(v):return visible(v))
			# V80 explicitly removes round gating. Compare the newly allowed early
			# case to the frozen ready outcome, normalizing only the copied round.
			# Old fixture bytes remain untouched; all other cases keep exact hashes.
			var key=recipe.id+":"+name
			comparison_keys[key]=key
			if name=="gated" and int(recipe.round_min)>1 and inv.validate_run(state):
				early_cases+=1;comparison_keys[key]=recipe.id+":ready"
				if preview.get("ok",false):preview.run.round=r.round
			elif name=="gated" and int(recipe.round_min)>1:
				# Future recruitment makes these old fixtures invalid independently
				# of crafting. Recipe identity still exists; no ready output is legal.
				invalid_early+=1
				var expected_relation={"target":recipe.target,"base_uid":"i1","material_uid":"i2","uids":["i1","i2"],"ready":false,"adjacent":true,"output":{},"blocked":[],"valid":[]}
				if relations!=[expected_relation]:failures+=1;printerr("FAIL invalid early relation ",key)
				relations=[] # Compare the remaining rejection/material facts unchanged.
			records[recipe.id+":"+name]=var_to_str([visible(preview),visible(explicit),relations,F.material_status(state,recipe.target,"i1",inv)]).sha256_text()
	if "--record" in OS.get_cmdline_user_args():
		FileAccess.open(BASELINE,FileAccess.WRITE).store_string(JSON.stringify(records,"\t"));print("RECORDED ",records.size()," V76 cases");quit();return
	var expected=JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
	if records.size()!=680 or expected.size()!=680:failures+=1;printerr("FAIL all 680 frozen outcomes retained")
	for key in records:
		if records[key]!=expected.get(comparison_keys[key]):failures+=1;printerr("FAIL frozen outcome ",key)
	C.combinations.clear();C.combinations.append_array(saved_recipes)
	print("CRAFT_EQUIVALENCE_V77 ",records.size()," cases (",early_cases," early ready outcomes; ",invalid_early," invalid early states retain rejection), ",failures," failures")
	quit(1 if failures else 0)
