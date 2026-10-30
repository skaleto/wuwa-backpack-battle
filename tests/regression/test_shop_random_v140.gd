extends SceneTree
const I=preload('res://scripts/inventory/inventory.gd')
const S=preload('res://scripts/shop/shop_v75.gd')
const C=preload('res://scripts/data/catalog.gd')
const P=preload('res://scripts/online/async_pvp.gd')
var failures=0
func ck(ok,label):
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():
 var inv=I.new();var run=inv.new_run('aemeath',140)
 ck(run.supply_version==140,'new games opt into random categories')
 if run.supply_version!=140:quit(1);return
 var original=run.duplicate(true);var facts=S.facts(run,inv);var bags=inv.available_bags(run)
 var hist=[0,0,0,0,0,0,0];var categories=[];var rng=RandomNumberGenerator.new();rng.seed=140
 for n in 6:categories.append({})
 var min_tier=0.0;var max_tier=0.0
 for slot in 6:
  var pool=S.pool(facts,slot);var total=0.0;var bag_total=0.0
  for k in pool:
   total+=pool[k]
   if C.is_tag(k,'bag'):bag_total+=pool[k]
  ck(is_equal_approx(total,1),'normalized slot '+str(slot))
  ck(is_equal_approx(bag_total,.15),'15 percent capacity weight in every slot')
 for seed_value in 1600:
  rng.seed=seed_value
  var offers=S.roll(facts,[],bags,rng);var count=0
  var replay=RandomNumberGenerator.new();replay.seed=seed_value
  ck(S.roll(facts,[],bags,replay)==offers and rng.state==replay.state,'deterministic refresh')
  for n in offers.size():
   var k=offers[n].kind;var category='bag' if C.is_tag(k,'bag') else 'weapon' if C.is_tag(k,'weapon') else 'echo' if C.is_tag(k,'echo') else 'other'
   categories[n][category]=true
   if category=='bag':count+=1
   ck(inv.shop_eligible(run,k),'no ineligible offer')
  hist[count]+=1
 ck(hist[0]>400 and hist[1]>400 and hist[2]>100,'zero, one and several bags all occur')
 for row in categories:ck(row.size()==4,'every slot supports every category')
 var locked=run.shop.duplicate(true);locked[1].locked=true;locked[5].locked=true
 var result=S.roll(facts,locked,bags,rng)
 ck(result[1]==locked[1] and result[5]==locked[5],'locked offers stay exact')
 for rn in [1,8]:
  run.round=rn;var pool=S.distribution(run,0,inv);var sum=0.0;var mass=0.0
  for k in pool:
   if not C.is_tag(k,'bag'):sum+=pool[k]*int(C.supply_profile(k,140).get('tier',1));mass+=pool[k]
  if rn==1:min_tier=sum/mass
  else:max_tier=sum/mass
 ck(max_tier>min_tier+.35,'round progression still raises expected quality')
 run=original.duplicate(true)
 ck(inv.validate_run(run),'new supply is valid and serializable')
 # Each shelf slot supports a real bag purchase and bag replacement.
 for slot in 6:
  var buyer=inv.new_run('aemeath',140);buyer.gold=50
  buyer.shop=[{},{},{},{},{},{}];buyer.shop[slot]={'kind':'pocket_single','locked':false}
  var cash=buyer.gold
  ck(inv.buy(buyer,slot) and buyer.stash[-1].kind=='pocket_single' and buyer.shop[slot].is_empty(),'bag purchase in slot '+str(slot))
  ck(buyer.gold==cash-int(C.items.pocket_single.price) and inv.validate_run(buyer),'single debit, valid bag stash')
  var replaced=inv.new_run('aemeath',140);replaced.gold=50;replaced.stash=replaced.items;replaced.items=[];replaced.primary=''
  replaced.shop=[{},{},{},{},{},{}];replaced.shop[slot]={'kind':'pouch','locked':false}
  var before_replace=replaced.duplicate(true)
  var plan=inv.plan_replace_bag(replaced,'b1','pouch',0,slot)
  ck(plan.get('ok',false) and replaced==before_replace,'replacement plans are readonly for every slot')
  ck(inv.commit_operation(replaced,plan).get('ok',false) and replaced.shop[slot].is_empty() and inv.validate_run(replaced),'replacement consumes exact offer')
  ck(not inv.commit_operation(replaced,plan).get('ok',false),'repeated replacement cannot consume twice')
 var storage=preload('res://scripts/storage/storage.gd').new('user://qa-shop140/'+str(OS.get_process_id()))
 ck(storage.save_checked(run) and storage.resume()==run,'current randomized shelf survives persistence')
 var old=inv.new_run_supply('aemeath',140,'full',129)
 ck(P.pool_id(run)!=P.pool_id(old),'different supply cannot silently share online pool')
 ck(old.shop.size()==6 and C.is_tag(old.shop[5].kind,'bag'),'old game retains old policy')
 var practice=preload('res://scripts/shop/practice_budget.gd')
 for seed_value in 5:
  for rn in [1,4,7,10]:
   var bot=practice.make_run(inv,rn,seed_value,'full',false,115,140)
   ck(inv.validate_run(bot) and bot.supply_version==140,'practice uses legal random shelves')
   ck(bot.practice_spend+bot.gold==bot.practice_budget,'practice procurement budget reconciles')
 print('SHOP140 histogram=',hist,' quality=',min_tier,' -> ',max_tier,' pool=',P.pool_id(run),' failures=',failures)
 quit(1 if failures else 0)
