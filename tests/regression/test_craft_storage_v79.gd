extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const F=preload("res://scripts/crafting/craft.gd")
var inv=I.new();var checks=0;var failures=0;var saves=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func save(_state):saves+=1
func fixture()->Dictionary:
 var r=inv.new_run("aemeath",19);r.shop=[{},{},{},{},{},{}];r.serial=20
 var sword=inv.make_piece("w_sword","i1");sword.paid_cost=4
 var echo=inv.make_piece("whiff","i2");echo.x=2;echo.y=1;echo.paid_cost=2
 r.items=[sword,echo];r.stash=[];r.primary="i1"
 return r
func _initialize():
 var r=fixture();var before=r.duplicate(true)
 var recipes=F.pair_recipes(r,r.items[0],r.items[1],inv)
 ck(inv.validate_run(r) and recipes.size()==1,"exact screenshot pair is legal")
 var target=recipes[0].target
 var p=F.preview(r,target,"i1",inv)
 ck(p.ok and p.get("destination","")=="stash","board too narrow sends output to storage")
 ck(r==before,"storage fallback preview is read-only")
 var entries=F.ready_options(r,inv)
 ck(entries.size()==1,"no backpack expansion required for button")
 if not entries.is_empty():
  var result=F.commit_ready(r,entries[0],inv,save)
  ck(result.ok and r.stash.size()==1 and r.items.is_empty(),"one click consumes exact pair and stores product")
  ck(r.stash[0].paid_cost==6 and r.gold==before.gold and r.serial==before.serial+1 and r.primary=="","cost UID and primary remain valid")
  ck(inv.validate_run(r) and saves==1,"fallback saved once as valid inventory")
  var committed=r.duplicate(true)
  ck(not F.commit_ready(r,entries[0],inv,save).ok and r==committed and saves==1,"duplicate click spends nothing")
 r=fixture()
 for n in 6:r.stash.append(inv.make_piece("nutrition","stored"+str(n)))
 before=r.duplicate(true);var count=saves
 ck(F.transact(r,target,"i1",inv,{},save).ok and r.stash.size()==7 and r.items.is_empty() and saves==count+1,"V103 six stored items do not block fallback; exact inputs consumed and one save")
 r=fixture();var bag=inv.make_piece("strip","extra");bag.x=3;bag.rotation=1;r.bags.append(bag)
 p=F.preview(r,target,"i1",inv)
 ck(p.ok and p.get("destination","board")=="board" and p.run.stash.is_empty(),"board fitting remains first priority")
 for n in 6:r.stash.append(inv.make_piece("nutrition","stored"+str(n)))
 p=F.preview(r,target,"i1",inv)
 ck(p.ok and p.get("destination","board")=="board","full storage does not block a fitting board output")
 r=fixture();entries=F.ready_options(r,inv)
 if not entries.is_empty():
  var altered=entries[0].duplicate(true);altered.stash_index+=1;before=r.duplicate(true)
  ck(not F.commit_ready(r,altered,inv,save).ok and r==before,"confirmation cannot change the previewed storage slot")
 r=fixture();entries=F.ready_options(r,inv)
 if not entries.is_empty():
  var candidate=entries[0];r.stash.append(inv.make_piece("nutrition","changed"));before=r.duplicate(true)
  ck(not F.commit_ready(r,candidate,inv,save).ok and r==before,"old stash destination does not silently move after state changes")
 print("CRAFT_STORAGE_V79 ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
