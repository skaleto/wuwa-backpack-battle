extends SceneTree
const I=preload('res://scripts/inventory/inventory.gd')
const SHOP=preload('res://scripts/shop/shop_v75.gd')
func _initialize():
 if FileAccess.file_exists('res://tests/fixtures/data/families-v127/supply-before.json'):
  printerr('Frozen baseline already exists; refusing to overwrite it.');quit(1);return
 var inv=I.new();var rows=[]
 for sv in [0,122,125]:
  for rn in [1,3,6,10]:
   var run=inv.new_run_supply('aemeath',173,'full',sv);run.round=rn
   run.stash=[inv.make_piece('soup','i90'),inv.make_piece('cool_tea','i91'),inv.make_piece('weapon_21020024','i92')];run.serial=92
   var distributions=[]
   for slot in 5:distributions.append(SHOP.distribution(run,slot,inv))
   rows.append({'run':run,'distributions':distributions})
 FileAccess.open('res://tests/fixtures/data/families-v127/supply-before.json',FileAccess.WRITE).store_string(JSON.stringify(rows))
 quit()
