extends SceneTree
## Historical rules: use the exact V116 catalogue before intentional V124 redesigns.
const HISTORICAL=preload("res://tests/fixtures/catalog_fixture_v116.gd")
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://tests/fixtures/recruitment_fixture_v113.gd")
const F=preload("res://scripts/crafting/craft.gd")
const SUP=preload("res://scripts/party/supports.gd")
var inv=I.new()
var failures=0
var checks=0
func ck(ok,label):
	checks+=1
	if not ok: failures+=1;printerr("FAIL ",label)
func _initialize():
	var saved_catalogue=HISTORICAL.apply()
	ck(C.combinations.filter(func(r):return not str(r.id).begins_with("V114_")).size()==136,"all approved recipes")
	ck(FileAccess.file_exists("res://data/compat/design/v92.json"),"persisted approved design")
	if not FileAccess.file_exists("res://data/compat/design/v92.json"):quit(1);return
	var spec=JSON.parse_string(FileAccess.get_file_as_string("res://data/compat/design/v92.json"))
	var star_revision=JSON.parse_string(FileAccess.get_file_as_string("res://data/compat/design/v101.json")).stars
	var space_revision=preload("res://scripts/data/space_catalog_v116.gd").CHANGES
	ck(spec.items.size()==197,"197 numeric profiles")
	var art=JSON.parse_string(FileAccess.get_file_as_string("res://assets/manifest.json"))
	var pairs={};var outputs={}
	for r in C.combinations.filter(func(r):return not str(r.id).begins_with("V114_")):
		var p=[r.base,r.materials[0]];p.sort();var key=JSON.stringify(p)
		ck(not pairs.has(key) and not outputs.has(r.target),"unique recipe "+r.id);pairs[key]=true;outputs[r.target]=r
		ck(r.materials.size()==1 and r.base!=r.materials[0] and r.fee==0,"two different pieces, no fee")
		ck(r.round_min==spec.items[r.target].dependency_round,"dependency gate")
		ck(spec.items[r.target].cost==spec.items[r.base].cost+spec.items[r.materials[0]].cost,"recursive investment")
	for k in spec.items:
		var x=C.items[k];var n=spec.items[k]
		var expected=n.duplicate(true)
		if star_revision.has(k):
			var revised=star_revision[k]
			expected.stars=revised.layout;expected.star=revised.text;expected.starText=revised.text;expected.material_effect=revised.effect
		if space_revision.has(k):
			for field in ["shape","stars"]:
				if expected.has(field):expected[field]=space_revision[k][field].duplicate(true)
			if expected.has("space"):expected.space=space_revision[k].shape.size()
		ck(x.has("v75") and x.v75==expected,"exact approved profile plus explicit V101 stars and V116 space revision "+k)
		ck(x.damage==n.damage and x.cooldown==n.cd and x.stamina==n.stamina,"base numbers "+k)
		ck(FileAccess.file_exists("res://"+art.items[k].path),"existing illustration "+k)
		for p in x.stars:ck(p not in x.shape,"stars outside footprint "+k)
		var core=n.capabilities.filter(func(t):return t in ["heal","shield","noise","frost"])
		ck(core.size()<=2,"bounded utility "+k)
	for k in spec.legacy:ck(not C.items[k].has("v75") and C.items[k].get("v60",{}).get("active",false),"legacy retained "+k)
	var reachable=0
	for recipe in C.combinations.filter(func(r):return not str(r.id).begins_with("V114_")):
		var chosen={}
		for leader in C.selectable_leaders():
			var run=inv.new_run(leader,131);run.round=10;run.roster=[];run.items=[];run.stash=[];run.primary="";run.bags=[]
			var def=C.items[recipe.target]
			if def.get("strict_signature",false):
				for owner in def.signature_owner_ids:
					if owner==C.characters[leader].roster_id:break
					if C.roster.has(owner) and C.roster[owner].element==C.characters[leader].element and C.roster[owner].released:run.roster.append(owner);break
			if C.is_tag(recipe.target,"weapon") and def.weapon_type not in SUP.unlocked_types(run):
				for role in C.roster:
					if C.roster[role].released and C.roster[role].element==C.characters[leader].element and C.roster[role].weapon_type==def.weapon_type and role not in run.roster and role!=C.characters[leader].roster_id:run.roster.append(role);break
			if not inv.craft_unlocked(run,recipe.target):continue
			run.recruited_round=10 if not run.roster.is_empty() else 0
			for y in range(0,6,2):
				for x in range(0,8,2):
					var bag=inv.make_piece("pouch","b%d_%d"%[x,y]);bag.x=x;bag.y=y;run.bags.append(bag)
			var base=inv.make_piece(recipe.base,"i1");base.paid_cost=2;run.items=[base]
			if C.is_tag(base.kind,"weapon"):run.primary=base.uid
			var mat=inv.make_piece(recipe.materials[0],"i2");mat.paid_cost=3;run.stash=[mat];run.serial=2
			run.golden_acquired=C.is_tag(base.kind,"golden") or C.is_tag(mat.kind,"golden")
			chosen=run;break
		if chosen.is_empty():continue
		reachable+=1
		ck(inv.validate_run(chosen),"transaction fixture "+recipe.id)
		ck(F.place_material(chosen,recipe.target,"i1",recipe.materials[0],inv).ok,"adjacent placement "+recipe.id)
		var result=F.transact(chosen,recipe.target,"i1",inv)
		ck(result.ok,"actual forge "+recipe.id+" "+result.reason)
		if result.ok:ck(result.output.paid_cost==5 and inv.validate_run(chosen),"cost preservation "+recipe.id)
	print("TRANSACTION_REACHABLE_V75 ",reachable," / ",C.combinations.size()," direct outputs for selectable leaders")
	print("CONTENT_V75 [historical V116 catalogue] ",checks," checks, ",failures," failures")
	HISTORICAL.restore(saved_catalogue)
	quit(1 if failures else 0)
