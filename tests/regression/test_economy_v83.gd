extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const C=preload("res://scripts/data/catalog.gd")
const P=preload("res://scripts/shop/practice_budget.gd")
const B=preload("res://scripts/battle/battle.gd")
const S=preload("res://scripts/storage/storage.gd")
var inv=I.new();var checks=0;var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():call_deferred("test")
func test():
 ck(I.ECONOMY.starting_gold()==9 and I.ECONOMY.income(-1)==10 and I.ECONOMY.income(0)==10 and I.ECONOMY.income(1)==11,"exact public income")
 ck(C.items.pouch.price==2 and C.items.strip.price==2 and C.items.corner.price==2 and C.items.travel.price==4,"all capacity shapes repriced")
 for paid in range(0,61):
  var piece=inv.make_piece("w_sword","test");piece.paid_cost=paid
  ck(inv.resale_value(piece)==int(floor(paid*.75)) and inv.resale_value(piece)<=paid,"paid resale has no money creation")
 for kind in C.items:
  var p=inv.make_piece(kind,"test");p.paid_cost=C.items[kind].price
  ck(inv.resale_value(p)<=p.paid_cost,"catalogue-wide purchase resale no profit "+kind)
 var r=inv.new_run("aemeath",19);var original=r.duplicate(true)
 ck(r.gold==9 and inv.resale_value(r.items[0])==2 and r.items[0].paid_cost==0,"starter exchange separate from real cash")
 var forged=r.items[0].duplicate(true);forged.salvage_credit=1000
 ck(inv.place(r,forged) and inv.find_piece(r,"i1")==original.items[0] and r.gold==original.gold,"drag cannot forge starter credit")
 var starter=inv.find_piece(r,"i1").duplicate(true);var gold=r.gold
 ck(inv.sell(r,starter) and r.gold==gold+2,"starter can fund one route change")
 var after=r.duplicate(true)
 ck(not inv.sell(r,starter) and r==after,"repeated sale cannot mint credit")
 r=inv.new_run("aemeath",19);r.items=r.items.filter(func(p):return p.uid=="i1")
 r.shop[2]={"kind":"mat_43020011","locked":false};r.shop[5]={"kind":"pouch","locked":false}
 ck(P.purchase(inv,r,5,"capacity",false) and P.purchase(inv,r,2,"shop",false),"buy capacity and real material")
 P.craft_owned(inv,r)
 var crafted=r.items.filter(func(p):return p.kind=="weapon_21020044")
 ck(crafted.size()==1,"starter first fusion")
 if crafted.size()==1:
  ck(crafted[0].paid_cost==2 and crafted[0].salvage_credit==2 and inv.resale_value(crafted[0])==3,"fusion preserves two-coin starter value plus paid lineage")
  ck(inv.snapshot(r,"test").items.filter(func(p):return p.uid==crafted[0].uid)[0].salvage_credit==2,"snapshot retains salvage credit")
  # Add a real second recipe input; long-chain provenance cannot duplicate credit.
  r.round=3;r.shop=[{},{},{},{},{},{}];r.shop[2]={"kind":"mat_43020051","locked":false};r.gold=30
  ck(P.purchase(inv,r,2,"shop",false),"buy second-stage material")
  P.craft_owned(inv,r)
  ck((r.items+r.stash).reduce(func(n,p):return n+int(p.get("salvage_credit",0)),0)==2,"continuous crafting conserves credit")
 # Replacing is exactly sale plus full-price purchase, including surplus change.
 r=inv.new_run("aemeath",19);r.items=[];r.primary="";r.shop[5]={"kind":"pouch","locked":false};r.bags[0].paid_cost=4
 var quote=inv.replacement_quote(r,"b1","pouch");gold=r.gold
 ck(quote.refund==3 and quote.price==0 and quote.cashback==1,"replacement returns surplus credit")
 ck(inv.replace_bag(r,"b1","pouch",0) and r.gold==gold+1 and r.bags[0].paid_cost==2,"replacement accounts full purchase and change atomically")
 var bag=r.bags[0].duplicate(true)
 ck(inv.sell(r,bag) and r.gold==gold+2,"replacement then sale cannot gain more than original resale")
 # Permanent provisions keep their paid identity across real player settlement.
 for supply in ["daily_tea","salt_tea","spicy_meat","soup"]:
  r=inv.new_run("aemeath",19);r.items=r.items.filter(func(p):return p.uid=="i1");r.stash=[]
  var food=inv.first_fit(inv.make_piece(supply,"i2"),r.items,r.bags);food.paid_cost=2;r.items.append(food)
  var snap=inv.snapshot(r,"calibration");var result=B.new().simulate(snap,snap,19,false)
  var money=r.gold;var possessions=r.items.duplicate(true)
  r.phase="result";r.combat=result;inv.finish(r,result.winner)
  ck(r.gold==money+I.ECONOMY.income(result.winner) and r.history.is_empty(),"settlement grants only public income "+supply)
  ck(r.items==possessions,"activated and unactivated supplies retain paid identity "+supply)
 for seed_value in range(31):
  var next=P.make_run(inv,3,seed_value)
  ck(next.practice_budget==30 and next.practice_spend+next.gold==30,"three rounds money reconciles")
  ck(not next.practice_ledger.any(func(e):return e.purpose=="consume"),"no automatic supply deletion or synthetic battle")
  var recipe_inputs=next.practice_ledger.filter(func(e):return e.purpose=="craft").reduce(func(ids,e):return ids+e.consumed,[])
  for entry in next.practice_ledger:
   if entry.purpose=="shop" and C.is_tag(entry.kind,"provision") and entry.uid not in recipe_inputs:
    ck((next.items+next.stash).any(func(p):return p.uid==entry.uid),"paid AI provision persists unless used in an actual recipe")
  ck(next.practice_ledger.all(func(e):return e.gold>=0),"AI no unearned sales income")
 # Migration writes only the isolated directory; all real player bytes stay untouched.
 var dir="/tmp/resonance-v83-economy-%d/"%OS.get_process_id();var store=S.new(dir)
 # Historical shelves must use the pre-V113 qualification pool.
 var old=S.HISTORICAL_I.new().new_run("aemeath",19);old.catalogue_hash=S.v82_hash;old.simulation_version="resonance-v75"
 old.items[0].erase("salvage_credit");old.items[1].kind="spicy_meat"
 old.items[1]=inv.first_fit(old.items[1],[old.items[0]],old.bags)
 store.write_json(dir+"run.json",old);var bytes=FileAccess.get_file_as_bytes(dir+"run.json")
 var upgraded=store.resume()
 ck(not upgraded.is_empty() and upgraded.catalogue_hash==C.catalogue_hash,"V82 isolated save migrates")
 if not upgraded.is_empty():
  ck(upgraded.gold==old.gold and upgraded.seed==old.seed and upgraded.shop==old.shop and upgraded.items[1].kind=="spicy_meat","migration preserves money shelves and existing supplies")
  ck(upgraded.items[0].salvage_credit==2 and store.resume()==upgraded,"starter credit migration idempotent")
  ck(FileAccess.get_file_as_bytes(dir+"run-before-v83-backup.json")==bytes,"exact migration backup")
  old.phase="battle";old.combat={"winner":1,"duration":10.0,"used":[["i2"],[]],"totals":[{},{}],"frames":[]}
  var settled=store.migrate_v83(old)
  ck(not settled.is_empty() and settled.phase=="result" and settled.combat.used[0]==["i2"] and settled.simulation_version=="resonance-v75","earned previous battle retained without rerun")
  if not settled.is_empty():
   inv.finish(settled,1)
   ck(settled.gold==20 and settled.simulation_version==C.SIMULATION_VERSION and settled.items.any(func(p):return p.uid=="i2"),"settle old fight once then use new economy")
 var ghost=inv.snapshot(old,"old");ghost.catalogue_hash=S.v82_hash;ghost.simulation_version="resonance-v75"
 var migrated=store.migrate_v83(ghost,true)
 ck(not migrated.is_empty() and migrated.simulation_version=="resonance-v75","old ghost does not claim new combat version")
 store.write_json(dir+"ghosts.json",[ghost]);ck(store.pool().size()==1,"old pool entry preserved")
 store.write_json(dir+"import.json",ghost);ck(not store.import_ghost(dir+"import.json").is_empty(),"old ghost import supported")
 ghost.simulation_version="resonance-v83";ck(store.migrate_v83(ghost,true).is_empty(),"old hash cannot assert new simulation")
 print("ECONOMY_V83 ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
