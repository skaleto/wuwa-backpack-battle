extends RefCounted
## Public transactions recorded before V129; no live Storage or UI is involved.
const I=preload('res://scripts/inventory/inventory.gd')
const SHOP=preload('res://scripts/shop/shop_v75.gd')
static func sample()->Array:
 var inv=I.new();var rows=[]
 for version in [0,122,125,127,128]:
  for round_number in [1,3,6,10]:
   for mode in ['full','focused']:
    for seed_value in [19,129]:
     var run=inv.new_run_supply('aemeath',seed_value,mode,version)
     run.round=round_number;run.gold=100
     var row={'version':version,'round':round_number,'mode':mode,'seed':seed_value,'states':[],'distribution_hashes':[]}
     for slot in 5:row.distribution_hashes.append(JSON.stringify(SHOP.distribution(run,slot,inv)).sha256_text())
     for step in 4:
      if step==1:inv.toggle_lock(run,0)
      if step==2 and not run.shop[5].is_empty():inv.buy(run,5)
      if not inv.refresh(run,true):push_error('Historical trace refresh failed')
      var snapshot=run.duplicate(true);snapshot.erase('catalogue_hash')
      row.states.append(snapshot)
     rows.append(row)
 return rows
