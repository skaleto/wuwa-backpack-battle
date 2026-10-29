extends SceneTree
const C=preload('res://scripts/data/catalog.gd')
const I=preload('res://scripts/inventory/inventory.gd')
const INFO=preload('res://scripts/ui/items/item_info.gd')
const SPEC=preload('res://scripts/data/ecosystem_catalog_v125.gd')
var failures=0
var checks=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():
 preload("res://tests/fixtures/catalog_fixture_v127.gd").apply()
 var spec=JSON.parse_string(FileAccess.get_file_as_string('res://data/items/families.json'))
 ck(C.supply_recipes(127).size()==202,'frozen V127 recipe identities')
 for kind in spec.new_items:
  ck(C.items.has(kind),'new family item '+kind)
  if not C.items.has(kind):continue
  var p=C.profile(kind)
  ck(p.introduced_version==127,'current family profile '+kind)
  ck(not C.is_tag(kind,'weapon'),'nonweapon ecosystem '+kind)
  ck(not INFO.live_effects(kind).is_empty(),'usable detail '+kind)
  ck(C.items[kind].stars==p.stars,'single star source '+kind)
  ck(not p.has('rule'),'no inherited weapon rule '+kind)
  ck(not C.items[kind].has('signature_owner'),'no inherited owner '+kind)
 var inv=I.new();var run=inv.new_run_supply('aemeath',127,'full',127)
 ck(run.get('supply_version')==127,'explicit historical supply127')
 ck(inv.validate_run(run),'new run legal')
 print('FAMILIES_CATALOG_V127 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
