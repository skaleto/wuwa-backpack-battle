extends SceneTree
var checks=0
var failures=0
func ck(ok,label):
	checks+=1
	if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():call_deferred('test')
func test():
	var g=preload('res://tests/fixtures/travel_fixture_v64.gd').new();root.add_child(g);await process_frame;g.set_process(false)
	var record=JSON.parse_string(FileAccess.get_file_as_string('res://tests/fixtures/data/feedback-v120/input/hsin-round10.json'));record.phase='result';record.history=[]
	if not g.storage.has_method('archive_completed'):
		ck(false,'application storage supports battle archives');g.queue_free();await process_frame;finish();return
	ck(g.storage.archive_completed(record),'completed match persists through game storage')
	var original=g.run.duplicate(true);var file=FileAccess.get_file_as_string(g.storage.root_path+'run.json')
	g._action('history');ck(g.overlay=='history' and g.history_rows.size()==1,'history entry opens outside current result')
	g._history_action('replay')
	ck(g.review.active and g.review.record==record.combat,'opens actual old battle')
	g._process(.2);g._review_action('play');var at=g.review.time;g._process(.5)
	ck(g.review.time==at and not g.review.playing,'history replay pauses and remains paused')
	g._review_action('panel');g._review_action('event:80')
	ck(is_equal_approx(g.review.time,float(record.combat.events[80].time)),'clicking a log seeks its exact time')
	ck(not g._review_snapshot().events.is_empty(),'log remains visible at selected timestamp')
	g._review_action('close')
	ck(g.run==original and g.screen=='game' and g.overlay=='history','closing replay restores exact current run and history list')
	ck(FileAccess.get_file_as_string(g.storage.root_path+'run.json')==file,'replay never writes current save')
	g._history_action('close');ck(g.overlay=='','history closes to preparation')
	g.screen='camp';g._action('history');g._history_action('replay');g._review_action('close');g._history_action('close')
	ck(g.screen=='camp' and g.run==original,'camp return is preserved too')
	g.queue_free();await process_frame;finish()
func finish():
	print('HISTORY_UI_V122 ',checks,' checks, ',failures,' failures');quit(0 if failures==0 else 1)
