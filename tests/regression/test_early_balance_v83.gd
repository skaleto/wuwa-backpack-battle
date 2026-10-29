extends "res://tools/legacy/audit_early_v83.gd"
var checks=0;var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():call_deferred("test")
func test():
 preload("res://tests/fixtures/catalog_fixture_v127.gd").apply() # Historical economic and recipe baseline; V128 has independent procurement coverage.
 var frozen=JSON.parse_string(FileAccess.get_file_as_string("res://data/compat/catalog-v82.json"))
 var space_revision=preload("res://scripts/data/space_catalog_v116.gd").CHANGES
 var core_revision=preload("res://scripts/data/strategy_catalog_v124.gd").spec.cores
 for k in frozen.items:
  for field in ["damage","cooldown","shape","stamina"]:
   var expected=0 if k in ["turtle","echo_butterfly"] and field=="cooldown" else frozen.items[k].get(field)
   if field=="shape" and space_revision.has(k):expected=space_revision[k].shape
   if core_revision.has(k) and field!="shape":expected=core_revision[k]["cd" if field=="cooldown" else field]
   ck(C.items[k].get(field)==expected,"preserved baseline except approved V116 space / V124 twelve cores "+k+":"+field)
 # V124 deliberately redirects only these three old branches; every other
 # original recipe still matches byte-for-byte as structured data.
 var redirected=["P046","P062","P076"]
 var removed=preload("res://scripts/data/family_catalog_v127.gd").spec.remove_recipes
 var unchanged=C.combinations.filter(func(r):return not str(r.id).begins_with("V114_") and not str(r.id).begins_with("V124_") and not str(r.id).begins_with("E125-") and not str(r.id).begins_with("F127-") and r.id not in redirected)
 ck(unchanged==frozen.recipes.filter(func(r):return r.id not in redirected and r.id not in removed),"original branches unchanged except explicit V124 redirects and V127 replacements")
 var replacement={"P046":"weapon_21010034","P062":"weapon_21020074","P076":"weapon_21040034"}
 for old in frozen.recipes.filter(func(r):return r.id in redirected):
  var expected=old.duplicate(true);expected.base=replacement[old.id]
  ck(C.combinations.filter(func(r):return r.id==old.id)==[expected],"approved redirect changes only base "+old.id)
 for leader in ["aemeath","yangyang_xuanling"]:
  var r=inv.new_run(leader,19);var b=B.new().simulate(r,r,31,false)
  ck(b.events.any(func(e):return e.side==0 and e.kind=="charge" and e.value<0),"opening charge actually triggers "+leader)
  ck("i2" in b.used[0],"new starting supply actually contributes "+leader)
  r.items=r.items.filter(func(p):return p.uid!="i2")
  b=B.new().simulate(r,r,31,false)
  ck(b.events.any(func(e):return e.side==0 and e.kind=="charge" and e.value<0),"character still contributes after food consumed "+leader)
 var wins=0;var losses=0
 for m in ["mat_43020011","whiff"]:
  for other in ["hsin","suisui"]:
   for n in ["mat_43020021","tea"]:
    var a=outfitted("aemeath",["pouch",m]);var b=outfitted(other,["pouch",n])
    P.craft_owned(inv,a);P.craft_owned(inv,b)
    var forward=duel(a,b);var reverse=duel(b,a)
    ck(forward.winner==-reverse.winner,"early first-craft side symmetry")
    if forward.winner==1:wins+=1
    if forward.winner==-1:losses+=1
 ck(wins>0 and losses>0,"same-cost first crafts have wins and losses, no unconditional type winner")
 # Concrete low-cost actions: capacity + fast attacker + healer, within start budget.
 var r=inv.new_run("aemeath",19);r.shop=[{}, {"kind":"whiff","locked":false},{"kind":"turtle","locked":false},{},{},{"kind":"pouch","locked":false}]
 for slot in [5,1,2]:ck(P.purchase(inv,r,slot,"shop",false),"affordable meaningful first-round buy")
 ck(r.gold==3 and inv.validate_run(r),"three buys leave three gold; real shapes fit")
 print("EARLY_BALANCE_V83 ",checks," checks; first crafts ",wins," wins ",losses," losses; ",failures," failures")
 quit(1 if failures else 0)
