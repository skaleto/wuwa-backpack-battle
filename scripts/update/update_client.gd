extends Node
## Network/cache state only. The scene owns when a restart is safe.
const P=preload("res://scripts/update/update_manifest.gd")
const S=preload("res://scripts/update/update_store.gd")
var config:Dictionary={}
var current:Dictionary={}
var platform=""
var store
var status="idle"
var error_message=""
var available:Dictionary={}
var artifact:Dictionary={}
var envelope=PackedByteArray()
var downloaded=0
var total=0
var enabled=false
var request:HTTPRequest
var operation=""
var requested_url=""
var redirects=0
var used_fallback=false
var verify_task=-1
var verify_result:Dictionary={}
var full_ready=""
var install_job=""
var helper_pid=-1
var helper_elapsed=0.0
var _progress_age=0.0
func configure(channel:Dictionary,directory:String,os_name:String,active:Dictionary={},allow_network:bool=true)->void:
 config=channel.duplicate(true);platform=os_name;enabled=allow_network
 current=active.duplicate(true) if not active.is_empty() else config.duplicate(true)
 store=S.new(directory,config,platform)
 request=HTTPRequest.new();request.use_threads=not OS.has_feature("web");request.max_redirects=0;add_child(request)
 request.request_completed.connect(_completed)
 if platform in ["iOS","Android"]:status="unsupported"
 elif enabled and FileAccess.file_exists(store.root+"full-ready.json"):
  var raw=P.read_envelope(store.root+"full-ready.json")
  var parsed=P.decode(raw,config,platform)
  if parsed.ok and parsed.artifact.kind=="full" and int(parsed.release.sequence)>int(current.sequence):
   var path=store.root+str(int(parsed.release.sequence))+"-full.zip"
   if FileAccess.file_exists(path):
    available=parsed.release;artifact=parsed.artifact;envelope=raw;full_ready=path;status="ready"
 if enabled and status=="idle" and not store.state().pending.is_empty():
  # Cache metadata is checked cheaply here; bytes are reverified by bootstrap.
  var raw=P.read_envelope(store.root+store.state().pending+".json")
  var parsed=P.decode(raw,config,platform)
  if parsed.ok:available=parsed.release;artifact=parsed.artifact;envelope=raw;status="ready"
func busy()->bool:return status in ["checking","downloading","verifying","installing"]
func version()->String:return str(current.get("version",config.get("version","")))
func check()->void:
 if busy() or status=="ready":return
 if not enabled:_error("开发环境不连接更新服务，请在发布客户端检查。");return
 if platform in ["iOS","Android"]:status="unsupported";return
 status="checking";error_message="";operation="feed";redirects=0;used_fallback=false
 request.download_file="";request.body_size_limit=P.LIMIT;request.timeout=12
 var stamp=str(int(Time.get_unix_time_from_system())/300)
 _request_url(str(config.feed_url)+("&" if "?" in str(config.feed_url) else "?")+"t="+stamp)
func _request_url(url:String)->void:
 if not P.url_allowed(url,config):_error("更新地址验证失败，当前版本不受影响。");return
 requested_url=url
 if request.request(url,PackedStringArray(["Cache-Control: no-cache"]))!=OK:_error("暂时无法连接更新服务，请稍后重试。")
func accept_feed(raw:PackedByteArray)->void:
 var parsed=P.decode(raw,config,platform)
 if not parsed.ok:_error("更新信息校验未通过，请稍后重试。");return
 var seq=int(parsed.release.sequence)
 if seq<=int(current.sequence) or seq<int(store.state().highest):status="current";available={};artifact={};return
 available=parsed.release;artifact=parsed.artifact;envelope=raw;status="available";error_message=""
func download()->void:
 if status not in ["available","error"] or artifact.is_empty():return
 if not enabled:_error("请在发布客户端下载更新。");return
 if artifact.kind=="web":status="ready";return
 status="downloading";error_message="";operation="package";redirects=0;used_fallback=false;downloaded=0;total=int(artifact.bytes)
 request.download_file=store.root+"download.part";request.body_size_limit=total;request.timeout=1800
 _request_url(artifact.url)
func _completed(result:int,code:int,headers:PackedStringArray,body:PackedByteArray)->void:
 if status not in ["checking","downloading"]:return
 if code in [301,302,303,307,308] and redirects<3:
  for header in headers:
   if header.to_lower().begins_with("location:"):
    redirects+=1;_request_url(header.substr(9).strip_edges());return
 if result!=HTTPRequest.RESULT_SUCCESS or code!=200:
  if operation=="package" and not used_fallback and artifact.has("fallback_url"):
   used_fallback=true;redirects=0;_request_url(artifact.fallback_url);return
  _error("下载未完成，可重试；当前游戏和存档不受影响。" if operation=="package" else "暂时未能取得更新信息，可以离线游玩。");return
 if operation=="feed":accept_feed(body)
 else:finish_download()
func finish_download()->void:
 if artifact.is_empty() or verify_task>=0:return
 status="verifying";verify_result={}
 verify_task=WorkerThreadPool.add_task(_verify_download)
func _verify_download()->void:
 var path=store.root+"download.part"
 if artifact.kind=="patch":verify_result=store.stage(path,envelope);return
 var f=FileAccess.open(path,FileAccess.READ)
 if f==null:verify_result=P.fail("disk");return
 var length=f.get_length();f.close()
 if length!=int(artifact.bytes) or FileAccess.get_sha256(path)!=artifact.sha256:verify_result=P.fail("checksum");return
 var target=store.root+str(int(available.sequence))+"-full.zip"
 if DirAccess.rename_absolute(path,target)!=OK:verify_result=P.fail("disk");return
 if not S.atomic_file(store.root+"full-ready.json",envelope):verify_result=P.fail("disk");return
 var pointer=store.state();pointer.highest=maxi(int(pointer.highest),int(available.sequence))
 if not store.write_state(pointer):verify_result=P.fail("disk");return
 verify_result={"ok":true,"full_path":target}
func _process(delta:float)->void:
 if status=="installing":
  helper_elapsed+=delta
  if FileAccess.file_exists(install_job+".result.json") or (helper_pid>0 and not OS.is_process_running(helper_pid)):
   _error("更新准备未完成。请检查安装目录权限和剩余空间后重试。");return
  if FileAccess.file_exists(install_job+".ready"):
   get_tree().quit();return
  if helper_elapsed>1800:
   if helper_pid>0:OS.kill(helper_pid)
   _error("更新准备超时，当前游戏未替换，请重试。");return
 _progress_age+=delta
 if status=="downloading" and _progress_age>=.1:
  _progress_age=0;downloaded=request.get_downloaded_bytes()
 if verify_task>=0 and WorkerThreadPool.is_task_completed(verify_task):
  WorkerThreadPool.wait_for_task_completion(verify_task);verify_task=-1
  if verify_result.get("ok",false):full_ready=verify_result.get("full_path","");status="ready";downloaded=total
  else:_error("下载文件校验失败或空间不足，请重试。")
func cancel()->void:
 if status not in ["checking","downloading"]:return
 request.cancel_request();status="available" if not available.is_empty() else "idle"
 if FileAccess.file_exists(store.root+"download.part"):DirAccess.remove_absolute(store.root+"download.part")
func restart(safe:bool)->bool:
 if not safe or status!="ready" or not enabled:return false
 if platform=="Web":
  if OS.has_feature("web"):JavaScriptBridge.eval("window.location.reload();",true);return true
  return false
 if artifact.get("kind","")=="full":return _install_full()
 OS.set_restart_on_exit(true,PackedStringArray())
 get_tree().quit();return true
func _install_full()->bool:
 # Executable helper is shipped outside the PCK and copied before replacement.
 var exe=OS.get_executable_path();var install=exe.get_base_dir();var relative=exe.get_file()
 if platform=="macOS":install=exe.get_base_dir().get_base_dir().get_base_dir();relative="Contents/MacOS/"+exe.get_file()
 var marker=install+("/Contents/Resources/update-install.json" if platform=="macOS" else "/update-install.json")
 if not FileAccess.file_exists(marker):_error("此安装目录不支持原位更新。请使用新版完整客户端。");return false
 var helper_name="SolarisUpdater.exe" if platform=="Windows" else "SolarisUpdater"
 var helper=exe.get_base_dir()+"/"+helper_name
 var cached=store.root+helper_name
 if not FileAccess.file_exists(helper) or DirAccess.copy_absolute(helper,cached)!=OK:_error("更新助手不可用，请使用新版完整客户端。");return false
 if platform!="Windows":FileAccess.set_unix_permissions(cached,448)
 var token=Crypto.new().generate_random_bytes(32).hex_encode()
 var job={"envelope":JSON.parse_string(envelope.get_string_from_utf8()),"archive":ProjectSettings.globalize_path(full_ready),"install_dir":install,"parent_pid":OS.get_process_id(),"platform":platform,"minimum_sequence":int(current.sequence),"ack_token":token,"ack_dir":ProjectSettings.globalize_path(store.root)}
 var job_path=store.root+"install-"+token+".json"
 if not S.atomic_file(job_path,JSON.stringify(job).to_utf8_buffer()):_error("无法保存更新任务，请检查磁盘空间。");return false
 helper_pid=OS.create_process(ProjectSettings.globalize_path(cached),PackedStringArray(["--job",ProjectSettings.globalize_path(job_path)]))
 if helper_pid<=0:_error("更新助手启动失败，当前版本未改动。");return false
 install_job=job_path;helper_elapsed=0.0;status="installing";return true
func _error(message:String)->void:error_message=message;status="error"
func _exit_tree()->void:
 if request!=null:request.cancel_request()
 if verify_task>=0:WorkerThreadPool.wait_for_task_completion(verify_task)

func snapshot()->Dictionary:
 return {"status":status,"version":version(),"error_message":error_message,"available":available.duplicate(true),"artifact":artifact.duplicate(true),"downloaded":downloaded,"total":total,"platform":platform,"full_download":not full_ready.is_empty()}

func open_download_folder()->void:
 if not full_ready.is_empty() and FileAccess.file_exists(full_ready):OS.shell_open(ProjectSettings.globalize_path(full_ready).get_base_dir())
