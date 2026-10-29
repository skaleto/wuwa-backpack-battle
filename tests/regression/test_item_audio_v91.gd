extends SceneTree
const G=preload("res://tests/fixtures/playable_fixture_v50.gd")
const B=preload("res://scripts/battle/battle.gd")
var game
var checks=0
var failures=0

func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)

func move(at:Vector2)->void:
	var event=InputEventMouseMotion.new();event.position=at;game._input(event)

func press(down:bool)->void:
	var event=InputEventMouseButton.new();event.position=game.mouse;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;game._input(event)

func at(x:float,y:float)->Vector2:
	return game._board_to_screen(game.BOARD+Vector2(x,y)*game.CELL)

func counts()->Dictionary:return game.audio_diagnostics().requested

func reset()->void:
	game.reset_slice();game._clear_held_pose();game.buttons=[]
	game.motion.modal_value=0;game.motion.modal_target=0;game.motion.last_overlay=""
	game.detail_parent_overlay="";game.bag_mode=false;game.drag_pressed=false
	game.run.stash=[game.piece("whiff","stored",0,0)]
	game.run.shop=[{"kind":"whiff","locked":false},{},{},{},{},{}];game.run.gold=50
	game.audio.requested.clear();game.audio.last_played.clear()

func _initialize():call_deferred("test")

func test():
	root.size=Vector2i(1440,960);game=G.new();root.add_child(game);await process_frame
	game.set_process(false);game.set_process_input(false)
	for origin in ["board","shop","stash","bag"]:
		for held in [false,true]:
			reset()
			var point=at(.5,.5)
			if origin=="shop":point=game._offer_rect(0).get_center()
			elif origin=="stash":point=game._stash_rect(0).get_center()
			elif origin=="bag":point=at(1.5,2.5)
			var label=origin+(" long hold" if held else " click")
			var expected={"bag_pick":1} if origin=="bag" else {"pick":1}
			if origin=="board":ck(not game.inventory.star_links(game.run.items[0],game.run.items,game.run).is_empty(),"fixture has an active star relation")
			var before=game.run.duplicate(true)
			move(point)
			ck(counts().is_empty(),label+" hover is visual only")
			press(true)
			ck(game.drag_origin==origin and not game.dragging.is_empty(),label+" grabs the intended object")
			ck(counts()==expected,label+" press has exactly one audible cue")
			if held:game._process(.8)
			press(false)
			ck(game.overlay=="item_details" and game.detail_origin==origin,label+" release opens the correct details")
			ck(counts()==expected,label+" opening details adds no second cue")
			ck(game.run==before,label+" inspection preserves inventory and gold")
			move(point+Vector2(1,0));move(point+Vector2(2,0))
			ck(counts()==expected,label+" post-release pointer motion does not replay star sound")
	# A real move still has separate grab and successful placement cues.
	reset();game.run.stash=[]
	move(at(.5,.5));press(true);move(game._stash_rect(0).get_center());press(false)
	ck(game.run.stash.any(func(item):return item.uid=="i1"),"real drag commits to stash")
	ck(counts()=={"pick":1,"drop":1},"real drag keeps grab and drop feedback")
	reset();game.run.stash=[]
	move(game._offer_rect(0).get_center());press(true);move(game._stash_rect(0).get_center());press(false)
	ck(game.run.shop[0].is_empty() and game.run.stash.size()==1,"real shop drag still purchases")
	ck(counts()=={"pick":1,"purchase":1},"real purchase keeps its confirmation cue")
	# A detail opened through a button must not also sound from the view helper.
	reset();game._action("catalogue")
	# Register the same invisible item button through the production button helper;
	# headless audio QA needs its input route, not catalogue texture rendering.
	game._button(Rect2(68,197,153,128),"","catalogue_detail:whiff",true,false)
	var entries=game.buttons.filter(func(button):return str(button.action).begins_with("catalogue_detail:") and button.enabled)
	ck(not entries.is_empty(),"catalogue exposes actual item buttons")
	if not entries.is_empty():
		game.mouse=entries[0].rect.get_center();press(true);press(false)
		ck(game.overlay=="item_details" and counts()=={"click":1},"catalogue item button produces one click cue")
	# Read-only battle inspection has no grab phase, but retains its click cue.
	reset();game.run.phase="battle";game.battle_entry_age=2
	move(at(.5,.5));press(true);press(false)
	ck(game.overlay=="item_details" and counts()=={"click":1},"battle inspection produces one click cue, no hover star")
	# Feed a genuine successful star event through the real presentation consumer.
	reset();var battle=B.new();var ctx=battle.begin(game.run,game.opponent,31)
	ctx.events=[];ctx.states[0].hp-=5
	battle.natural(ctx,0,game.run.items[1],"attack",1.0)
	var stars=ctx.events.filter(func(event):return event.kind=="star_trigger")
	ck(not stars.is_empty(),"real battle produces a successful star effect")
	if not stars.is_empty():
		var before=game.run.duplicate(true);game._play_event(stars[0])
		ck(counts()=={"star":1},"successful battle star still dispatches selected bubble once")
		ck(game.run==before,"sound feedback does not mutate the battle build")
	print("ITEM_AUDIO_V91 ",checks," checks, ",failures," failures")
	game.queue_free();await process_frame;quit(1 if failures else 0)
