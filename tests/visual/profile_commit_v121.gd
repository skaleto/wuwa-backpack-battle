extends SceneTree
const I=preload('res://scripts/inventory/inventory.gd')
const LIFE=preload('res://scripts/run/run_lifecycle.gd')
const SESSION=preload('res://scripts/run/run_session.gd')
const S=preload('res://scripts/storage/storage.gd')
func _initialize():
 var r=JSON.parse_string(FileAccess.get_file_as_string('res://tests/fixtures/data/feedback-v120/input/hsin-round10.json'));r.phase='battle'
 var inv=I.new();var store=S.new('user://qa-profile-v121/'+str(OS.get_process_id()));var report={};var start=Time.get_ticks_usec()
 var plan=LIFE.result(r);report.plan_ms=(Time.get_ticks_usec()-start)/1000.0
 start=Time.get_ticks_usec();SESSION.stamp(r);report.stamp_ms=(Time.get_ticks_usec()-start)/1000.0
 start=Time.get_ticks_usec();inv.validate_run(plan.run);report.validation_ms=(Time.get_ticks_usec()-start)/1000.0
 start=Time.get_ticks_usec();plan.duplicate(true);report.plan_copy_ms=(Time.get_ticks_usec()-start)/1000.0
 start=Time.get_ticks_usec();plan.run.duplicate(true);report.run_copy_ms=(Time.get_ticks_usec()-start)/1000.0
 start=Time.get_ticks_usec();store.save(plan.run);report.save_ms=(Time.get_ticks_usec()-start)/1000.0
 print(JSON.stringify(report));FileAccess.open('res://build/qa/feedback-v121/commit-before.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'));quit()
