extends SceneTree
const C=preload('res://scripts/data/catalog.gd')
const I=preload('res://scripts/inventory/inventory.gd')
const PRESENT=preload('res://scripts/ui/items/item_presentation_v75.gd')
var failures=0
var checks=0
const EXPECTED={'mat_42310060':'清芬草','mat_42310070':'香柠草','mat_42310030':'夜息香','mat_42310220':'银雪莲','mat_42300110':'金铃子','mat_42300020':'木莲','mat_42310080':'蚀夜幽兰','mat_42310100':'月藻','mat_42300080':'云芝','mat_42300090':'傲寒钟','mat_42500020':'辉萤石','mat_42500040':'植珀','mat_41400074':'留音声核','mat_41400054':'呼啸岩拳','provision_jinzhou_stew':'今州烩','provision_snow_lotus_pastry':'雪莲酥'}
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():
 ck(C.SIMULATION_VERSION=='resonance-v128','current simulation explicitly versioned 128')
 for kind in EXPECTED:
  ck(C.items.has(kind),'original item exists '+EXPECTED[kind])
  if not C.items.has(kind):continue
  var item=C.items[kind];var n=C.profile(kind)
  ck(item.name==EXPECTED[kind] and str(item.source_id).length()==8,'exact original identity '+kind)
  ck(str(item.source_page).ends_with('/'+str(item.source_id)),'source page matches identity '+kind)
  ck(n.introduced_version==128 and n.active,'new active profile '+kind)
  ck(C.is_tag(kind,'provision') if kind.begins_with('provision_') else C.is_tag(kind,'material') and C.is_tag(kind,'craft_material'),'UI and procurement share actual material classification '+kind)
  ck(not item.has('signature_owner') and not n.has('rule'),'no hidden owner or inherited attack '+kind)
  ck(item.stars==n.stars and item.asset_path=='res://assets/skins/chibi/items_v128/'+kind+'.png','one shape/star/art source '+kind)
  ck(not item.canonical_effect.is_empty() and item.adaptation_summary.begins_with('本作改编'),'canonical and adaptation separate '+kind)
  for star in item.stars:ck(star not in item.shape,'stars outside footprint '+kind)
  var detail=str(PRESENT.effect_rows(kind))
  ck(not '60%' in detail and not '50%' in detail,'new material detail never invents legacy low-life trigger '+kind)
  if kind in ['mat_42300110','provision_snow_lotus_pastry']:ck(detail.count('治疗1')==1,'clock healing described exactly once '+kind)
  if kind=='mat_41400074':ck(detail.count('每8秒')==1,'core frost clock described exactly once')
 var run=I.new().new_run_supply('aemeath',128,'full',128)
 for recipe in preload('res://scripts/data/original_catalog_v128.gd').spec.recipes:
  ck(preload('res://scripts/crafting/recipe_tree.gd').branch_summary(recipe)==recipe.trade,'new branch presents the actual authored input trade '+recipe.id)
 ck(run.get('supply_version')==128,'frozen V128 supply remains constructible')
 ck(C.v128_items.values().filter(func(i):return 'bag' in i.tags or i.get('v128',i.get('v127',i.get('v125',i.get('v124',i.get('v75',{}))))).get('active',false)).size()==264,'exact frozen V128 264 active records')
 print('ORIGINAL_CATALOG_V128 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
