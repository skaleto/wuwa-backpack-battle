extends SceneTree
const I=preload('res://scripts/inventory/inventory.gd')
const C=preload('res://scripts/data/catalog.gd')
const SHOP=preload('res://scripts/shop/shop_v75.gd')
var inv=I.new();var checks=0;var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():
 var run=inv.new_run_supply('aemeath',19,'full',122)
 ck(run.get('supply_version',0)==122,'new runs explicitly select supply122')
 ck(inv.snapshot(run,'qa').get('supply_version',0)==122,'snapshot preserves supply selection')
 for bad in [1,121,123,122.5,'122',null,true]:
  var invalid=run.duplicate(true);invalid.supply_version=bad
  ck(not inv.validate_run(invalid),'reject unsupported supply version '+str(bad))
 # The frozen V122 probability/RNG evidence predates V124 recipe redirects.
 # Use that exact catalogue only for this legacy loop; keep fixture bytes intact.
 var saved_catalogue=preload('res://tests/fixtures/catalog_fixture_v116.gd').apply()
 for row in JSON.parse_string(FileAccess.get_file_as_string('res://tests/fixtures/supply_legacy_v122.json')):
  var old=row.before.duplicate(true)
  var expected_after=row.after.duplicate(true)
  ck(old.catalogue_hash==C.v116_hash and expected_after.catalogue_hash==C.v116_hash,'frozen supply evidence identifies the published V116 catalogue')
  old.catalogue_hash=C.catalogue_hash;expected_after.catalogue_hash=C.catalogue_hash
  ck(inv.validate_run(old),'legacy saved offers remain valid')
  for slot in [3,4]:
   var actual=SHOP.distribution(old,slot,inv);var expected=row['slot'+str(slot)]
   ck(actual.size()==expected.size(),'legacy pool membership unchanged')
   for kind in expected:ck(abs(actual.get(kind,-1)-expected[kind])<.000000001,'legacy exact probability '+kind)
  ck(inv.refresh(old,true) and JSON.parse_string(JSON.stringify(old))==expected_after,'legacy RNG, shelf and charged transaction unchanged')
 preload('res://tests/fixtures/catalog_fixture_v116.gd').restore(saved_catalogue)
 # A late ingredient cannot be inserted into a zero-weight ordinary tier.
 var data={'round':1,'supply_version':122,'eligible':{'w_sword':true,'weapon_21020024':true},'unlocked':{'weapon_21020015':true},'owned':{'zig':true},'partners':['weapon_21020024']}
 ck(SHOP.pool(data,3).get('weapon_21020024',0)==0,'focused aid respects ordinary zero weight')
 ck(SHOP.pool(data,4).get('weapon_21020024',0)==0,'missing aid respects ordinary zero weight')
 # A sole missing ingredient for a late target must not receive forced 70% mass.
 run.round=2;run.shop=[{},{},{},{},{},{}];run.items=[];run.primary=''
 run.stash=[inv.make_piece('weapon_21010104','i1')]
 var ordinary=SHOP.ordinary(run,4,inv);var assisted=SHOP.distribution(run,4,inv)
 ck(assisted.get('mat_42300050',0)<.08,'terminal leaf remains uncommon instead of guaranteed aid')
 ck(assisted.get('mat_42300050',0)>0,'early terminal lucky supply is still possible')
 ck(inv.craft_unlocked(run,'weapon_21010036'),'supply has no crafting round gate')
 var scarcity_run=inv.new_run_supply('jingran',91,'full',122)
 var first_pool=SHOP.ordinary(scarcity_run,2,inv)
 ck(first_pool.get('mat_42300050',0)>0 and first_pool.mat_42300050<first_pool.mat_43020011*.1,'short terminal catalyst has low nonzero opening supply')
 ck(abs(first_pool.mat_43020011-first_pool.mat_43020021)<.000001,'basic starter upgrade materials retain equal ordinary weight')
 for kind in ['mat_42500030','electro_coin']:
  ck(first_pool.get(kind,0)>0 and first_pool[kind]<first_pool.mat_43020011*.1,'crafted terminal catalyst branch stays rare '+kind)
 scarcity_run.round=5
 var middle_pool=SHOP.ordinary(scarcity_run,2,inv)
 ck(abs(middle_pool.mat_42300050-middle_pool.mat_43020011)<.000001,'terminal catalyst reaches ordinary supply by midgame')
 for mode in ['full','focused']:
  var branch=inv.new_run_supply('zani',91,mode,122);branch.round=2
  var scarce=SHOP.ordinary(branch,2,inv);branch.erase('supply_version')
  var historic=SHOP.ordinary(branch,2,inv)
  for kind in ['answer','lamp']:
   if historic.has(kind):ck(scarce[kind]>0 and scarce[kind]<historic[kind]*.2,'direct crafted catalyst cannot bypass scarcity '+mode+kind)
 for leader in C.selectable_leaders():
  var starter=C.characters[leader].starter
  var basic=C.combinations.filter(func(r):return r.base==starter and int(C.items[r.target].get('v75',{}).get('tier',0))==2)
  ck(not basic.is_empty(),'every starter keeps a first upgrade '+leader)
  for recipe in basic:
   ck(preload('res://scripts/shop/supply_policy_v122.gd').commodity_weight(recipe.materials[0],1)==1,'first upgrade input remains ordinary '+recipe.target)
 for mode in ['full','focused']:
  var fresh=inv.new_run('aemeath',31,mode)
  for rn in [1,2,3,5,8,11]:
   fresh.round=rn
   for slot in 5:
    var dist=SHOP.distribution(fresh,slot,inv);var total=0.0
    for kind in dist:total+=dist[kind];ck(inv.shop_eligible(fresh,kind),'eligible '+kind)
    ck(abs(total-1)<.000001,'normalization '+mode+str(rn)+str(slot))
 var frozen=inv.new_run_supply('aemeath',19,'focused',0)
 ck(not frozen.has('supply_version'),'explicit historic constructor retains absent version')
 var locked=run.duplicate(true);locked.shop=[{'kind':'w_sword','locked':true},{},{},{},{},{}]
 var before=locked.duplicate(true);var plan=inv.plan_refresh(locked,true)
 ck(locked==before and plan.ok,'refresh remains a pure plan')
 ck(inv.commit_operation(locked,plan).ok and locked.shop[0]==before.shop[0],'new supply preserves locked offer')
 var old_plan=inv.plan_refresh(locked,true);locked.gold+=1;var changed=locked.duplicate(true)
 ck(not inv.commit_operation(locked,old_plan).ok and locked==changed,'stale plan cannot bypass full transaction validation')
 var matchmaker=preload('res://scripts/shop/matchmaking.gd').new(inv.practice,preload('res://scripts/shop/practice_budget.gd').METHOD)
 var old_enemy=matchmaker.practice(1,8,'full',0)
 var new_enemy=matchmaker.practice(1,8,'full',122)
 ck(old_enemy.get('supply_version',0)==0 and new_enemy.get('supply_version',0)==122,'practice builds the requested public supply version')
 ck(matchmaker.practice_cache.size()==2,'supply versions occupy independent practice cache keys')
 ck(old_enemy.practice_spend+old_enemy.practice_unspent==9 and new_enemy.practice_spend+new_enemy.practice_unspent==9,'practice retains public starting budget')
 old_enemy.round=4;new_enemy.round=4;old_enemy.owner='old';new_enemy.owner='new'
 ck(matchmaker.choose(4,8,[old_enemy,new_enemy],'qa','full',122).owner=='new','new runs match only new supply ghosts')
 ck(matchmaker.choose(4,8,[new_enemy,old_enemy],'qa','full',0).owner=='old','old runs match only old supply ghosts')
 for candidate in [old_enemy,new_enemy]:ck(inv.validate_ghost(JSON.parse_string(JSON.stringify(candidate))),'JSON ghost preserves supply validity')
 print('SUPPLY_V122 ',checks,' checks, ',failures,' failures')
 quit(1 if failures else 0)
