extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const C=preload("res://scripts/data/catalog.gd")
const SHOP=preload("res://scripts/shop/shop_v75.gd")
var inv=I.new();var checks=0;var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func tier_sum(distribution:Dictionary,tier:int)->float:
 var total=0.0
 for k in distribution:
  if int(C.items[k].v75.tier)==tier:total+=distribution[k]
 return total
func _initialize():
 var r=inv.new_run("aemeath",19,"focused")
 ck(not inv.shop_eligible(r,"weapon_21020015"),"high-quality direct offers unavailable at opening")
 r.round=3
 ck(inv.shop_eligible(r,"aero_coin") and inv.shop_eligible(r,"contract"),"default supply connects echo and final recipe materials")
 for leader in C.selectable_leaders():
  r=inv.new_run(leader,19,"focused")
  for rn in [1,2,3,5,8,11]:
   r.round=rn
   var facts=SHOP.facts(r,inv)
   for slot in 5:
    var d=SHOP.pool(facts,slot)
    ck(not d.is_empty() and absf(d.values().reduce(func(a,b):return a+b,0.0)-1.0)<.00001,"normalized real offers %s r%d slot%d"%[leader,rn,slot])
    ck(d.keys().all(func(k):return int(C.items[k].v75.tier)<5 and not C.items[k].v75.craft_only),"final items never sold directly")
   var weapon=SHOP.ordinary_pool(facts,0);var echo=SHOP.ordinary_pool(facts,1)
   if rn==1:ck(tier_sum(weapon,1)>.999 and tier_sum(echo,1)>.999,"opening remains basic")
   if rn>=3:ck(tier_sum(weapon,2)>0 and tier_sum(weapon,3)>0,"real middle quality weapon supply "+leader)
   if rn>=5:ck(tier_sum(weapon,4)>0 and tier_sum(echo,4)>0,"real high quality category supply "+leader)
   if rn==11:ck(tier_sum(weapon,1)>.19 and tier_sum(weapon,4)>.24,"late supply preserves basic ingredients while advancing quality")
 r=inv.new_run("aemeath",19,"focused");r.round=11
 r.stash.append(inv.make_piece("cyan_heron","qa-existing"))
 var missing=SHOP.missing(r,inv)
 ck("contract" in missing,"late missing partner is still offered")
 var ordinary=SHOP.ordinary(r,4,inv);var assisted=SHOP.distribution(r,4,inv)
 ck(float(assisted.get("contract",0))>float(ordinary.get("contract",0)),"missing ingredient receives actual recipe assistance")
 print("SUPPLY_V93 ",checks," checks, ",failures," failures");quit(1 if failures else 0)
