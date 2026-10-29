extends SceneTree
const C=preload('res://scripts/data/catalog.gd')
const SKIN=preload('res://scripts/ui/visual_skin.gd')
const GEO=preload('res://scripts/ui/items/art_geometry.gd')
var checks=0
var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():
 for kind in preload('res://scripts/data/original_catalog_v128.gd').spec.new_items:
  var path=SKIN.item_path(kind);var expected='res://assets/items/solaris/'+kind+'.png'
  ck(path==expected and FileAccess.file_exists(path),'native new original image resolves '+kind)
  if not FileAccess.file_exists(path):continue
  var image=Image.load_from_file(path);var entry=SKIN.manifest.items.get(kind,{})
  ck(image!=null and image.get_width()>0 and image.get_height()>0,'decodable original image '+kind)
  ck(entry.get('sha256','')==FileAccess.get_sha256(path),'registered exact image bytes '+kind)
  ck(FileAccess.file_exists(GEO.path(kind)),'offline geometry exists '+kind)
  if image==null:continue
  for turn in 4:
   var descriptor=GEO.descriptor(kind,turn,image)
   ck(not descriptor.get('empty',true) and descriptor.image_size==Vector2(image.get_size()),'four uncut rotations '+kind+'/'+str(turn))
 print('ORIGINAL_ASSETS_V128 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
