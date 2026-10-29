extends SceneTree
const G=preload("res://tests/fixtures/playable_fixture_v50.gd")
var game
var checks=0
var failures=0
func _initialize():call_deferred("run_test")
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func run_test():
	game=G.new();root.add_child(game);await process_frame;game.set_process(false)
	game.set_visual_skin("chibi",false);game._clear_feedback()
	var state=game.run.duplicate(true)
	# Dense simultaneous hits used to wrap the fifth number onto the first.
	for i in 5:game._apply_impact({"kind":"attack","side":0,"uid":"i1","value":7,"time":0})
	var positions=game.floats.map(func(v):return v.position)
	for i in positions.size():
		for j in range(i+1,positions.size()):check(positions[i].distance_to(positions[j])>=34,"simultaneous damage has separate readable positions %d/%d"%[i,j])
	check(game.run==state,"presentation leaves inventory/economy unchanged")
	for i in 20:game._apply_impact({"kind":"attack","side":i%2,"uid":"i1","value":12,"time":0})
	check(game.floats.all(func(v):return v.position.y>=190 and v.position.y<=390),"dense labels remain below HUD and above inventory")
	for i in game.floats.size():
		for j in range(i+1,game.floats.size()):
			var delta=(game.floats[i].position-game.floats[j].position).abs()
			check(delta.x>=100 or delta.y>=36,"dense two-sided labels have non-overlapping lanes")
	game._clear_feedback();game._start_battle();game.battle_entry_age=1.0
	var combat_state=game.combat.duplicate(true)
	game._play_event({"kind":"attack","side":0,"uid":"i1","value":7,"time":0})
	check(game.floats.is_empty() and not game.pending_impacts.is_empty(),"attack result waits for travelling hit")
	game.paused=true
	var pending=game.pending_impacts.duplicate(true);game._process(.2)
	check(game.pending_impacts==pending,"pause holds pending hits")
	check(game.combat==combat_state,"presentation cannot rewrite simulation")
	if game.has_method("_vitals_frame"):
		game.combat_time=.2
		check(game._vitals_frame()==game.combat.frames[0],"health stays on pre-impact frame while projectile travels")
		game.combat_time=.7
		check(game._vitals_frame()==game.combat.frames[4],"health follows the same 300ms impact delay")
	else:check(false,"health presentation shares impact timing")
	game._clear_feedback();game._play_event({"kind":"heal","side":0,"uid":"i2","value":18,"time":1})
	check(game.floats.is_empty() and game.pending_impacts.size()==1,"healing numbers also wait for visible health timeline")
	var Motion=load("res://scripts/ui/presentation.gd")
	var fast=Motion.new();var slow=Motion.new()
	fast.smooth("hp",1);slow.smooth("hp",1)
	for n in 60:
		fast.update(1.0/60);fast.smooth("hp",.25)
	for n in 30:
		slow.update(1.0/30);slow.smooth("hp",.25)
	check(is_equal_approx(fast.bars.hp,slow.bars.hp),"health trail remains equal at 30 and 60 FPS")
	fast.update(.04);var once=fast.smooth("hp",.1)
	check(fast.smooth("hp",.1)==once,"redrawing the same frame does not accelerate health easing")
	fast.update(.1,0)
	check(fast.smooth("hp",.1)==once,"pause freezes health trail")
	var skipped=Motion.new();skipped.smooth("hp",1)
	for n in 30:skipped.update(1.0/30)
	check(is_equal_approx(skipped.smooth("hp",.25),slow.bars.hp),"skipped render frames retain elapsed feedback time")
	game.queue_free();await process_frame
	print("V55 POLISH ",checks," checks ",failures," failures");quit(1 if failures else 0)
