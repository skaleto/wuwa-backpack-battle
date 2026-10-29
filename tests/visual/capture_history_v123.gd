extends SceneTree
## Native pixels and real input dispatch, without activating a desktop window.
const OUT='res://build/qa/feedback-v123/native/'
var g
var viewport
var checks=0
var failures=0
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():
	root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true);call_deferred('test')
func shot(name:String):
	g.queue_redraw();await process_frame;RenderingServer.force_draw(true);await process_frame
	ck(viewport.get_texture().get_image().save_png(OUT+name+'.png')==OK,'capture '+name)
func pointer(at:Vector2,pressed:bool):
	var e=InputEventMouseButton.new();e.position=at;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;g._input(e)
func click_action(action:String):
	var buttons=g.review_buttons if g.review.active else g.history_buttons
	var found=buttons.filter(func(b):return b.action==action and b.enabled)
	ck(found.size()==1,'registered control '+action)
	if found.is_empty():return
	pointer(found[0].rect.get_center(),true);pointer(found[0].rect.get_center(),false)
func test():
	if DisplayServer.get_name()=='headless':quit(2);return
	DirAccess.make_dir_recursive_absolute(OUT)
	viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	g=preload('res://tests/fixtures/travel_fixture_v64.gd').new();viewport.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
	var source=JSON.parse_string(FileAccess.get_file_as_string('res://tests/fixtures/data/feedback-v120/input/hsin-round10.json'));source.phase='result';source.history=[]
	ck(g.storage.archive_completed(source),'archive exact dense battle')
	var before=g.run.duplicate(true);var disk=FileAccess.get_file_as_bytes(g.storage.root_path+'run.json')
	g._action('history');await shot('01-both-layouts')
	ck(g.history_record.builds[0].items.size()==15 and g.history_record.builds[1].items.size()==22,'all 37 pieces in preview, without a twelve-item truncation')
	click_action('replay');await shot('02-battle-opening')
	ck(g.review.playing and not g.review_panel and g.review.time==0,'replay opens in full battlefield at time zero')
	# Deliver all events from the beginning, including the final impact tail.
	for n in 1000:
		g._process(1.0/60);await process_frame
		if n==359:await shot('03-battle-playing')
		if not g.review.playing and g.review_tail==0:break
	ck(g.review.time==g.review.duration and g.pending_impacts.is_empty(),'native full battle reaches recorded final frame and clears impact tail')
	await shot('04-battle-end')
	click_action('play');g._process(.5);await process_frame
	var track=g.REVIEW_VIEW.TRACK
	pointer(track.position+Vector2(track.size.x*.25,10),true)
	var move=InputEventMouseMotion.new();move.position=track.position+Vector2(track.size.x*.60,10);g._input(move)
	ck(not g.review.playing and is_equal_approx(g.review.time,g.review.duration*.60),'drag previews exact recorded state')
	pointer(move.position,false);ck(g.review.playing,'release resumes an already playing replay')
	click_action('play');await shot('05-paused-at-time')
	var at=g.review.time;g._process(.4);ck(g.review.time==at,'native pause holds battle clock')
	for n in 2:click_action('speed')
	ck(g.review.speed==4,'native speed controls reach four times')
	click_action('panel');await shot('06-data-log')
	ck(g.review_panel and not g.review.playing,'data log opens paused')
	var events=g.review_buttons.filter(func(b):return b.action.begins_with('event:'))
	ck(not events.is_empty(),'real event rows are clickable')
	if not events.is_empty():
		var event_id=int(events[0].action.trim_prefix('event:'));click_action(events[0].action)
		ck(is_equal_approx(g.review.time,float(source.combat.events[event_id].time)),'log row seeks its recorded timestamp')
	click_action('panel');await shot('07-return-to-battle')
	ck(not g.review_panel and not g.review.playing,'battle returns at selected timestamp and stays paused')
	click_action('close');await shot('08-return-to-history')
	ck(g.run==before and FileAccess.get_file_as_bytes(g.storage.root_path+'run.json')==disk,'native replay restores current run and never writes its save')
	g.queue_free();await process_frame
	print('NATIVE_HISTORY_V123 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
