extends SceneTree
const C=preload('res://scripts/data/catalog.gd')
const I=preload('res://scripts/inventory/inventory.gd')
const SHOP=preload('res://scripts/shop/shop_v75.gd')
const POLICY=preload('res://scripts/shop/supply_policy_v127.gd')
const STORAGE=preload('res://scripts/storage/storage.gd')
var failures=0
var checks=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():
 preload("res://tests/fixtures/catalog_fixture_v127.gd").apply()
 var inv=I.new();var spec=preload('res://scripts/data/family_catalog_v127.gd').spec
 # Owned historical objects can change their current stars or functional tags.
 # Compare every updated old object against the actual pre-overlay catalogue,
 # including focused partner help, not just empty/full-pool eligibility.
 var focused=[]
 for sv in [0,122,125]:
  for kind in spec.updates:
   var previous=inv.new_run_supply('yinlin',125,'focused',sv)
   previous.items=[];previous.primary='';previous.stash=[inv.make_piece(kind,'i50')];previous.serial=50;previous.round=6
   var distributions=[]
   for slot in 5:distributions.append(SHOP.distribution(previous,slot,inv))
   focused.append({'run':previous,'distributions':distributions})
 var saved=preload('res://tests/fixtures/catalog_fixture_v125.gd').apply()
 for row in focused:
  for slot in 5:
   var previous=SHOP.distribution(row.run,slot,inv);var current=row.distributions[slot]
   ck(previous.size()==current.size() and previous.keys().all(func(k):return absf(previous[k]-current.get(k,-1))<0.000000001),'historical focused help preserved '+row.run.stash[0].kind+'/'+str(slot))
 preload('res://tests/fixtures/catalog_fixture_v116.gd').restore(saved)
 ck(C.v125_hash=='4c78d2a99b31442730432dcf7359fedf40f858baffea67b8f56ed06aa07e933a','historical V125 hash preserved')
 var baseline=JSON.parse_string(FileAccess.get_file_as_string('res://tests/fixtures/data/families-v127/supply-before.json'))
 for row in baseline:
  for slot in 5:
   var now=SHOP.distribution(row.run,slot,inv);var before=row.distributions[slot]
   ck(now.size()==before.size(),'old supply size '+str(row.run.get('supply_version',0))+'/'+str(slot))
   ck(before.keys().all(func(k):return now.has(k) and absf(now[k]-before[k])<0.00000001),'old supply probabilities '+str(row.run.get('supply_version',0))+'/'+str(slot))
 var run=inv.new_run_supply('aemeath',127,'full',127)
 for kind in spec.new_items:
  var n=C.profile(kind)
  ck(inv.shop_eligible(run,kind)==not n.craft_only,'base supply only '+kind)
  ck(inv.craft_unlocked(run,kind),'no round gate for owned crafting '+kind)
 for rn in [1,3,6,10]:
  run.round=rn
  for slot in 5:
   var before=run.duplicate(true);var d=SHOP.distribution(run,slot,inv)
   ck(is_equal_approx(d.values().reduce(func(a,b):return a+b,0.0),1),'normalized distribution')
   ck(run==before,'read-only probability projection')
   ck(d.keys().all(func(k):return inv.shop_eligible(run,k)),'no locked/craft-only injection')
 # A material already in stash can bias toward multiple branches, never replace
 # ordinary zero probability with a forced early terminal.
 run.round=1;run.stash=[inv.make_piece('cool_tea','i90')];run.serial=90
 var data=SHOP.facts(run,inv);var d=SHOP.distribution(run,4,inv)
 ck(d.has('relic_tea_strainer') and d.has('mat_42300030'),'both tea branch inputs can be found')
 ck(not d.has('provision_strong_tea') and not d.has('provision_clear_tea'),'terminal tea not sold directly')
 var store=STORAGE.new('user://qa-family127-'+str(OS.get_process_id())+'/')
 var old=baseline[0].run.duplicate(true);old.simulation_version='resonance-v125';old.catalogue_hash=C.v125_hash
 var original=old.duplicate(true);var migrated=store.migrate_v127(old)
 ck(not migrated.is_empty() and old==original,'pure precise migration')
 if not migrated.is_empty():
  ck(migrated.items==old.items and migrated.stash==old.stash and migrated.gold==old.gold and migrated.seed==old.seed,'paid inventory and RNG unchanged')
  ck(migrated.get('supply_version',0)==old.get('supply_version',0) and migrated.simulation_version==C.SIMULATION_VERSION,'future version and old supply retained')
 old.catalogue_hash='invented';ck(store.migrate_v127(old).is_empty(),'unknown hash refused')
 old=original.duplicate(true);old.stash.append(inv.make_piece('relic_cutlery','i100'));old.serial=100
 ck(store.migrate_v127(old).is_empty(),'new item cannot masquerade as historical save')
 var lens=inv.new_run_supply('yinlin',125,'full',125);lens.stash.append(inv.make_piece('magnifier','i50'));lens.serial=50
 lens.catalogue_hash=C.v125_hash;lens.simulation_version='resonance-v125'
 var lens_before=lens.duplicate(true);var lens_after=store.migrate_v127(lens)
 ck(not lens_after.is_empty() and lens==lens_before and lens_after.stash==lens.stash,'historically owned lens survives its new supply introduction version')
 # Exercise the actual persistence entry rather than only a migration helper.
 store.write_json(store.root_path+'run.json',original)
 var bytes=FileAccess.get_file_as_bytes(store.root_path+'run.json')
 var resumed=store.resume()
 ck(not resumed.is_empty() and resumed.catalogue_hash==C.catalogue_hash,'V125 resumes through current public loader')
 ck(FileAccess.get_file_as_bytes(store.root_path+'run-before-v127-backup.json')==bytes,'exact old bytes backed up before migration')
 var current_bytes=FileAccess.get_file_as_bytes(store.root_path+'run.json')
 ck(store.resume()==resumed and FileAccess.get_file_as_bytes(store.root_path+'run.json')==current_bytes,'second resume is idempotent')
 var combat={'winner':-1,'duration':2.1,'events':[{'kind':'attack','value':7.123}],'frames':[{'time':0,'sides':[]}],'totals':[{},{}]}
 old=original.duplicate(true);old.phase='result';old.combat=combat.duplicate(true);old.opponent=inv.snapshot(original,'old')
 old.opponent.catalogue_hash=C.v125_hash;old.opponent.simulation_version='resonance-v125'
 old.history=[{'round':1,'winner':-1,'combat':combat.duplicate(true)}]
 var frozen=store.migrate_v127(old)
 ck(not frozen.is_empty() and frozen.combat==combat and frozen.history==old.history and frozen.simulation_version=='resonance-v125','completed combat and history remain frozen')
 ck(frozen.get('opponent',{}).get('simulation_version','')=='resonance-v125','historical opponent provenance preserved')
 run=inv.new_run('aemeath',7);run.gold=20
 for kind in ['magnifier','relic_cutlery','relic_tea_strainer','relic_clockwork','relic_diaphragm','relic_guard_plate','relic_breaker_wedge','relic_noise_lamp','relic_cooling_can']:
  run.round=10;run.shop[2]={'kind':kind,'locked':false};run.gold=20
  ck(inv.validate_run(run) and inv.buy(run,2) and run.stash[-1].kind==kind,'current base is actually purchasable '+kind)
 print('FAMILIES_SUPPLY_V127 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
