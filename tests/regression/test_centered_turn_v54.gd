extends SceneTree
class ObservedGame extends "res://tests/fixtures/playable_fixture_v50.gd":
	var edge_ghost:Dictionary={}
	func _draw():
		edge_ghost={};super._draw()
	func _draw_stars(item:Dictionary,items:Array,origin:Vector2,active_only:bool=false,preview_build:Dictionary={})->void:
		if not dragging.is_empty() and origin==BOARD:edge_ghost=item.duplicate(true)
		super._draw_stars(item,items,origin,active_only,preview_build)
var game
var checks:Array=[]
func _initialize():
	DirAccess.make_dir_recursive_absolute("user://qa-reports/")
	call_deferred("run")
func check(ok:bool,label:String):
	checks.append({"ok":ok,"label":label})
	if not ok:printerr("FAIL ",label)
func at(x:float,y:float)->Vector2:return game._board_to_screen(game.BOARD+Vector2(x,y)*game.CELL)
func button(down:bool,id:int=MOUSE_BUTTON_LEFT):
	var e=InputEventMouseButton.new();e.position=game.mouse;e.button_index=id;e.pressed=down;game._input(e)
func key(code:int):
	var e=InputEventKey.new();e.keycode=code;e.pressed=true;game._input(e)
func move(p:Vector2):
	var e=InputEventMouseMotion.new();e.position=p;game._input(e)
func center(piece:Dictionary)->Vector2:
	var result=Vector2.ZERO
	var cells=game.inventory.cells(piece)
	for cell in cells:result+=Vector2(cell)+Vector2.ONE*.5
	return result/cells.size()*game.CELL
func visible_piece()->Dictionary:
	return game._held_source_piece() if game.has_method("_held_source_piece") else game.dragging
func pixel_pose()->Transform2D:
	var item=visible_piece()
	return game._held_pose()*Transform2D(game._projection_for(item.kind,item.rotation,game.CELL).transform)
func tick(delta:float):game._process(delta)
func fill_board():
	game.run.bags=[]
	for y in 3:
		for x in 4:game.run.bags.append(game.piece("pouch","b%d%d"%[x,y],x*2,y*2))
func setup(kind:String,rotation:int=0):
	game.reset_slice();game.motion.modal_value=0;game.motion.modal_target=0;game.buttons=[]
	fill_board();game.run.items=[];game.run.stash=[];game.run.gold=100
	var item=game.piece(kind,"held",1,0);item.rotation=rotation
	if game.C.is_tag(kind,"bag"):game.run.bags=[item]
	else:game.run.items=[item]
	game.mouse=at(1.22,.68);button(true)
	check(game.dragging.get("uid","")=="held",kind+" actual off-center press picks target")
func run():
	root.size=Vector2i(1440,960);game=ObservedGame.new();root.add_child(game);await process_frame
	game.set_process(false);game.set_process_input(false)
	for skin in ["original","chibi"]:
		game.set_visual_skin(skin,false)
		for kind in ["w_sword","verdant","corner"]:
			for rotation in [0,1]:
				setup(kind,rotation)
				if game.dragging.is_empty():continue
				var label=skin+" "+kind+" r"+str(rotation)
				var source=game.dragging.duplicate(true)
				var base_center=center(source)
				var anchor=game._held_pose()*base_center
				var expected=at(source.x,source.y)+base_center*game._board_transform().get_scale().x
				check(anchor.distance_to(expected)<.05,label+" pickup preserves occupied center")
				var before=game.run.duplicate(true)
				var initial_pose=game._held_pose()
				var art_start=pixel_pose() if kind!="corner" else initial_pose
				button(true,MOUSE_BUTTON_RIGHT)
				var art_after=pixel_pose() if kind!="corner" else game._held_pose()
				check(art_after.is_equal_approx(art_start),label+" turn input has no source-pixel pose jump")
				for delta in [1.0/60,.083333333,.1]:
					tick(delta)
					check((game._held_pose()*center(visible_piece())).distance_to(anchor)<.05,label+" occupied centroid fixed at t "+str(delta))
					var art_now=pixel_pose() if kind!="corner" else game._held_pose()
					check(art_now.get_scale().is_equal_approx(art_start.get_scale()),label+" rigid source pixel scale")
					if delta<.02:check(absf(angle_difference(initial_pose.get_rotation(),game._held_pose().get_rotation()))<deg_to_rad(8),label+" first 60Hz frame turns less than eight degrees")
				check(absf(angle_difference(initial_pose.get_rotation()+PI*.5,game._held_pose().get_rotation()))<.001,label+" quarter-turn settles at 0.2 seconds")
				var moved=Vector2(13,-9);move(game.mouse+moved)
				check((game._held_pose()*center(visible_piece())).distance_to(anchor+moved)<.05,label+" pointer delta translates center")
				for n in 3:
					var previous=pixel_pose() if kind!="corner" else game._held_pose()
					key(KEY_R)
					check((pixel_pose() if kind!="corner" else game._held_pose()).is_equal_approx(previous),label+" rapid retarget has no pose jump")
					tick(.035)
				tick(.2)
				check(game.dragging.rotation==source.rotation and absf(angle_difference(initial_pose.get_rotation(),game._held_pose().get_rotation()))<.001,label+" four turns restore source orientation")
				key(KEY_ESCAPE);tick(.05);check(game.run==before and game.dragging.is_empty(),label+" cancel keeps all gameplay data")
				check(game.drag_source.is_empty() and is_zero_approx(game.drag_turn_remaining),label+" cancel clears held source and animation")
		setup("verdant");var rapid_start=pixel_pose();var rapid_center=game._held_center_screen()
		for n in 4:
			var previous=pixel_pose();key(KEY_R)
			check(pixel_pose().is_equal_approx(previous),skin+" four rapid inputs preserve visible pixel transform at input "+str(n))
			tick(.025)
			check((game._held_pose()*center(visible_piece())).distance_to(rapid_center)<.05,skin+" rapid turn center remains stationary "+str(n))
		tick(.2)
		check(game.dragging.rotation==0 and pixel_pose().is_equal_approx(rapid_start),skin+" four rapid turns restore every source pixel")
		key(KEY_ESCAPE)
		# Ghost and release both use final centroid even during unfinished turns.
		setup("w_sword");button(true,MOUSE_BUTTON_RIGHT);move(at(3.22,2.68))
		if game.has_method("_drag_placement_cell"):
			var target=game._drag_placement_cell();var probe=game.dragging.duplicate(true);probe.x=target.x;probe.y=target.y
			check(game.inventory.can_place(probe,game.run.items,game.run.bags),skin+" parity target is legal")
			button(false)
			check(game.run.items[0].x==target.x and game.run.items[0].y==target.y and game.run.items[0].rotation==1,skin+" release commits exact final ghost cell before animation settles")
		else:check(false,skin+" final ghost and release expose shared centered projection")
		setup("corner");var before=game.run.duplicate(true);key(KEY_R);move(at(7.8,5.8));button(false)
		check(game.run==before and game.rejection_left>0 and game.overlay.is_empty(),skin+" invalid rotated bag returns atomically with local red feedback")
		game.reset_slice();game.buttons=[];game.run.gold=100;game.run.shop[0]={"kind":"w_sword","locked":true}
		before=game.run.duplicate(true);game.mouse=game._offer_rect(0).get_center();button(true);key(KEY_R);key(KEY_ESCAPE)
		check(game.run==before,skin+" cancelled shop rotation does not buy")
		key(KEY_1);check(not game.dragging.is_empty() and game.run==before,skin+" keyboard pickup remains deferred")
		key(KEY_R);game.set_visual_skin("chibi" if skin=="original" else "original",false)
		check(game.dragging.is_empty() and game.run==before,skin+" skin toggle cancels uncommitted rotation")
		game.set_visual_skin(skin,false);game.reset_slice();game.buttons=[]
		game.run.items=[];game.run.bags=[game.piece("satchel","carry-bag",1,1)]
		var carried=game.piece("whiff","carried",1,1);game.run.items=[carried];game.run.primary=""
		game.mouse=at(3.72,2.63);button(true)
		check(game.drag_origin=="bag",skin+" empty paper grabs bag containing item")
		var carry_pose=game._held_pose();var carry_anchor=carry_pose*center(visible_piece())
		var carried_center=carry_pose*(center(carried)+Vector2(carried.x-1,carried.y-1)*game.CELL)
		key(KEY_R);tick(.1)
		var rotated_center=game._held_pose()*(center(carried)+Vector2(carried.x-1,carried.y-1)*game.CELL)
		check(is_equal_approx(rotated_center.distance_to(carry_anchor),carried_center.distance_to(carry_anchor)),skin+" carried item follows same rigid center turn")
		move(game.mouse+Vector2(2,1)*game.CELL*game._board_transform().get_scale().x)
		var carry_target=game._drag_placement_cell();var bag_probe=game.dragging.duplicate(true);bag_probe.x=carry_target.x;bag_probe.y=carry_target.y
		var tx=game.inventory.bag_transaction(game.run,bag_probe)
		check(tx.ok,skin+" carried bag destination is legal")
		button(false);check(game.run.items==tx.items and game.run.bags==tx.bags,skin+" bag ghost transaction and committed contents agree")
		game.reset_slice();game.buttons=[];game.run.items=[];fill_board();game.run.stash=[game.piece("verdant","stored",0,0)]
		game.mouse=game._stash_rect(0).get_center();button(true);var stash_anchor=game._held_center_screen()
		key(KEY_R);tick(.1);check((game._held_pose()*center(visible_piece())).distance_to(stash_anchor)<.05,skin+" stash pickup turns around center")
		move(at(2.5,2.5));var stash_target=game._drag_placement_cell();button(false)
		check(game.run.stash.is_empty() and game.run.items.size()==1 and Vector2i(game.run.items[0].x,game.run.items[0].y)==stash_target,skin+" rotated stash release agrees with ghost")
		game.reset_slice();game.buttons=[];before=game.run.duplicate(true);game._action("forge");game._action("forge_confirm")
		check(not game.forge_output.is_empty(),skin+" forge produces deferred output")
		var forge_anchor=game._held_center_screen();key(KEY_R);tick(.1)
		check(game.forge_output.rotation==1 and (game._held_pose()*center(visible_piece())).distance_to(forge_anchor)<.05,skin+" forge keyboard rotation keeps occupied center")
		move(at(7.5,5.5));var forge_target=game._drag_placement_cell()
		check(Vector2i(game.forge_output.x,game.forge_output.y)==forge_target,skin+" forge ghost uses shared centered projection")
		button(false);check(game.run==before and not game.forge_output.is_empty(),skin+" invalid forge release consumes nothing")
		key(KEY_ESCAPE);check(game.run==before and game.forge_output.is_empty(),skin+" forge Escape cancels")
		game._action("forge");game._action("forge_confirm");key(KEY_R)
		game.set_visual_skin("chibi" if skin=="original" else "original",false)
		check(game.forge_output.is_empty() and game.run==before,skin+" skin change cancels forge preview without mutation")
		await boundary_checks(skin)
	var failures=checks.filter(func(v):return not v.ok).size()
	var f=FileAccess.open("user://qa-reports/centered-turn-v54.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"));f.close()
	print("V54 CENTERED TURN ",checks.size()," checks ",failures," failures")
	game.queue_free();await process_frame;quit(1 if failures else 0)

func redraw():
	game.queue_redraw();await process_frame
func boundary_checks(skin:String):
	game.set_visual_skin(skin,false);game.reset_slice();game.buttons=[];game.motion.modal_value=0;game.motion.modal_target=0
	fill_board();game.run.items=[game.piece("w_sword","edge",2,1)];game.run.primary="edge"
	game.mouse=at(2.22,1.68);button(true);key(KEY_R);move(at(-.78,2.68))
	var cell=game._drag_placement_cell()
	check(not game._board_screen_rect().has_point(game.mouse) and cell==Vector2i(0,1),skin+" off-center pointer leaves board while final sword target is (0,1)")
	var probe=game.dragging.duplicate(true);probe.x=cell.x;probe.y=cell.y
	check(game.inventory.can_place(probe,game.run.items,game.run.bags),skin+" edge target is genuinely legal")
	await redraw()
	check(game.edge_ghost.get("x",-1)==0 and game.edge_ghost.get("y",-1)==1 and game.edge_ghost.get("rotation",-1)==1,skin+" legal edge ghost actually draws while pointer is outside")
	button(false)
	check(game.run.items[0].x==0 and game.run.items[0].y==1 and game.run.items[0].rotation==1,skin+" off-board pointer releases sword at visible edge ghost")
	# A long forge result reproduces the same edge reach through real R input.
	game.reset_slice();game.buttons=[];game.motion.modal_value=0;game.motion.modal_target=0;fill_board();game.run.items=[];game.run.round=4
	var recipes=game.C.combinations.filter(func(r):return r.base=="w_sword")
	check(not recipes.is_empty(),skin+" active sword has an exact upgrade recipe")
	if recipes.is_empty():return
	var recipe=recipes[0]
	var base=game.piece("w_sword","edge-base",2,1);game.run.items=[base];game.run.primary=base.uid
	for n in recipe.materials.size():game.run.items.append(game.piece(recipe.materials[n],"edge-material-"+str(n),2+n,2))
	game.forge_base=base.uid;game._action("forge")
	game.forge_index=game.FORGE.options(game.run,base.uid,game.inventory).map(func(v):return v.target).find(recipe.target)
	game.mouse=at(2.5,1.5);game._action("forge_confirm");key(KEY_R)
	var target=Vector2i(0,1)
	move(at(target.x,target.y)+center(game.forge_output)*game._board_transform().get_scale().x-game.drag_center_offset)
	check(not game._board_screen_rect().has_point(game.mouse),skin+" forged result can reach left edge with pointer outside")
	var forge_preview=game._forge_placement_preview()
	check(forge_preview.ok and Vector2i(game.forge_output.x,game.forge_output.y)==target,skin+" forged edge projection is valid")
	button(false)
	check(game.forge_output.is_empty() and game.run==forge_preview.get("run",{}),skin+" off-board pointer commits exact forge preview once")
	key(KEY_ESCAPE)
	# Explicit destinations win even when a far-end grip leaves the held center
	# over the board. Returning a preview to its shop never becomes a purchase.
	for destination in ["shop","stash","sell"]:
		game.reset_slice();game.buttons=[];game.motion.modal_value=0;game.motion.modal_target=0;fill_board();game.run.stash=[]
		var piece=game.piece("verdant","destination",1,0);piece.rotation=0 if destination=="shop" else 1
		game.run.items=[piece];game.run.primary=piece.uid
		game.mouse=at(5.8,.5) if destination=="shop" else at(1.5,4.8);button(true)
		var before=game.run.duplicate(true)
		if destination=="shop":key(KEY_R);move(game._offer_rect(3).position+Vector2(5,5))
		elif destination=="stash":move(game._stash_mat_rect().position+Vector2(40,5))
		else:move(game._sell_rect().position+Vector2(5,5))
		if destination in ["shop","stash"]:check(game._board_screen_rect().has_point(game._held_center_screen()),skin+" "+destination+" pointer target overlaps held board center")
		await redraw();check(game.edge_ghost.is_empty(),skin+" explicit "+destination+" target suppresses board ghost")
		button(false)
		if destination=="shop":check(game.run==before,skin+" return to shop cancels instead of dropping behind the panel")
		elif destination=="stash":check(game.run.items.is_empty() and game.run.stash.size()==1,skin+" explicit stash target wins over held board center")
		else:check(game.run.items.is_empty() and game.run.gold>before.gold,skin+" explicit sell target wins over board projection")
