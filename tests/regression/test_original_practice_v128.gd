extends SceneTree
const I=preload('res://scripts/inventory/inventory.gd')
const C=preload('res://scripts/data/catalog.gd')
const P=preload('res://scripts/shop/practice_budget.gd')
var checks=0
var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():call_deferred('test')
func test():
 var inv=I.new()
 var acquisitions={};var totals={'runs':0,'spent':0,'remaining':0,'purchases':0,'refreshes':0,'crafts':0}
 for seed_value in C.selectable_leaders().size():
  for rn in [1,4,7,10]:
   var run=P.make_run(inv,rn,seed_value,'full',false,115,128)
   ck(not run.is_empty() and inv.validate_run(run),'current public procurement remains legal '+str(seed_value)+'/'+str(rn))
   if run.is_empty():continue
   ck(run.supply_version==128 and run.practice_spend+run.gold==run.practice_budget,'current supply and exact spending reconcile')
   ck(run.practice_ledger.all(func(row):return row.source=='public_transaction'),'all purchases use public transaction')
   totals.runs+=1;totals.spent+=run.practice_spend;totals.remaining+=run.gold
   for row in run.practice_ledger:
    if row.purpose=='refresh':totals.refreshes+=1
    if row.purpose=='craft':totals.crafts+=1
    if C.profile(str(row.kind)).get('introduced_version',0)==128:acquisitions[row.kind]=int(acquisitions.get(row.kind,0))+1
    if row.has('acquired'):totals.purchases+=1
 print('W128_PROCUREMENT ',JSON.stringify({'totals':totals,'new_item_transactions':acquisitions}))
 print('ORIGINAL_PRACTICE_V128 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
