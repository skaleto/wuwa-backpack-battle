extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const C=preload("res://scripts/data/catalog.gd")
const F=preload("res://scripts/crafting/craft.gd")
const FIX=preload("res://tests/fixtures/craft_fixture_v75.gd")
var inv=I.new();var checks=0;var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
 for recipe in C.combinations:
  var r=FIX.make(inv,recipe.target)
  # Earliest legal recruitment history; no invalid future-round metadata.
  r.round=1 if r.roster.is_empty() else r.roster.size()+1
  r.recruited_round=0 if r.roster.is_empty() else r.round;r.shop=[{},{},{},{},{},{}]
  var base=inv.make_piece(recipe.base,"i1");var mat=inv.make_piece(recipe.materials[0],"i2")
  r.items=[base];r.stash=[mat];r.primary=base.uid if C.is_tag(base.kind,"weapon") else ""
  r.golden_acquired=C.is_tag(base.kind,"golden") or C.is_tag(mat.kind,"golden")
  ck(inv.validate_run(r),"legal early inventory "+recipe.id)
  ck(F.place_material(r,recipe.target,base.uid,mat.kind,inv).ok,"early adjacency "+recipe.id)
  var before=r.duplicate(true);var plan=F.preview(r,recipe.target,base.uid,inv)
  ck(plan.ok and r==before,"all owned recipes independent of supply round "+recipe.id)
  ck(F.relationships(r,inv).any(func(v):return v.target==recipe.target and v.ready),"early relation matches transaction "+recipe.id)
  ck(F.transact(r,recipe.target,base.uid,inv).ok and inv.validate_run(r),"early output valid "+recipe.id)
 var r=inv.new_run("aemeath",19)
 ck(not inv.shop_eligible(r,"weapon_21020024") and not inv.shop_eligible(r,"weapon_21020015"),"round one does not refresh later equipment")
 r.round=2
 ck(inv.shop_eligible(r,"weapon_21020024") and not inv.shop_eligible(r,"weapon_21020015"),"round two supplies intermediate sword but not final sword")
 r.round=5
 ck(inv.shop_eligible(r,"weapon_21020015"),"final sword direct supply opens on existing round five schedule")
 var source=FileAccess.get_file_as_string("res://scripts/crafting/recipe_tree.gd")
 ck(not '第%d回合起' in source,"recipe card removes obsolete craft round text")
 print("CRAFT_SUPPLY_V80 ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
