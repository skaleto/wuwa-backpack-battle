extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
var count=0
var failed=0
func ck(ok:bool,label:String):
	count+=1
	if not ok:failed+=1;printerr("FAIL ",label)
func _initialize():
	if not FileAccess.file_exists("res://scripts/online/async_pvp.gd"):
		ck(false,"async snapshot/matching implementation exists");quit(1);return
	var p=load("res://scripts/online/async_pvp.gd")
	var inv=I.new();var run=inv.new_run("aemeath",17)
	var pool=p.pool_id(run);var frozen=p.freeze(inv,run,"alice","run-01")
	ck(frozen.ok,"valid starting snapshot freezes")
	ck(frozen.sha256==p.digest(frozen.bytes),"hash binds exact bytes")
	var key=p.object_key(pool,1,0,"alice","run-01",frozen.sha256)
	var decoded=p.decode(inv,frozen.bytes,key,pool,1)
	ck(decoded.ok and decoded.build.items==run.items,"remote decode retains exact item layouts")
	ck(not p.decode(inv,frozen.bytes,key,pool,2).ok,"cross-round download rejects")
	ck(not p.decode(inv,frozen.bytes,key,"wrong",1).ok,"cross-version download rejects")
	ck(not p.decode(inv,"{}".to_utf8_buffer(),key,pool,1).ok,"hash mismatch rejects")
	var candidates=[]
	for spec in [["alice",3],["bob",2],["cat",3],["dog",4]]:
		candidates.append({"key":p.object_key(pool,6,spec[1],spec[0],"run-01","a".repeat(64)),"wins":spec[1],"player_id":spec[0]})
	var ranked=p.rank(candidates,"alice",3,[],9)
	ck(ranked.size()==3 and ranked[0].player_id=="cat","nearest wins first, own builds excluded")
	var repeated=p.rank(candidates,"alice",3,["cat"],9)
	ck(repeated[0].player_id=="cat","near win layer retained when only recent account exists")
	var xml='<ListBucketResult><IsTruncated>true</IsTruncated><NextContinuationToken>abc&amp;def</NextContinuationToken><Contents><Key>'+key+'</Key><Size>1200</Size></Contents></ListBucketResult>'
	var listed=p.parse_listing(xml.to_utf8_buffer(),pool,1)
	ck(listed.ok and listed.entries.size()==1 and listed.continuation=="abc&def","OSS XML pagination and entities")
	ck(not p.parse_listing('<bad'.to_utf8_buffer(),pool,1).ok,"bad listing fails safely")
	var encoded='<ListBucketResult><Contents><Key>'+key.uri_encode()+'</Key><Size>1200</Size></Contents><EncodingType>url</EncodingType><IsTruncated>false</IsTruncated></ListBucketResult>'
	ck(p.parse_listing(encoded.to_utf8_buffer(),pool,1).entries.size()==1,"URL encoded OSS keys decoded exactly once")
	ck(not p.parse_listing('<ListBucketResult><IsTruncated>true</IsTruncated></ListBucketResult>'.to_utf8_buffer(),pool,1).ok,"truncated list without cursor rejected")
	var body=JSON.parse_string(frozen.bytes.get_string_from_utf8());body.build.items[0].rotation="oops"
	var bytes=JSON.stringify(body).to_utf8_buffer()
	ck(not p.decode(inv,bytes,p.object_key(pool,1,0,"alice","run-01",p.digest(bytes)),pool,1).ok,"malformed item rejected before typed validator")
	print("async protocol ",count," checks, failures ",failed);quit(1 if failed else 0)
