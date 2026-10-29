extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const F=preload("res://scripts/crafting/craft.gd")
func _initialize():
 var inv=I.new();var r=inv.new_run("aemeath",19)
 r.items=[];r.bags=[];r.stash=[];r.primary="";r.serial=100
 for y in range(0,6,2):
  for x in range(0,8,2):
   var b=inv.make_piece("pouch","b%d-%d"%[x,y]);b.x=x;b.y=y;r.bags.append(b)
 for y in 6:
  for x in 8:
   var p=inv.make_piece("mat_43020011","m%d-%d"%[x,y]);p.x=x;p.y=y;r.items.append(p)
 for n in 6:r.stash.append(inv.make_piece("mat_43020011","stash"+str(n)))
 assert(inv.validate_run(r))
 var started=Time.get_ticks_usec();var relations=F.relationships(r,inv)
 print("GUIDANCE_WORST_NO_MATCH_US ",Time.get_ticks_usec()-started," relations=",relations.size())
 quit()
