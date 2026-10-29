extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
var game
var inv
var checks=0
var failures=0
func ck(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():call_deferred("run_tests")
func fresh()->Dictionary:
	var r=inv.new_run("aemeath",19);r.serial=30
	return r
func run_tests():
	game=G.new();root.add_child(game);await process_frame
	game.set_process(false);game.set_process_input(false);inv=game.inventory
	var run=fresh();var before=run.duplicate(true);var bag=run.bags[0].duplicate(true)
	bag.rotation=1;bag.paid_cost=999
	var preview=inv.stash_preview(run,bag)
	ck(preview.ok and run==before,"bag preview is read-only")
	ck(preview.displaced.size()==before.items.size(),"preview lists every departing item")
	ck(inv.stash(run,bag),"last bag and its contents can be stashed")
	ck(run==preview.run,"commit exactly equals preview")
	ck(run.bags.is_empty() and run.items.is_empty(),"stashing last bag leaves empty board")
	ck(inv.validate_run(run) and not inv.validate_ghost(inv.snapshot(run,"qa")),"empty equipped run valid but combat ghost invalid")
	ck(run.gold==before.gold and inv.purchased_capacity(run)==inv.purchased_capacity(before),"stash conserves money and capacity")
	var stored=inv.find_piece(run,bag.uid)
	ck(stored.rotation==1 and stored.paid_cost==before.bags[0].paid_cost and stored.cost_basis==before.bags[0].cost_basis,"rotation stored and owned cost basis authoritative")
	game.storage.save(run);var restored=game.storage.resume()
	ck(restored==run,"last-bag run survives isolated save and load")
	var fitted=inv.first_fit(stored,run.items,run.bags)
	ck(inv.place(run,fitted) and inv.validate_run(run),"stored bag can return to empty board")
	var restored_item=run.stash.filter(func(v):return not inv.C.is_tag(v.kind,"bag"))[0]
	ck(inv.place(run,inv.first_fit(restored_item,run.items,run.bags)),"contents can return after bag")
	# A blade covers both bags; only items losing coverage move, always whole.
	run=fresh();run.bags=[game.piece("satchel","b1",0,0),game.piece("pouch","b2",3,0)]
	run.items=[game.piece("w_sword","i1",2,0),game.piece("mat_43020011","i2",0,1),game.piece("nutrition","i3",4,1)]
	run.stash=[];run.primary="i1";before=run.duplicate(true)
	ck(inv.validate_run(run),"cross-bag fixture valid")
	preview=inv.stash_preview(run,run.bags[0])
	ck(preview.ok and preview.displaced.map(func(v):return v.uid)==["i1","i2"],"cross-bag item and contained item travel whole")
	ck(inv.stash(run,run.bags[0]) and run.items==[before.items[2]] and run.stash.size()==3,"other bag item stays put")
	# V103: page size is not capacity, including bag itself and each displaced item.
	run=before.duplicate(true)
	for n in 4:run.stash.append(game.piece("mat_43020011","stored%d"%n,0,0))
	before=run.duplicate(true);preview=inv.stash_preview(run,run.bags[0])
	ck(preview.ok and run==before and preview.run.stash.size()==7,"V103 seventh arrival preview is readonly and complete")
	ck(inv.stash(run,run.bags[0]) and run==preview.run,"V103 bag and covered items commit together above six")
	for field in ["kind","level","tuning","rotation","paid_cost"]:
		run=fresh();before=run.duplicate(true);bag=run.bags[0].duplicate(true)
		bag[field]={"kind":"pouch","level":1,"tuning":"strong","rotation":4,"paid_cost":-1}[field]
		ck(not inv.stash(run,bag) and run==before,"invalid bag metadata rejected: "+field)
	run=fresh();bag=run.bags[0].duplicate(true);bag.uid="missing";before=run.duplicate(true)
	ck(not inv.stash(run,bag) and run==before,"unowned bag rejected")
	for phase in ["battle","result","ending"]:
		run=fresh();run.phase=phase;before=run.duplicate(true)
		ck(not inv.stash(run,run.bags[0]) and run==before,"stash rejects phase "+phase)
	# Real pointer press/motion/release takes the bag-origin route.
	game.reset_slice();game.motion.modal_value=0;game.motion.modal_target=0
	before=game.run.duplicate(true);var start=game._bag_handle(game.run.bags[0]).get_center()
	var press=InputEventMouseButton.new();press.position=start;press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;game._input(press)
	ck(game.drag_origin=="bag","controller picks visible bag edge")
	var motion=InputEventMouseMotion.new();motion.position=game._stash_mat_rect().get_center();motion.relative=motion.position-start;game._input(motion)
	var rotate=InputEventKey.new();rotate.keycode=KEY_R;rotate.pressed=true;game._input(rotate)
	preview=game._stash_display_preview()
	ck(preview.get("ok",false) and preview.displaced.size()==before.items.size(),"controller previews destination slots for bag contents")
	var release=InputEventMouseButton.new();release.position=motion.position;release.button_index=MOUSE_BUTTON_LEFT;game._input(release)
	ck(game.run.bags.is_empty() and game.run.items.is_empty() and game.overlay.is_empty(),"controller stores last bag without modal")
	ck(game.stash_transfer.flights.size()==before.items.size() and not game.stash_transfer.flights.any(func(v):return inv.C.is_tag(v.piece.kind,"bag")),"only contents fly from board; bag does not duplicate")
	before=game.run.duplicate(true);game._start_battle();ck(game.run==before,"empty board cannot start battle")
	var bag_slot=-1
	for n in game.run.stash.size():
		if inv.C.is_tag(game.run.stash[n].kind,"bag"):bag_slot=n
	ck(bag_slot>=0 and game.run.stash[bag_slot].rotation==1,"controller preserves rotated bag in stash")
	var restore_at=game._stash_rect(bag_slot).get_center()
	press.position=restore_at;game._input(press)
	motion.position=game._board_to_screen(game.BOARD+Vector2(.5,.5)*game.CELL);motion.relative=motion.position-restore_at;game._input(motion)
	release.position=motion.position;game._input(release)
	ck(game.run.bags.size()==1 and game.run.bags[0].rotation==1 and inv.validate_run(game.run),"controller restores rotated bag from stash")
	# V103: an already occupied first page still accepts an entire bag.
	game.reset_slice();game.motion.modal_value=0;game.motion.modal_target=0
	while game.run.stash.size()<6:game.run.stash.append(game.piece("mat_43020011","full%d"%game.run.stash.size(),0,0))
	before=game.run.duplicate(true);press.position=game._bag_handle(game.run.bags[0]).get_center();game._input(press)
	motion.position=game._stash_mat_rect().get_center();motion.relative=motion.position-press.position;game._input(motion)
	ck(not game._stash_drop_projection().has_area() and game._stash_display_preview().get("ok",false) and game.run==before,"V103 bag storage preview remains readonly across pages")
	release.position=motion.position;game._input(release)
	ck(game.run.bags.is_empty() and game.run.items.is_empty() and game.run.stash.size()==6+before.items.size()+1 and game.overlay.is_empty(),"V103 pointer release keeps bag and every contained item across pages")

	game.run=fresh();game.run.round=3;game.run.gold=100;game.run.shop=[{},{},{},{},{},{"kind":"pouch","locked":false}]
	game.run.bags=[];game.run.items=[];game.run.primary="";game.run.stash=[]
	game.run.bags=preload("res://tests/fixtures/capacity_fixture_v111.gd").full_bags(inv)
	ck(inv.stash(game.run,game.run.bags[0]),"a full-capacity owned bag can be stored")
	ck(inv.purchased_capacity(game.run)==63 and not inv.buy(game.run,5),"stored capacity still counts toward 63 purchase cap")
	print("BAG_STASH_V76 ",checks," checks, ",failures," failures")
	game.queue_free();await process_frame;quit(1 if failures else 0)
