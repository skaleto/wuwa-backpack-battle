extends SceneTree
const G=preload("res://tests/fixtures/playable_fixture_v50.gd")
const C=preload("res://scripts/data/catalog.gd")
const F=preload("res://scripts/crafting/craft.gd")
const FIX=preload("res://tests/fixtures/craft_fixture_v75.gd")
var checks=0
var failures=0
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
	AudioServer.set_bus_mute(0,true)
	call_deferred("test")
func test():
	var game=G.new();root.add_child(game);await process_frame
	game.set_process(false);game.set_process_input(false);game.music.set_process(false)
	var inv=game.inventory
	var source=game.piece("weapon_21020074","i1",0,0)
	var prism=game.piece("echo_glacio","i2",2,1)
	var r=inv.new_run("aemeath",19);r.round=4;r.serial=10;r.shop=[{},{},{},{},{},{}]
	r.items=[source,prism];r.stash=[];r.primary="i1"
	r.bags=[game.piece("satchel","b1",0,0),game.piece("pouch","b2",3,0)]
	ck(inv.validate_run(r) and inv.adjacent(source,prism),"screenshot pair is legal and adjacent")
	var before=r.duplicate(true)
	ck(F.preview(r,"weapon_21020086","i1",inv).ok,"V113 exact pair crafts without signature owner")
	ck(inv.has_method("craft_requirements"),"recipe UI has shared explicit qualification facts")
	if inv.has_method("craft_requirements"):
		var needed=inv.craft_requirements(r,"weapon_21020086")
		ck(needed.unlocked and needed.owners.is_empty() and needed.owner_met,"Glacial Gaze has no recruitment qualification")
		for recipe in C.combinations:
			var facts=inv.craft_requirements(r,recipe.target)
			ck(facts.unlocked==inv.craft_unlocked(r,recipe.target),"all recipe requirements agree with craft gate: "+recipe.target)
		var allowed=FIX.make(inv,"weapon_21020086")
		allowed.items=[source,prism];allowed.primary="i1"
		ck(inv.craft_requirements(allowed,"weapon_21020086").unlocked,"owner-qualified roster clears displayed lock")
		ck(F.preview(allowed,"weapon_21020086","i1",inv).ok,"same material pair crafts when existing owner rule is met")
	ck(r==before,"qualification display remains read only")
	ck(game.has_method("_item_star_snapshot"),"details have a spatial star diagram model")
	if game.has_method("_item_star_snapshot"):
		game.run=r
		for rotation in 4:
			source.rotation=rotation;source.x=2;source.y=2
			var model=game._item_star_snapshot(source,"board")
			ck(model.cells==inv.cells(source),"diagram follows actual occupied shape and rotation "+str(rotation))
			ck(model.markers.size()==3,"all three remote and adjacent stars remain in diagram "+str(rotation))
			ck(model.markers.filter(func(m):return m.state=="lit").size()==0,"non-weapon prism never lights sword-only star")
		var model=game._item_star_snapshot(source,"shop")
		ck(model.matched_count==-1 and model.markers.all(func(m):return m.state=="unlit"),"shop diagram shows range without claiming owned matches")
		source.rotation=0;source.x=0;source.y=0
		var weapon=game.piece("w_sword","i3",0,2);r.items=[source,weapon];game.run=r
		model=game._item_star_snapshot(source,"board")
		ck(model.matched_count==1 and model.markers.filter(func(m):return m.state=="lit").size()==1,"diagram counts one multi-cell partner once")
	game.reset_slice();game.overlay="";game.motion.modal_value=0;game.dragging={}
	game.buttons=[{"rect":Rect2(1000,800,100,60),"action":"battle","enabled":true,"modal":false,"circle":false}]
	game.mouse=Vector2(1050,830);game.audio.requested.clear();game._mouse_down()
	ck(game.run.phase=="battle","real battle button starts combat")
	ck(int(game.audio.requested.get("start",0))==1 and int(game.audio.requested.get("click",0))==0,"battle button produces one start cue, no layered generic click")
	game.audio.requested.clear();game._start_battle()
	ck(int(game.audio.requested.get("start",0))==0,"repeat start outside shop does not emit success")
	game.music.set_context("battle",false);game.music._process(1)
	game.run.phase="battle";game.combat.winner=1;game.combat_time=game._replay_end();game.event_cursor=game.combat.events.size()
	game.battle_entry_age=1;game.paused=false;game.pending_impacts=[];game.skip_requested=false
	game.audio.requested.clear();game._process(.016)
	ck(game.music.diagnostics().active.is_empty(),"actual victory frame immediately stops all BGM")
	ck(int(game.audio.requested.get("win",0))==1,"actual victory frame emits selected stinger once")
	game._process(.016);ck(int(game.audio.requested.get("win",0))==1,"result frames never repeat victory cue")
	game.audio.set_muted(false);game.audio.stop_all();game.audio.last_played.clear();game.audio.play_event("win")
	ck(game.audio.pools.ui.any(func(p):return p.playing and is_equal_approx(p.volume_db,-2)),"victory is 4dB louder than previous -6dB")
	print("FEEDBACK_V99 ",checks," checks, ",failures," failures")
	game.audio.stop_all();game.music.stop_all();await create_timer(.25).timeout
	game.queue_free();await process_frame;await create_timer(.15).timeout;quit(1 if failures else 0)
