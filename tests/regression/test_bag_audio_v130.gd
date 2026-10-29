extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
var g
var checks=0
var failures=0
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:call_deferred("test")
func reset()->void:
	g.reset_slice();g.set_process(false);g.set_process_input(false);g.buttons=[]
	g.run.items=[];g.run.stash=[];g.run.primary="";g.run.gold=30
	g.run.bags=[g.piece("satchel","bag",0,0)]
	g.run.shop=[{},{},{},{},{},{"kind":"pocket_double","locked":false}]
	g.drag_pressed=false;g.bag_mode=false;g.audio.requested.clear();g.audio.last_played.clear()
func move(at:Vector2)->void:
	var e=InputEventMouseMotion.new();e.position=at;g._input(e)
func button(down:bool)->void:
	var e=InputEventMouseButton.new();e.position=g.mouse;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;g._input(e)
func at(x:float,y:float)->Vector2:return g._board_to_screen(g.BOARD+Vector2(x,y)*g.CELL)
func counts()->Dictionary:return g.audio.diagnostics().requested
func test()->void:
	if DisplayServer.get_name()!="headless":root.hide()
	root.unfocusable=true;root.size=Vector2i(1440,960)
	g=G.new();root.add_child(g);await process_frame
	for origin in ["bag","shop","stash"]:
		reset()
		var start=at(.5,.5)
		if origin=="shop":start=g._offer_rect(5).get_center()
		if origin=="stash":g.run.stash=[g.piece("pocket_double","stored",0,0)];start=g._stash_rect(0).get_center()
		var before=g.run.duplicate(true);move(start);button(true)
		ck(g.drag_origin==origin,"grabs bag from "+origin)
		ck(counts()=={"bag_pick":1},"one cloth grab from "+origin)
		button(false)
		ck(counts()=={"bag_pick":1},"inspection has no drop or second cue "+origin)
		ck(g.run==before,"inspection preserves inventory "+origin)
	reset();move(at(.5,.5));button(true);move(at(4.5,3.5));button(false)
	ck(g.run.bags[0].x==4 and g.run.bags[0].y==3,"legal bag move committed")
	ck(counts()=={"bag_pick":1,"bag_drop":1},"successful move has distinct cloth drop")
	reset();move(at(.5,.5));button(true);move(at(8.5,6.5));button(false)
	ck(counts()=={"bag_pick":1,"reject":1},"invalid drop never sounds successful")
	reset();move(at(.5,.5));button(true);move(g._stash_mat_rect().get_center());button(false)
	ck(g.run.bags.is_empty() and g.run.stash.size()==1,"bag moved to stash")
	ck(counts()=={"bag_pick":1,"bag_drop":1},"stash gets cloth drop")
	reset();move(g._offer_rect(5).get_center());button(true);move(g._stash_mat_rect().get_center());button(false)
	ck(g.run.gold==28 and g.run.stash.size()==1,"shop bag purchases only on drop")
	ck(counts()=={"bag_pick":1,"purchase":1,"bag_drop":1},"purchase has currency confirmation plus physical bag landing")
	for key in ["bag_pick","bag_drop"]:
		ck(g.audio.streams.has(key),"registered sample "+key)
		if g.audio.streams.has(key):ck(g.audio.streams[key].get_length()>=.10 and g.audio.streams[key].get_length()<.55,"short sample "+key)
	print("BAG_AUDIO_V130 ",checks," checks, ",failures," failures")
	g.queue_free();await process_frame;await create_timer(.12).timeout;quit(1 if failures else 0)
