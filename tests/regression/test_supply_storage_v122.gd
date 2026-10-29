extends SceneTree
const I=preload('res://scripts/inventory/inventory.gd')
const S=preload('res://scripts/storage/storage.gd')
var checks=0
var failures=0
func ck(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():
 var inv=I.new();var storage=S.new('/tmp/resonance-supply-v122-'+str(Time.get_ticks_usec()))
 for version in [0,122]:
  var run=inv.new_run_supply('aemeath',19,'full',version)
  storage.save(run)
  var restored=storage.resume()
  ck(restored==run,'full run survives save/reload with identical numeric metadata '+str(version))
  ck(not restored.has('supply_version') if version==0 else restored.supply_version is int,'old absence/new integer preserved '+str(version))
  var ghost=inv.snapshot(run,'qa')
  storage.write_json(storage.root_path+'ghosts.json',[ghost])
  var pool=storage.pool()
  ck(pool.size()==1 and (not pool[0].has('supply_version') if version==0 else pool[0].supply_version is int),'ghost pool preserves absent/integer supply '+str(version))
  storage.write_json(storage.root_path+'import.json',ghost)
  var imported=storage.import_ghost(storage.root_path+'import.json',false)
  ck(not imported.is_empty() and (not imported.has('supply_version') if version==0 else imported.supply_version is int),'manual import preserves absent/integer supply '+str(version))
 var invalid=inv.new_run('aemeath',19);invalid.supply_version=122.5
 storage.write_json(storage.root_path+'run.json',invalid)
 var before=FileAccess.get_file_as_bytes(storage.root_path+'run.json')
 ck(storage.resume().is_empty() and FileAccess.get_file_as_bytes(storage.root_path+'run.json')==before,'fractional supply rejected before normalization without save rewrite')
 print('SUPPLY_STORAGE_V122 ',checks,' checks, ',failures,' failures')
 quit(1 if failures else 0)
