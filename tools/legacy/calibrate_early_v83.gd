extends "res://tools/legacy/audit_early_v83.gd"
func _initialize():call_deferred("calibrate")
func calibrate():
 C.characters.aemeath.v60_opening=[{"type":"charge","value":6}]
 C.characters.aemeath.starter_supply="daily_tea"
 C.characters.yangyang_xuanling.v60_opening=[{"type":"charge","value":6}]
 C.characters.yangyang_xuanling.starter_supply="salt_tea"
 for damage in [5.65,5.8,6.0,6.2]:
  for k in ["weapon_21020044","weapon_21020024"]:C.items[k].damage=damage;C.items[k].v75.damage=damage
  var outcomes=[]
  for m in ["mat_43020011","whiff"]:
   for other in ["hsin","suisui"]:
    for r in ["mat_43020021","tea"]:
     var a=outfitted("aemeath",["pouch",m]);var b=outfitted(other,["pouch",r])
     P.craft_owned(inv,a);P.craft_owned(inv,b)
     outcomes.append(duel(a,b).winner)
  print(damage," ",outcomes)
 quit()
