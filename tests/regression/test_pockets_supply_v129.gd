extends SceneTree
const C=preload('res://scripts/data/catalog.gd')
const I=preload('res://scripts/inventory/inventory.gd')
const SHOP=preload('res://scripts/shop/shop_v75.gd')
var checks=0
var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():
 var baseline=JSON.parse_string(FileAccess.get_file_as_string('res://tests/fixtures/data/pockets-v129/baseline/supply-v128.json'))
 var current=JSON.parse_string(JSON.stringify(preload('res://tests/scenarios/pocket_supply_trace_v129.gd').sample()))
 ck(current.size()==baseline.size(),'same historical trace coverage')
 for i in mini(current.size(),baseline.size()):ck(current[i]==baseline[i],'exact old distributions, locked slots, purchases and refresh RNG '+str(i))
 var inv=I.new();var run=inv.new_run('aemeath',129);var old=inv.new_run_supply('aemeath',129,'full',128)
 for rn in [1,3,6,10]:
  run.round=rn;old.round=rn
  for slot in 5:ck(SHOP.distribution(run,slot,inv)==SHOP.distribution(old,slot,inv),'ordinary item probabilities unchanged '+str(rn)+'/'+str(slot))
  var choices=inv.available_bags(run);var counts={};var source=run.duplicate(true)
  ck(choices.size()==(7 if rn==1 else 8),'all eligible bag shapes share one slot '+str(rn))
  var facts=SHOP.facts(run,inv)
  # Item-slot probabilities are compared above. Lock them while sampling the
  # dedicated bag draw so this distribution test does not repeat that work.
  var previous=run.shop.duplicate(true)
  for slot in 5:previous[slot].locked=true
  for seed_value in 1200:
   var rng=RandomNumberGenerator.new();rng.seed=seed_value
   var offers=SHOP.roll(facts,previous,choices,rng)
   ck(offers.filter(func(v):return C.is_tag(v.get('kind',''),'bag')).size()==1 and offers.size()==6,'exactly one bag offer '+str(rn)+'/'+str(seed_value))
   counts[offers[5].kind]=int(counts.get(offers[5].kind,0))+1
   var replay=RandomNumberGenerator.new();replay.seed=seed_value
   ck(SHOP.roll(facts,previous,choices,replay)==offers and replay.state==rng.state,'deterministic roll and RNG '+str(rn)+'/'+str(seed_value))
  ck(run==source,'sampling never mutates current run')
  for kind in choices:ck(counts.get(kind,0)>90 and counts.get(kind,0)<240,'all shapes sampled without a dominant extra budget '+str(rn)+'/'+kind)
 run.round=1;run.gold=100
 var before=run.duplicate(true)
 for kind in preload('res://scripts/data/pocket_catalog_v129.gd').spec:ck(not inv.set_bag_offer(run,kind) and run==before,'no click-to-cycle shortcut '+kind)
 var offered=run.shop[5].duplicate(true);ck(inv.toggle_lock(run,5),'lock bag slot')
 ck(inv.refresh(run,true) and run.shop[5].kind==offered.kind and run.shop[5].locked,'normal refresh preserves bag lock')
 print('POCKETS_SUPPLY_V129 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
