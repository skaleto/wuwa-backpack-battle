extends SceneTree
const CASE='res://tests/fixtures/data/feedback-v120/input/hsin-round10.json'
var checks=0
var failures=0
func ck(ok,label):
	checks+=1
	if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():
	if not ResourceLoader.exists('res://scripts/storage/battle_archive.gd'):
		ck(false,'persistent frozen battle archive exists');finish();return
	var Archive=load('res://scripts/storage/battle_archive.gd')
	var path='user://qa-history-v122/'+str(OS.get_process_id())+'/'
	var store=Archive.new(path)
	var run=JSON.parse_string(FileAccess.get_file_as_string(CASE));run.phase='result';run.history=[]
	var before=run.duplicate(true)
	ck(store.remember(run),'completed real battle is archived')
	ck(run==before,'archive does not modify current run')
	var entries=store.entries();ck(entries.size()==1,'one battle row')
	var id=entries[0].id
	var record=store.read(id)
	ck(record.combat==run.combat,'all 338 events and 140 frames retained exactly')
	ck(record.builds[0].wins==run.wins and record.builds[0].gold==run.gold,'original HUD counters retained for replay')
	ck(record.builds[0].items==run.items and record.builds[1].items==run.opponent.items,'both actual combatants preserved')
	ck(store.remember(run) and store.entries().size()==1,'repeated result is idempotent')
	var settled=run.duplicate(true);settled.phase='ending';settled.wins+=1;settled.gold+=9
	ck(store.remember(settled) and store.entries().size()==1,'settled ending does not duplicate same fight')
	var malformed={'version':1,'combat':{'frames':'bad','events':[]},'builds':[{},{}]}
	ck(not Archive.valid(malformed),'malformed evidence rejected without runtime exception')
	store=Archive.new(path)
	ck(store.entries().size()==1 and store.read(id)==record,'record survives reopening store')
	var replay=preload('res://scripts/battle/battle_review.gd').new()
	ck(replay.open(record.combat,record.builds),'archived evidence opens existing replay')
	replay.seek(3.1);var exact=replay.time;replay.advance(5)
	ck(replay.time==exact,'pause holds timestamp and data')
	replay.play();replay.advance(.5);ck(replay.time>exact,'play advances archived evidence')
	replay.seek(1.2);var frame=preload('res://scripts/battle/battle_review.gd').frame_at(record.combat,1.2)
	ck(frame==preload('res://scripts/battle/battle_review.gd').frame_at(run.combat,1.2),'seek is recorded frame, never a new simulation')
	record.combat.events.clear();ck(store.read(id).combat.events.size()==338,'readers cannot mutate stored evidence')
	var unfinished=run.duplicate(true);unfinished.phase='battle'
	ck(store.remember(unfinished) and store.entries().size()==1,'unfinished battle is not labelled finished')
	var legacy={'phase':'result','round':2,'history':[]}
	ck(store.remember(legacy) and store.entries().size()==1,'old summary is not fabricated into replay')
	ck(store.read('../run').is_empty() and store.read('').is_empty(),'record IDs cannot access other files')
	var corrupted=FileAccess.open(path+'battles/'+id+'.rpl',FileAccess.WRITE);corrupted.store_string('broken');corrupted.close()
	ck(store.read(id).is_empty(),'corrupted record fails gracefully')
	ck(store.remember(run) and not store.read(id).is_empty(),'retry repairs incomplete payload without duplicate row')
	var summary=FileAccess.open(path+'battles/'+id+'.json',FileAccess.WRITE);summary.store_string('{}');summary.close()
	ck(store.entries().is_empty(),'malformed summary cannot enter UI')
	ck(store.remember(run) and store.entries().size()==1,'complete payload repairs malformed summary')
	var blocker=path+'not-a-directory';var f=FileAccess.open(blocker,FileAccess.WRITE);f.store_string('x');f.close()
	ck(not Archive.new(blocker+'/').remember(run),'storage failure is reported, not success')
	finish()
func finish():
	print('HISTORY_V122 ',checks,' checks, ',failures,' failures');quit(0 if failures==0 else 1)
