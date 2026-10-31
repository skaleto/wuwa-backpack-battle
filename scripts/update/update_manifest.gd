extends RefCounted
## Public signed protocol only; never reads a player profile or mutates a run.
const LIMIT=65536
const MAX_PACKAGE=2147483648
static func fail(reason:String)->Dictionary:return {"ok":false,"reason":reason}
static func integer(v:Variant)->bool:return (v is int or v is float) and is_finite(float(v)) and float(v)==floor(float(v))
static func url_allowed(url:String,config:Dictionary)->bool:
 for character in url:
  if character.unicode_at(0)<33:return false
 if url.length()>4096 or "#" in url or "\\" in url or "\n" in url or "\r" in url:return false
 var regex=RegEx.new();regex.compile("^https://([a-z0-9.-]+)/[^ ]+$")
 var found=regex.search(url)
 return found!=null and found.get_string(1) in config.get("hosts",[])
static func decode(bytes:PackedByteArray,config:Dictionary,platform:String)->Dictionary:
 if bytes.is_empty() or bytes.size()>LIMIT:return fail("manifest_size")
 var envelope=JSON.parse_string(bytes.get_string_from_utf8())
 if not envelope is Dictionary or not envelope.get("payload") is String or not envelope.get("signature") is String:return fail("envelope")
 var payload=Marshalls.base64_to_raw(envelope.payload);var signature=Marshalls.base64_to_raw(envelope.signature)
 if payload.is_empty() or payload.size()>LIMIT or signature.is_empty():return fail("signature")
 var key=CryptoKey.new()
 if key.load_from_string(str(config.get("public_key","")),true)!=OK:return fail("key")
 var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(payload)
 if not Crypto.new().verify(HashingContext.HASH_SHA256,hash.finish(),signature,key):return fail("signature")
 return validate(JSON.parse_string(payload.get_string_from_utf8()),config,platform)
static func validate(release:Variant,config:Dictionary,platform:String)->Dictionary:
 if not release is Dictionary or release.get("schema")!=1:return fail("schema")
 for field in ["sequence","runtime"]:
  if not integer(release.get(field)) or release[field]<1 or release[field]>2147483647:return fail("version")
 for field in ["version","base_id"]:
  if not release.get(field) is String or release[field].is_empty() or release[field].length()>80:return fail("version")
 if not release.get("notes",[]) is Array or release.get("notes",[]).size()>8:return fail("notes")
 for note in release.get("notes",[]):
  if not note is String or note.length()>180:return fail("notes")
 if not release.get("platforms") is Dictionary:return fail("platform")
 var artifact=release.platforms.get(platform)
 if not artifact is Dictionary or artifact.get("kind") not in ["patch","full","web"]:return fail("platform")
 if artifact.kind=="patch" and (release.base_id!=config.get("base_id") or release.runtime!=config.get("runtime")):
  artifact=artifact.get("full")
  if not artifact is Dictionary or artifact.get("kind")!="full":return fail("base")
 if not url_allowed(str(artifact.get("url","")),config):return fail("origin")
 if artifact.has("fallback_url") and not url_allowed(str(artifact.fallback_url),config):return fail("origin")
 if artifact.kind=="web":
  if platform!="Web":return fail("platform")
 else:
  if platform in ["Web","iOS","Android"]:return fail("platform")
  var regex=RegEx.new();regex.compile("^[0-9a-f]{64}$")
  if not artifact.get("sha256") is String or regex.search(artifact.sha256)==null:return fail("hash")
  if not integer(artifact.get("bytes")) or artifact.bytes<1 or artifact.bytes>MAX_PACKAGE:return fail("size")
  if artifact.kind=="patch" and (release.base_id!=config.get("base_id") or release.runtime!=config.get("runtime")):return fail("base")
  if artifact.kind=="full":
   if not safe_relative(artifact.get("archive_root")) or "/" in artifact.archive_root or not safe_relative(artifact.get("executable")):return fail("layout")
 return {"ok":true,"release":release.duplicate(true),"artifact":artifact.duplicate(true)}

static func safe_relative(value:Variant)->bool:
 if not value is String or value.is_empty() or value.length()>512 or value.begins_with("/") or "\\" in value or ":" in value:return false
 for character in value:
  if character.unicode_at(0)<32:return false
 for part in value.split("/"):
  if part in ["",".",".."]:return false
 return true
static func read_envelope(path:String)->PackedByteArray:
 var file=FileAccess.open(path,FileAccess.READ)
 if file==null:return PackedByteArray()
 if file.get_length()>LIMIT:file.close();return PackedByteArray()
 var raw=file.get_buffer(file.get_length());file.close();return raw
