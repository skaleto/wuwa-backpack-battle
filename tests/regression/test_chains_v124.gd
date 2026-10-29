extends SceneTree
## Controlled acquired leaves, not a shop-probability test. Every current recipe
## is forced once as a chain's final edge; its inputs are recursively crafted.
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const F=preload("res://scripts/crafting/craft.gd")
const CAP=preload("res://tests/fixtures/capacity_fixture_v111.gd")
var inv=I.new()
var incoming={}
var by_id={}
var lineage={}
var leaf_paid={}
var seen={}
var checks=0
var failures=0
var transactions=0
func ck(ok:bool,label:String)->bool:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
 return ok
func fixture(wide:bool=true)->Dictionary:
 var run=inv.new_run("aemeath",124);run.round=10;run.items=[];run.stash=[];run.primary="";run.serial=100;run.shop=[{},{},{},{},{},{}]
 if wide:run.bags=CAP.full_bags(inv)
 lineage.clear();leaf_paid.clear()
 return run
func leaf(run:Dictionary,kind:String)->Dictionary:
 var identity=inv.next_identity(run);run.serial=identity.serial
 var item=inv.make_piece(kind,identity.uid)
 # Deliberately varied recorded acquisition costs test lineage rather than
 # reproducing any profile's historical recursive cost estimate.
 item.paid_cost=int(C.items[kind].price)+int(run.serial)%3;item.cost_basis="actual"
 run.stash.append(item);lineage[item.uid]=[item.uid];leaf_paid[item.uid]=item.paid_cost
 if C.is_tag(kind,"golden"):run.golden_acquired=true
 return item
func make_kind(run:Dictionary,kind:String,forced_id:String="",stack:Array=[])->Dictionary:
 if not ck(kind not in stack,"ancestry terminates "+kind):return {}
 if not incoming.has(kind):return leaf(run,kind)
 var recipe=by_id[forced_id] if not forced_id.is_empty() else incoming[kind][0]
 var base=make_kind(run,recipe.base,"",stack+[kind])
 var material=make_kind(run,recipe.materials[0],"",stack+[kind])
 if base.is_empty() or material.is_empty():return {}
 return forge(run,recipe,base,material)
func place_pair(run:Dictionary,base:Dictionary,material:Dictionary)->bool:
 for item in run.items.duplicate(true):
  if not inv.stash(run,item):return false
 var fit=inv.first_fit(base,run.items,run.bags)
 if fit.is_empty() or not inv.place(run,fit):return false
 for rotation in 4:
  for y in inv.HEIGHT:
   for x in inv.WIDTH:
    var moved=material.duplicate(true);moved.x=x;moved.y=y;moved.rotation=rotation
    if inv.adjacent(fit,moved) and inv.can_place(moved,run.items,run.bags):return inv.place(run,moved)
 return false
func forge(run:Dictionary,recipe:Dictionary,base:Dictionary,material:Dictionary)->Dictionary:
 if not ck(place_pair(run,base,material),"exact acquired inputs can be placed "+recipe.id):return {}
 var before=run.duplicate(true)
 var roots=lineage[base.uid]+lineage[material.uid]
 var expected_paid=roots.reduce(func(total,uid):return total+int(leaf_paid[uid]),0)
 var others=(before.items+before.stash).filter(func(p):return p.uid not in [base.uid,material.uid])
 var result=F.transact(run,recipe.target,base.uid,inv,{},Callable(),str(recipe.id))
 if not ck(result.ok,"continuous ancestor transaction "+recipe.id+" "+str(result.get("reason",""))):return {}
 transactions+=1;seen[recipe.id]=true
 ck(result.recipe_id==recipe.id and result.output.kind==recipe.target,"exact requested recipe and target "+recipe.id)
 ck(result.consumed==[base.uid,material.uid],"only selected ancestor instances consumed "+recipe.id)
 ck(result.output.paid_cost==expected_paid and result.output.paid_cost==int(base.paid_cost)+int(material.paid_cost),"paid lineage equals acquired leaf costs "+recipe.id)
 ck(result.output.cost_basis=="actual","recorded cost basis survives complete chain "+recipe.id)
 ck(run.gold==before.gold and run.seed==before.seed,"chain has no fee or hidden RNG "+recipe.id)
 ck(others.all(func(p):return inv.find_piece(run,p.uid)==p),"unrelated acquired pieces preserved "+recipe.id)
 ck((run.items+run.stash).size()==(before.items+before.stash).size()-1 and inv.validate_run(run),"one legal output replaces exact two inputs "+recipe.id)
 lineage[result.output.uid]=roots
 return result.output
func overflow_chain()->void:
 var run=fixture(false)
 for index in 107:run.stash.append(inv.make_piece("nutrition","retained"+str(index)))
 var retained=run.stash.duplicate(true)
 var output=make_kind(run,"weapon_21020024","P009")
 if not ck(not output.is_empty(),"real P009 ancestry completes in small starting bag"):return
 ck(run.items.is_empty() and run.stash.size()==108 and inv.find_piece(run,output.uid)==output,"four-cell output overflows into the 108th stored slot")
 ck(retained.all(func(p):return inv.find_piece(run,p.uid)==p),"overflow preserves all 107 unrelated stored pieces")
 # A legitimately owned capacity fixture is placed by the public transaction;
 # then the same stored intermediate is consumed by a real new V124 branch.
 var bag=leaf(run,"pouch");bag=bag.duplicate(true);bag.x=3;bag.y=0
 if not ck(inv.place(run,bag),"owned capacity extends the bag through public placement"):return
 var material=make_kind(run,"mat_43020051")
 var next=forge(run,by_id.V124_02,output,material)
 ck(not next.is_empty() and inv.find_piece(run,output.uid).is_empty(),"stored ancestor continues through exact V124_02")
 ck(run.stash.size()==107 and retained.all(func(p):return inv.find_piece(run,p.uid)==p),"continued chain preserves unlimited unrelated storage")
func _initialize()->void:
 # Frozen prior rules; V125 replacements covered by ecosystem suites.
 preload("res://tests/fixtures/catalog_fixture_v124.gd").apply()
 for recipe in C.combinations:
  by_id[recipe.id]=recipe
  if not incoming.has(recipe.target):incoming[recipe.target]=[]
  incoming[recipe.target].append(recipe)
 ck(C.combinations.size()==165 and by_id.size()==165,"all 165 current recipe identities retained")
 for recipe in C.combinations:
  var run=fixture();var result=make_kind(run,recipe.target,str(recipe.id))
  ck(not result.is_empty() and result.kind==recipe.target,"full ancestor path reaches forced edge "+recipe.id)
 ck(seen.size()==165 and C.combinations.all(func(r):return seen.has(r.id)),"every current edge exercised in a continuous acquired lineage")
 overflow_chain()
 print("CHAINS_V124 ",checks," checks, ",failures," failures; ",seen.size()," recipe identities, ",transactions," continuous transactions")
 quit(1 if failures else 0)
