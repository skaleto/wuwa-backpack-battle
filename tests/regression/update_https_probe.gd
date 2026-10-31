extends SceneTree
class Probe extends "res://scripts/update/update_client.gd":
 var port=0
 func _request_url(url:String)->void:
  if not P.url_allowed(url,config):_error("origin denied");return
  requested_url=url
  if request.request(url.replace("https://localhost/","https://localhost:"+str(port)+"/"))!=OK:_error("connection failed")
var failures=0
func ck(ok:bool,label:String):
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():call_deferred("run_probe")
func wait_ready(c):
 for i in 600:
  if not c.busy():return
  await create_timer(.01).timeout
 ck(false,"request completes within bound")
func run_probe():
 var path=OS.get_cmdline_user_args()[0];var cfg=JSON.parse_string(FileAccess.get_file_as_string(path))
 var cert=X509Certificate.new();cert.load(cfg.certificate)
 var c=Probe.new();c.port=int(cfg.qa_port);root.add_child(c);c.configure(cfg,cfg.cache,"Windows",{},true)
 c.request.set_tls_options(TLSOptions.client(cert))
 c.check();await wait_ready(c);ck(c.status=="available","HTTPS signed feed")
 c.download();await wait_ready(c);ck(c.status=="ready","streamed HTTPS download verified and staged")
 ck(c.store.state().active.is_empty() and not c.store.state().pending.is_empty(),"network completion cannot activate live game")
 c.status="idle";c.config.feed_url=cfg.feed_url.replace("feed.json","tampered.json")
 c.check();await wait_ready(c);ck(c.status=="error","tampered network payload denied")
 c.status="idle";c.config.feed_url=cfg.feed_url.replace("feed.json","redirect.json")
 c.check();await wait_ready(c);ck(c.status=="error","redirect to nontrusted origin denied")
 c.status="available";c.artifact.url=cfg.feed_url.replace("feed.json","corrupt.pck")
 c.download();await wait_ready(c);ck(c.status=="error","corrupt downloaded bytes denied")
 ck(not c.store.state().pending.is_empty(),"failed retry preserves earlier good pending pack")
 c.queue_free();await process_frame
 print("UPDATE_HTTPS failures=",failures);quit(1 if failures else 0)
