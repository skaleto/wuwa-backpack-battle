extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const MODEL=preload("res://scripts/ui/run_progress_view.gd")
const S=preload("res://scripts/storage/storage.gd")
const A=preload("res://scripts/run/run_application.gd")
const AA=preload("res://scripts/online/async_run_application.gd")
const BOOT=preload("res://scripts/update/bootstrap.gd")
class FailingStorage:
 extends S
 func abandon_run(_run:Dictionary)->bool:return false
var failures=0
func ck(ok:bool,label:String):
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():call_deferred("test")
func test():
 var g=G.new();root.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
 ck(g.has_method("_maybe_prompt_update"),"new release prompts automatically")
 ck(g._application().has_method("abandon"),"application supports ending a run without fake losses")
 ck(g.has_method("_run_progress_model"),"HUD and result share explicit progression projection")
 var before=g.run.duplicate(true)
 g.screen="camp";g.overlay="";g.motion.modal_value=0
 g.update_client.enabled=true;g.update_client.status="available"
 g._maybe_prompt_update();ck(g.overlay=="updates","startup opens available update")
 g._update_action("updates:back");g._maybe_prompt_update()
 ck(g.overlay.is_empty(),"later dismisses without reopening each frame")
 g.startup_update_prompted=false;g.overlay="settings";g._maybe_prompt_update();ck(g.overlay=="settings","does not overwrite settings")
 g.overlay="";g.screen="game";g._maybe_prompt_update();ck(g.overlay.is_empty(),"does not interrupt play")
 ck(g.run==before,"update prompt leaves run untouched")
 for winner in [1,0,-1]:
  var value=before.duplicate(true);value.phase="result";value.wins=3;value.losses=1
  var snapshot=value.duplicate(true)
  var initial=MODEL.model(value,{"winner":winner},0)
  var final=MODEL.model(value,{"winner":winner},2)
  ck(initial.wins==3 and initial.hearts==3,"progress starts from actual pre-settlement counters")
  ck(final.wins==(4 if winner==1 else 3) and final.hearts==(3 if winner==1 else 2),"result projection matches win/loss/draw settlement")
  ck(MODEL.model(value,{"winner":winner},2,true).wins==3,"replay never previews another award")
  ck(value==snapshot,"drawing cannot settle result")
  value.phase="ending";ck(not MODEL.model(value,{"winner":winner},2).result,"settled ending never increments again")
 # Isolated real persistence and mode separation.
 g.game_mode="practice";g.storage=g.practice_storage;g.run=before.duplicate(true)
 ck(g.storage.save(g.run),"fixture saved")
 var identity=g.storage.owner
 var online=AA.new(g.inventory,g.online_storage,g.engine).start("aemeath",71).run
 var online_bytes=FileAccess.get_file_as_bytes(g.online_storage.root_path+"run.json")
 g._refresh_camp_saves();g.screen="game";g.overlay="menu"
 g._request_end_run("practice","menu");g._cancel_end_run()
 ck(g.run==before and g.overlay=="menu" and not g.storage.resume().is_empty(),"cancel preserves active run")
 g._request_end_run("practice","menu");g._confirm_end_run()
 ck(g.screen=="camp" and g.run.is_empty() and g.storage.resume().is_empty(),"confirm ends current run and returns home")
 ck(FileAccess.file_exists(g.storage.root_path+"run-abandoned.json"),"explicit ending keeps recovery backup")
 ck(g.storage.owner==identity and FileAccess.get_file_as_bytes(g.online_storage.root_path+"run.json")==online_bytes,"other mode and identity unchanged")
 ck(not g._update_restart_safe(),"other unfinished mode remains visible update blocker")
 g._request_end_run("async","updates");g._confirm_end_run()
 ck(g.overlay=="updates" and g._update_restart_safe() and BOOT.safe_to_activate(g.practice_storage.root_path),"ending both modes enables original immutable updater")
 # Failure, duplicate and stale requests never erase current state.
 var fail=FailingStorage.new("user://qa-end-failure-"+str(OS.get_process_id())+"/")
 var app=A.new(g.inventory,fail,g.engine);var run=before.duplicate(true)
 ck(not app.abandon(run,A.SESSION.stamp(run)).ok and run==before,"delete failure leaves live run intact")
 var files=S.new("user://qa-end-stale-"+str(OS.get_process_id())+"/")
 app=A.new(g.inventory,files,g.engine);files.save(run)
 var changed=run.duplicate(true);changed.gold+=1;files.save(changed)
 ck(not app.abandon(run,A.SESSION.stamp(run)).ok and files.resume()==changed,"stale disk state preserved")
 ck(not app.abandon(run,"stale").ok and run==before,"stale confirmation rejected")
 # Ending pending online match is explicit; no fabricated result/award.
 var online_files=S.new("user://qa-end-pending-"+str(OS.get_process_id())+"/")
 var online_app=AA.new(g.inventory,online_files,g.engine)
 var pending=online_app.start("aemeath",79).run;online_app.prepare_match(pending,"alice")
 ck(online_app.abandon(pending,A.SESSION.stamp(pending)).ok and pending.is_empty(),"explicit abandon can end pending frozen online run")
 ck(not online_app.abandon(pending,A.SESSION.stamp(pending)).ok,"repeat abandon does not execute")
 g.queue_free();await process_frame;print("RELEASE_FEEDBACK failures=",failures);quit(1 if failures else 0)
