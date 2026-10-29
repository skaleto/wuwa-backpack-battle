extends SceneTree
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const F=preload("res://scripts/crafting/craft.gd")
var inv=I.new()
var checks=0
var failures=0
var report={"samples":0,"material_shelves":0,"needed_material_shelves":0,"bags":{}}
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
 for leader in C.characters:
  for seed_value in range(24):
   var r=inv.new_run(leader,seed_value*37+13);r.round=2
   var needed=[]
   for recipe in C.combinations:
    if F.accepts_base(recipe,C.characters[leader].starter) and recipe.round_min<=2:
     for kind in recipe.materials:
      if kind not in needed:needed.append(kind)
   for n in 3:
    inv.refresh(r,true);report.samples+=1
    if r.shop.any(func(o):return C.is_tag(o.get("kind",""),"craft_material")):report.material_shelves+=1
    if r.shop.any(func(o):return o.get("kind","") in needed):report.needed_material_shelves+=1
    var bag=r.shop[5].get("kind","");report.bags[bag]=int(report.bags.get(bag,0))+1
    check(inv.validate_run(r),"refreshed run validates")
 check(report.needed_material_shelves>=report.samples*.8,"usable ingredients appear reliably with a missing starter upgrade")
 check(report.bags.has("strip") and report.bags.has("corner"),"refresh exposes more than square bags")
 var r=inv.new_run("encore",50)
 check("strip" in inv.available_bags(r) and "corner" in inv.available_bags(r),"small alternative shapes are available in opening round")
 var offered=r.shop[5].kind
 inv.refresh(r,true)
 check(r.shop[5].kind!=offered,"unlocked bag offer rotates on refresh")
 r.shop[5]={};inv.refresh(r,true)
 check(not r.shop[5].is_empty(),"purchased bag slot replenishes")
 r.round=2;r.shop[0].locked=true
 var locked=r.shop[0].duplicate(true);var equal=r.duplicate(true)
 inv.refresh(r,true);inv.refresh(equal,true)
 check(r==equal and r.shop[0]==locked,"determinism and player locks preserved")
 var material="mat_43020031"
 check(inv.shop_eligible(r,material),"craft ingredients can be purchased through normal shop")
 r.shop[2]={"kind":material,"locked":false};var gold=r.gold
 check(inv.buy(r,2) and r.gold==gold-C.items[material].price and r.stash[-1].kind==material,"normal material purchase charges once and retains valid ownership")
 var out="before" if "--before" in OS.get_cmdline_user_args() else "after"
 var f=FileAccess.open("res://build/qa/ui-v56/"+out+"/supply.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
 print("V56 SUPPLY ",checks," checks ",failures," failures ",JSON.stringify(report));quit(1 if failures else 0)
