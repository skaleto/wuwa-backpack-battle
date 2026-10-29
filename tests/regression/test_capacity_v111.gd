extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const FIX=preload("res://tests/fixtures/capacity_fixture_v111.gd")
const F=preload("res://scripts/crafting/craft.gd")
var game
var inv
var checks=0
var failures=0
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:call_deferred("run_tests")
func at(x:float,y:float)->Vector2:return game._board_to_screen(game.BOARD+Vector2(x,y)*game.CELL)
func move(at_position:Vector2)->void:
	var e=InputEventMouseMotion.new();e.position=at_position;game._input(e)
func button(at_position:Vector2,down:bool,id:int=MOUSE_BUTTON_LEFT)->void:
	var e=InputEventMouseButton.new();e.position=at_position;e.button_index=id;e.pressed=down;game._input(e)
func run_tests()->void:
	game=G.new();root.add_child(game);await process_frame
	game.set_process(false);game.set_process_input(false);inv=game.inventory
	ck(inv.WIDTH==9 and inv.HEIGHT==7 and inv.MAX_CAPACITY==63,"logical board expands to exactly 9 by 7")
	ck(inv.coverage(game.run.bags).size()==6 and game.run.gold==9,"starting capacity and money unchanged")
	for y in 7:
		for x in 9:
			ck(inv.in_bounds(Vector2i(x,y)) and game._board_cell(at(x+.5,y+.5))==Vector2i(x,y),"cell center roundtrip %d,%d"%[x,y])
	for cell in [Vector2i(-1,0),Vector2i(9,0),Vector2i(0,-1),Vector2i(0,7)]:
		ck(not inv.in_bounds(cell),"outside expanded boundary rejected "+str(cell))
	ck(game.QL.BOARD_AREA.encloses(game._board_screen_rect()) and is_equal_approx(game.QL.PITCH,480.0/7.0),"preparation fits existing panel with square cells")
	# This file was recorded with the unmodified 8 by 6 implementation.
	var old=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/data/capacity-v111/old-48-cell-run.json"))
	# V114 adds recruitment metadata and an effective overlay hash; test the same
	# frozen geometry after the separately tested migration.
	old=game.storage.migrate_v114(old)
	ck(inv.validate_run(old) and inv.coverage(old.bags).size()==48,"old full-board run still valid without migration")
	game.storage.save(old);var bytes=FileAccess.get_file_as_bytes(game.storage.root_path+"run.json");var resumed=game.storage.resume()
	# JSON numbers start as floats; the existing loader normalizes integer fields.
	ck(JSON.parse_string(JSON.stringify(resumed))==JSON.parse_string(JSON.stringify(old)) and FileAccess.get_file_as_bytes(game.storage.root_path+"run.json")==bytes,"old save resumes with identical values and disk bytes")
	var r=old.duplicate(true);r.gold=100;r.shop[5]={"kind":"strip","locked":false}
	ck(inv.buy(r,5) and inv.purchased_capacity(r)==51,"purchase can expand beyond former 48-cell cap")
	var fitted=inv.first_fit(r.stash[-1],r.items,r.bags)
	ck(not fitted.is_empty() and fitted.x==8 and inv.place(r,fitted),"new right column supports automatic bag placement")
	r=inv.new_run("aemeath",111);r.bags=FIX.full_bags(inv);r.items=[];r.stash=[];r.primary="";r.serial=1000;r.gold=100
	for y in 7:
		for x in 9:r.items.append(game.piece("mat_43020011","cell%d-%d"%[x,y],x,y))
	ck(inv.bags_legal(r.bags) and inv.coverage(r.bags).size()==63 and inv.validate_run(r),"all 63 cells can contain actual existing items")
	game.storage.save(r);ck(game.storage.resume()==r,"expanded board roundtrips through isolated storage")
	ck(inv.validate_ghost(inv.snapshot(r,"capacity-qa")),"expanded board accepted as asynchronous battle snapshot")
	r.shop[5]={"kind":"strip","locked":false};var before=r.duplicate(true)
	ck(not inv.buy(r,5) and r==before,"64-plus purchase rejected without any state mutation")
	ck(inv.stash(r,r.bags[0]) and inv.purchased_capacity(r)==63,"storing a bag preserves owned capacity")
	before=r.duplicate(true);ck(not inv.buy(r,5) and r==before,"stored bags cannot bypass 63-cell purchase cap")
	# Move, rotate and purchase with actual controller events at newly added edges.
	game.reset_slice();game.motion.modal_value=0;game.motion.modal_target=0
	game.run.bags=FIX.full_bags(inv);game.run.items=[game.piece("w_sword","blade",0,0)];game.run.primary="blade";game.run.stash=[];game.run.serial=100
	var origin=at(1.5,.5);button(origin,true);move(at(7.5,6.5));button(at(7.5,6.5),false)
	var blade=inv.find_piece(game.run,"blade")
	ck(blade.x==6 and blade.y==6,"pointer drag places long weapon across bottom-right edge")
	button(at(7.5,6.5),true);button(at(7.5,6.5),true,MOUSE_BUTTON_RIGHT);move(at(8.5,4.5));button(at(8.5,4.5),false)
	blade=inv.find_piece(game.run,"blade")
	ck(blade.rotation==1 and inv.occupied(blade).all(func(p):return p.x==8) and inv.validate_run(game.run),"rotated weapon fits last column through real input")
	var held_at=game._board_to_screen(game._item_rect(blade,game.BOARD).get_center());before=game.run.duplicate(true)
	button(held_at,true);move(at(9.5,6.5));button(at(9.5,6.5),false)
	ck(game.run==before,"out-of-board pointer release preserves full state")
	game.run.gold=100;game.run.shop[0]={"kind":"mat_43020011","locked":false};before=game.run.duplicate(true)
	var offer=game._offer_rect(0).position+Vector2(50,44)
	button(offer,true);move(at(0.5,6.5));ck(game.run==before,"shop drag toward new row has no purchase side effects")
	button(at(0.5,6.5),false)
	ck(game.run.shop[0].is_empty() and game.run.items.any(func(p):return p.kind=="mat_43020011" and p.x==0 and p.y==6),"shop release purchases into new bottom row")
	# Adjacency/crafting queries must also include the newly added region.
	game.reset_slice();game.run.bags=FIX.full_bags(inv);game.run.serial=100
	game.run.items=[game.piece("w_sword","blade",5,6),game.piece("whiff","partner",8,6)];game.run.primary="blade";game.run.stash=[]
	var options=F.ready_options(game.run,inv)
	ck(not options.is_empty(),"craft relation is found at bottom-right corner")
	if not options.is_empty():ck(F.commit_ready(game.run,options[0],inv).ok and inv.validate_run(game.run),"craft at new edge commits via normal placement")
	game.run.phase="battle";game.battle_entry_age=1.0
	for side in 2:
		var rect=game._board_screen_rect(side);var area=game.Q_BATTLE.BOARDS[side];var pitch=game._board_transform(side).get_scale()*game.CELL
		ck(area.grow(.001).encloses(rect) and is_equal_approx(pitch.x,pitch.y) and pitch.x>=56,"entire battle board fits panel with square readable cells "+str(side))
		ck(game._board_cell(rect.end-pitch*.5,side)==Vector2i(8,6),"battle last-cell mapping "+str(side))
	print("CAPACITY_V111 ",checks," checks, ",failures," failures")
	game.queue_free();await process_frame;quit(1 if failures else 0)
