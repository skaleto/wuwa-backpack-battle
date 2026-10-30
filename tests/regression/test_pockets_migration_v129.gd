extends SceneTree
const C=preload('res://scripts/data/catalog.gd')
const I=preload('res://scripts/inventory/inventory.gd')
const S=preload('res://scripts/storage/storage.gd')
const KINDS=['pocket_single','pocket_double','pocket_long_l','pocket_long_j']
var checks=0
var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():
 var inv=I.new();var store=S.new('user://qa-pockets129-migration-'+str(OS.get_process_id())+'/')
 ck(store.has_method('migrate_v129'),'exact V128 migration exists')
 if not store.has_method('migrate_v129'):finish();return
 var hash128=JSON.parse_string(FileAccess.get_file_as_string('res://tests/fixtures/data/wuwa-items-v128/runtime-catalogue.json')).catalogue_hash
 for version in [0,122,125,127,128]:
  store=S.new('user://qa-pockets129-migration-'+str(OS.get_process_id())+'/'+str(version)+'/')
  var old=inv.new_run_supply('aemeath',129,'full',version);old.catalogue_hash=hash128;old.simulation_version='resonance-v128'
  var original=old.duplicate(true);var migrated=store.call('migrate_v129',old)
  ck(not migrated.is_empty() and old==original,'pure migration '+str(version))
  if migrated.is_empty():continue
  var normalized=migrated.duplicate(true);normalized.catalogue_hash=hash128
  ck(normalized==original,'only hash changes for unchanged battle rules '+str(version))
  old.catalogue_hash='unknown';ck(store.call('migrate_v129',old).is_empty(),'unknown hash rejected')
  old=original.duplicate(true);old.supply_version=129
  ck(store.call('migrate_v129',old).is_empty(),'old hash cannot claim supply 129')
  for kind in KINDS:
   for collection in ['stash','pending_gifts','pending_rearrange']:
    old=original.duplicate(true);old[collection].append(inv.make_piece(kind,'i100'));old.serial=100
    ck(store.call('migrate_v129',old).is_empty(),'new owned ID cannot spoof historical hash '+kind+'/'+collection)
   old=original.duplicate(true);old.shop[5]={'kind':kind,'locked':false}
   ck(store.call('migrate_v129',old).is_empty(),'new offer cannot spoof historical hash '+kind)
  var combat={'winner':-1,'duration':2.1,'events':[{'kind':'attack','value':7.123}],'frames':[{'time':0,'sides':[]}],'totals':[{},{}]}
  old=original.duplicate(true);old.phase='result';old.combat=combat.duplicate(true);old.history=[{'round':1,'winner':-1,'combat':combat.duplicate(true)}]
  old.opponent=inv.snapshot(original,'historical');old.opponent.catalogue_hash=hash128;old.opponent.simulation_version='resonance-v128'
  var frozen=store.call('migrate_v129',old)
  ck(not frozen.is_empty() and frozen.combat==combat and frozen.history==old.history and frozen.simulation_version=='resonance-v128','completed combat stays frozen')
  ck(frozen.get('opponent',{}).get('simulation_version')=='resonance-v128','historical opponent provenance retained')
  store.write_json(store.root_path+'run.json',old)
  var bytes=FileAccess.get_file_as_bytes(store.root_path+'run.json');var loaded=store.resume()
  ck(not loaded.is_empty() and loaded.catalogue_hash==C.catalogue_hash,'public resume migrates')
  ck(FileAccess.get_file_as_bytes(store.root_path+'run-before-v129-backup.json')==bytes,'exact pre-migration backup')
  var current=FileAccess.get_file_as_bytes(store.root_path+'run.json')
  ck(store.resume()==loaded and FileAccess.get_file_as_bytes(store.root_path+'run.json')==current,'second resume idempotent')
  var ghost=old.opponent.duplicate(true);store.write_json(store.root_path+'ghosts.json',[ghost])
  var ghost_bytes=FileAccess.get_file_as_bytes(store.root_path+'ghosts.json');var pool=store.pool()
  ck(pool.size()==1 and pool[0].items==JSON.parse_string(JSON.stringify(ghost.items)) and int(pool[0].get('supply_version',0))==version,'old ghost migrated with supply')
  ck(FileAccess.get_file_as_bytes(store.root_path+'ghosts.json')==ghost_bytes,'ghost file read-only')
  store.write_json(store.root_path+'import.json',ghost)
  var imported=store.import_ghost(store.root_path+'import.json',false)
  ck(not imported.is_empty() and int(imported.get('supply_version',0))==version,'manual import uses same migration')
 for previous in [[C.v116_hash,'migrate_v124','resonance-v116'],[C.v124_hash,'migrate_v125','resonance-v124'],[C.v125_hash,'migrate_v127','resonance-v125'],[C.v127_hash,'migrate_v128','resonance-v127']]:
  var fake=inv.new_run_supply('aemeath',129,'full',0);fake.catalogue_hash=previous[0];fake.simulation_version=previous[2];fake.stash.append(inv.make_piece('pocket_single','i100'));fake.serial=100
  ck(store.call(previous[1],fake).is_empty(),'older published hashes reject new pocket '+previous[1])
 var current_run=inv.new_run_supply('aemeath',129,'full',129);current_run.gold=30
 for kind in KINDS:
  current_run.shop[5]={'kind':kind,'locked':false};ck(inv.buy(current_run,5),'new pocket public buy before save '+kind)
 store.save(current_run);var resumed=store.resume()
 ck(resumed==current_run and resumed.supply_version==129,'four new pocket kinds round-trip losslessly')
 finish()
func finish():
 print('POCKETS_MIGRATION_V129 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
