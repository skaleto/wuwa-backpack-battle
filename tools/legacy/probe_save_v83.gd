extends SceneTree
const S=preload("res://scripts/storage/storage.gd")
const I=preload("res://scripts/inventory/inventory.gd")
func _initialize():
 var source="user://run.json";var before=FileAccess.get_file_as_bytes(source)
 var dir="/tmp/resonance-v83-save-probe-%d/"%OS.get_process_id()
 var storage=S.new(dir);var file=FileAccess.open(dir+"run.json",FileAccess.WRITE);file.store_buffer(before);file.close()
 var old=JSON.parse_string(before.get_string_from_utf8());var run=storage.resume()
 assert(not run.is_empty() and storage.inventory.validate_run(run))
 for key in ["gold","seed","round","wins","losses","shop","history"]:assert(run[key]==old[key])
 for key in I.OWNED_COLLECTIONS:
  assert(run[key].size()==old[key].size())
  for n in run[key].size():
   for field in ["uid","kind","x","y","rotation","paid_cost"]:assert(run[key][n].get(field)==old[key][n].get(field))
 assert(storage.resume()==run)
 assert(FileAccess.get_file_as_bytes(source)==before)
 print("PASS actual save copied to isolated directory; ownership, money, offers, RNG and history preserved; original bytes unchanged")
 quit()
