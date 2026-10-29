extends SceneTree
const I=preload('res://scripts/inventory/inventory.gd')
const S=preload('res://scripts/storage/storage.gd')
const A=preload('res://scripts/run/run_application.gd')
const B=preload('res://scripts/battle/battle.gd')
var checks=0
var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():
 var inv=I.new();var engine=B.new()
 var root_path='user://qa-history-app-v122/'+str(OS.get_process_id())+'/'
 var files=S.new(root_path);var app=A.new(inv,files,engine)
 var run=inv.new_run('aemeath',122)
 var enemy=inv.practice(1,122,'full',122)
 ck(app.begin(run,enemy).ok and app.finish_replay(run).ok,'real application finishes battle')
 var result=run.duplicate(true);var combat=run.combat.duplicate(true)
 ck(files.battle_history().is_empty(),'animation completion avoids duplicate archive I/O')
 ck(app.advance(run,combat).ok and not run.has('combat'),'advance consumes current result')
 var rows=files.battle_history();ck(rows.size()==1,'advance archives before evidence removal')
 ck(files.battle_history(run).size()==1 and run.history[-1].replay_id==rows[0].id,'new summary links exact archived battle without duplicate row')
 var unrelated=run.duplicate(true);unrelated.history[-1].erase('replay_id');unrelated.history[-1].winner=-int(combat.winner);unrelated.history[-1].duration+=7
 ck(files.battle_history(unrelated).size()==2,'same-build legacy fight is not hidden by another archive')
 var loaded=files.battle_record(rows[0].id).combat
 if loaded!=combat:diff(loaded,combat,'combat')
 ck(loaded==combat,'persisted evidence exact after next shop')
 var reloaded_result=JSON.parse_string(JSON.stringify(result));reloaded_result.phase='ending'
 ck(files.archive_completed(reloaded_result) and files.battle_history().size()==1,'reloaded ending preserves original battle identity')
 ck(files.battle_record(rows[0].id).combat==combat,'reloaded ending never replaces exact binary evidence')
 var gold=run.gold
 ck(not app.advance(run,combat).ok and run.gold==gold and files.battle_history().size()==1,'double continue cannot duplicate rewards or history')
 files=S.new(root_path);app=A.new(inv,files,engine)
 ck(files.battle_history().size()==1,'history survives storage reopen')
 var new_game=app.start('hsin',123,'full',result)
 ck(new_game.ok and files.battle_history().size()==1,'new game keeps preceding result idempotently')
 var historical=JSON.parse_string(FileAccess.get_file_as_string('res://tests/fixtures/data/feedback-v120/input/hsin-round10.json'))
 var legacy_store=S.new(root_path+'old-history/');var legacy_app=A.new(inv,legacy_store,engine)
 ck(legacy_store.archive_completed(historical),'old summary-only rounds archived alongside current full fight')
 ck(legacy_store.battle_history(historical).size()==10,'known current result is not duplicated as old summary')
 var replacement=legacy_app.start('aemeath',125,'full',historical)
 var retained=legacy_store.battle_history(replacement.run)
 ck(replacement.ok and retained.size()==10 and retained.filter(func(row):return row.replayable).size()==1,'new game retains nine unavailable old summaries and one true replay')
 var block_path=root_path+'unwritable/';var bad=S.new(block_path)
 var blocker=FileAccess.open(block_path+'battles',FileAccess.WRITE);blocker.store_string('blocked');blocker.close()
 bad.save(result);var original=FileAccess.get_file_as_string(block_path+'run.json')
 app=A.new(inv,bad,engine);run=result.duplicate(true)
 var before=run.duplicate(true);var failed=app.advance(run,combat)
 ck(not failed.ok and failed.get('error','')=='history_save','archive failure blocks destructive advance')
 ck(run==before and FileAccess.get_file_as_string(block_path+'run.json')==original,'archive failure leaves run and persisted evidence intact')
 ck(not app.start('hsin',124,'full',result).ok and FileAccess.get_file_as_string(block_path+'run.json')==original,'new game cannot overwrite unarchived result')
 print('HISTORY_APPLICATION_V122 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)

func diff(a,b,path):
 if a==b:return false
 if a is Dictionary and b is Dictionary:
  for key in b:
   if not a.has(key):print('MISSING ',path,'.',key);return true
   if diff(a[key],b[key],path+'.'+str(key)):return true
 elif a is Array and b is Array:
  if a.size()!=b.size():print('SIZE ',path);return true
  for i in a.size():
   if diff(a[i],b[i],path+'['+str(i)+']'):return true
 else:print('DIFF ',path,' ',a,' != ',b,' TYPES ',typeof(a),' ',typeof(b));return true
 return false
