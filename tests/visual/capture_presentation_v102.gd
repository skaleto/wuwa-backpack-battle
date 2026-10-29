extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const OUT="res://build/qa/feedback-v102/after/"
var game
var viewport
func _initialize()->void:
	root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true);call_deferred("run")
func shot(name:String)->void:
	game.paint_alpha=1;game.paint_offset=Vector2.ZERO;game.motion.transition_left=0;game.transition_image=null
	game.queue_redraw();await process_frame
	RenderingServer.force_draw(true);await process_frame
	assert(viewport.get_texture().get_image().save_png(OUT+name+".png")==OK)
func click(at:Vector2)->void:
	for pressed in [true,false]:
		var event=InputEventMouseButton.new();event.position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		game._input(event)
func run()->void:
	for dir in ["","fusion-frames","quality-frames"]:DirAccess.make_dir_recursive_absolute(OUT+dir)
	viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport);game=G.new();viewport.add_child(game);await process_frame
	game.set_process(false);game.set_process_input(false)
	var own=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/data/battle-review-v100/reported-fight.json")).build
	for key in own:game.run[key]=own[key]
	game.run.phase="shop";game.run.round=6;game.run.gold=12;game.run.shop=[{},{},{},{},{},{}]
	game.screen="game";game.mouse=Vector2(30,100);game._clear_feedback()
	var star=game.run.items.filter(func(item):return item.kind=="weapon_21020076")[0]
	game._open_item_details(star,"board");game.motion.modal_value=1;game.item_selection_age=game.ITEM_SELECTION_DURATION
	await shot("01-selected-own-stars")
	# The slot recipient is also in another source's star map. Hold it without
	# moving: the same controller path as mouse-down must show only its own map.
	game._close_item_details();game.motion.modal_value=0;game.motion.modal_target=0
	var echo=game.run.items.filter(func(item):return item.kind=="thundering")[0]
	var at=game._craft_item_center({"piece":echo,"origin":"board","index":0},false)
	var press=InputEventMouseButton.new();press.position=at;press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true
	game._input(press);game._process(.08)
	assert(game.dragging.get("uid","")==echo.uid)
	await shot("02-held-own-stars")
	game.dragging={};game.drag_pressed=false;game._clear_held_pose();game.hovered={};game.detail_item={};game.overlay=""
	game.run.shop=[{"kind":"heron","locked":false},{"kind":"weapon_21020076","locked":false},{},{},{},{}]
	game.run.stash=[game.piece("heron","ambient-stash",0,0)];game.mouse=Vector2(30,100)
	for n in 72:
		game._process(1.0/24);await shot("quality-frames/%03d"%n)
		if n==24:await shot("03-quality-ambient")
	# Real inline craft, using independent QA storage through the real input.
	game.fusion_view.finish();game.reset_slice();game.run.round=3;game.run.serial=20;game.run.shop=[{},{},{},{},{},{}]
	game.run.bags=[]
	for y in range(0,6,2):
		for x in range(0,8,2):game.run.bags.append(game.piece("pouch","b%d-%d"%[x,y],x,y))
	game.run.items=[game.piece("w_sword","i1",2,2),game.piece("mat_43020011","i2",2,1)]
	game.run.primary="i1";game.run.stash=[];game.mouse=Vector2(30,100)
	game.motion.modal_value=0;game.motion.modal_target=0;game.inline_craft.refresh(game._craft_view_model())
	await shot("04-before-fusion")
	for n in 18:await shot("fusion-frames/%03d"%n)
	click(game.inline_craft.entries[0].rect.get_center())
	assert(game.fusion_view.active() and game.run.items.size()==1)
	for n in 48:
		game._process(1.0/30);await shot("fusion-frames/%03d"%(n+18))
		if n==5:await shot("05-fusion-white")
		if n==17:await shot("06-fusion-approach")
		if n==31:await shot("07-fusion-embers")
		if n==40:await shot("08-after-fusion")
	assert(not game.fusion_view.active() and game.fusion_view.get_child_count()==0)
	# Small initial bag sends the result into storage. The burst follows it.
	game.reset_slice();game.run.serial=20;game.run.shop=[{},{},{},{},{},{}]
	game.run.items=[game.piece("w_sword","i1",0,0),game.piece("whiff","i2",2,1)];game.run.primary="i1";game.run.stash=[]
	game.motion.modal_value=0;game.motion.modal_target=0;game.inline_craft.refresh(game._craft_view_model())
	click(game.inline_craft.entries[0].rect.get_center());game._process(1.0)
	assert(game.run.stash.size()==1 and game.fusion_view.destination==game._stash_rect(0).get_center())
	await shot("09-fusion-to-stash")
	game.fusion_view.finish();game.queue_free();await process_frame
	await create_timer(1.0).timeout
	var log=FileAccess.open(OUT+"capture-complete.txt",FileAccess.WRITE)
	log.store_string("9 native stills; 72 quality frames and 66 fusion frames; real inline craft input; own-only hold; actual stash destination; QA storage; Dummy audio; hidden unfocusable window.")
	quit()
