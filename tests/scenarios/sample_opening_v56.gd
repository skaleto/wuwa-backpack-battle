extends SceneTree
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const B=preload("res://scripts/battle/battle.gd")
const F=preload("res://scripts/crafting/craft.gd")
var inv=I.new()
var battle=B.new()
var opponents={}
var records=[]
func _initialize():
 var out="before" if "--before" in OS.get_cmdline_user_args() else "after"
 var holdout="--holdout" in OS.get_cmdline_user_args()
 for leader in C.characters:
  for seed_id in 12:
   for policy in ["upgrade","echo"]:play(leader,(1009+seed_id*41) if holdout else (101+seed_id*37),policy)
 var summary={}
 for leader in C.characters:
  var rows=records.filter(func(v):return v.leader==leader)
  summary[leader]={"battles":rows.size(),"wins":rows.filter(func(v):return v.winner==1).size(),"crafted":rows.filter(func(v):return v.crafted).size()}
 var f=FileAccess.open("res://build/qa/ui-v56/"+out+("/opening-holdout.json" if holdout else "/opening-samples.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"method":"6 leaders x 12 fixed seeds x 2 simple shopping policies x first 3 rounds. Actual random offers and prices; no recipe-page direct purchases. This is scripted sampling, not a balance verdict.","summary":summary,"rows":records},"\t"));f.close()
 print("V56 OPENING ",records.size()," battles ",JSON.stringify(summary));quit()
func needs(r:Dictionary)->Array:
 var owned=r.items+r.stash;var result=[]
 for recipe in C.combinations:
  if recipe.round_min>r.round or not inv.signature_owned(r,recipe.target):continue
  if not owned.any(func(v):return F.accepts_base(recipe,v.kind)):continue
  for k in recipe.materials:
   if k not in result and owned.filter(func(v):return v.kind==k).size()<recipe.materials.count(k):result.append(k)
 return result
func buy(r:Dictionary,index:int,policy:String)->bool:
 if r.shop[index].is_empty():return false
 var k=r.shop[index].kind;var d=C.items[k]
 if C.is_tag(k,"bag"):
  if inv.coverage(r.bags).size()>=6+r.round*4:return false
 elif C.is_tag(k,"craft_material"):
  if policy!="upgrade" or k not in needs(r):return false
 elif (r.items+r.stash).any(func(v):return v.kind==k):return false
 elif C.is_tag(k,"weapon"):return false
 elif C.is_tag(k,"material"):return false
 var p=inv.make_piece(k,"candidate");var fit=inv.first_fit(p,r.items,r.bags)
 if fit.is_empty():
  return inv.buy(r,index) if C.is_tag(k,"craft_material") else false
 return not inv.purchase_at(r,index,fit,"board").is_empty()
func craft(r:Dictionary)->bool:
 var base=inv.primary_weapon(r)
 for recipe in C.combinations:
  if recipe.round_min>r.round or not F.accepts_base(recipe,base.kind) or not inv.signature_owned(r,recipe.target):continue
  if not recipe.materials.all(func(k):return (r.items+r.stash).filter(func(v):return v.kind==k).size()>=recipe.materials.count(k)):continue
  var next=r.duplicate(true)
  for item in next.items.duplicate(true):
   if item.uid!=base.uid and item.kind not in recipe.materials:inv.stash(next,item)
  for k in recipe.materials:F.place_material(next,recipe.target,base.uid,k,inv)
  var tx=F.transact(next,recipe.target,base.uid,inv)
  if not tx.ok:continue
  for item in next.stash.duplicate(true):
   var fit=inv.first_fit(item,next.items,next.bags)
   if not fit.is_empty():inv.place(next,fit)
  r.clear();r.merge(next,true);return true
 return false
func play(leader:String,seed_value:int,policy:String):
 var r=inv.new_run(leader,seed_value)
 for round_index in 3:
  var did_craft=false
  for shelf in 2:
   buy(r,5,policy);buy(r,1,policy)
   for index in [2,4,0,3]:buy(r,index,policy)
   if policy=="upgrade":did_craft=craft(r) or did_craft
   if shelf==0:inv.refresh(r,true)
  assert(inv.validate_run(r))
  var key=str(r.round)+":"+str(posmod(seed_value+round_index*7,31))
  if not opponents.has(key):opponents[key]=inv.practice(r.round,posmod(seed_value+round_index*7,31))
  var fight=battle.simulate(r,opponents[key],seed_value,false)
  records.append({"leader":leader,"seed":seed_value,"policy":policy,"round":r.round,"winner":fight.winner,"crafted":did_craft,"gold":r.gold,"items":r.items.map(func(v):return v.kind)})
  r.phase="result";inv.finish(r,int(fight.winner))
