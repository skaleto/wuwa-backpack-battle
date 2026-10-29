extends SceneTree
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const B=preload("res://scripts/battle/battle.gd")
const SHOP=preload("res://scripts/shop/shop_v75.gd")
const P=preload("res://scripts/shop/practice_budget.gd")
var inv=I.new();var report={"starters":[],"pairs":[],"controlled":[],"shop":[],"practice":[]}
func _initialize():call_deferred("audit")
func duel(a,b):
 var result=B.new().simulate(a,b,31,false)
 return {"winner":result.winner,"duration":result.duration,"damage":[result.totals[0].damage,result.totals[1].damage],"heal":[result.totals[0].heal,result.totals[1].heal],"shield":[result.totals[0].shield,result.totals[1].shield],"charge_used":result.events.filter(func(e):return e.kind=="charge" and e.value<0).size(),"states":result.frames[-1].sides}
func outfitted(leader,extras:Array,round_number:int=1):
 var r=inv.new_run(leader,19);r.round=round_number;r.shop=[{},{},{},{},{},{}];r.serial=100
 for kind in extras:
  var p=inv.make_piece(kind,"extra"+str(r.items.size()+r.bags.size()))
  var fit=inv.first_fit(p,r.items,r.bags)
  if fit.is_empty():return {}
  if C.is_tag(kind,"bag"):r.bags.append(fit)
  else:r.items.append(fit)
 return r if inv.validate_run(r) else {}
func audit():
 var leaders=C.selectable_leaders()
 for leader in leaders:
  var r=inv.new_run(leader,19);var ctx=B.new().begin(r,r,31)
  report.starters.append({"leader":leader,"items":r.items.map(func(i):return i.kind),"stash":r.stash.map(func(i):return i.kind),"used_cells":r.items.reduce(func(n,i):return n+inv.cells(i).size(),0),"state":ctx.states[0]})
  for other in leaders:report.pairs.append({"a":leader,"b":other,"result":duel(r,inv.new_run(other,19))})
  for round_number in range(1,4):
   r.round=round_number
   var data=SHOP.facts(r,inv);var slots=[]
   for slot in 5:
    var pool=SHOP.pool(data,slot);var cost=0.0;var count=pool.size();var price_bins={};var dead=0.0
    for kind in pool:
     var price=int(C.items[kind].price);cost+=pool[kind]*price;price_bins[str(price)]=float(price_bins.get(str(price),0))+pool[kind]
     if C.is_tag(kind,"craft_material"):dead+=pool[kind]
    slots.append({"slot":slot,"count":count,"mean_price":cost,"price_probabilities":price_bins,"material_probability":dead})
   report.shop.append({"leader":leader,"round":round_number,"slots":slots})
 for additions in [[],["whiff"],["turtle"],["pouch","whiff"],["pouch","whiff","turtle"],["pouch","medical","whiff"]]:
  for other in ["hsin","suisui"]:
   var a=outfitted("aemeath",additions);var b=outfitted(other,additions)
   report.controlled.append({"other":other,"extras":additions,"extra_cost":additions.reduce(func(n,k):return n+int(C.items[k].price),0),"fits_both":not a.is_empty() and not b.is_empty(),"result":duel(a,b) if not a.is_empty() and not b.is_empty() else {}})
 report.equal_crafts=[]
 for blade_material in ["mat_43020011","whiff"]:
  for other in ["hsin","suisui"]:
   for rectifier_material in ["mat_43020021","tea"]:
    var left=outfitted("aemeath",["pouch",blade_material]);var right=outfitted(other,["pouch",rectifier_material])
    if left.is_empty() or right.is_empty():continue
    P.craft_owned(inv,left);P.craft_owned(inv,right)
    report.equal_crafts.append({"other":other,"blade_material":blade_material,"rectifier_material":rectifier_material,"extra_cost_each":int(C.items.pouch.price)+int(C.items[blade_material].price),"a":left.items.map(func(i):return i.kind),"b":right.items.map(func(i):return i.kind),"result":duel(left,right)})
 # Weapon-only counterfactual: same leader, no opening supply; rectifier is not offered to this leader.
 var a=inv.new_run("aemeath",19);a.items=[inv.make_piece("w_sword","i1")];a.primary="i1";a.stash=[]
 var b=a.duplicate(true);b.items=[inv.make_piece("w_rectifier","i1")]
 report.weapon_only=duel(a,b)
 report.neutral_crafts=[]
 a.bags=[];b.bags=[]
 for x in [0,3]:
  var bag=inv.make_piece("satchel","b"+str(x));bag.x=x;a.bags.append(bag);b.bags.append(bag.duplicate(true))
 for sword in ["weapon_21020044","weapon_21020024"]:
  for rectifier in ["weapon_21050104","weapon_21050044"]:
   a.items=[inv.make_piece(sword,"i1")];b.items=[inv.make_piece(rectifier,"i1")]
   report.neutral_crafts.append({"a":sword,"b":rectifier,"result":duel(a,b)})
 print("controlled done")
 for round_number in range(1,4):
  for seed_value in range(31):
   var r=P.make_run(inv,round_number,seed_value)
   report.practice.append({"round":round_number,"seed":seed_value,"leader":r.leader,"gold":r.gold,"spent":r.practice_spend,"items":r.items.map(func(i):return i.kind),"capacity":inv.coverage(r.bags).size(),"ledger":r.practice_ledger})
  print("practice round ",round_number)
 var save=JSON.parse_string(FileAccess.get_file_as_string("user://run.json"))
 report.saved_history=[]
 if save is Dictionary:
  for h in save.get("history",[]):
   if int(h.round)>3:continue
   var row={"round":h.round,"winner":h.winner,"duration":h.duration,"items":h.build.items.map(func(i):return {"kind":i.kind,"paid_cost":i.get("paid_cost",0)}),"totals":h.totals,"matching_practice":[],"opponent_outcomes":{"wins":0,"draws":0,"losses":0}}
   for seed_value in range(31):
    var enemy=P.make_run(inv,int(h.round),seed_value);var result=B.new().simulate(h.build,enemy,31,false)
    row.opponent_outcomes["wins" if result.winner==1 else "losses" if result.winner==-1 else "draws"]+=1
    if result.winner!=int(h.winner) or not is_equal_approx(result.duration,float(h.duration)):continue
    if not is_equal_approx(result.totals[0].damage,float(h.totals[0].damage)) or not is_equal_approx(result.totals[1].damage,float(h.totals[1].damage)):continue
    if not is_equal_approx(result.totals[1].shield,float(h.totals[1].shield)):continue
    row.matching_practice.append({"seed":seed_value,"leader":enemy.leader,"items":enemy.items.map(func(i):return {"kind":i.kind,"paid_cost":i.get("paid_cost",0)}),"bags":enemy.bags.map(func(i):return i.kind),"spent":enemy.practice_spend,"ledger":enemy.practice_ledger})
   report.saved_history.append(row)
 var out=FileAccess.open("res://build/qa/balance-v83/after.json",FileAccess.WRITE);out.store_string(JSON.stringify(report));out.close();print("AUDIT COMPLETE");quit()
