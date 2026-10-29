extends SceneTree
var g
var viewport
var failures=0
var checks=0
const OUT='res://build/qa/feedback-v122/native/'
func ck(ok,label):
	checks+=1
	if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():
	root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true);call_deferred('test')
func shot(name:String):
	g.queue_redraw();await process_frame;RenderingServer.force_draw(true);await process_frame
	ck(viewport.get_texture().get_image().save_png(OUT+name+'.png')==OK,'capture '+name)
func click(at:Vector2):
	var event=InputEventMouseButton.new();event.position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;g._input(event)
	event.pressed=false;g._input(event)
func test():
	if DisplayServer.get_name()=='headless':quit(2);return
	DirAccess.make_dir_recursive_absolute(OUT)
	viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	g=preload('res://tests/fixtures/travel_fixture_v64.gd').new();viewport.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
	var evidence=JSON.parse_string(FileAccess.get_file_as_string('res://tests/fixtures/data/feedback-v120/input/hsin-round10.json'));evidence.phase='result'
	ck(g.storage.archive_completed(evidence),'archive original completed fixture')
	g.saved={};g.screen='camp';g.camp_age=3;g.mouse=Vector2(1410,950)
	await shot('01-start')
	click(Vector2(1117,880));await shot('02-history')
	ck(g.overlay=='history' and not g.history_buttons.is_empty(),'visible history button opens journal')
	click(Vector2(434,838));await shot('02b-older-summaries')
	ck(g.history_page==1 and g.history_selected==6,'pagination selects visible old record')
	ck(not g.history_rows[g.history_selected].replayable,'old summaries do not pretend to contain replay')
	click(Vector2(180,838));await shot('02-history')
	var original=g.run.duplicate(true);click(Vector2(1040,830));await shot('03-battle')
	ck(g.review.active and not g.review_panel and g.review.playing,'actual replay opens full battle')
	g._review_action('play')
	click(g.REVIEW_VIEW.TRACK.position+Vector2(g.REVIEW_VIEW.TRACK.size.x*.4,10));var at=g.review.time
	g._process(.5);ck(is_equal_approx(at,g.review.time),'mouse scrubbing pauses')
	g._review_action('play')
	for n in 15:g._process(1.0/30);await process_frame
	g._review_action('play');await shot('04-paused')
	ck(not g.review.playing,'paused old fight')
	g._review_action('panel');g._review_action('item:'+str(evidence.items[0].uid));await shot('05-item-log')
	ck(not g.review_timeline.is_empty(),'specific item can filter actual events')
	g._review_action('close');g._history_action('close');await shot('06-return')
	ck(g.screen=='camp' and g.run==original,'return to camp does not replace live run')
	g.queue_free();await process_frame;print('NATIVE_HISTORY_V122 ',checks,' checks, ',failures,' failures');quit(0 if failures==0 else 1)
