extends SceneTree
var failures=0
var checks=0
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var path="res://scripts/battle/battle_review.gd"
	ck(ResourceLoader.exists(path),"battle review read-only model exists")
	if not ResourceLoader.exists(path):quit(1);return
	var R=load(path)
	var record=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/data/battle-review-v100/replay.json"))
	var own=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/data/battle-review-v100/reported-fight.json")).build
	var enemy=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/data/battle-review-v100/enemy.json"))
	var before=JSON.stringify([record,own,enemy])
	for side in 2:
		var rows=R.rows(record,[own,enemy],side,INF)
		ck(rows.size()>3,"all items and non-item sources survive, side "+str(side))
		var build=own if side==0 else enemy
		for item in build.items:ck(rows.any(func(r):return r.uid==item.uid),"includes even zero-contribution item "+item.uid)
		for key in ["damage","heal","shield"]:
			var total=0.0
			for row in rows:total+=float(row[key])
			ck(is_equal_approx(total,float(record.totals[side][key])),"exact totals reconcile for "+str(side)+key)
	var rows=R.rows(record,[own,enemy],0,INF)
	var star=rows.filter(func(r):return r.kind=="weapon_21020076")[0]
	ck(star.activations==6 and star.charged==0,"real historical activation and charged counts")
	ck(is_equal_approx(star.damage,41.28),"unrounded event damage, not displayed 41.3")
	ck(R.rows(record,[own,enemy],0,0).all(func(r):return r.damage==0),"no future contribution at start")
	var timeline=R.timeline(record,[own,enemy],-1,"")
	ck(timeline.size()>100,"detailed chronological timeline includes all actual kinds")
	for n in range(1,timeline.size()):ck(timeline[n].time>=timeline[n-1].time,"stable chronological ordering")
	var filtered=R.timeline(record,[own,enemy],0,star.uid)
	ck(not filtered.is_empty() and filtered.all(func(e):return e.side==0 and (e.source_uid==star.uid or e.partner_uid==star.uid)),"item filter respects side and participating UID")
	ck(R.frame_at(record,0).sides[0].hp==162,"opening frame from original evidence")
	ck(R.frame_at(record,999).sides[0].hp==0,"clamped final recorded frame")
	var twins=[{"leader":"aemeath","items":[{"uid":"collision","kind":"w_sword","x":1,"y":2},{"uid":"other","kind":"w_sword","x":4,"y":2}],"bags":[{"uid":"empty_bag","kind":"satchel","x":1,"y":1}]},{"leader":"qingxiao","items":[{"uid":"collision","kind":"w_sword","x":0,"y":0}],"bags":[]}]
	var cross={"events":[{"time":1.0,"side":0,"kind":"delay","source_uid":"other","uid":"other","target_uid":"collision","target_side":1,"value":.3}]}
	ck(R.timeline(cross,twins,0,"collision").is_empty(),"enemy target UID does not match a different allied instance")
	ck(R.timeline(cross,twins,1,"collision").size()==1,"target's timeline includes incoming effects from opposing source")
	var twin_rows=R.rows(cross,twins,0,INF)
	ck(twin_rows.any(func(r):return r.uid=="empty_bag"),"equipped pockets included even with zero contributions")
	var first_twin=twin_rows.filter(func(r):return r.uid=="collision")[0];var second=twin_rows.filter(func(r):return r.uid=="other")[0]
	ck(first_twin.name!=second.name and first_twin.get("position_label","")!=second.get("position_label",""),"same-kind copies have stable visible identity and position")
	var enhanced_record={"events":[{"time":1,"side":0,"kind":"trigger","uid":"collision","charged":true,"prepared":true}]}
	ck(R.rows(enhanced_record,twins,0,INF)[0].enhanced==1,"one attack carrying both enhancements is counted once")
	var replay=R.new()
	ck(replay.open(record,[own,enemy]),"complete record opens")
	ck(not replay.playing and replay.time==record.duration,"opens at final result")
	replay.play();ck(replay.time==0 and replay.playing,"replay from end starts at zero")
	var first=replay.advance(1.8)
	ck(first.any(func(e):return e.kind=="attack"),"playback releases recorded events")
	replay.seek(.5);ck(not replay.playing and replay.time==.5,"scrub pauses")
	replay.play();var after=replay.advance(1.3)
	ck(after.any(func(e):return e.kind=="attack"),"backward seek can replay same events")
	replay.advance(999);ck(not replay.playing and replay.time==record.duration,"reaching end only pauses")
	replay.close();ck(not replay.active,"close presentation")
	ck(JSON.stringify([record,own,enemy])==before,"query and repeat replay never mutate evidence or builds")
	ck(not replay.open({"legacy_result":true,"events":[],"frames":[],"duration":5},[own,enemy]),"missing historical evidence cannot be fabricated")
	# Real game adapter: replay must never call simulation or application settlement.
	var G=load("res://tests/fixtures/playable_fixture_v50.gd");var game=G.new()
	root.add_child(game);await process_frame;game.set_process(false);game.set_process_input(false)
	for key in own:game.run[key]=own[key]
	game.run.phase="result";game.run.combat=record.duplicate(true);game.run.opponent=enemy.duplicate(true)
	game.combat=record.duplicate(true);game.opponent=enemy.duplicate(true);game.screen="game"
	var run_before=JSON.stringify(game.run)
	var disk_before=FileAccess.get_file_as_bytes(game.storage.root_path+"run.json")
	game._open_battle_review()
	ck(game.review.active and game.review_panel,"result opens real read-only page")
	game._review_action("one_side");game._review_action("side:1")
	ck(game.review_timeline_side==1 and game.review_timeline.all(func(e):return e.side==1),"only-side filter follows side tab")
	game._review_action("side:0");game._review_action("both")
	game._review_action("item:"+star.uid)
	ck(game.review_timeline.all(func(e):return e.side==0),"equal UIDs across sides do not leak into item filter")
	game._review_action("play")
	while game.review.playing:game._process(.1)
	var final_pose_clock=game._portrait_clock()
	game._process(.2)
	ck(game._portrait_clock()>final_pose_clock and game.review.time==record.duration,"natural tail advances portrait feedback without advancing recorded time")
	for n in 140:game._process(.1)
	ck(not game.review.playing and game.run.phase=="result","full replay reaches end without settlement")
	ck(game.pending_impacts.is_empty(),"final playback impact has time to land")
	ck(game.floats.is_empty() and game.projectiles.is_empty() and game.combat_vfx.impacts.is_empty(),"natural replay completion drains all transient effects")
	game._review_seek(1.0);game._review_action("play");game._process(.4);game._review_action("play")
	var paused_pose_clock=game._portrait_clock()
	game._process(.5)
	ck(game._portrait_clock()==paused_pose_clock and game.review.time<record.duration,"manual pause freezes portrait feedback with the recorded frame")
	game._review_seek(1.0);game._review_action("play");game._process(.9);game._review_action("close")
	ck(JSON.stringify(game.run)==run_before,"replay, seek and close preserve exact real state")
	ck(FileAccess.get_file_as_bytes(game.storage.root_path+"run.json")==disk_before,"replay has zero storage writes")
	ck(not game.review.active and game.combat_time>=record.duration,"close restores completed battle presentation")
	var prepared_hit=record.events.filter(func(e):return e.kind=="attack" and e.side==0)[0].duplicate(true)
	prepared_hit.charged=false;prepared_hit.prepared=true
	game._clear_feedback();game._play_event(prepared_hit);game._apply_impact(prepared_hit)
	ck(game.projectiles[-1].strong and game.combat_vfx.impacts[-1].strong,"local prepared strike has actual enhanced presentation")
	game.queue_free();await process_frame
	print("BATTLE_REVIEW_V101 ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
