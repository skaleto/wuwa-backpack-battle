extends SceneTree
## Historical rules: use the exact V116 catalogue before intentional V124 redesigns.
const HISTORICAL=preload("res://tests/fixtures/catalog_fixture_v116.gd")
## Controlled recursive fixtures: exhaustively transact ancestry; not shop reach probability.
const I=preload("res://tests/fixtures/recruitment_fixture_v113.gd")
const C=preload("res://scripts/data/catalog.gd")
const F=preload("res://scripts/crafting/craft.gd")
const FIX=preload("res://tests/fixtures/craft_fixture_v75.gd")
var inv=I.new();var checks=0;var failures=0;var incoming={};var history=[]
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func make_kind(r,kind):
 if not incoming.has(kind):
  var identity=inv.next_identity(r);r.serial=identity.serial
  var p=inv.make_piece(kind,identity.uid);p.paid_cost=int(C.items[kind].v75.cost)
  var fit=inv.first_fit(p,r.items,r.bags)
  ck(not fit.is_empty(),"controlled root fits")
  if fit.is_empty():return {}
  r.items.append(fit);return fit
 var recipe=incoming[kind];var a=make_kind(r,recipe.base);var b=make_kind(r,recipe.materials[0])
 if a.is_empty() or b.is_empty():return {}
 F.place_material(r,kind,a.uid,b.kind,inv)
 var result=F.transact(r,kind,a.uid,inv)
 ck(result.ok and inv.validate_run(r),"recursive actual transaction "+recipe.id)
 if not result.ok:return {}
 history.append({"recipe":recipe.id,"inputs":result.consumed,"output":result.output})
 ck(result.output.paid_cost==int(C.items[kind].v75.cost),"recursive cost provenance "+kind)
 return result.output
func _initialize():
 var saved_catalogue=HISTORICAL.apply()
 for recipe in C.combinations.filter(func(r):return not str(r.id).begins_with("V114_")):incoming[recipe.target]=recipe
 var paths=[]
 for target in incoming:
  var r=FIX.make(inv,target,true);history=[];var result=make_kind(r,target)
  ck(not result.is_empty() and result.kind==target,"ancestry reaches target "+target)
  paths.append({"target":target,"history":history.duplicate(true)})
 var file=FileAccess.open("res://build/qa/gameplay-v75/checks/chains.json",FileAccess.WRITE);file.store_string(JSON.stringify(paths,"\t"));file.close()
 print("CHAINS_V75 [historical V116 catalogue] ",checks," checks, ",failures," failures; ",paths.size()," full ancestries")
 HISTORICAL.restore(saved_catalogue)
 quit(1 if failures else 0)
