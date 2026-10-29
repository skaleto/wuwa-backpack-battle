extends SceneTree
const C=preload('res://scripts/data/catalog.gd')
const I=preload('res://scripts/inventory/inventory.gd')
const S=preload('res://scripts/storage/storage.gd')
var checks=0
var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():
 var inv=I.new();var store=S.new('user://qa-original128-'+str(OS.get_process_id())+'/')
 ck(store.has_method('migrate_v128'),'exact V127 migration exists')
 if not store.has_method('migrate_v128'):finish();return
 var old=inv.new_run_supply('aemeath',128,'full',127);old.catalogue_hash=C.v127_hash;old.simulation_version='resonance-v127'
 var original=old.duplicate(true);var migrated=store.call('migrate_v128',old)
 ck(not migrated.is_empty() and old==original,'pure exact hash migration')
 if migrated.is_empty():finish();return
 for key in ['items','stash','bags','shop','gold','seed','serial','supply_version','recruitment']:
  ck(migrated[key]==original[key],'owned property unchanged '+key)
 ck(migrated.catalogue_hash==C.catalogue_hash and migrated.simulation_version=='resonance-v128','next battle uses current catalog')
 old.catalogue_hash='unknown';ck(store.call('migrate_v128',old).is_empty(),'unknown hash rejected')
 old=original.duplicate(true);old.supply_version=128
 ck(store.call('migrate_v128',old).is_empty(),'historical hash cannot claim new supply version')
 for kind in preload('res://scripts/data/original_catalog_v128.gd').spec.new_items:
  old=original.duplicate(true);old.stash.append(inv.make_piece(kind,'i100'));old.serial=100
  ck(store.call('migrate_v128',old).is_empty(),'new ID cannot spoof historical hash '+kind)
 var combat={'winner':-1,'duration':2.1,'events':[{'kind':'attack','value':7.123}],'frames':[{'time':0,'sides':[]}],'totals':[{},{}]}
 old=original.duplicate(true);old.phase='result';old.combat=combat.duplicate(true);old.history=[{'round':1,'winner':-1,'combat':combat.duplicate(true)}]
 old.opponent=inv.snapshot(original,'historical');old.opponent.catalogue_hash=C.v127_hash;old.opponent.simulation_version='resonance-v127'
 var frozen=store.call('migrate_v128',old)
 ck(not frozen.is_empty() and frozen.combat==combat and frozen.history==old.history and frozen.simulation_version=='resonance-v127','completed combat remains frozen')
 ck(frozen.get('opponent',{}).get('simulation_version')=='resonance-v127','historical opponent provenance retained')
 store.write_json(store.root_path+'run.json',old)
 var bytes=FileAccess.get_file_as_bytes(store.root_path+'run.json');var loaded=store.resume()
 ck(not loaded.is_empty() and loaded.catalogue_hash==C.catalogue_hash,'public resume migrates')
 ck(FileAccess.get_file_as_bytes(store.root_path+'run-before-v128-backup.json')==bytes,'byte exact pre-migration backup')
 var current=FileAccess.get_file_as_bytes(store.root_path+'run.json')
 ck(store.resume()==loaded and FileAccess.get_file_as_bytes(store.root_path+'run.json')==current,'second resume idempotent')
 var ghost=old.opponent.duplicate(true);store.write_json(store.root_path+'ghosts.json',[ghost])
 var ghost_bytes=FileAccess.get_file_as_bytes(store.root_path+'ghosts.json');var pool=store.pool()
 ck(pool.size()==1 and pool[0].simulation_version=='resonance-v127' and pool[0].items==JSON.parse_string(JSON.stringify(ghost.items)),'old ghost survives read-only migration')
 ck(FileAccess.get_file_as_bytes(store.root_path+'ghosts.json')==ghost_bytes,'ghost source bytes preserved')
 finish()
func finish():
 print('ORIGINAL_MIGRATION_V128 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
