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
  var r=FIX.make(inv,recipe.target);ck(not r.is_empty(),"eligible target fixture")
  if r.is_empty():continue
  var base=inv.make_piece(recipe.base,"i1");base.paid_cost=2;r.items=[base]
  r.primary="i1" if C.is_tag(base.kind,"weapon") else ""
  var mat=inv.make_piece(recipe.materials[0],"i2");mat.paid_cost=3;r.stash=[mat];r.golden_acquired=C.is_tag(base.kind,"golden") or C.is_tag(mat.kind,"golden")
  ck(F.ready_options(r,inv).is_empty(),"stash does not advertise ready "+recipe.id)
  ck(F.place_material(r,recipe.target,"i1",mat.kind,inv).ok,"actual adjacent placement "+recipe.id)
  var before=r.duplicate(true);var matching=F.ready_options(r,inv).filter(func(v):return v.target==recipe.target)
  ck(r==before and matching.size()==1,"pure single exact preview "+recipe.id)
  if matching.is_empty():continue
  var entry=matching[0]
  ck(not F.transact(r,recipe.target,"i1",inv,{"x":8,"y":5,"rotation":0}).ok and r==before,"invalid output atomic "+recipe.id)
  var stale=r.duplicate(true);stale.items[1].x=6;stale.items[1].y=5;var stale_before=stale.duplicate(true)
  ck(not F.commit_ready(stale,entry,inv).ok and stale==stale_before,"moved partner rejects stale preview "+recipe.id)
  var gated=r.duplicate(true);gated.round=maxi(1,recipe.round_min-1)
  if recipe.round_min>1:
   # Some legacy fixtures move recruitment from round 10 into the past too.
   # Preserve rejection of those invalid saves; legal early inputs can craft.
   var early=F.preview(gated,recipe.target,"i1",inv)
   ck(early.ok if inv.validate_run(gated) else not early.ok and early.reason=="存档状态异常","V80 early craft respects state validity "+recipe.id)
  var result=F.commit_ready(r,entry,inv)
  ck(result.ok and r.items.size()==1 and r.items[0]==entry.output and r.gold==before.gold,"exact output no fee "+recipe.id)
  ck(inv.validate_run(r) and r.items[0].paid_cost==5,"legal paid lineage "+recipe.id)
  if C.is_tag(recipe.target,"weapon"):ck(r.primary==r.items[0].uid,"primary rebound "+recipe.id)
  before=r.duplicate(true)
  ck(not F.commit_ready(r,entry,inv).ok and r==before,"double commit atomic "+recipe.id)
 print("CRAFT_V75 ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
