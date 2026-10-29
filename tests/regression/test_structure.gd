extends SceneTree
const C=preload("res://scripts/data/catalog.gd")
const S=preload("res://scripts/ui/visual_skin.gd")
const G=preload("res://scripts/ui/items/art_geometry.gd")
var failures=0
var checks=0
func ck(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
 ck(C.catalogue_hash=="16cf6ae5e46b9328761bf304624cd172bbf74e7da6f6bcc0a639e7c7ee46e82f","layout retains published online pool fingerprint")
 ck(S.validate_manifest().is_empty(),"registered current assets all exist")
 var seen={}
 for kind in C.items:
  if C.is_tag(kind,"bag"):continue
  var path=G.path(kind)
  if seen.has(path):continue
  seen[path]=true
  ck(FileAccess.file_exists(path),"offline cache survives move: "+kind)
  if not FileAccess.file_exists(path):continue
  var data=FileAccess.open(path,FileAccess.READ).get_var(false)
  ck(data is Array and data.size()==4 and data.all(func(v):return v is Dictionary and not v.get("empty",true)),"four cached rotations: "+kind)
 for entry in S.manifest.items.values():
  var path="res://"+str(entry.path).trim_prefix("res://")
  ck(FileAccess.get_sha256(path)==str(entry.sha256),"registry matches source bytes: "+path)
 for folder in DirAccess.get_directories_at("res://assets/characters/rigs"):
  var rig="res://assets/characters/rigs/"+folder+"/rig.tscn"
  ck(load(rig) is PackedScene,"retained authoring rig resolves: "+folder)
 print("STRUCTURE ",checks," checks, ",failures," failures; ",seen.size()," unique silhouette caches")
 quit(1 if failures else 0)
