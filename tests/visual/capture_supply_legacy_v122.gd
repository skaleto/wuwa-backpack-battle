extends SceneTree
const I=preload('res://scripts/inventory/inventory.gd')
const SHOP=preload('res://scripts/shop/shop_v75.gd')
func _initialize():
 var inv=I.new();var rows=[]
 for mode in ['full','focused']:
  for rn in [1,2,4,6]:
   for seed_value in [19,173]:
    var run=inv.new_run_supply('aemeath',seed_value,mode,0)
    run.erase('supply_version');run.round=rn
    if rn>1:run.stash=[inv.make_piece('weapon_21020024','i3')];run.serial=3
    var before=run.duplicate(true);assert(inv.refresh(run,true))
    rows.append({'before':before,'after':run,'slot3':SHOP.distribution(before,3,inv),'slot4':SHOP.distribution(before,4,inv)})
 var f=FileAccess.open('res://tests/fixtures/supply_legacy_v122.json',FileAccess.WRITE);f.store_string(JSON.stringify(rows,' '));f.close();quit()
