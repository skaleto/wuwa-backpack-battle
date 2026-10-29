extends SceneTree
var checks=0
var failures=0
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():call_deferred('test')
func pointer(g,at:Vector2,pressed:bool)->void:
	var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;e.position=at;g._input(e)
func test():
	var g=preload('res://tests/fixtures/travel_fixture_v64.gd').new();root.add_child(g);await process_frame;g.set_process(false)
	var record=JSON.parse_string(FileAccess.get_file_as_string('res://tests/fixtures/data/feedback-v120/input/hsin-round10.json'));record.phase='result';record.history=[]
	ck(g.storage.archive_completed(record),'archive fixture')
	var before=g.run.duplicate(true);var disk=FileAccess.get_file_as_bytes(g.storage.root_path+'run.json')
	g._action('history')
	ck(g.get('history_record') is Dictionary and g.get('history_record').get('builds',[]).size()==2,'history selection loads both actual layouts')
	if g.get('history_record') is Dictionary and not g.get('history_record').is_empty():
		ck(g.history_record.builds[0].items==record.items and g.history_record.builds[1].items==record.opponent.items,'preview preserves all positions and rotations, not a kind list')
	g._history_action('replay')
	ck(g.review.active and not g.review_panel,'replay opens unobstructed battle, not statistics')
	ck(g.review.playing and g.review.time==0,'history replay starts at opening automatically')
	ck(g.run.items==record.items and g.opponent.bags==record.opponent.bags,'battle uses both archived formations')
	ck(not g._review_snapshot().has('rows'),'on-field playback does not rebuild full statistics each frame')
	# Normalize for old implementation so subsequent failures remain diagnostic.
	g._review_seek(0);g._review_action('play');g._process(.5)
	var time=g.review.time;g._review_action('play');var pose=g._portrait_clock();g._process(.5)
	ck(g.review.time==time and g._portrait_clock()==pose,'pause freezes recorded state and portrait clock')
	var speeds=[]
	for n in 4:g._review_action('speed');speeds.append(g.review.speed)
	ck(speeds==[2.0,4.0,.5,1.0],'speed offers 0.5, 1, 2, 4 without changing time')
	ck(g.review.time==time,'changing playback speed never seeks')
	g.review.speed=2;g._review_action('play');g._process(.25)
	ck(is_equal_approx(g.review.time,time+.5),'double speed advances recorded clock twice as fast')
	var track=g.REVIEW_VIEW.TRACK
	pointer(g,track.position+Vector2(track.size.x*.25,10),true)
	ck(g.review_scrubbing and not g.review.playing and is_equal_approx(g.review.time,g.review.duration*.25),'timeline press pauses and previews exact position')
	var motion=InputEventMouseMotion.new();motion.position=track.position+Vector2(track.size.x*.60,10);g._input(motion)
	ck(is_equal_approx(g.review.time,g.review.duration*.60),'drag continuously seeks forward')
	ck(g._current_frame()==g.BATTLE_REVIEW.frame_at(record.combat,g.review.time),'both combatants use the sought recorded frame')
	pointer(g,motion.position,false)
	ck(g.review.playing and not g.review_scrubbing,'release resumes if playing before dragging')
	if g.review.playing:g._review_action('play')
	pointer(g,track.position+Vector2(track.size.x*.1,10),true);pointer(g,track.position+Vector2(track.size.x*.1,10),false)
	ck(not g.review.playing and is_equal_approx(g.review.time,g.review.duration*.1),'paused scrub stays paused and seeks backward')
	g._review_action('panel')
	ck(g.review_panel and not g.review.playing,'statistics remain available while paused')
	g._review_action('event:80')
	ck(is_equal_approx(g.review.time,float(record.combat.events[80].time)),'event log seeks its original timestamp')
	g._review_action('panel');g._review_action('play')
	for n in 500:
		g._process(.05)
		if not g.review.playing and g.review_tail==0:break
	ck(g.review.time==g.review.duration and g.pending_impacts.is_empty(),'full battle plays to completion including impact tail')
	ck(g.run.phase=='result' and g.combat==record.combat,'historical playback neither simulates nor settles')
	g._review_action('close')
	ck(g.run==before and g.overlay=='history','return preserves active run and history selection')
	ck(FileAccess.get_file_as_bytes(g.storage.root_path+'run.json')==disk,'playback never writes the active save')
	# Summary-only records must not reuse a prior enemy layout.
	g.history_rows.append({'id':'legacy-preview','time':0,'round':1,'winner':0,'duration':1,'legacy':true,'replayable':false,'leaders':['aemeath',''],'items':[['w_sword'],[]]})
	g._history_action('select:'+str(g.history_rows.size()-1))
	ck(g.get('history_record') is Dictionary and g.history_record.is_empty(),'legacy summary clears stale full layouts')
	g._history_action('replay');ck(not g.review.active,'missing old combat cannot be fabricated')
	g.queue_free();await process_frame
	print('HISTORY_PLAYBACK_V123 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
