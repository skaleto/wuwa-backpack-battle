extends SceneTree
## Legal late-run surface working set from the independent quality review.
const G=preload("res://scripts/game.gd")
var game
var checks=[]
var measurements=[]
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	checks.append({"ok":ok,"label":label})
	if not ok:printerr("FAIL ",label)
func texture_ids()->Dictionary:
	var ids={}
	for path in game.SKIN.textures:ids[path]=game.SKIN.textures[path].get_instance_id()
	return ids
func draw_frame()->int:
	var start=Time.get_ticks_usec()
	game.queue_redraw();await process_frame;RenderingServer.force_draw(false);await process_frame
	return Time.get_ticks_usec()-start
func exercise(surface:String,opacity:float=1.0):
	game.overlay=surface;game.motion.modal_value=0 if surface.is_empty() else opacity;game.motion.modal_target=game.motion.modal_value
	var label=surface+(" transition" if opacity<1.0 else "")
	await draw_frame()
	var previous=texture_ids()
	for n in 3:
		var before=game.run.duplicate(true)
		var elapsed=await draw_frame();var now=texture_ids();var recreated=[]
		for path in now:
			if previous.has(path) and previous[path]!=now[path]:recreated.append(path.get_file())
		check(recreated.is_empty(),label+" warm frame "+str(n)+" keeps texture instances")
		check(game.run==before,label+" drawing leaves legal run unchanged")
		var metrics=game.SKIN.cache_metrics() if game.SKIN.has_method("cache_metrics") else {}
		if not metrics.is_empty():
			check(metrics.frame_loads==0,label+" warm frame "+str(n)+" performs zero texture loads")
			check(metrics.resident_bytes<=metrics.budget_bytes,label+" resident textures obey byte budget")
		measurements.append({"surface":label,"frame":n,"usec":elapsed,"textures":now.size(),"recreated":recreated,"metrics":metrics})
		previous=now
func run():
	root.size=Vector2i(1440,960)
	game=G.new();game.storage=game.S.new("user://qa-skin-cache");game.muted=true;game.native_rigs_enabled=false
	root.add_child(game);await process_frame;game.set_process(false);game.set_process_input(false);game.set_visual_skin("chibi",false)
	game.run=game.inventory.new_run("verina",50);game.run.round=8;game.run.gold=99;game.run.items=[];game.run.stash=[];game.run.bags=[]
	for p in [Vector2i(0,0),Vector2i(3,0),Vector2i(0,2),Vector2i(3,2),Vector2i(0,4)]:
		var bag=game.inventory.make_piece("satchel" if game.run.bags.is_empty() else "travel","bag"+str(game.run.bags.size()));bag.x=p.x;bag.y=p.y;game.run.bags.append(bag)
	var kinds=game.C.items.keys().filter(func(k):return not game.C.is_tag(k,"bag") and FileAccess.file_exists(game.SKIN.item_path(k)))
	kinds.sort_custom(func(a,b):return game.C.items[a].shape.size()<game.C.items[b].shape.size())
	for kind in kinds:
		var piece=game.inventory.make_piece(kind,"cache"+str(game.run.items.size()+game.run.stash.size()))
		if not game.inventory.valid_piece(piece) or not game.inventory.collection_legal(game.run.items+game.run.stash+[piece],game.run.leader):continue
		var fit=game.inventory.first_fit(piece,game.run.items,game.run.bags)
		if not fit.is_empty():game.run.items.append(fit)
		elif game.run.stash.size()<6:game.run.stash.append(piece)
	game.run.primary=game.inventory.primary_weapon(game.run).get("uid","")
	var owned=(game.run.items+game.run.stash).map(func(piece):return piece.kind)
	game.run.shop=[]
	for kind in kinds:
		if kind in owned or game.C.is_tag(kind,"consumable") or game.C.is_tag(kind,"keepsake") or not game.inventory.valid_piece(game.inventory.make_piece(kind,"offer")) or not game.inventory.shop_eligible(game.run,kind):continue
		game.run.shop.append({"kind":kind,"locked":false})
		if game.run.shop.size()==5:break
	game.run.shop.append({})
	game.screen="game";game.catalogue_page=10;game.catalogue_focus=80;game.motion.transition_left=0;game.reroll_age=2;game.phase_age=2;game.age=8
	check(game.inventory.validate_run(game.run),"late-run working set is legal")
	check(game.run.items.size()>=19 and game.run.stash.size()==6 and game.run.shop.size()==6,"large legal board/stash/shop working set")
	await exercise("catalogue");await exercise("");await exercise("catalogue",.5)
	game._open_item_details(game.run.items[0],"board");await exercise("item_details")
	await exercise("catalogue")
	if game.SKIN.has_method("cache_metrics"):
		check(game.SKIN.cache_metrics().resident_bytes<=game.SKIN.IDLE_CACHE_BUDGET_BYTES,"return to a small page evicts the hidden large working set")
	game.set_visual_skin("original",false)
	check(game.SKIN.textures.is_empty(),"switch releases previous skin texture cache")
	var failures=checks.filter(func(value):return not value.ok).size()
	var file=FileAccess.open("res://build/qa/demo-v50/skins/checks/cache.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"measurements":measurements,"failures":failures},"\t"));file.close()
	print("SKIN CACHE: ",checks.size()," checks, ",failures," failures")
	for measurement in measurements:print(JSON.stringify(measurement))
	game.queue_free();await process_frame;quit(1 if failures else 0)
