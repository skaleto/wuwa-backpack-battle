extends SceneTree
const G=preload("res://scripts/game.gd")
const S=preload("res://scripts/storage/storage.gd")
var failures=0
var checks=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("review")
func review() -> void:
	var game=G.new();game.storage=S.new("user://motion-v24-test-"+str(Time.get_ticks_msec()));game.muted=true
	root.add_child(game);await process_frame;game.set_process(false)
	game.screen="game"
	for leader in G.C.characters:
		game.run=game.inventory.new_run(leader,24);game.opponent=game.inventory.new_run("jiyan",25)
		game._rig_trigger(0,"hit",1.0)
		var rig=game._get_portrait_rig(0).rig
		check(rig.mesh.texture.resource_path.ends_with(leader+"-portrait.webp"),leader+" owns its original-art native skeleton")
	var rig=load("res://assets/characters/rigs/jiyan/rig.tscn").instantiate();root.add_child(rig)
	var points=[Vector2(655,214),Vector2(670,470),Vector2(716,1260),Vector2(1120,880)]
	rig.clear();rig.sample(.14)
	var idle=points.map(func(p):return rig.deform_point(p))
	rig.trigger("hit",0);rig.sample(.14)
	var delta=rig.deform_point(points[0])-idle[0]
	for n in range(points.size()):check((rig.deform_point(points[n])-idle[n]).distance_to(delta)<.01,"hit translates the complete silhouette without rubber deformation")
	game.run=game.inventory.new_run("jiyan",24);game.opponent=game.inventory.new_run("jiyan",25);game._start_battle()
	# Playback begins after the real board entry; feedback clock checks start there.
	game._process(1.0)
	game.pending_impacts=[{"delay":.2,"event":{"kind":"attack","side":0,"value":4,"uid":"i1"}}]
	game.paused=true;var before=float(game.pending_impacts[0].delay);game._process(.1)
	check(is_equal_approx(float(game.pending_impacts[0].delay),before),"paused battle also pauses in-flight impact")
	# Pause must freeze all battle feedback, while UI controls remain responsive.
	game.combat_vfx.spawn(Vector2.ZERO,0,"sword",Color.WHITE)
	game.projectiles=[{"side":0,"life":.3,"color":Color.WHITE}]
	game.motion.hit=[.22,0.0];game.floats=[{"life":1.0}]
	game.attack_left=[.48,0.0];game.item_sways={"probe":.38};game.hit_pause=.055
	var feedback=var_to_str([game.combat_vfx.impacts,game.projectiles,game.motion.hit,game.floats,game.attack_left,game.item_sways,game.hit_pause])
	game._process(.1)
	check(feedback==var_to_str([game.combat_vfx.impacts,game.projectiles,game.motion.hit,game.floats,game.attack_left,game.item_sways,game.hit_pause]),"pause holds every combat decoration and hit-stop")
	game.paused=false;game.overlay="menu";game._process(.1)
	check(feedback==var_to_str([game.combat_vfx.impacts,game.projectiles,game.motion.hit,game.floats,game.attack_left,game.item_sways,game.hit_pause]),"menu holds every combat decoration")
	game.overlay="";game.hit_pause=0;game.speed=4;game.pending_impacts=[];game.event_cursor=game.combat.events.size()
	var clock=game.combat_time;game._process(.025)
	check(is_equal_approx(game.combat_time-clock,.1) and is_equal_approx(game.projectiles[0].life,.2) and is_equal_approx(game.combat_vfx.impacts[0].age,.1),"four-times speed uses one clock for poses, travel and impact")
	var battle_hash=var_to_str(game.combat).sha256_text()
	for leader in G.C.characters:
		var role=G.C.characters[leader].roster_id
		game._play_event({"kind":"intro","side":0,"uid":"test","time":game.combat_time,"role_id":role,"label":""})
		var slot=game._support_rig_slot(0,leader)
		check(game.portrait_rigs[slot].rig.character_id==leader and game.portrait_rigs[slot].rig.action=="intro",leader+" has its own support animation")
	check(var_to_str(game.combat).sha256_text()==battle_hash,"animation cannot mutate combat data")
	game._action("skip");game._process(.02)
	check(game.run.phase=="result" and game.combat_vfx.impacts.is_empty() and game.projectiles.is_empty(),"skip clears all effects")
	print("MOTION_V24: ",checks," checks; ",failures," failures")
	game.queue_free();rig.queue_free();await process_frame;quit(1 if failures else 0)
