extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const C=preload("res://scripts/data/catalog.gd")
var inv=I.new()
var checks=0
var failures=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
 for n in range(1,11):
  for seed_value in [0,7,13]:
   var g=inv.practice(n,seed_value)
   check(inv.validate_ghost(g),"valid opponent round "+str(n))
   check(g.practice_budget==9+8*(n-1) and g.practice_spend+g.practice_unspent==g.practice_budget,"paid opponent budget reconciles")
   if n<=3:
    check(g==inv.practice(n,seed_value),"opponent deterministic independently of player gear")
    for row in g.practice_ledger:
     if row.purpose in ["purchase","capacity","craft_material"]:
      check(row.get("source","")=="shop" and row.gold==int(C.items[row.kind].price),"opening gear bought from actual shelf at public price")
     if row.purpose=="craft":
      check(row.round>=2+posmod(seed_value,3) and row.get("source","")=="owned_materials","opening crafts consume owned material at the seeded planning pace")
 print("V56 PRACTICE ",checks," checks ",failures," failures");quit(1 if failures else 0)
