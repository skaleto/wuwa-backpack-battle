extends SceneTree
const C=preload('res://scripts/data/catalog.gd')
const I=preload('res://scripts/inventory/inventory.gd')
const SHOP=preload('res://scripts/shop/shop_v75.gd')
const POLICY=preload('res://scripts/shop/supply_policy_v127.gd')
var checks=0
var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():
 var inv=I.new();var spec=preload('res://scripts/data/original_catalog_v128.gd').spec
 var baseline=JSON.parse_string(FileAccess.get_file_as_string('res://tests/fixtures/data/families-v127/runtime-catalogue.json'))
 ck(C.v127_hash==baseline.catalogue_hash,'exact V127 hash frozen')
 ck(JSON.parse_string(JSON.stringify(C.v127_items))==baseline.items and JSON.parse_string(JSON.stringify(C.v127_combinations))==baseline.recipes,'all V127 definitions frozen before overlay')
 ck(C.v127_item_ids.size()+16==C.v128_items.size() and C.v127_combinations.size()+spec.recipes.size()==C.v128_combinations.size(),'V128 remains exactly additive content')
 var comparisons=[]
 for sv in [0,122,125,127]:
  for rn in [1,3,6,10]:
   for mode in ['full','focused']:
    for kind in ['cool_tea','relic_recorder','relic_lunchbox','mat_42500010','weapon_21020074']:
     var r=inv.new_run_supply('aemeath',128,mode,sv);r.round=rn;r.stash=[inv.make_piece(kind,'i50')];r.serial=50
     var ds=[]
     for slot in 5:ds.append(SHOP.distribution(r,slot,inv))
     comparisons.append({'run':r,'distributions':ds})
 var saved=preload('res://tests/fixtures/catalog_fixture_v127.gd').apply()
 for row in comparisons:
  for slot in 5:
   var before=SHOP.distribution(row.run,slot,inv);var now=row.distributions[slot]
   ck(before.size()==now.size() and before.keys().all(func(k):return absf(before[k]-now.get(k,-1))<0.000000001),'exact old distribution '+str(row.run.get('supply_version',0))+'/'+str(row.run.round)+'/'+row.run.pool_mode+'/'+str(slot))
 preload('res://tests/fixtures/catalog_fixture_v116.gd').restore(saved)
 var run=inv.new_run('aemeath',128)
 for kind in spec.new_items:
  var n=C.profile(kind)
  for rn in [1,4,6,10]:
   run.round=rn
   ck(inv.shop_eligible(run,kind)==(not n.craft_only and rn>=n.shop_round),'exact natural shop stage '+kind+'/'+str(rn))
   ck(inv.craft_unlocked(run,kind),'owned recipes never round gated '+kind)
  run.round=10;run.gold=100;run.shop[2]={'kind':kind,'locked':false}
  if not n.craft_only:ck(inv.buy(run,2),'new material actual public purchase '+kind)
  run.shop[2]={}
 for rn in [1,3,6,10]:
  run.round=rn
  for slot in 5:
   var untouched=run.duplicate(true);var distribution=SHOP.distribution(run,slot,inv)
   ck(is_equal_approx(distribution.values().reduce(func(a,b):return a+b,0.0),1),'normalized current probabilities')
   ck(distribution.keys().all(func(k):return inv.shop_eligible(run,k)) and run==untouched,'read-only eligible current supply')
 # Every old functional budget is shared with alternatives, never counted twice.
 var old_kinds=['mat_43020011','mat_42500010','mat_42500030','relic_guard_plate']
 var expanded=old_kinds+['mat_42500020','mat_42310070']
 var old_shares=POLICY.shares(old_kinds);var current_shares=POLICY.shares(expanded)
 var old_totals={};var current_totals={}
 for k in old_shares:old_totals[POLICY.family(k)]=old_totals.get(POLICY.family(k),0.0)+old_shares[k]
 for k in current_shares:current_totals[POLICY.family(k)]=current_totals.get(POLICY.family(k),0.0)+current_shares[k]
 ck(old_totals==current_totals,'new alternatives share exactly the old functional budget')
 print('ORIGINAL_SUPPLY_V128 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
