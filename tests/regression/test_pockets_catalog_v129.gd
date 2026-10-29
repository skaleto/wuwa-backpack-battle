extends SceneTree
const C=preload('res://scripts/data/catalog.gd')
const I=preload('res://scripts/inventory/inventory.gd')
const P=preload('res://scripts/inventory/pocket_rules.gd')
const SHAPES={'pocket_single':[[0,0]],'pocket_double':[[0,0],[1,0]],'pocket_long_l':[[0,0],[0,1],[0,2],[1,2]],'pocket_long_j':[[1,0],[1,1],[1,2],[0,2]]}
var checks=0
var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func signature(cells:Array)->String:
 var keys=cells.map(func(v):return str(v.x)+','+str(v.y));keys.sort();return '|'.join(keys)
func _initialize():
 var inv=I.new();var old=JSON.parse_string(FileAccess.get_file_as_string('res://tests/fixtures/data/wuwa-items-v128/runtime-catalogue.json'))
 ck(C.items.size()==old.items.size()+4,'exactly four ordinary pockets appended')
 ck(C.items.values().filter(func(d):return 'bag' in d.tags).size()==9,'catalogue has five established and four ordinary pockets')
 ck(C.v128_hash==old.catalogue_hash and C.catalogue_hash!=old.catalogue_hash,'published V128 hash frozen, current catalogue advances')
 for kind in old.items:ck(JSON.parse_string(JSON.stringify(C.items[kind]))==old.items[kind],'V128 item remains exact '+kind)
 ck(JSON.parse_string(JSON.stringify(C.combinations))==old.recipes,'recipes unchanged')
 var run=inv.new_run('aemeath',129)
 ck(run.get('supply_version')==129,'new runs use supply 129')
 ck(I.WIDTH==9 and I.HEIGHT==7 and I.MAX_CAPACITY==63 and inv.coverage(run.bags).size()==6,'board and initial capacity unchanged')
 for kind in SHAPES:
  ck(C.items.has(kind),'new pocket exists '+kind)
  if not C.items.has(kind):continue
  var item=C.items[kind]
  ck(item.shape==JSON.parse_string(JSON.stringify(SHAPES[kind])) and item.tags==['bag'] and item.stars.is_empty(),'exact capacity shape '+kind)
  ck(item.price=={'pocket_single':1,'pocket_double':2,'pocket_long_l':3,'pocket_long_j':3}[kind],'approved price '+kind)
  ck(inv.shop_eligible(run,kind) and kind in inv.available_bags(run),'all new shapes eligible in first shop '+kind)
  ck(P.profile(kind).stat=='capacity' and P.profile(kind).amount==0 and not P.applies(kind,'w_sword'),'no new combat bonus '+kind)
  var shown=preload('res://scripts/inventory/pocket_profiles_v129.gd').profile(kind)
  ck(shown.name==item.name and shown.effect==str(SHAPES[kind].size())+' 格' and shown.stat=='capacity','display name and capacity agree '+kind)
  ck(preload('res://scripts/run/demo_features.gd').item_enabled(kind),'new capacity pocket appears in catalogue '+kind)
  ck(preload('res://scripts/ui/shop_presentation.gd').benefits(kind)==[['bag','扩容']],'shop promises capacity only '+kind)
  ck(preload('res://scripts/ui/items/item_info.gd').rows({'kind':kind})[0]==['占格 / 价格',str(SHAPES[kind].size())+' 格 / '+str(int(item.price))+' 贝币'],'detail area and price agree '+kind)
  ck(preload('res://scripts/ui/items/item_description.gd').effects(kind)==['扩展物品可放置的区域。'],'detail promises no combat effect '+kind)
  var unique=[]
  for rotation in 4:
   var piece=inv.make_piece(kind,'p');piece.rotation=rotation
   var cells=inv.cells(piece);var key=signature(cells)
   if key not in unique:unique.append(key)
   ck(cells.size()==SHAPES[kind].size() and cells.all(func(c):return c.x>=0 and c.y>=0),'normalized rotation preserves area '+kind+'/'+str(rotation))
  ck(unique.size()==(1 if kind=='pocket_single' else 2 if kind=='pocket_double' else 4),'expected unique rotations '+kind)
 if C.items.has('pocket_long_l') and C.items.has('pocket_long_j'):
  var left=[];var right=[]
  for rotation in 4:
   var a=inv.make_piece('pocket_long_l','a');a.rotation=rotation;left.append(signature(inv.cells(a)))
   var b=inv.make_piece('pocket_long_j','b');b.rotation=rotation;right.append(signature(inv.cells(b)))
  ck(left.all(func(k):return k not in right),'long L and J remain distinct under every rotation')
 print('POCKETS_CATALOG_V129 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
