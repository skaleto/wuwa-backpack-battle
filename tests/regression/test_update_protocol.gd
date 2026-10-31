extends SceneTree
var failures=0
func ck(ok:bool,label:String):
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
 var path="res://scripts/update/update_manifest.gd"
 if not ResourceLoader.exists(path):ck(false,"signed update protocol exists");quit(1);return
 var P=load(path);var key=Crypto.new().generate_rsa(2048)
 var cfg={"public_key":key.save_to_string(true),"hosts":["updates.example.org"],"base_id":"test-base","runtime":1,"sequence":10}
 var body={"schema":1,"sequence":11,"version":"test-11","base_id":"test-base","runtime":1,"notes":["修复显示"],"platforms":{"Windows":{"kind":"patch","url":"https://updates.example.org/releases/11.pck","sha256":"a".repeat(64),"bytes":1024}}}
 var raw=JSON.stringify(body).to_utf8_buffer();var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(raw)
 var signature=Crypto.new().sign(HashingContext.HASH_SHA256,hash.finish(),key)
 var envelope=JSON.stringify({"payload":Marshalls.raw_to_base64(raw),"signature":Marshalls.raw_to_base64(signature)})
 var result=P.decode(envelope.to_utf8_buffer(),cfg,"Windows")
 ck(result.get("ok",false) and result.release.sequence==11,"signed release accepted")
 var altered=JSON.parse_string(envelope);altered.payload=Marshalls.raw_to_base64((raw.get_string_from_utf8()+" ").to_utf8_buffer())
 ck(not P.decode(JSON.stringify(altered).to_utf8_buffer(),cfg,"Windows").ok,"signed payload tampering rejected")
 var other_cfg=cfg.duplicate(true);other_cfg.public_key=Crypto.new().generate_rsa(2048).save_to_string(true)
 ck(not P.decode(envelope.to_utf8_buffer(),other_cfg,"Windows").ok,"wrong signing key rejected")
 ck(not P.decode(envelope.replace("payload","wrong").to_utf8_buffer(),cfg,"Windows").ok,"missing signed payload rejected")
 ck(not P.decode(envelope.to_utf8_buffer(),cfg,"macOS").ok,"wrong platform rejected")
 ck(not P.url_allowed("http://updates.example.org/a",cfg),"HTTPS mandatory")
 ck(not P.url_allowed("https://updates.example.org.evil.org/a",cfg),"host exact match")
 ck(not P.url_allowed("https://user@updates.example.org/a",cfg),"credentials in URL rejected")
 ck(not P.url_allowed("https://updates.example.org/a#x",cfg),"fragments rejected")
 body.platforms.Windows.url="https://evil.org/payload.pck"
 ck(not P.validate(body,cfg,"Windows").ok,"signed but untrusted download origin rejected")
 body.platforms.Windows.url="https://updates.example.org/releases/11.pck";body.platforms.Windows.bytes=-1
 ck(not P.validate(body,cfg,"Windows").ok,"negative size rejected")
 body.platforms.Windows.bytes=1024;body.sequence=1.5
 ck(not P.validate(body,cfg,"Windows").ok,"fractional sequence rejected")
 body.sequence=11;body.base_id="other"
 ck(not P.validate(body,cfg,"Windows").ok,"wrong patch base rejected")
 body.base_id="test-base";body.runtime=2
 ck(not P.validate(body,cfg,"Windows").ok,"patch runtime mismatch rejected")
 var fallback=body.platforms.Windows.duplicate(true);fallback.kind="full";fallback.archive_root="SolarisBrawl";fallback.executable="SolarisBrawl.exe"
 body.platforms.Windows.full=fallback
 ck(P.validate(body,cfg,"Windows").get("artifact",{}).get("kind")=="full","incompatible patch selects signed full client")
 body.platforms.Windows.full.executable="../run.exe"
 ck(not P.validate(body,cfg,"Windows").ok,"unsafe full layout rejected")
 print("UPDATE_PROTOCOL failures=",failures);quit(1 if failures else 0)
