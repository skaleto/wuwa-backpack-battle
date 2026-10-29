extends SceneTree
const C=preload("res://scripts/data/catalog.gd")
const B=preload("res://scripts/battle/battle.gd")
var checks=0
var failures=0
var battle=B.new()

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL V60: ",label)

func near(actual: float,expected: float,label: String) -> void:
	check(absf(actual-expected)<.0001,label+" (got %.4f, expected %.4f)"%[actual,expected])

func build(items: Array=[],primary: String="") -> Dictionary:
	return {"leader":"jiyan","round":1,"items":items,"primary":primary,"supports":[],"bags":[],"roster":[]}

func piece(kind: String,uid: String="",x: int=0,y: int=0) -> Dictionary:
	return {"kind":kind,"uid":uid if not uid.is_empty() else kind,"x":x,"y":y,"rotation":0,"level":0,"tuning":""}

func fixture(kind: String,tags: Array,actions: Array,activation: String="cooldown",cooldown: float=100.0,star: Dictionary={},special: Dictionary={}) -> void:
	C.items[kind]={"name":kind,"tags":tags,"shape":[[0,0]],"stars":[],"target":"attack","element":"neutral","weapon_type":"broadblade","damage":0.0,"heal":0.0,"stamina":0.0,"cooldown":cooldown,"v60":{"active":true,"activation":activation,"actions":actions,"star":star,"special":special}}
	for action in actions:
		if action.type in ["damage","heal"]:C.items[kind][action.type]+=float(action.value)

func setup_fixtures() -> void:
	fixture("v_weapon",["weapon","attack"],[{"type":"damage","value":10},{"type":"charge","value":1}])
	fixture("v_echo",["echo","attack"],[{"type":"damage","value":3}])
	fixture("v_healer",["echo","heal"],[{"type":"heal","value":5}])
	fixture("v_guard",["relic","shield"],[{"type":"shield","value":5}])
	fixture("v_star",["relic"],[],"none",0,{"event":"attack","actions":[{"type":"charge","value":1}],"interval":2.0,"family":"charge_family"})
	C.items.v_star.stars=[[0,1],[1,1]]
	fixture("v_heal_star",["relic"],[],"none",0,{"event":"heal","actions":[{"type":"shield","value":3}],"interval":0.0,"family":"healing_family"})
	C.items.v_heal_star.stars=[[0,1]];C.items.v_heal_star.target="heal"
	fixture("v_shield_star",["relic"],[],"none",0,{"event":"shield","actions":[{"type":"damage","value":9}],"interval":0.0,"family":"shield_family"})
	C.items.v_shield_star.stars=[[0,1]];C.items.v_shield_star.target="relic"
	fixture("v_multi",["echo","attack"],[{"type":"damage","value":3},{"type":"damage","value":3}])
	fixture("v_status",["relic"],[{"type":"noise","value":2},{"type":"frost","value":2}])
	fixture("v_cleanse",["relic"],[{"type":"cleanse","value":1}])
	fixture("v_breaker",["weapon","attack"],[{"type":"damage","value":4},{"type":"break_shield","value":8}])
	fixture("v_counter",["relic"],[],"none",0,{}, {"shield_counter":{"damage":3,"interval":1.5}})
	fixture("v_open",["consumable"],[{"type":"max_hp","value":10},{"type":"charge","value":6}],"opening")
	fixture("v_hp",["consumable","heal"],[{"type":"heal","value":20}],"hp50")
	fixture("v_hp60",["consumable","shield"],[{"type":"shield","value":6}],"hp60")
	fixture("v_stamina",["consumable"],[{"type":"stamina","value":4}],"stamina3")
	fixture("v_debuff",["consumable"],[{"type":"cleanse","value":2}],"first_debuff")
	fixture("v_time",["consumable"],[{"type":"haste","value":3}],"time6")
	fixture("v_discount",["consumable"],[{"type":"stamina_discount","value":.2}],"opening")

func activate(ctx: Dictionary,side: int,item: Dictionary,time: float=0.0) -> void:
	battle.activate(ctx,side,item,time,true,"attack")
	battle.commit_pending(ctx,time)

func advance(ctx: Dictionary,end: float) -> void:
	while float(ctx.time)+.00001<end:
		battle.step(ctx,minf(end,float(ctx.time)+.1))

func events(ctx: Dictionary,kind: String,uid: String="") -> Array:
	return ctx.events.filter(func(ev):return ev.kind==kind and (uid.is_empty() or ev.uid==uid))

func test_charge() -> void:
	var w=piece("v_weapon","main");var secondary=piece("v_weapon","secondary");var echo=piece("v_echo")
	var ctx=battle.begin(build([w,secondary,echo],"main"),build())
	ctx.states[0].charge=6
	activate(ctx,0,echo)
	check(ctx.states[0].charge==6,"echo never consumes charge")
	activate(ctx,0,secondary)
	check(ctx.states[0].charge==6,"secondary weapon never consumes charge")
	activate(ctx,0,w)
	near(events(ctx,"attack","main")[0].value,18,"primary ordinary attack consumes six for 80 percent base bonus")
	check(ctx.states[0].charge==1,"root grants charge only after checking charge at attack start")
	check(events(ctx,"heavy","main").size()==1,"charge attack emits truthful heavy cue once")
	ctx.states[0].charge=5
	activate(ctx,0,w,1)
	near(events(ctx,"attack","main")[-1].value,10,"sixth charge gained by attack cannot empower same attack")
	battle.activate(ctx,0,w,2,false,"derived");battle.commit_pending(ctx,2)
	check(ctx.states[0].charge==6,"derived weapon action cannot consume charge")
	near(battle.weapon_damage_weight(ctx,0,secondary),.5,"secondary weapon retains reserve damage weight")

func test_star_roots() -> void:
	var source=piece("v_star");var w=piece("v_weapon","main",0,1)
	C.items.v_weapon.shape=[[0,0],[1,0]]
	var ctx=battle.begin(build([source,w],"main"),build())
	activate(ctx,0,w)
	check(ctx.states[0].charge==2,"one covered root grants its own and star charge")
	check(events(ctx,"star_trigger").size()==1,"same target on multiple stars triggers once")
	var ev=events(ctx,"star_trigger")[0]
	check(ev.source_uid==source.uid and ev.trigger_uid==w.uid,"star event identifies source and triggering target")
	activate(ctx,0,w,1)
	check(events(ctx,"star_trigger").size()==1,"fixed star ICD is independent of repeated roots")
	activate(ctx,0,w,2)
	check(events(ctx,"star_trigger").size()==2,"star reopens exactly at its fixed interval")
	var remote=piece("v_weapon","remote",5,4)
	ctx=battle.begin(build([source,remote],"remote"),build());activate(ctx,0,remote)
	check(events(ctx,"star_trigger").is_empty(),"remote matching capability never triggers")
	var heal=piece("v_healer","heal",0,1)
	ctx=battle.begin(build([source,heal]),build());ctx.states[0].hp=80;activate(ctx,0,heal)
	check(events(ctx,"star_trigger").is_empty(),"covered mismatching capability never triggers")
	var source2=piece("v_star","star2",1,0)
	ctx=battle.begin(build([source,source2,w],"main"),build());activate(ctx,0,w)
	check(events(ctx,"star_trigger").size()==1,"same-family source copies share one cooldown")
	var multi=piece("v_multi","multi",0,1)
	ctx=battle.begin(build([source,multi]),build());activate(ctx,0,multi)
	check(events(ctx,"attack","multi").size()==2 and events(ctx,"star_trigger").size()==1,"multihit activation publishes one attack root")
	C.items.v_weapon.shape=[[0,0]]

func test_effective_events() -> void:
	var healer=piece("v_healer","heal",0,2);var source=piece("v_heal_star","heal_star",0,1);var chained=piece("v_shield_star","chain",0,0)
	var ctx=battle.begin(build([healer,source,chained]),build())
	activate(ctx,0,healer)
	check(events(ctx,"star_trigger").is_empty(),"full HP ordinary heal publishes no effective heal event")
	ctx.states[0].hp=100;activate(ctx,0,healer,1)
	near(ctx.totals[0].heal,2,"healing reports only effective recovery")
	near(ctx.states[0].shield,3,"effective root heal triggers linked shield")
	check(events(ctx,"star_trigger").size()==1,"derived shield cannot recursively trigger damage source")
	near(ctx.states[1].hp,102,"no derived effect loop reaches opponent")
	var guard=piece("v_guard","guard",0,1)
	ctx=battle.begin(build([chained,guard]),build());ctx.states[0].shield=40.8;activate(ctx,0,guard)
	check(events(ctx,"star_trigger").is_empty(),"zero actual shield gain publishes no shield event")

func test_status_timing() -> void:
	var weapon=piece("v_weapon","main");var echo=piece("v_echo")
	C.items.v_weapon.cooldown=2;C.items.v_echo.cooldown=2
	var ctx=battle.begin(build([weapon,echo],"main"),build())
	ctx.states[0].haste=6;ctx.states[0].haste_until=6;ctx.states[0].frost=2;ctx.states[0].frost_until=8
	advance(ctx,1)
	near(ctx.progress[0].main,.5*1.24*.92,"weapon haste and frost combine multiplicatively")
	near(ctx.progress[0].v_echo,.5*1.24,"echo haste ignores frost")
	var snapshot=battle.frame(1,ctx)
	near(snapshot.cooldown_fractions[0].main,ctx.progress[0].main,"frame carries true integrated progress")
	ctx=battle.begin(build([weapon,echo],"main"),build());ctx.states[0].freeze_until=.6;ctx.states[0].frost_immune_until=3.6
	advance(ctx,.6)
	near(ctx.progress[0].main,0,"freeze fully pauses weapon progress for 0.6 seconds")
	near(ctx.progress[0].v_echo,.3,"freeze never pauses echoes")
	advance(ctx,.7);near(ctx.progress[0].main,.05,"weapon resumes after freeze")
	C.items.v_weapon.cooldown=100;C.items.v_echo.cooldown=100
	fixture("v_haste",["relic"],[{"type":"haste","value":5}])
	var haste=piece("v_haste");ctx=battle.begin(build([haste]),build());activate(ctx,0,haste)
	activate(ctx,0,haste,5)
	check(ctx.states[0].haste==6 and ctx.states[0].haste_until==11,"haste caps at six and refreshes all stacks for six seconds")
	near(events(ctx,"haste")[-1].value,1,"capped haste cue reports actual gained stacks")
	advance(ctx,10.9);check(ctx.states[0].haste==6,"refreshed haste remains before expiry")
	advance(ctx,11);check(ctx.states[0].haste==0,"haste expires at refreshed deadline")

func test_debuffs_and_cleanse() -> void:
	var source=piece("v_status");var cleanser=piece("v_cleanse")
	var ctx=battle.begin(build([source]),build([cleanser]))
	activate(ctx,0,source)
	check(ctx.states[1].noise==2 and ctx.states[1].frost==2,"ordinary status root applies enemy stacks")
	near(ctx.states[1].hp,100,"each successful frost layer deals one damage")
	activate(ctx,1,cleanser)
	check(ctx.states[1].noise==2 and ctx.states[1].frost==1,"cleanse resolves equal stacks in favor of frost")
	activate(ctx,1,cleanser)
	check(ctx.states[1].noise==1 and ctx.states[1].frost==1,"repeated cleanse reevaluates the larger stack count")
	ctx.states[1].frost=4;ctx.states[1].noise=0
	activate(ctx,0,source,1)
	check(ctx.states[1].frost==0,"fifth frost clears stacks immediately")
	near(ctx.states[1].freeze_until,1.6,"fifth frost freezes weapons for 0.6 seconds")
	check(events(ctx,"freeze")[-1].stacks==1,"freeze event explicitly marks active frozen status")
	near(ctx.states[1].frost_immune_until,4.6,"freeze is followed by three seconds of frost immunity")
	var hp=ctx.states[1].hp
	activate(ctx,0,source,2);near(ctx.states[1].hp,hp,"frost during immunity fails without damage")
	activate(ctx,1,cleanser,1.2);near(ctx.states[1].freeze_until,1.6,"cleanse does not undo existing freeze")
	fixture("v_noise",["relic"],[{"type":"noise","value":2}]);var noise=piece("v_noise")
	ctx=battle.begin(build([noise]),build());activate(ctx,0,noise)
	advance(ctx,1.9);activate(ctx,0,noise,1.9)
	near(ctx.states[1].noise_next,2,"noise refresh preserves next fixed tick")
	advance(ctx,2);near(ctx.states[1].hp,98,"noise tick deals current stacks on original beat")
	near(ctx.states[1].noise_until,13.9,"noise refresh extends duration to twelve seconds")
	ctx.states[1].shield=5;advance(ctx,4)
	near(ctx.states[1].shield,1,"noise damage hits shield first")
	near(ctx.states[1].hp,98,"shield absorbs noise tick HP damage")
	activate(ctx,0,noise,4);activate(ctx,0,noise,4)
	check(ctx.states[1].noise==6,"noise caps at six")

func test_shield_breaker() -> void:
	var breaker=piece("v_breaker","main");var counter=piece("v_counter")
	var ctx=battle.begin(build([breaker],"main"),build([counter]))
	ctx.states[1].shield=3
	activate(ctx,0,breaker)
	near(ctx.states[1].hp,98,"shield removal occurs before damage and excess never reaches HP")
	near(ctx.states[0].hp,102,"shield removal alone never triggers shield counter")
	near(events(ctx,"break_shield")[0].value,3,"shield removal event reports actual removed shield")
	ctx.states[1].shield=20
	activate(ctx,0,breaker,2)
	near(ctx.states[1].shield,8,"regular damage follows exact shield removal")
	near(ctx.states[0].hp,99,"regular shield damage triggers one derived counter")
	check(events(ctx,"counter").size()==1,"shield counter cannot recurse")

func test_supplies() -> void:
	var items=[piece("v_open"),piece("v_hp"),piece("v_hp60"),piece("v_stamina"),piece("v_debuff"),piece("v_time"),piece("v_discount")]
	var ctx=battle.begin(build(items),build())
	near(ctx.states[0].max_hp,112,"opening supply increases maximum HP once")
	near(ctx.states[0].hp,112,"opening max HP also fills granted maximum")
	check(ctx.states[0].charge==6 and ctx.used[0].has("v_open"),"opening supply consumes exactly once")
	ctx.states[0].hp=40;ctx.states[0].stamina=1
	battle.step(ctx,.1)
	near(ctx.states[0].hp,60,"HP threshold supply heals once")
	near(ctx.states[0].shield,6,"hp60 supply rechecks current threshold after earlier healing")
	near(ctx.states[0].stamina,5.2,"stamina threshold supply restores after normal regeneration")
	check(ctx.used[0].has("v_hp") and ctx.used[0].has("v_hp60") and ctx.used[0].has("v_stamina"),"threshold supplies are recorded as consumed")
	ctx.states[0].hp=40;battle.step(ctx,.2);near(ctx.states[0].hp,40,"consumed supply cannot trigger twice")
	var status=piece("v_status");activate(ctx,1,status,.2);battle.step(ctx,.3)
	check(ctx.used[0].has("v_debuff"),"first debuff triggers cleansing supply once")
	advance(ctx,6)
	check(ctx.used[0].has("v_time") and ctx.states[0].haste==3,"time6 supply consumes exactly at six seconds")
	near(ctx.states[0].stamina_discount,.2,"opening ration sets fractional stamina discount")
	fixture("v_double",["echo","attack"],[{"type":"damage","value":60},{"type":"damage","value":50}])
	var attacker=piece("v_double")
	ctx=battle.begin(build([attacker]),build([piece("v_hp")]))
	activate(ctx,0,attacker)
	near(ctx.states[1].hp,12,"HP supply activates between successive damage events once threshold is crossed")
	ctx=battle.begin(build([piece("v_status")]),build([piece("v_debuff")]))
	activate(ctx,0,piece("v_status"))
	check(ctx.states[1].noise==0 and ctx.states[1].frost==2,"first debuff supply reacts to first application before subsequent status actions")

func test_replay_and_symmetry() -> void:
	C.items.v_weapon.cooldown=2;C.items.v_weapon.damage=200;C.items.v_weapon.v60.actions=[{"type":"damage","value":200}]
	var w=piece("v_weapon","main");var a=build([w],"main")
	var one=battle.simulate(a,a,71);var two=battle.simulate(a,a,71)
	check(one==two,"same input and seed reproduce entire replay")
	check(one.winner==0,"simultaneous lethal root attacks resolve to mirrored draw")
	near(one.duration,2,"simultaneous lethal activation happens after exact cooldown")
	for key in ["winner","duration","frames","events","totals","used","seed"]:check(one.has(key),"replay preserves "+key)
	check(one.frames[-1].sides[0].hp==0 and one.frames[-1].sides[1].hp==0,"both actor plans commit before death decision")
	var minimal=battle.simulate(a,a,71,false)
	check(minimal.frames.size()==2 and minimal.events==one.events,"capture flag preserves battle and initial/final frame contract")
	check(one.events.all(func(ev):return not ev.get("resources",true)),"disabled energy and concerto never generate hidden resources")

func test_specials_and_openings() -> void:
	fixture("v_plain",["weapon","attack"],[{"type":"damage","value":10}])
	var w=piece("v_plain","main");w.level=4;w.tuning="strong"
	var ctx=battle.begin(build([w],"main"),build());activate(ctx,0,w)
	near(events(ctx,"attack","main")[0].value,10,"legacy tuning and level cannot amplify V60 item numbers")
	C.characters.v_leader={"weapon_type":"broadblade","element":"fusion","v60_opening":[{"type":"charge","value":2},{"type":"haste","value":2},{"type":"max_hp","value":8}]}
	var leader_build=build();leader_build.leader="v_leader"
	ctx=battle.begin(leader_build,build())
	check(ctx.states[0].charge==2 and ctx.states[0].haste==2,"character explicit opening actions seed V60 statuses")
	near(ctx.states[0].max_hp,110,"character max HP opening changes maximum")
	near(ctx.states[0].hp,110,"character max HP opening changes current HP equally")
	fixture("v_strike",["echo","attack"],[{"type":"damage","value":6}],"cooldown",100,{}, {"shield_strike":{"consume":8,"multiplier":1.5}})
	var strike=piece("v_strike");ctx=battle.begin(build([strike]),build());ctx.states[0].shield=10
	activate(ctx,0,strike)
	near(ctx.states[0].shield,2,"shield strike consumes at most eight shield")
	near(events(ctx,"attack")[0].value,18,"shield strike adds exactly consumed shield times multiplier")
	fixture("v_eater",["weapon","attack"],[{"type":"damage","value":10}],"cooldown",100,{}, {"noise_consume":{"max_layers":2,"damage_per_layer":6,"requires_charge":true}})
	var eater=piece("v_eater","main");ctx=battle.begin(build([eater],"main"),build());ctx.states[1].noise=3
	activate(ctx,0,eater)
	check(ctx.states[1].noise==3,"noise eater requires charged primary activation")
	ctx.states[0].charge=6;activate(ctx,0,eater,1)
	check(ctx.states[1].noise==1,"charged noise eater consumes at most two layers")
	near(events(ctx,"derived")[-1].value,12,"noise eater derives six damage per consumed layer")
	fixture("v_threshold",["weapon","attack"],[{"type":"damage","value":10},{"type":"haste","value":1}],"cooldown",100,{}, {"haste_damage":{"min_stacks":6,"value":2},"haste_stamina":{"min_stacks":4,"multiplier":.8},"low_hp_damage":{"threshold":.35,"value":6}})
	var threshold=piece("v_threshold","main");C.items.v_threshold.stamina=2
	ctx=battle.begin(build([threshold],"main"),build());ctx.states[0].haste=5
	activate(ctx,0,threshold)
	near(events(ctx,"attack")[-1].value,10,"haste bonus checks stacks before own grant")
	ctx.states[1].hp=30;activate(ctx,0,threshold,1)
	near(events(ctx,"attack")[-1].value,18,"preexisting haste and low HP independently add exact bonuses")
	ctx.states[0].stamina_discount=.15
	near(battle.stamina_cost(ctx,0,threshold),2*.85*.8,"haste stamina multiplier combines with nonstacking ration discount")
	fixture("v_contract",["relic"],[],"cooldown",6,{}, {"haste_derived":{"min_stacks":4,"value":3}})
	var contract=piece("v_contract","contract",0,1);var source=piece("v_star")
	ctx=battle.begin(build([contract,source]),build());ctx.states[0].haste=4
	activate(ctx,0,contract)
	check(events(ctx,"derived","contract").size()==1 and events(ctx,"attack","contract").is_empty(),"contract follower deals derived damage without becoming ordinary attack")
	check(events(ctx,"star_trigger").is_empty(),"contract derived hit does not feed attack stars")
	fixture("v_flower",["relic","shield"],[{"type":"shield","value":3}],"cooldown",6,{"event":"self","actions":[],"interval":0.0,"family":"flower"},{"matched_healer_shield":{"per_item":1,"max_items":2}})
	C.items.v_flower.v60.erase("star")
	C.items.v_flower.target="heal";C.items.v_flower.stars=[[0,1],[1,1],[2,1]]
	var flower=piece("v_flower")
	ctx=battle.begin(build([flower,piece("v_healer","h1",0,1),piece("v_healer","h2",1,1),piece("v_healer","h3",2,1)]),build());activate(ctx,0,flower)
	near(ctx.states[0].shield,5,"flower adds one per matched healer with maximum of two")
	check(events(ctx,"star_trigger").size()==1,"flower static star benefit emits one self root cue")
	ctx=battle.begin(build([piece("v_hp","hp1"),piece("v_hp","hp2")]),build());ctx.states[0].hp=40;battle.step(ctx,.1)
	check(ctx.used[0].size()==1 and ctx.states[0].hp==60,"duplicate threshold supplies recheck after each actual heal")
	ctx=battle.begin(build(),build());ctx.states[1].haste=2;ctx.states[1].haste_until=.1;battle.step(ctx,.1)
	var expired=events(ctx,"haste")[-1]
	check(expired.target_side==1,"side one haste expiry cue targets the actual owner")
	C.characters.erase("v_leader")

func test_simultaneous_heal_condition_and_stamina_spend() -> void:
	var dream=piece("dreamless","dream");var turtle=piece("turtle","turtle")
	var team=build([dream,turtle])
	var ctx=battle.begin(team,team)
	for side in range(2):
		ctx.states[side].hp=34
		ctx.progress[side].dream=1
		ctx.progress[side].turtle=1
	battle.step(ctx,.1)
	var hits=events(ctx,"attack","dream")
	near(hits[0].value,20,"side zero low-HP bonus uses shared pre-tick enemy HP")
	near(hits[1].value,20,"side one low-HP bonus ignores other actor planning heals")
	near(ctx.states[0].hp,ctx.states[1].hp,"mirrored heal and low-HP attacks remain symmetric")
	near(ctx.totals[0].heal,4,"snapshot preserves actual ordinary healing on side zero")
	near(ctx.totals[1].heal,4,"snapshot preserves actual ordinary healing on side one")
	var w1=piece("w_broadblade","w1");var w2=piece("w_broadblade","w2");var w3=piece("w_broadblade","w3")
	ctx=battle.begin(build([w1,w2,w3,piece("soup")],"w1"),build())
	ctx.states[0].stamina=3
	for uid in ["w1","w2","w3"]:ctx.progress[0][uid]=1
	battle.step(ctx,.1)
	check(events(ctx,"attack").size()==3,"soup restores stamina after first spend before later ready weapons")
	check(events(ctx,"tired").is_empty(),"same-tick soup prevents false stamina wait cues")
	check(ctx.used[0].has("soup"),"first below-three stamina crossing consumes soup")
	near(ctx.states[0].stamina,3.2+4-3*float(C.items.w_broadblade.stamina),"same-tick regeneration, spend and soup reserve are exact")

func test_native_noise_consume_after_primary_hit() -> void:
	var weapon=piece("weapon_21010044","main")
	var ctx=battle.begin(build([weapon],"main"),build([piece("salt_tea")]))
	ctx.states[0].charge=6;ctx.states[1].hp=64;ctx.states[1].noise=1
	activate(ctx,0,weapon)
	near(ctx.states[1].hp,45.856,"charged native ordinary hit precedes noise-consume damage and emergency shield")
	near(ctx.states[1].shield,2,"salt tea shields the subsequent six noise-consume damage")
	check(ctx.states[1].noise==0 and ctx.used[1].has("salt_tea"),"native noise consumption and emergency supply happen once")
	var primary_order=int(events(ctx,"attack","main")[0].order)
	var consume_order=int(events(ctx,"derived","main")[0].order)
	check(primary_order<consume_order,"replay orders ordinary hit before noise-consume derived hit")

func test_frost_expiry_and_integrated_progress() -> void:
	fixture("v_frost_one",["relic"],[{"type":"frost","value":1}])
	var source=piece("v_frost_one")
	var ctx=battle.begin(build([source]),build())
	activate(ctx,0,source)
	check(ctx.states[1].has("frost_until"),"frost stores its refreshed eight-second expiry")
	near(float(ctx.states[1].get("frost_until",0)),8,"first successful frost application lasts eight seconds")
	advance(ctx,7)
	activate(ctx,0,source,7)
	near(float(ctx.states[1].get("frost_until",0)),15,"successful frost refresh extends all layers by eight seconds")
	advance(ctx,14.9)
	check(ctx.states[1].frost==2,"refreshed frost layers persist until their deadline")
	advance(ctx,15)
	check(ctx.states[1].frost==0,"all frost layers expire exactly at refreshed deadline")
	check(battle.frame(15,ctx).sides[1].statuses.all(func(v):return v.id!="frost"),"expired frost leaves replay status list")
	ctx=battle.begin(build([source]),build());activate(ctx,0,source);advance(ctx,9)
	check(ctx.states[1].frost==0,"unrefreshed frost is absent after eight seconds")
	var weapon=piece("v_weapon","main")
	ctx=battle.begin(build([weapon],"main"),build())
	ctx.states[0].haste=6;ctx.states[0].haste_until=.03
	ctx.states[0].frost=2;ctx.states[0].frost_until=.06
	battle.step(ctx,.1)
	var expected=(.03*1.24*.92+.03*.92+.04)/100.0
	near(ctx.progress[0].main*100,expected*100,"progress splits haste and frost expiry boundaries within one tick")
	check(ctx.states[0].frost==0,"partial-interval expiry clears stack state for next tick")

func test_native_catalogue() -> void:
	for kind in C.items.keys():
		if str(kind).begins_with("v_"):C.items.erase(kind)
	var leaders=["aemeath","hsin","suisui","qingxiao","lu_hers","yangyang_xuanling"]
	for leader in leaders:
		check(C.characters.has(leader),"native catalogue contains new leader "+leader)
		var team=build();team.leader=leader
		var ctx=battle.begin(team,build())
		for action in C.characters[leader].get("v60_opening",[]):
			var key=str(action.type)
			if key=="max_hp":near(ctx.states[0].max_hp,102+float(action.value),leader+" has exact published opening health")
			else:near(ctx.states[0][key],float(action.value),leader+" has exact published opening "+key)
	for kind in ["whiff","whiff_fast"]:
		check(C.items[kind].v60.actions.filter(func(a):return a.type=="damage").size()==2,kind+" preserves two hits within one root")
	var weapon=piece("w_broadblade","main");var ration=piece("rations")
	var ctx=battle.begin(build([weapon,ration],"main"),build())
	near(battle.stamina_cost(ctx,0,weapon),float(C.items.w_broadblade.stamina)*.85,"native ration grants fifteen percent weapon discount")
	var flower=piece("flower");var healer=piece("turtle","healer")
	var location=battle.inventory.stars(flower)[0]
	healer.x=location.x;healer.y=location.y
	ctx=battle.begin(build([flower,healer]),build());activate(ctx,0,flower)
	near(ctx.states[0].shield,4,"native flower applies standalone matched healer special")
	var sample=battle.inventory.new_run("aemeath",83)
	var opponent=battle.inventory.new_run("hsin",97)
	var result=battle.simulate(sample,opponent,301)
	check(result.duration>0 and result.duration<=45,"native starter inventories simulate through actual public bridge")
	check(result.events.any(func(ev):return ev.kind=="attack"),"native starter replay contains real attacks")
	check(result.events.all(func(ev):return ev.kind not in ["burst","relay","intro","outro"]),"native starter battle has no old burst or concerto callbacks")

func _initialize() -> void:
	setup_fixtures()
	var ctx=battle.begin(build(),build(),7)
	for key in ["charge","haste","noise","frost"]:check(ctx.states[0].has(key),"battle owns "+key+" state")
	check(battle.frame(0,ctx).has("cooldown_fractions"),"replay exposes actual cooldown progress")
	if not battle.has_method("activate") or not battle.has_method("step"):
		check(false,"ordinary roots and timed battle steps execute V60 rules")
	else:
		test_charge();test_star_roots();test_effective_events();test_status_timing();test_debuffs_and_cleanse();test_shield_breaker();test_supplies();test_specials_and_openings();test_simultaneous_heal_condition_and_stamina_spend();test_native_noise_consume_after_primary_hit();test_frost_expiry_and_integrated_progress();test_replay_and_symmetry();test_native_catalogue()
	print("BATTLE_V60: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
