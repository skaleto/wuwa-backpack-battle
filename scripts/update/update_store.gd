extends RefCounted
## Versioned cache and atomic activation. Never opens run.json or identity files.
const P=preload("res://scripts/update/update_manifest.gd")
var root:String
var config:Dictionary
var platform:String
func _init(directory:String,channel:Dictionary,os_name:String):
 root=directory.trim_suffix("/")+"/";config=channel.duplicate(true);platform=os_name
 DirAccess.make_dir_recursive_absolute(root)
 if OS.get_name()!="Windows":FileAccess.set_unix_permissions(root,448)
func state()->Dictionary:
 var value=JSON.parse_string(FileAccess.get_file_as_string(root+"state.json")) if FileAccess.file_exists(root+"state.json") else null
 if not value is Dictionary:return {"active":"","previous":"","pending":"","trial":"","highest":int(config.sequence)}
 var result={"active":"","previous":"","pending":"","trial":"","highest":int(config.sequence)}
 for name in ["active","previous","pending","trial"]:
  if value.get(name) is String and valid_id(value[name]):result[name]=value[name]
 if P.integer(value.get("highest")):result.highest=maxi(int(config.sequence),int(value.highest))
 return result
static func valid_id(value:String)->bool:
 if value.is_empty():return true
 var regex=RegEx.new();regex.compile("^[0-9]{1,10}-[0-9a-f]{64}$")
 return regex.search(value)!=null
func write_state(value:Dictionary)->bool:return atomic_file(root+"state.json",JSON.stringify(value).to_utf8_buffer())
static func atomic_file(path:String,bytes:PackedByteArray)->bool:
 var temporary=path+".tmp";var f=FileAccess.open(temporary,FileAccess.WRITE)
 if f==null:return false
 f.store_buffer(bytes);f.flush();var ok=f.get_error()==OK;f.close()
 if not ok:return false
 if OS.get_name()!="Windows":FileAccess.set_unix_permissions(temporary,384)
 return DirAccess.rename_absolute(temporary,path)==OK
func stage(download:String,envelope:PackedByteArray)->Dictionary:
 var parsed=P.decode(envelope,config,platform)
 if not parsed.ok or parsed.artifact.kind!="patch":return P.fail("manifest")
 var release=parsed.release;var artifact=parsed.artifact;var current=state()
 if int(release.sequence)<=int(config.sequence) or int(release.sequence)<int(current.highest):return P.fail("downgrade")
 var file=FileAccess.open(download,FileAccess.READ)
 if file==null:return P.fail("download")
 var size=file.get_length();file.close()
 if size!=int(artifact.bytes) or FileAccess.get_sha256(download)!=artifact.sha256:return P.fail("checksum")
 var id=str(int(release.sequence))+"-"+artifact.sha256
 var target=root+id+".pck"
 if DirAccess.rename_absolute(download,target)!=OK:return P.fail("disk")
 if not atomic_file(root+id+".json",envelope):return P.fail("disk")
 current.pending=id;current.highest=maxi(current.highest,int(release.sequence))
 if not write_state(current):return P.fail("disk")
 return {"ok":true,"id":id,"release":release}
func verified(id:String)->Dictionary:
 if id.is_empty() or not valid_id(id):return {}
 var metadata=root+id+".json";var pack=root+id+".pck"
 if not FileAccess.file_exists(metadata) or not FileAccess.file_exists(pack):return {}
 var raw=P.read_envelope(metadata)
 var parsed=P.decode(raw,config,platform)
 if not parsed.ok or parsed.artifact.kind!="patch":return {}
 var expected=str(int(parsed.release.sequence))+"-"+parsed.artifact.sha256
 if id!=expected or int(parsed.release.sequence)<=int(config.sequence):return {}
 var f=FileAccess.open(pack,FileAccess.READ)
 if f==null:return {}
 var size=f.get_length();f.close()
 if size!=int(parsed.artifact.bytes) or FileAccess.get_sha256(pack)!=parsed.artifact.sha256:return {}
 return {"path":pack,"release":parsed.release,"id":id}
func prepare_boot(allow_activation:bool)->Dictionary:
 var value=state()
 if not value.trial.is_empty():
  value.active=value.previous;value.previous="";value.pending="";value.trial=""
  if not write_state(value):return {}
 if allow_activation and not value.pending.is_empty():
  var candidate=verified(value.pending)
  if candidate.is_empty():value.pending="";write_state(value)
  else:
   value.previous=value.active;value.active=value.pending;value.pending="";value.trial=value.active
   if not write_state(value):return {}
 var active=verified(value.active)
 if active.is_empty() and not value.active.is_empty():
  value.active=value.previous;value.previous="";value.trial=""
  if not write_state(value):return {}
  return verified(value.active)
 return active
func acknowledge()->bool:
 var value=state()
 if not value.trial.is_empty():
  value.trial=""
  if not write_state(value):return false
 prune()
 return true
func reject_active()->void:
 var value=state();value.active=value.previous;value.previous="";value.pending="";value.trial="";write_state(value)

func prune()->void:
 # Exact cache names only; keep unknown files and one healthy fallback.
 var value=state();var keep=[value.active,value.previous,value.pending,value.trial]
 var directory=DirAccess.open(root)
 if directory==null:return
 for name in directory.get_files():
  if name.ends_with(".pck") or name.ends_with(".json"):
   var id=name.get_basename()
   if not id.is_empty() and valid_id(id) and id not in keep and not directory.is_link(name):directory.remove(name)
 var full_path=root+"full-ready.json"
 if FileAccess.file_exists(full_path):
  var parsed=P.decode(P.read_envelope(full_path),config,platform)
  if parsed.ok and int(parsed.release.sequence)<=int(config.sequence):
   var archive=str(int(parsed.release.sequence))+"-full.zip"
   if not directory.is_link(archive):directory.remove(archive)
   directory.remove("full-ready.json")
