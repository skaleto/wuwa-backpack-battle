extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const F=preload("res://scripts/crafting/craft.gd")
func _initialize():
 var inv=I.new()
 var r=inv.new_run("aemeath",19)
 r.items=[];r.stash=[];r.primary="";r.bags=[]
 var b=inv.make_piece("satchel","b1");r.bags.append(b)
 var sword=inv.make_piece("w_sword","i2");r.items.append(sword);r.primary=sword.uid
 var metal=inv.make_piece("mat_43020011","i3");metal.y=1;r.items.append(metal);r.serial=10
 print("INITIAL valid=",inv.validate_run(r)," adjacent=",inv.adjacent(sword,metal)," preview=",F.preview(r,"weapon_21020044",sword.uid,inv).get("reason")," ready=",F.ready_options(r,inv).size())
 var more=inv.make_piece("strip","b4");more.x=3;more.rotation=1;r.bags.append(more)
 print("EXPANDED valid=",inv.validate_run(r)," preview=",F.preview(r,"weapon_21020044",sword.uid,inv).get("reason")," ready=",F.ready_options(r,inv).size())
 for y in 1:
  var block=inv.make_piece("nutrition","block"+str(y));block.x=3;block.y=y;r.items.append(block)
 print("OCCUPIED valid=",inv.validate_run(r)," preview=",F.preview(r,"weapon_21020044",sword.uid,inv).get("reason")," ready=",F.ready_options(r,inv).size())
 quit()
