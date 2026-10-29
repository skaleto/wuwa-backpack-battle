extends SceneTree
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const P=preload("res://scripts/shop/practice_budget.gd")
const S=preload("res://scripts/storage/storage.gd")
var inv=I.new();var checks=0;var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():call_deferred("test")
func test():
 ck(P.METHOD=="shop-procurement-v116","version current procurement")
 var r=inv.new_run("aemeath",19);r.items=[inv.make_piece("whiff","i1")];r.shop[0]={"kind":"w_sword","locked":false}
 ck(P.utility(r,0,"迅捷联动")>0,"missing first input weapon is useful")
 r.items=[inv.make_piece("w_sword","i1")];r.shop[0]={"kind":"whiff","locked":false}
 ck(P.utility(r,0,"迅捷联动")>8,"missing second input non-material has priority")
 r.items=[inv.make_piece("w_broadblade","i1")];r.shop[0]={"kind":"spicy_meat","locked":false}
 ck(not P.missing_recipes(r,"spicy_meat").is_empty(),"V113 foreign weapon recipes create real ingredient opportunities")
 for seed_value in [2,13,30]:
  for round_number in [1,2,3,5]:
   r=P.make_run(inv,round_number,seed_value)
   ck(inv.validate_run(r),"legal synthetic history")
   ck(r.practice_spend+r.gold==I.ECONOMY.budget(round_number),"public budget")
   ck(r==P.make_run(inv,round_number,seed_value),"deterministic history")
   if round_number<=3:ck(r.gold>=P.OPENING_RESERVE[round_number-1],"opening reserve")
   for current in range(1,mini(round_number,3)+1):
    ck(r.practice_ledger.filter(func(e):return e.round==current and e.purpose=="shop").size()<=current,"opening purchase limit")
    ck(not r.practice_ledger.any(func(e):return e.round==current and e.purpose=="refresh"),"opening one shelf")
   ck(r.practice_ledger.filter(func(e):return e.purpose=="consume" and e.source=="synthetic_mirror_battle").size()==0,"permanent supplies need no synthetic consumption battles")
 # Authoritative star arrangement must discover actual V75 filters, not blank target.
 r=inv.new_run("aemeath",1);r.items=[];r.bags=[];r.serial=20;r.primary="i1"
 for y in [0,2]:
  for x in [0,3]:
   var b=inv.make_piece("satchel","b%d%d"%[x,y]);b.x=x;b.y=y;r.bags.append(b)
 for kind in ["w_sword","heron","whiff"]:
  var item=inv.first_fit(inv.make_piece(kind,"i"+str(r.items.size()+1)),r.items,r.bags);r.items.append(item)
 P.arrange(inv,r)
 ck(P.bonds(inv,r)>0 and inv.validate_run(r),"V75 capability stars are arranged legally")
 # Exact-input continuous chain, deliberately controlled fixture, not procurement evidence.
 r.items=[inv.make_piece("w_sword","i1")];r.stash=[];r.round=2;r.practice_ledger=[]
 for kind in ["mat_43020011","mat_43020051"]:
  r.serial+=1;r.stash.append(inv.make_piece(kind,"i"+str(r.serial)))
 P.craft_owned(inv,r)
 ck(r.practice_ledger.filter(func(e):return e.purpose=="craft").size()>=2,"continuous owned chain exhausts current legal recipes")
 for entry in r.practice_ledger:
  if entry.purpose=="craft":ck(inv.adjacent(entry.inputs[0],entry.inputs[1]) and not inv.occupied(entry.inputs[0]).any(func(cell):return cell in inv.occupied(entry.inputs[1])),"fusion ledger records actual adjacent input positions")
 var storage=S.new("/tmp/resonance-v75-practice-%d"%OS.get_process_id())
 r=inv.new_run("aemeath",8);var before=r.duplicate(true);var enemy=storage.opponent(r)
 ck(r==before and enemy.source=="practice","opponent no player mutation")
 enemy.items.clear();ck(not storage.opponent(r).items.is_empty(),"cached copies isolated")
 var other=r.duplicate(true);other.gold=999
 ck(storage.opponent(other)==storage.opponent(r),"public round/seed opponent cannot peek player wealth")
 print("PRACTICE_V75 ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
