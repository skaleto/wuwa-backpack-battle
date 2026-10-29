extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const F=preload("res://scripts/crafting/craft.gd")
const S=preload("res://scripts/storage/storage.gd")
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
class CountedStorage extends S:
 var writes=0
 func save(state:Dictionary)->bool:
  writes+=1;return super.save(state)
var inv=I.new();var checks=0;var failures=0;var saves=0
func ck(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func save(_state):saves+=1
func populated(count:int)->Dictionary:
 var r=inv.new_run("aemeath",19);r.gold=1000;r.shop=[{},{},{},{},{},{}];r.serial=1000;r.stash=[]
 for n in count:r.stash.append(inv.make_piece("mat_43020011","stored"+str(n)))
 return r
func _initialize():call_deferred("run_tests")
func run_tests():
 var r=populated(130);var before=r.duplicate(true)
 ck(inv.validate_run(r),"130-item live storage is legal")
 ck(inv.validate_ghost(r,true),"shared owned validation has no hidden 128 cap")
 var storage=CountedStorage.new("user://qa-v103-unlimited/"+str(OS.get_process_id())+"/");storage.save(r)
 ck(storage.resume()==r,"130 owned items survive current save and reload")
 var historical=S.new("user://qa-v103-legacy/")
 var old=r.duplicate(true);old.catalogue_hash=historical.v82_hash
 ck(not historical.v82_inventory.validate_run(old),"historical v82 validator retains its six-slot constraint")
 r.shop[0]={"kind":"mat_43020011","locked":false};before=r.duplicate(true)
 var planned=inv.plan_buy(r,0)
 ck(planned.ok and r==before,"purchase above 130 previews without mutation")
 var app=preload("res://scripts/run/run_application.gd").new(inv,storage,null)
 var result=app.commit(r,planned)
 ck(result.ok and r.stash.size()==131 and r.gold==before.gold-2,"purchase appends and charges actual item price")
 ck(not app.commit(r,planned).ok and storage.writes==2,"one initial save plus one purchase save; duplicate plan rejected without write")
 r=populated(130);r.round=3;r.shop[5]={"kind":"pouch","locked":false};before=r.duplicate(true)
 var bag_purchase=inv.make_piece("pouch","preview");bag_purchase.rotation=1
 planned=inv.plan_purchase_at(r,5,bag_purchase,"stash")
 ck(planned.ok and r==before,"shop bag preview above 130 preserves source")
 var purchased=inv.purchase_at(r,5,bag_purchase,"stash")
 ck(not purchased.is_empty() and r.stash.size()==131 and r.stash[-1].kind=="pouch" and r.stash[-1].rotation==1 and inv.validate_run(r),"shop bag purchase retains rotation in unlimited storage")
 r=populated(130);before=r.duplicate(true)
 var bag=r.bags[0].duplicate(true);var preview=inv.stash_preview(r,bag)
 ck(preview.ok and r==before,"storing bag and contents remains readonly without capacity gate")
 ck(inv.stash(r,bag) and r.stash.size()==130+before.items.size()+1 and r.items.is_empty() and r.bags.is_empty(),"whole bag and every covered item stored")
 ck(inv.validate_run(r),"large stored bag transaction valid")
 r=populated(130);var item=r.items[0].duplicate(true)
 ck(inv.stash(r,item) and r.stash.size()==131,"manual equipment storage above old limit")
 r=populated(130);before=r.duplicate(true)
 inv.gift(r,"mat_43020011")
 ck(r.stash.size()==131 and r.pending_gifts.is_empty(),"gift arrives directly instead of pending capacity queue")
 r.pending_gifts=[inv.make_piece("mat_43020011","pendinggift")];r.pending_rearrange=[inv.make_piece("mat_43020011","pendingreflow")]
 inv.claim_pending(r)
 ck(r.stash.size()==133 and r.pending_gifts.is_empty() and r.pending_rearrange.is_empty(),"legacy pending ownership drains without cap")
 r=populated(130);r.items=[inv.make_piece("w_sword","i1"),inv.make_piece("whiff","i2")];r.items[1].x=2;r.items[1].y=1;r.primary="i1"
 var recipe=F.pair_recipes(r,r.items[0],r.items[1],inv)[0]
 var entries=F.ready_options(r,inv);before=r.duplicate(true)
 ck(entries.size()==1 and entries[0].destination=="stash" and entries[0].stash_index==130,"craft preview has append destination above 130")
 if not entries.is_empty():
  result=F.commit_ready(r,entries[0],inv,save)
  ck(result.ok and r.stash.size()==131 and r.items.is_empty() and saves==1,"craft consumes exact pair and stores result once")
  ck(r.stash[-1].kind==recipe.target and inv.validate_run(r),"fallback output keeps genuine ownership")
  before=r.duplicate(true)
  ck(not F.commit_ready(r,entries[0],inv,save).ok and r==before and saves==1,"repeated craft cannot duplicate output")
 # Repositioning a bag may uncover a cross-bag blade even above 130 items.
 r=populated(130);r.bags=[inv.make_piece("satchel","b1"),inv.make_piece("pouch","b2")];r.bags[1].x=3
 r.items=[inv.make_piece("w_sword","i1")];r.items[0].x=2;r.primary="i1"
 var moved=r.bags[0].duplicate(true);moved.y=3;before=r.duplicate(true)
 var bag_plan=inv.bag_transaction(r,moved)
 ck(bag_plan.ok and r==before and bag_plan.stash.size()==131,"moving bag previews whole crossing item into unlimited storage")
 ck(inv.place(r,moved) and r.stash[-1].uid=="i1" and r.items.is_empty() and inv.validate_run(r),"cross-bag item retained on bag move")
 # All inventory participates in recipes even when UI pages hide it.
 var material_recipe=inv.C.combinations.filter(func(v):return v.base=="w_sword" and "mat_43020011" in v.materials)[0]
 var status=F.material_status(r,material_recipe.target,"i1",inv)
 ck(status.size()==1 and status[0].owned==130 and status[0].stash==130,"recipe counts include all retained material instances across pages")
 print("UNLIMITED_STASH_V103 ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
