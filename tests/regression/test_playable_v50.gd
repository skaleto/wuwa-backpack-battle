extends SceneTree
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const B=preload("res://scripts/battle/battle.gd")
const E=preload("res://scripts/battle/resonance_effects.gd")
const F=preload("res://scripts/crafting/craft.gd")
const S=preload("res://scripts/storage/storage.gd")
const PB=preload("res://scripts/shop/practice_budget.gd")
var inv=I.new()
var engine=B.new()
var checks=0
var failures=0
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func piece(kind:String,uid:String,x:int,y:int)->Dictionary:
	var p=inv.make_piece(kind,uid);p.x=x;p.y=y;return p
func build(weapon:String="w_rectifier",echo:String="whiff",leader:String="encore")->Dictionary:
	var r=inv.new_run(leader,50);r.round=2;r.items=[piece(weapon,"i1",0,0),piece(echo,"i2",2,0)];r.primary="i1";r.serial=2
	r.bags=[piece("satchel","b1",0,0),piece("satchel","b2",3,0)];return r
func marked(weapon:String="w_rectifier",echo:String="whiff",leader:String="encore")->Dictionary:
	var ctx=engine.begin(build(weapon,echo,leader),build(),50)
	ctx.states[0].resonance.weapons.i1.marks=2;ctx.states[0].resonance.weapons.i1.mark_until=9.0;return ctx
func chases(ctx:Dictionary)->Array:return ctx.events.filter(func(v):return v.kind=="coordinated" and v.side==0)
func _initialize():
	triggers();advance();crafting();compatibility()
	print("V50 RULES: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
func triggers():
	for missing in [0.0,10.0]:
		var ctx=marked("w_rectifier","turtle");ctx.states[0].hp-=missing
		engine.activate(ctx,0,ctx.queues[0][1],4,true,"attack")
		check(chases(ctx).is_empty() and ctx.states[0].resonance.weapons.i1.marks==2,"turtle never consumes marks; missing HP "+str(missing))
		check(ctx.totals[0].heal==minf(4,missing),"actual turtle heal "+str(missing))
		check((ctx.totals[0].energy_generated>0)==(missing>0),"only nonzero heal generates resources")
	var ctx=marked("w_rectifier","violet");engine.activate(ctx,0,ctx.queues[0][1],4,true,"attack")
	check(chases(ctx).is_empty() and ctx.states[0].resonance.weapons.i1.marks==2,"violet block preparation does not chase")
	for kind in ["copy","counter","coordinated"]:
		ctx=marked();engine.activate(ctx,0,ctx.queues[0][1],4,false,kind)
		check(chases(ctx).size()==(2 if kind=="coordinated" else 0) and ctx.states[0].resonance.weapons.i1.marks==2,"derived "+kind+" does not clear marks")
	ctx=marked();ctx.states[1].shield=999
	engine.activate(ctx,0,ctx.queues[0][1],4,true,"attack")
	check(chases(ctx).size()==1,"whiff two hits cause one chase even against shield")
	check(ctx.events.filter(func(v):return v.kind=="attack" and v.uid=="i2").size()==2,"whiff still deals two ordinary hits")
	var hit=chases(ctx)[0]
	check(hit.get("source_uid","")=="i1" and hit.get("trigger_uid","")=="i2" and hit.get("consumed_marks",0)==2,"chase carries source, trigger, and consumed marks")
	check(ctx.totals[0].energy_generated==4 and not hit.resources,"chase adds no resources")
	ctx.states[0].resonance.weapons.i1.marks=1
	engine.activate(ctx,0,ctx.queues[0][1],6.9,true,"attack")
	check(chases(ctx).size()==1 and ctx.states[0].resonance.weapons.i1.marks==1,"ICD retains marks")
	engine.activate(ctx,0,ctx.queues[0][1],7,true,"attack")
	check(chases(ctx).size()==2,"ICD opens at exactly 3 seconds")
	ctx=marked();E.tick(engine,ctx,9.0);engine.activate(ctx,0,ctx.queues[0][1],9,true,"attack")
	check(chases(ctx).is_empty() and ctx.states[0].resonance.weapons.i1.marks==0,"marks expire at six second boundary")
	ctx=marked("w_rectifier","bellborne");engine.activate(ctx,0,ctx.queues[0][1],4,true,"attack")
	check(chases(ctx).size()==1 and ctx.states[0].bell_charges==3,"bell ordinary attack plus block preparation chases once")
	ctx.states[0].resonance.weapons.i1.marks=1
	engine.add_hit(ctx,1,ctx.queues[1][0],3,4.1,true)
	check(chases(ctx).size()==1 and ctx.states[0].resonance.weapons.i1.marks==1,"later incoming hit/block cannot clear marks")
	ctx=marked("w_rectifier","whiff","yinlin");ctx.states[0].resonance.yinlin_until=8
	engine.activate(ctx,0,ctx.queues[0][1],4,true,"attack")
	hit=chases(ctx)[0]
	check(hit.get("contributions",{}).get("leader:yinlin",0)==4 and hit.get("contributions",{}).get("weapon:i1",0)>0,"leader bonus is separately attributed")
	check(ctx.totals[0].damage_by_uid.get("leader:yinlin",0)==4,"leader contribution is not charged to weapon output total")
	ctx=marked();check(engine.frame(4,ctx).get("weapon_marks",[{},{}])[0].get("i1",0)==2,"replay exposes per-weapon marks for honest item cues")
func advance():
	for ready in [8.0,4.3]:
		var ctx=marked("weapon_21050044");ctx.timers[0].i2=ready
		engine.activate(ctx,0,ctx.queues[0][1],4,true,"attack")
		var expected=maxf(4+B.STEP,ready-.5)
		check(is_equal_approx(ctx.timers[0].i2,expected),"candidate advances by .5 with STEP floor")
		var events=ctx.events.filter(func(v):return v.kind=="cooldown_advance")
		check(events.size()==1,"one actual cooldown advance event")
		if not events.is_empty():check(is_equal_approx(events[0].old_ready_time,ready) and is_equal_approx(events[0].new_ready_time,expected),"event records actual old/new ready times")
		check(ctx.totals[0].energy_generated==4 and chases(ctx).size()==1,"advance creates neither hit nor resources")
	var ctx=marked("weapon_21050044","whiff","yinlin");ctx.states[0].resonance.weapons.i1.marks=0;ctx.states[0].resonance.yinlin_until=8;ctx.timers[0].i2=8.0
	engine.activate(ctx,0,ctx.queues[0][1],4,true,"attack")
	check(ctx.timers[0].i2==8 and ctx.events.all(func(v):return v.kind!="cooldown_advance"),"leader-only chase does not advance Jinzhou timer")
	check(chases(ctx)[0].source_uid=="leader:yinlin" and chases(ctx)[0].uid=="leader:yinlin","leader-only chase does not flash or credit the weapon as its source")
	var fight=engine.simulate(build("weapon_21050044"),build(),50)
	var roots=fight.events.filter(func(v):return v.kind=="trigger" and v.side==0 and v.uid=="i2" and v.resources)
	check(roots.size()>1 and is_equal_approx(roots[1].time-roots[0].time,3.5),"actual simulator next ordinary whiff is 3.5 seconds later")
func crafting():
	var r=build();r.items.append(piece("mat_43020031","i3",2,1));r.serial=3
	var before=r.duplicate(true)
	var f=F.new();var methods=f.get_method_list().filter(func(v):return v.name=="preview")
	var explicit=not methods.is_empty() and methods[0].args.size()==5
	check(explicit,"craft preview accepts explicit output placement")
	if not explicit:return
	var bad=f.call("transact",r,"weapon_21050044","i1",inv,{"x":2,"y":0,"rotation":0})
	check(not bad.ok and r==before,"chosen collision never falls back and changes nothing")
	bad=f.call("transact",r,"weapon_21050044","i1",inv,{"x":7,"y":5,"rotation":0})
	check(not bad.ok and r==before,"out of board chosen footprint atomic failure")
	var preview=f.call("preview",r,"weapon_21050044","i1",inv,{"x":0,"y":0,"rotation":0})
	check(preview.ok and r==before,"cancelling pure preview preserves complete run")
	if not preview.ok:return
	check(inv.adjacent(r.items[0],r.items[1]) and inv.adjacent(preview.output,r.items[1]),"square upgrade retains actual edge adjacency")
	var echo=r.items[1].duplicate(true);echo.x=3
	check(not inv.adjacent(preview.output,echo),"moving echo away removes adjacency")
	var outcome=f.call("transact",r,"weapon_21050044","i1",inv,{"x":0,"y":0,"rotation":0})
	check(outcome.ok and r.items.size()==2 and r.serial==4 and r.gold==before.gold and r.primary==outcome.output.uid,"explicit commit consumes once and inherits primary")
	r=build();r.items[0].kind="weapon_21050023";r.items.append(piece("mat_43020031","i3",2,1));r.serial=3
	check(not F.preview(r,"weapon_21050044","i1",inv).ok,"Jinzhou requires named Liuguang base")
	var recipe=C.combinations.filter(func(v):return v.target=="weapon_21050044")[0]
	r.items.pop_back()
	check(PB.prepare_upgrade(inv,r,recipe,r.items[0],false).is_empty(),"practice crafting cannot bypass named base restriction")
func compatibility():
	var r=inv.new_run("encore",50);var ghost=inv.snapshot(r,"qa-v50")
	check(ghost.get("simulation_version","")==C.SIMULATION_VERSION,"snapshot carries gameplay simulation marker")
	var old=r.duplicate(true);old.erase("simulation_version")
	check(inv.validate_run(old),"old save without marker remains valid")
	var storage=S.new("user://qa-playable-v50-rules")
	storage.save(old);check(not storage.resume().is_empty(),"old save resumes through isolated storage")
	var incompatible=ghost.duplicate(true);incompatible.owner="legacy";incompatible.simulation_version="resonance-v49"
	storage.write_json(storage.root_path+"ghosts.json",[incompatible])
	check(storage.opponent(r).get("owner","")!="legacy","incompatible ghost excluded from matchmaking")
	var other=ghost.duplicate(true);other.visual_skin="chibi"
	check(inv.snapshot(other,"qa-v50")==ghost,"visual skin never changes gameplay snapshot")
