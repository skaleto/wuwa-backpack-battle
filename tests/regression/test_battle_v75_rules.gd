extends SceneTree
## Historical rules: use the exact V116 catalogue before intentional V124 redesigns.
const HISTORICAL=preload("res://tests/fixtures/catalog_fixture_v116.gd")
const C=preload("res://scripts/data/catalog.gd")
const B=preload("res://scripts/battle/battle.gd")
var b=B.new()
var failures=0
var checks=0
var tested=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL V75 RULE: ",label)
func near(a:float,z:float,label:String)->void:check(absf(a-z)<.002,label+" got %.5f expected %.5f"%[a,z])
func k(name:String)->String:
	for id in C.items:
		if C.items[id].name==name:return id
	return name
func p(name:String,uid:String="")->Dictionary:return {"kind":k(name),"uid":k(name) if uid=="" else uid,"x":0,"y":0,"rotation":0,"level":0,"tuning":""}
func build(items:Array=[],primary:String="")->Dictionary:return {"leader":"jiyan","round":1,"items":items,"primary":primary,"supports":[],"bags":[],"roster":[]}
func attach(source:Dictionary,targets:Array)->Array:
	var cells=b.inventory.stars(source)
	for index in range(targets.size()):targets[index].x=cells[index%cells.size()].x;targets[index].y=cells[index%cells.size()].y
	return [source]+targets
func arena(items:Array,primary:String="",enemies:Array=[])->Dictionary:
	var ctx=b.begin(build(items,primary),build(enemies))
	for side in range(2):
		ctx.states[side].hp=10000.;ctx.states[side].max_hp=10000.;ctx.states[side].shield=0.;ctx.states[side].charge=0;ctx.states[side].haste=0
		for item in ctx.queues[side]:
			if not b.profile(item).is_empty():
				var s=b.own(ctx,side,item)
				for clock in s.clocks:s.clocks[clock]=999.
	return ctx
func advance(ctx:Dictionary,t:float)->void:
	while ctx.time+.000001<t:b.step(ctx,minf(t,ctx.time+.1))
func pulse(ctx:Dictionary,item:Dictionary,charged:bool=false,side:int=0)->float:
	ctx.states[side].charge=6 if charged else 0
	ctx.states[side].stamina=10
	ctx.progress[side][item.uid]=1.
	var prior=ctx.totals[side].damage
	b.step(ctx,ctx.time+.01)
	return ctx.totals[side].damage-prior
func base(item:Dictionary)->float:return float(b.profile(item).damage)
func ev(ctx:Dictionary,kind:String,uid:String="")->Array:return ctx.events.filter(func(e):return e.kind==kind and (uid=="" or e.uid==uid))
func test_openings_and_clocks()->void:
	tested.append("openings_and_clocks")
	var a=p("茶");a=p("tea")
	var descendant=p("星序协响");var ctx=b.begin(build([a,descendant,p("tea","other")]),build())
	near(ctx.states[0].max_hp,117,"tea provenance highest across descendants")
	ctx=b.begin(build([p("nutrition"),p("宙算仪轨")]),build());ctx.states[0].hp=40;b.step(ctx,.1)
	near(ctx.totals[0].heal,18,"one shared inherited emergency")
	ctx.states[0].hp=40;b.step(ctx,.2);near(ctx.totals[0].heal,18,"emergency cannot retrigger")
	ctx.states[0].hp=0;b.step(ctx,.3);near(ctx.states[0].hp,0,"no revival")
	var dragon=p("龙抬头");ctx=b.begin(build([dragon]),build());near(ctx.states[0].shield,12,"dragon opening shield")
	ctx.states[0].stamina=1;b.step(ctx,.1);near(ctx.states[0].stamina,5.1,"dragon retains later stamina trigger with V112 recovery")
	var flower=p("flower");ctx=b.begin(build([flower]),build());near(ctx.states[0].shield,0,"salt provenance is threshold not opening")
	ctx.states[0].hp=50;b.step(ctx,.1);near(ctx.states[0].shield,8,"flower threshold eight")
	advance(ctx,6);near(ctx.states[0].shield,11,"flower independent three at six")
	for id in ["medical","turtle","echo_aureate","echo_butterfly","rocksteady","bellborne","weapon_21050036"]:
		var item=p(id);ctx=b.begin(build([item],item.uid),build());ctx.states[0].hp=50;ctx.states[0].haste=6;ctx.states[0].haste_until=100
		var n=b.profile(item);var clock="heal" if n.healPeriod>0 else "shield";var period=float(n[clock+"Period"])
		advance(ctx,period-.1);near(ctx.totals[0][clock],0,id+" full first independent period")
		advance(ctx,period);near(ctx.totals[0][clock],float(n[clock+"Amount"]),id+" exact support amount")
	ctx=b.begin(build([p("medical"),p("rocksteady")]),build());ctx.states[0].shield=ctx.states[0].max_hp*.4;advance(ctx,6)
	near(ctx.totals[0].heal,0,"full HP no actual heal")
	near(ctx.totals[0].shield,0,"capped shield no actual gain")
	check(ev(ctx,"heal").is_empty() and ev(ctx,"shield").is_empty(),"no false support events")
func test_opening_attacks_and_stacks()->void:
	tested.append("opening_attacks_and_stacks")
	for spec in [["暗夜长刃·玄明",8,1],["暗夜臂铠·夜芒",4,2],["暗夜矩阵·暝光",4,2]]:
		var item=p(spec[0]);var ctx=arena([item],item.uid)
		for index in range(4):near(pulse(ctx,item),base(item)+(float(spec[1]) if index<int(spec[2]) else 0),str(spec[0])+" bounded opener "+str(index))
	for spec in [["纹秋",.6,5,6],["不灭航路",.1,3,4],["漪澜浮录",.7,5,6]]:
		var item=p(spec[0]);var ctx=arena([item],item.uid)
		for index in range(7):
			var expected=base(item)*(1+minf(index,spec[2])*spec[1]) if spec[0]=="不灭航路" else base(item)+minf(index,spec[2])*spec[1]
			near(pulse(ctx,item),expected,str(spec[0])+" bounded incremental hit "+str(index))
		ctx.progress[0][item.uid]=0;b.own(ctx,0,item).until=ctx.time+.01;b.step(ctx,ctx.time+.02)
		near(b.own(ctx,0,item).stack,0,str(spec[0])+" stack expiry")
	for name in ["风流的寓言诗","叙别的罗曼史","酩酊的英雄志","大海的馈赠","虚饰的华尔兹"]:
		var item=p(name);var ctx=arena([item],item.uid);pulse(ctx,item)
		near(b.own(ctx,0,item).stack,0,name+" no free condition stack")
		ctx.states[1].noise=1;ctx.states[1].noise_until=100;ctx.states[1].noise_next=100;ctx.states[1].frost=1;ctx.states[1].frost_until=100
		pulse(ctx,item);near(b.own(ctx,0,item).stack,1,name+" preexisting status stack")
	var anchor=p("心之锚");var ctx=arena([anchor],anchor.uid)
	for i in range(5):near(pulse(ctx,anchor),base(anchor),"anchor preparation")
	near(pulse(ctx,anchor),base(anchor)+7,"anchor fifth stack buffs NEXT hit")
	near(b.own(ctx,0,anchor).stack,0,"anchor clears burst")
func test_charged_and_burst_groups()->void:
	tested.append("charged_and_burst_groups")
	for spec in [["浩境粼光",3],["苍鳞千嶂",4]]:
		var item=p(spec[0]);var ctx=arena([item],item.uid)
		near(pulse(ctx,item,true),base(item)*1.8,str(spec[0])+" new stacks not spent same attack")
		near(pulse(ctx,item,true),base(item)*1.8+spec[1],str(spec[0])+" old charged stack")
	for name in ["金掌","容赦的沉思录"]:
		var item=p(name);var ctx=arena([item],item.uid);ctx.states[1].noise=1;ctx.states[1].noise_until=100;ctx.states[1].noise_next=100
		for i in range(3):pulse(ctx,item)
		near(pulse(ctx,item,true),base(item)*1.8+6,name+" consumes three old stacks")
	for spec in [["金穹",2],["翼锋",2],["擎渊怒涛",2],["悲喜剧",2]]:
		var item=p(spec[0]);var ctx=arena([item],item.uid);pulse(ctx,item,true)
		near(pulse(ctx,item),base(item)+spec[1],str(spec[0])+" first ordinary reward")
		near(pulse(ctx,item),base(item)+spec[1],str(spec[0])+" second ordinary reward")
		near(pulse(ctx,item),base(item),str(spec[0])+" ordinary reward exhausted")
	for spec in [["无眠烈火",6],["奔雷",5],["阳焰",5],["相位涟漪",6],["蜃影",6],["碎骨",5]]:
		var item=p(spec[0]);var ctx=arena([item],item.uid)
		for index in range(3):near(pulse(ctx,item),base(item),str(spec[0])+" three prep")
		near(pulse(ctx,item),base(item)+spec[1],str(spec[0])+" next heavy bullet")
		near(pulse(ctx,item),base(item),str(spec[0])+" burst not prep")
	for spec in [["赫奕流明",6,3,4],["曜光",3,2,3]]:
		var item=p(spec[0]);var ctx=arena([item],item.uid)
		for i in range(spec[1]):near(pulse(ctx,item),base(item),str(spec[0])+" prep")
		for i in range(spec[2]):near(pulse(ctx,item),base(item)+spec[3],str(spec[0])+" bounded burst")
		near(pulse(ctx,item),base(item),str(spec[0])+" restart after burst")
	var cut=p("裁春");var ctx=arena([cut],cut.uid)
	for i in range(3):pulse(ctx,cut)
	near(pulse(ctx,cut),base(cut),"spring does not grant free burst without three haste")
	ctx.states[0].haste=3;ctx.states[0].haste_until=100
	var prior=ev(ctx,"attack",cut.uid).size();near(pulse(ctx,cut),base(cut)+14,"spring exact base plus eight three three")
	check(ev(ctx,"attack",cut.uid).size()-prior==3,"spring three hit events")
	near(ev(ctx,"attack",cut.uid)[-2].value,3,"spring second segment exactly three")
	near(ctx.states[0].haste,0,"spring consumes haste before own every-two award when fifth hit")
	near(b.own(ctx,0,cut).get("prep",-1),0,"spring burst cannot prepare itself")
func test_windows_and_conditions()->void:
	tested.append("windows_and_conditions")
	for spec in [["焰痕",.2,4],["凌空",.2,4],["诸方玄枢",.25,4],["清音",.2,5]]:
		var item=p(spec[0]);var ctx=arena([item],item.uid)
		near(pulse(ctx,item,true),base(item)*1.8,str(spec[0])+" trigger not buffed by new window")
		near(pulse(ctx,item),base(item)*(1+spec[1]),str(spec[0])+" active window")
		var s=b.own(ctx,0,item);s.window=ctx.time+.01;b.step(ctx,ctx.time+.02)
		near(pulse(ctx,item,true),base(item)*1.8,str(spec[0])+" lockout no immediate reopen")
	var item=p("重破刃-41型");var ctx=arena([item],item.uid);near(pulse(ctx,item),base(item)+3,"high HP bonus")
	ctx.states[0].hp=5000;near(pulse(ctx,item),base(item),"high HP gate")
	item=p("瞬斩刀-18型");ctx=arena([item],item.uid);ctx.states[0].hp=3000
	near(pulse(ctx,item,true),base(item)*1.8+5,"low HP charge")
	near(pulse(ctx,item,true),base(item)*1.8,"low HP interval")
	item=p("天之苍苍");ctx=arena([item],item.uid);ctx.states[1].noise=3;ctx.states[1].noise_until=100;ctx.states[1].noise_next=100
	near(pulse(ctx,item,true),base(item)*1.8+6,"three noise charged condition")
	item=p("鸣动仪-25型");ctx=arena([item],item.uid);near(pulse(ctx,item),base(item)+2,"rectifier sixty percent condition")
	ctx.states[0].hp=5000;near(pulse(ctx,item),base(item),"rectifier below sixty no bonus")
func test_star_resources_and_advances()->void:
	tested.append("star_resources_and_advances")
	for name in ["远行者长刃·辟路","远行者迅刀·旅迹","远行者佩枪·洞察","远行者臂铠·破障","远行者矩阵·探幽"]:
		var source=p(name);var echo=p("echo_aureate");var ctx=arena(attach(source,[echo]),source.uid)
		pulse(ctx,echo);near(ctx.states[0].charge,1,name+" echo star charge")
		pulse(ctx,echo);near(ctx.states[0].charge,0,name+" shared cooldown rejects next event")
	var source=p("contract");var echo=p("echo_aureate");var invalid=p("w_sword");var ctx=arena(attach(source,[echo,invalid]),invalid.uid)
	check(b.linked(ctx,0,source).size()==1,"category excludes weapon from echo contract")
	pulse(ctx,echo);near(ctx.states[0].haste,1,"contract natural echo")
	var duplicate=p("contract","duplicate");duplicate.x=source.x;duplicate.y=source.y
	ctx=arena([source,duplicate,echo]);pulse(ctx,echo);near(ctx.states[0].haste,1,"same-name copies share interval")
	echo.x=100;ctx=arena([source,echo]);pulse(ctx,echo);near(ctx.states[0].haste,0,"off-star no effect")
	source=p("行进序曲");echo=p("echo_aureate");ctx=arena(attach(source,[echo]),source.uid)
	pulse(ctx,echo);check(ctx.progress[0][source.uid]>.15,"overture advances actual source")
	source=p("钧天正音");var w1=p("w_broadblade","a");var w2=p("w_sword","b");echo=p("echo_aureate")
	ctx=arena(attach(source,[w1,w2,echo]),w1.uid);pulse(ctx,w2);ctx.progress[0][w1.uid]=0;ctx.progress[0][w2.uid]=.8;pulse(ctx,echo)
	check(ev(ctx,"cooldown_advance").size()==1 and ev(ctx,"cooldown_advance")[0].uid==w1.uid,"dual event advances longest actual star weapon only")
	source=p("异响空灵");echo=p("echo_aureate");ctx=arena(attach(source,[echo]),source.uid);pulse(ctx,echo);pulse(ctx,echo)
	check(ev(ctx,"cooldown_advance").size()==1 and ev(ctx,"cooldown_advance")[0].uid==source.uid,"discord fallback self when main not on own star")
	source=p("华彩乐段");w1=p("w_sword");ctx=arena(attach(source,[w1]),source.uid)
	for i in range(3):pulse(ctx,source)
	check(ev(ctx,"cooldown_advance").size()==1,"relay prepares after third own")
	pulse(ctx,w1);check(ev(ctx,"cooldown_advance").size()==2,"actual designated partner returns relay")
func test_distinct_echoes_and_recipients()->void:
	tested.append("distinct_echoes_and_recipients")
	for name in ["脉冲协臂","白昼之脊","昭日译注","海的呢喃","幽冥的忘忧章","云琅","那奢靡优雅的归宿"]:
		var source=p(name);var a=p("echo_aureate","a");var same=p("echo_aureate","b");var ctx=arena(attach(source,[a,same]),source.uid)
		pulse(ctx,a);pulse(ctx,same)
		var s=b.own(ctx,0,source)
		check(s.stack==0 and not s.has("next_echo") and s.buffs.is_empty(),name+" duplicate UIDs do not make two names")
		var other=p("echo_glacio","other");ctx=arena(attach(source,[a,other]),source.uid);pulse(ctx,a);pulse(ctx,other)
		if name in ["脉冲协臂","白昼之脊"]:near(ctx.states[0].haste,1,name+" different-name alternation")
		elif name=="云琅":near(b.own(ctx,0,source).stack,1,"cloud alternation stack")
		elif name=="那奢靡优雅的归宿":check(not ev(ctx,"derived",source.uid).is_empty(),"elegance nonrecursive copy")
		else:check(not b.own(ctx,0,source).buffs.is_empty() or b.own(ctx,0,source).has("next_echo"),name+" distinct pair prepares reward")
	var source=p("掣傀之手");var a=p("echo_aureate");var other=p("echo_glacio");var weapon=p("w_sword")
	var ctx=arena(attach(source,[a,other,weapon]),weapon.uid);pulse(ctx,a);pulse(ctx,other)
	near(pulse(ctx,weapon),base(weapon)+6,"marks go to next partner weapon")
	near(b.own(ctx,0,source).get("marks",-1),0,"marks consumed once")
	source=p("裁竹");ctx=arena(attach(source,[a,other]),source.uid);pulse(ctx,a);pulse(ctx,other)
	for i in range(3):pulse(ctx,source)
	near(pulse(ctx,source),base(source)+10,"two distinct echo bamboo substitution")
	near(pulse(ctx,a),base(a)+3,"bamboo first contributor recipient")
	near(pulse(ctx,other),base(other)+3,"bamboo second contributor recipient")
func test_actual_healing_and_shields()->void:
	tested.append("actual_healing_and_shields")
	for spec in [["宙算仪轨","charged",5],["星序协响","flat",3]]:
		var source=p(spec[0]);var weapon=p("w_broadblade");var second=p("w_pistol");var ctx=arena(attach(source,[weapon,second]),weapon.uid)
		b.own(ctx,0,source).clocks.heal=.01;b.step(ctx,.01)
		check(b.own(ctx,0,weapon).buffs.is_empty(),str(spec[0])+" full HP rejects own heal trigger")
		ctx.states[0].hp-=100;b.own(ctx,0,source).clocks.heal=.02;b.step(ctx,.02)
		var charged=spec[1]=="charged"
		near(pulse(ctx,weapon,charged),base(weapon)*(1.8 if charged else 1)+float(spec[2]),str(spec[0])+" actual own heal buffs real target")
		if spec[0]=="星序协响":near(pulse(ctx,second),(base(second)+3),"star sequence second partner full bonus has full effect")
	var source=p("驭冕铸雷之权");var shield=p("rocksteady");var ctx=arena(attach(source,[shield]),source.uid)
	b.own(ctx,0,source).clocks.shield=.01;b.step(ctx,.01);near(b.own(ctx,0,source).stack,0,"crown self shield excluded")
	b.own(ctx,0,shield).clocks.shield=.02;b.step(ctx,.02);near(b.own(ctx,0,source).stack,1,"crown other actual star shield")
	near(pulse(ctx,source,true),base(source)*1.8+2,"crown penetration damage consumes old shield stack")
	ctx.states[0].shield=ctx.states[0].max_hp*.4;b.own(ctx,0,shield).clocks.shield=3;ctx.time=2.99;b.step(ctx,3)
	near(b.own(ctx,0,source).stack,0,"shield cap cannot feed penetration")
	source=p("异度");var healer=p("medical");ctx=arena(attach(source,[healer]),source.uid);pulse(ctx,source);pulse(ctx,source)
	ctx.states[0].hp-=100;b.own(ctx,0,healer).clocks.heal=ctx.time+.01;b.step(ctx,ctx.time+.01)
	near(ctx.totals[0].heal,5,"yidu next external heal gets one two-point addition")
	check(not b.own(ctx,0,source).heal_ready,"yidu addition consumed")
	source=p("血誓盟约");ctx=arena([source],source.uid);ctx.states[0].hp-=100;b.own(ctx,0,source).clocks.heal=.01;b.step(ctx,.01)
	near(pulse(ctx,source),base(source)+4,"blood actual healing next hit")
func test_statuses_defenses_and_multihit()->void:
	tested.append("statuses_defenses_and_multihit")
	var flame=p("焰光裁定");var other=p("echo_spectro");var ctx=arena([flame,other],flame.uid);ctx.progress[0].clear()
	b.apply_noise(ctx,0,flame,1,0);b.apply_noise(ctx,0,other,1,0);b.apply_noise(ctx,0,other,1,1)
	near(ctx.states[1].noise_next,2,"refresh preserves noise beat")
	b.step(ctx,2);near(ctx.totals[0].damage,3.25,"flame boosts own contribution only")
	ctx.team[0].noise_boost_until=10;ctx.team[0].forest_until=10;b.step(ctx,4)
	near(ctx.totals[0].damage,3.25+3.25*1.25,"global DOT maximum rather than multiply")
	ctx=arena([other]);b.apply_frost(ctx,0,other,5,0)
	near(ctx.states[1].freeze_until,.6,"freeze exact duration");near(ctx.states[1].frost_immune_until,3.6,"immune measured from freeze start")
	near(ctx.totals[0].damage,0,"no unapproved frost hit")
	b.apply_frost(ctx,0,other,1,3.5);near(ctx.states[1].frost,0,"immune rejects new frost")
	b.apply_frost(ctx,0,other,1,3.6);near(ctx.states[1].frost,1,"immunity boundary accepts frost")
	var dream=p("无妄者");ctx=arena([dream]);ctx.states[1].hp=3000
	var value=pulse(ctx,dream);near(value,base(dream)+6,"dreamless full base and execute")
	near(ev(ctx,"attack",dream.uid)[-1].value,snappedf(base(dream)*.5+6,.1),"execute only last segment")
	check(ev(ctx,"trigger",dream.uid).size()==1 and ev(ctx,"attack",dream.uid).size()==6,"multi-hit one natural event six hits")
	var violet=p("violet");var enemy=p("w_broadblade");ctx=arena([violet],"",[enemy])
	b.own(ctx,0,violet).clocks.stance=5;advance(ctx,5)
	check(ev(ctx,"attack",violet.uid).is_empty(),"purple stance replaces auto attack")
	ctx.team[0].ward=3;ctx.team[0].ward_until=20
	near(pulse(ctx,enemy,false,1),base(enemy)*.7,"purple thirty percent beats bell twenty-five")
	near(ctx.totals[0].damage,8,"purple alive counter exact eight")
	advance(ctx,7);near(ctx.totals[0].damage,8,"purple caught excludes timeout six")
	ctx=arena([violet]);b.own(ctx,0,violet).clocks.stance=5;advance(ctx,7)
	near(ctx.totals[0].damage,6,"uncaught purple timeout six")
	near(ctx.states[0].charge,1,"purple end charge once")
	var remains=p("万囮牢·朽躯");ctx=arena([remains]);ctx.states[0].shield=4
	near(pulse(ctx,remains),base(remains)+6,"remains spend actual four shield")
	near(ctx.states[0].shield,0,"remains exact shield subtraction")
func test_break_and_reactive()->void:
	tested.append("break_and_reactive")
	for spec in [["源能机锋",6,true],["燎照之骑",5,false]]:
		var item=p(spec[0]);var ctx=arena([item],item.uid);ctx.states[1].shield=1;pulse(ctx,item,spec[2])
		near(pulse(ctx,item,spec[2]),base(item)*(1.8 if spec[2] else 1)+spec[1],str(spec[0])+" actual shield break next attack")
	var source=p("千般渡");var shield=p("rocksteady");var enemy=p("w_broadblade");var ctx=arena(attach(source,[shield]),source.uid,[enemy]);ctx.builds[1].primary=enemy.uid
	b.own(ctx,0,shield).clocks.shield=.01;b.step(ctx,.01)
	pulse(ctx,enemy,false,1);near(ev(ctx,"counter",source.uid).size(),0,"crossing counter rejects ordinary enemy")
	pulse(ctx,enemy,true,1);near(ev(ctx,"counter",source.uid).size(),1,"crossing counter requires enemy charged attack")
	near(b.own(ctx,0,source).stack,0,"counter consumes carry")
	var steel=p("钢影拳-21丁型");ctx=arena([steel],steel.uid,[enemy]);ctx.states[0].hp=5000;pulse(ctx,enemy,false,1)
	near(ctx.totals[0].heal,0,"steel does not prematurely heal on enemy hit")
	near(pulse(ctx,steel),base(steel)+5,"steel next punch damage")
	near(ctx.totals[0].heal,2,"steel heals on next punch")
func test_all_profiles_and_symmetry()->void:
	tested.append("all_profiles_and_symmetry")
	for id in C.items:
		if not C.items[id].has("v75"):continue
		var item=p(id);var team=build([item],item.uid);var result=b.simulate(team,team,19,false)
		check(result.winner==0,id+" real simulate mirrored symmetry")
		check(result.frames.size()==2,id+" compact replay shape")
	var legacy=p("whiff_fast");var ctx=b.begin(build([legacy]),build());advance(ctx,12)
	check(not ev(ctx,"attack",legacy.uid).is_empty(),"legacy missing profile uses V60")
func support(ctx:Dictionary,item:Dictionary,key:String)->void:
	b.own(ctx,0,item).clocks[key]=ctx.time+.01;b.step(ctx,ctx.time+.01)
func test_precise_reviews_and_roles()->void:
	tested.append("precise_reviews_and_roles")
	var item=p("暗夜长刃·玄明");var main=p("w_sword");var ctx=arena([item,main],main.uid)
	near(pulse(ctx,item),(base(item)+8),"all weapon flat damage is full")
	var before=ctx.states[0].charge;b.activate(ctx,0,item,1,false,"derived");b.commit_pending(ctx,1)
	near(ctx.states[0].charge,before,"derived activation cannot generate charge")
	near(ev(ctx,"trigger",item.uid).size(),1,"derived activation cannot generate ordinary root")
	var source=p("鸣动仪-25型");var nutrition=p("nutrition");ctx=b.begin(build(attach(source,[nutrition]),source.uid),build())
	ctx.states[0].hp=49;b.step(ctx,.1)
	check(not b.own(ctx,0,source).buffs.is_empty(),"emergency actual heal crosses sixty and feeds star")
	var violet=p("violet");source=p("琼枝冰绡");ctx=arena(attach(source,[violet]),source.uid)
	for i in range(3):pulse(ctx,source)
	b.own(ctx,0,violet).clocks.stance=.04;b.step(ctx,.04);ctx.progress[0].clear();advance(ctx,2.04)
	near(ctx.totals[0].damage-3*base(source),12,"purple natural timeout consumes next-Echo six bonus")
	var aim=p("穿击枪-26型");var enemy=p("echo_spectro");ctx=arena([aim],aim.uid,[enemy]);ctx.progress[0].clear();ctx.progress[1].clear()
	b.queue_hit(ctx,1,enemy,1,1);ctx.time=1;b.commit_pending(ctx,1);advance(ctx,5.9)
	near(b.own(ctx,0,aim).stack,0,"aim no early stack after HP hit")
	advance(ctx,6);near(b.own(ctx,0,aim).stack,1,"aim full five from most recent HP hit")
	b.queue_hit(ctx,1,enemy,1,6.1,"noise_tick");b.commit_pending(ctx,6.1)
	near(b.own(ctx,0,aim).stack,0,"DOT HP hit consumes aim stack")
	near(ctx.totals[0].heal,2,"aim actual healing clamped to missing HP")
	var counter=p("千般渡");ctx=arena([counter,main],main.uid,[enemy]);b.own(ctx,0,counter).stack=3
	var counters=[];b.after_weapon_hit(ctx,0,main,.1,true,counters)
	near(counters[0].damage,12,"all weapons keep full counter damage")
	var hold=p("时和岁稔");var echo=p("echo_aureate");ctx=arena(attach(hold,[echo]),hold.uid)
	pulse(ctx,hold);pulse(ctx,echo);near(pulse(ctx,hold,true),base(hold)*1.8+8,"time harvest two fixed extras")
	near(ev(ctx,"attack",hold.uid)[-1].value,4,"time harvest final segment four")
	near(ev(ctx,"attack",hold.uid)[-2].value,4,"time harvest middle segment four")
func test_remaining_own_clauses()->void:
	tested.append("remaining_own_clauses")
	var item=p("东落");var ctx=arena([item],item.uid);pulse(ctx,item,true);ctx.progress[0].clear();advance(ctx,4.01)
	near(b.own(ctx,0,item).stack,2,"eastfall independent two-second charge storage")
	near(pulse(ctx,item,true),base(item)*1.8+4,"eastfall spends prior stored layers")
	for name in ["凋亡频移","永续坍缩","悖论喷流","尘云旋臂","核熔星盘","赝作的矮星"]:
		item=p(name);ctx=arena([item],item.uid)
		for i in range(3):pulse(ctx,item)
		near(ctx.states[0].charge,float(b.profile(item).charge)+1,name+" extra third-attack charge once")
		if name!="赝作的矮星":
			pulse(ctx,item,true);near(pulse(ctx,item),base(item)+3,name+" primary spend next natural plus three")
	item=p("不归孤军");ctx=arena([item],item.uid);pulse(ctx,item);pulse(ctx,item)
	near(ctx.states[0].haste,1,"army every two haste")
	ctx.progress[0].clear();advance(ctx,6.03);near(ctx.states[0].haste,0,"army no-hit haste expires")
	item=p("飞景");var partner=p("w_sword");ctx=arena(attach(item,[partner]),item.uid)
	for i in range(3):pulse(ctx,item)
	near(pulse(ctx,item),base(item)+3,"flying scene next attack plus three")
	near(ev(ctx,"cooldown_advance").size(),2,"flying scene advances self and exactly one partner")
	item=p("镭射切变");ctx=arena([item],item.uid)
	for i in range(3):pulse(ctx,item)
	ctx.states[1].shield=5;near(pulse(ctx,item),base(item)+3,"laser prepared damage")
	check(not ev(ctx,"break_shield",item.uid).is_empty() and not ev(ctx,"cooldown_advance",item.uid).is_empty(),"laser actual break advances own")
	for name in ["飞逝","停驻之烟"]:
		item=p(name);ctx=arena([item],item.uid);ctx.states[0].haste=3;ctx.states[0].haste_until=100
		pulse(ctx,item);pulse(ctx,item);near(pulse(ctx,item),base(item)+4,name+" third hit when three haste")
	item=p("袍泽之固");ctx=arena([item],item.uid);pulse(ctx,item,true)
	near(pulse(ctx,item),base(item)+5,"comrade next fist not current")
	item=p("骇行");var enemy=p("w_broadblade");ctx=arena([item],item.uid,[enemy]);pulse(ctx,item,true)
	near(b.own(ctx,0,item).armor,3,"armor three from charge")
	near(pulse(ctx,enemy,false,1),base(enemy)-1,"armor flat mitigation one")
	near(b.own(ctx,0,item).armor,2,"armor consumes one per weapon root")
	item=p("焰光裁定");ctx=arena([item],item.uid)
	for i in range(3):pulse(ctx,item)
	ctx.states[1].shield=6;pulse(ctx,item);near(ev(ctx,"break_shield",item.uid)[-1].value,6,"flame fourth ordinary removes six shield")
	item=p("白昼之脊");ctx=arena([item],item.uid);ctx.states[1].noise=3;ctx.states[1].noise_until=100;ctx.states[1].noise_next=100
	for i in range(3):pulse(ctx,item)
	ctx.states[1].shield=1000;var hp=ctx.states[1].hp;pulse(ctx,item)
	near(hp-ctx.states[1].hp,minf(base(item)*.2,4),"day spine prepared hit exact capped piercing")
	for spec in [["不屈命定之冠",.15,4],["永远的启明星",.3,8]]:
		item=p(spec[0]);ctx=arena([item],item.uid);ctx.states[1].noise=1;ctx.states[1].noise_until=100;ctx.states[1].noise_next=100;ctx.states[1].shield=1000;hp=ctx.states[1].hp
		pulse(ctx,item,spec[0]=="永远的启明星")
		near(hp-ctx.states[1].hp,minf(base(item)*(1.8 if spec[0]=="永远的启明星" else 1)*spec[1],spec[2]),str(spec[0])+" piercing reallocates damage")
	item=p("溢彩荧辉");ctx=arena([item],item.uid);pulse(ctx,item);near(pulse(ctx,item),base(item)*1.2,"glow next ordinary multiplier")
	item=p("玻色星仪");ctx=arena([item],item.uid);pulse(ctx,item);pulse(ctx,item);ctx.states[1].shield=4;pulse(ctx,item)
	near(pulse(ctx,item),base(item)+3,"boson real break next ordinary three")
	item=p("玉阙玄华");ctx=arena([item],item.uid);pulse(ctx,item,true);ctx.states[1].shield=100;pulse(ctx,item)
	near(ev(ctx,"break_shield",item.uid)[-1].value,4,"jade primary charge next hit breaks four")
	item=p("和光回唱");ctx=arena([item],item.uid);ctx.states[1].noise=1;ctx.states[1].noise_until=100;ctx.states[1].noise_next=100
	for i in range(3):near(pulse(ctx,item),base(item),"harmony three old-noise prep hits")
	near(pulse(ctx,item),base(item)+4,"harmony consumes old three at attack start")
	near(b.own(ctx,0,item).stack,1,"harmony only fresh postattack layer remains")
	near(ctx.team[0].noise_boost,.25,"harmony DOT window")
	for name in ["解形煞","燎照之骑","坚岩斗士","先锋幼岩"]:
		item=p(name);ctx=arena([item]);ctx.states[1].shield=100;pulse(ctx,item)
		check(not ev(ctx,"break_shield",item.uid).is_empty(),name+" explicit shield removal")
	item=p("舒云秘制凉茶");ctx=arena([item]);ctx.progress[0].clear();advance(ctx,6)
	near(ctx.states[0].haste,2,"cool tea uses at six without incoming status")
	near(ctx.used[0].size(),1,"cool tea once-per-battle supply")
func test_remaining_star_clauses()->void:
	tested.append("remaining_star_clauses")
	for name in ["永夜长明","今州守望"]:
		var source=p(name);var echo=p("echo_aureate");var ctx=arena(attach(source,[echo]),source.uid);pulse(ctx,echo)
		near(pulse(ctx,source),base(source)+2,name+" echo next attack reward")
	var source=p("重破刃-41型");var healer=p("medical");var ctx=arena(attach(source,[healer]),source.uid);ctx.states[0].max_hp=100;ctx.states[0].hp=79;support(ctx,healer,"heal")
	near(pulse(ctx,source),base(source)+5,"heal eighty crossing plus own high HP")
	for name in ["浩境粼光","苍鳞千嶂"]:
		source=p(name);var echo=p("echo_aureate");ctx=arena(attach(source,[echo]),source.uid);pulse(ctx,echo)
		near(b.own(ctx,0,source).stack,1,name+" echo inserts shared stack")
	source=p("昙切");var noise=p("echo_spectro");ctx=arena(attach(source,[noise]),source.uid)
	for i in range(3):ctx.time=float(i);support(ctx,noise,"noise")
	near(pulse(ctx,source,true),base(source)*1.8+8,"noise three successful applications prepare charge")
	for name in ["西升","飞逝","停驻之烟","林间的咏叹调","溢彩荧辉","aero_coin"]:
		source=p(name);var soup=p("soup");ctx=arena(attach(source,[soup]),source.uid);ctx.states[0].stamina=1;b.step(ctx,.01)
		near(ctx.states[0].haste,1 if name=="西升" else 2,name+" actual supply first-use event")
		ctx.states[0].stamina=1;b.step(ctx,.02);near(ctx.states[0].haste,1 if name=="西升" else 2,name+" same supply no repeat")
	source=p("沉冥");var echo=p("echo_aureate");var weapon=p("w_sword");ctx=arena(attach(source,[weapon,echo]),source.uid)
	pulse(ctx,weapon);pulse(ctx,echo);pulse(ctx,weapon);pulse(ctx,echo)
	near(pulse(ctx,source),base(source)+3,"alternating category stance four events")
	source=p("奇幻变奏");echo=p("echo_aureate");var other=p("echo_glacio");weapon=p("w_sword")
	ctx=arena(attach(source,[echo,other,weapon]),weapon.uid);pulse(ctx,echo);pulse(ctx,other);pulse(ctx,echo)
	check(ev(ctx,"cooldown_advance").size()==1 and ev(ctx,"cooldown_advance")[0].uid==weapon.uid,"variation two alternations target main")
	source=p("渊海回声");ctx=arena(attach(source,[weapon]),weapon.uid);pulse(ctx,weapon,true);ctx.states[0].hp-=100;support(ctx,source,"heal")
	near(ctx.totals[0].heal,6,"sea echo charged main next heal four plus two")
	source=p("昭日译注");ctx=arena(attach(source,[echo,other]),source.uid);pulse(ctx,echo);pulse(ctx,other)
	near(pulse(ctx,echo),base(echo)+minf(base(echo)*.35,6),"translation next echo base percent only")
	source=p("诸方玄枢");ctx=arena(attach(source,[echo]),source.uid);pulse(ctx,source,true)
	var end=b.own(ctx,0,source).window
	for i in range(5):pulse(ctx,echo)
	near(b.own(ctx,0,source).window,end+3,"pivot echo extension maximum three")
	source=p("存帧");ctx=arena(attach(source,[weapon]),weapon.uid);b.apply_frost(ctx,0,source,5,0)
	near(pulse(ctx,weapon),base(weapon)+minf(base(weapon)*.3,6),"freeze snapshot one partner base copy")
	near(pulse(ctx,weapon),base(weapon),"snapshot cannot recurse or repeat")
	source=p("栖霞饮露");ctx=arena([source],source.uid);ctx.states[0].hp-=100;b.apply_frost(ctx,0,source,1,0);support(ctx,source,"heal")
	var first=ctx.totals[0].heal;support(ctx,source,"heal")
	near(ctx.totals[0].heal-first,float(b.profile(source).healAmount)+3,"frost before actual heal prepares next healing")
	for name in ["青羽鹭","绝息魄","云闪之鳞"]:
		source=p(name);ctx=arena(attach(source,[weapon]),weapon.uid,[p("w_broadblade")])
		for i in range(4):pulse(ctx,weapon)
		if name=="绝息魄":near(pulse(ctx,source),base(source)+4,"soulfrayer weapon count next echo")
		elif name=="云闪之鳞":check(not ev(ctx,"cooldown_advance",source.uid).is_empty(),"thundering own clock advanced")
		else:pulse(ctx,source);check(not ev(ctx,"delay").is_empty(),"cyan delays actual enemy weapon")
	for name in ["霁息兽尊","千傀重楼"]:
		source=p(name);ctx=arena(attach(source,[healer]),source.uid);ctx.states[0].hp-=100;ctx.states[0].frost=2;ctx.states[0].frost_until=100;support(ctx,healer,"heal")
		near(ctx.states[0].frost,1,name+" actual star heal cleanses")
	source=p("共鸣回响·天演溯心");var shield=p("rocksteady");ctx=arena(attach(source,[shield]),source.uid);support(ctx,shield,"shield")
	near(ctx.states[1].noise,1,"shield root grants derived single noise")
	source=p("天傀劫煞");ctx=arena(attach(source,[echo,other,weapon]),weapon.uid);pulse(ctx,echo);pulse(ctx,other)
	check(not ev(ctx,"cooldown_advance",weapon.uid).is_empty(),"two echo names advance actual star weapon")
	source=p("flower");ctx=arena(attach(source,[healer]));ctx.states[0].hp-=100;support(ctx,healer,"heal");support(ctx,source,"shield")
	near(ctx.totals[0].shield,4,"flower actual healer adds one to next base shield")
	source=p("lamp");ctx=arena(attach(source,[weapon,shield]),weapon.uid);pulse(ctx,weapon);near(ctx.states[0].charge,1,"lamp star weapon charges")
	support(ctx,shield,"shield");near(pulse(ctx,weapon,true),base(weapon)*1.8+3,"lamp actual shield grants main next charge")
	source=p("answer");ctx=arena(attach(source,[weapon]),weapon.uid);ctx.states[1].shield=100;ctx.states[1].frost=1;ctx.states[1].frost_until=100;pulse(ctx,weapon)
	check(not ev(ctx,"break_shield",source.uid).is_empty(),"answer natural weapon on status removes shield")
	source=p("sail");var main=p("w_broadblade");ctx=arena(attach(source,[weapon]),main.uid);ctx.queues[0].append(main);ctx.builds[0].items.append(main);ctx.progress[0][main.uid]=0;ctx.bonuses[0][main.uid]={"speed":0,"multiplier":1};ctx.waiting[0][main.uid]=false;b.own(ctx,0,main)
	pulse(ctx,main,true);near(pulse(ctx,weapon),(base(weapon)+4),"sail different partner full damage")
	source=p("judgment");ctx=arena(attach(source,[echo]),weapon.uid);ctx.queues[0].append(weapon);ctx.builds[0].items.append(weapon);ctx.progress[0][weapon.uid]=0;ctx.bonuses[0][weapon.uid]={"speed":0,"multiplier":1};ctx.waiting[0][weapon.uid]=false;b.own(ctx,0,weapon)
	pulse(ctx,weapon,true);near(pulse(ctx,echo),base(echo)+minf(base(echo)*.4,6),"judgment next echo last segment only")
func test_every_profile_numerical_base_and_clocks()->void:
	tested.append("every_profile_numerical_base_and_clocks")
	for id in C.items:
		if not C.items[id].has("v75"):continue
		var item=p(id);var n=b.profile(item);var ctx=arena([item],item.uid)
		if n.cd>0 and id!="violet":
			var bonus=0
			match b.rule(item):
				"暗夜长刃·玄明":bonus=8
				"暗夜臂铠·夜芒","暗夜矩阵·暝光":bonus=4
				"重破刃-41型":bonus=3
				"鸣动仪-25型":bonus=2
			near(pulse(ctx,item),float(n.damage)+bonus,id+" first natural numerical action without double V60")
			near(ctx.states[0].charge,float(n.charge),id+" exact first natural charge")
			near(ctx.states[0].haste,1 if int(n.hasteEvery)==1 else 0,id+" exact first natural haste")
		else:check(not ctx.progress[0].has(item.uid),id+" no phantom periodic attack")
		for clock in ["heal","shield","noise","frost"]:
			var period=float(n.get(clock+"Period",0))
			if period<=0:continue
			ctx=arena([item],item.uid);ctx.progress[0].clear();ctx.states[0].hp=9000;b.own(ctx,0,item).clocks={clock:period}
			var prior=float(ctx.totals[0].get(clock,0));b.step(ctx,period-.001)
			if clock in ["heal","shield"]:near(ctx.totals[0][clock],prior,id+" "+clock+" no early pulse")
			else:near(ctx.states[1][clock],0,id+" "+clock+" no early status")
			b.step(ctx,period)
			if clock in ["heal","shield"]:near(ctx.totals[0][clock]-prior,float(n[clock+"Amount"]),id+" "+clock+" exact source N amount")
			else:near(ctx.states[1][clock],1,id+" "+clock+" exact source N period")
func test_remaining_resource_and_timed_clauses()->void:
	tested.append("remaining_resource_and_timed_clauses")
	for name in ["源能长刃·测壹","源能迅刀·测贰","源能佩枪·测叁","源能臂铠·测肆","重破刃-41型"]:
		var item=p(name);var ctx=arena([item],item.uid);ctx.origins[0].emergency=true;ctx.states[0].hp=3000;support(ctx,item,"heal")
		near(ctx.totals[0].heal,float(b.profile(item).healAmount)+1,name+" below-forty independent heal one extra")
	for name in ["暗夜迅刀·黑闪","暗夜佩枪·暗星"]:
		var item=p(name);var ctx=arena([item],item.uid);b.step(ctx,.1)
		near(ctx.progress[0][item.uid],.1*1.25/float(b.profile(item).cd),name+" initial cooldown speed twenty-five percent")
		pulse(ctx,item);pulse(ctx,item);var before=ctx.progress[0][item.uid];b.step(ctx,ctx.time+.1)
		near(ctx.progress[0][item.uid]-before,.1/float(b.profile(item).cd),name+" opening speed ends after two")
	var item=p("千古洑流");var echo=p("echo_aureate");var ctx=arena(attach(item,[echo]),item.uid);pulse(ctx,item);pulse(ctx,item)
	near(ctx.states[0].haste,1,"eternal flow gains haste every two attacks");near(b.own(ctx,0,item).stack,1,"eternal flow every two damage stack")
	pulse(ctx,echo);near(b.own(ctx,0,item).stack,2,"echo same damage stack capped two")
	item=p("灼霜");ctx=arena([item],item.uid);b.apply_frost(ctx,0,item,5,0)
	near(pulse(ctx,item),base(item)+7,"first friendly freeze prepares seven next damage")
	near(pulse(ctx,item),base(item),"freeze bonus no stored repeats")
	item=p("死与舞");ctx=arena([item],item.uid);pulse(ctx,item,true)
	near(pulse(ctx,item),base(item)+7,"death dance first reward");near(pulse(ctx,item),base(item)+7,"death dance second reward")
	pulse(ctx,item,true);near(pulse(ctx,item),base(item),"death dance full five-second lock after last shot")
	item=p("光影双生");ctx=arena(attach(item,[echo]),item.uid);pulse(ctx,item,true)
	near(pulse(ctx,echo),base(echo)+4,"light shadow charge to next echo")
	near(pulse(ctx,item,true),base(item)*1.8+4,"light shadow echo back to next charged main")
	item=p("呼啸重音");var weapon=p("w_sword");ctx=arena(attach(item,[echo,weapon]),item.uid);pulse(ctx,echo);pulse(ctx,item)
	check(ev(ctx,"cooldown_advance").any(func(e):return e.uid==weapon.uid and str(e.get("source_uid",""))==item.uid),"roar needs own attack and star echo then targets weapon")
	item=p("万物持存的注释");var shield=p("rocksteady");ctx=arena(attach(item,[shield]),item.uid);support(ctx,shield,"shield")
	near(pulse(ctx,item,true),base(item)*1.8+1,"annotation different actual shield pierce stack")
	check(b.own(ctx,0,item).clocks.has("shield") and b.profile(item).shieldPeriod==6.0,"V88 annotation retains six-second shield supply")
	for spec in [["whiff","haste",1],["zig","haste",0],["echo_jade_snake","charge",1],["feilian","charge",2],["heron","charge",2]]:
		item=p(spec[0]);ctx=arena([item]);pulse(ctx,item)
		near(ctx.states[0][spec[1]],spec[2],str(spec[0])+" exact root resource once")
	item=p("feilian");ctx=arena(attach(item,[weapon]),weapon.uid);pulse(ctx,item)
	check(ev(ctx,"attack",item.uid).size()==2,"feilian two equal segments")
	near(pulse(ctx,weapon,true),base(weapon)*1.8+5,"feilian highest star weapon charged bonus")
	item=p("heron");ctx=arena(attach(item,[weapon]),weapon.uid);pulse(ctx,item)
	near(pulse(ctx,weapon),base(weapon)+5,"heron linked primary next hit")
	item=p("electro_coin");ctx=arena(attach(item,[weapon]),weapon.uid);pulse(ctx,weapon)
	near(ctx.states[0].charge,1,"electro coin true weapon event")
	item=p("spectro_coin");ctx=arena(attach(item,[weapon]),weapon.uid);b.own(ctx,0,item).clocks.noise=6;pulse(ctx,weapon)
	near(b.own(ctx,0,item).clocks.noise,5,"spectro weapon advances noise clock exactly one")
	item=p("glasses");ctx=arena([item]);ctx.states[0].frost=2;ctx.states[0].frost_until=100;b.own(ctx,0,item).clocks.cleanse=8;advance(ctx,8)
	near(ctx.states[0].frost,1,"glasses independent eight-second cleanse")
	for spec in [["daily_tea","haste",2],["spicy_meat","charge",3],["maocai","shield",12],["rations","stamina_discount",.15]]:
		item=p(spec[0]);ctx=b.begin(build([item,p(spec[0],"copy")]),build())
		near(ctx.states[0][spec[1]],minf(float(spec[2])*2,6) if spec[0] in ["daily_tea","spicy_meat"] else 24 if spec[0]=="maocai" else .15,str(spec[0])+" bounded explicit opening")
	item=p("revive");ctx=arena([item]);b.apply_frost(ctx,1,p("echo_glacio"),1,0)
	near(ctx.states[0].frost,0,"revive removes first debuff once")
	b.apply_frost(ctx,1,p("echo_glacio"),1,.1);near(ctx.states[0].frost,1,"revive no second use")
	item=p("captain_seal");var large=p("w_broadblade");ctx=arena(attach(item,[weapon,large]),large.uid)
	near(pulse(ctx,large),base(large)+3,"captain highest base first hit")
	near(pulse(ctx,large),base(large)+3,"captain highest base second hit")
	near(pulse(ctx,large),base(large),"captain stops after two")
	item=p("starfall");ctx=arena(attach(item,[weapon,large]),large.uid);pulse(ctx,large,true);pulse(ctx,large,true)
	near(pulse(ctx,weapon),(base(weapon)+3),"starfall paired charge partner full bonus")
	near(pulse(ctx,weapon),(base(weapon)+3),"starfall second hit")
	near(pulse(ctx,weapon),base(weapon),"starfall no permanent buff")
func test_legacy_cross_version_events()->void:
	tested.append("legacy_cross_version_events")
	var source=p("contract_echo");var echo=p("echo_aureate");var ctx=arena(attach(source,[echo]));pulse(ctx,echo)
	near(ctx.states[0].haste,1,"legacy contract receives current natural echo")
	source=p("contract");echo=p("turtle_clean");ctx=arena(attach(source,[echo]));ctx.states[0].hp-=100;pulse(ctx,echo)
	near(ctx.states[0].haste,1,"legacy healer Echo activates current echo star once")
	source=p("rock_wall");var healer=p("medical");ctx=arena(attach(source,[healer]));ctx.states[0].hp-=100;support(ctx,healer,"heal")
	near(ctx.totals[0].shield,2,"legacy healing alias accepts current healer event")
	source=p("鸣动仪-25型");healer=p("turtle_clean");ctx=arena(attach(source,[healer]),source.uid);ctx.states[0].max_hp=100;ctx.states[0].hp=59;pulse(ctx,healer)
	near(pulse(ctx,source),base(source)+5,"legacy actual heal carries crossing ratios to current source")
	source=p("驭冕铸雷之权");var shield=p("rock_wall");ctx=arena(attach(source,[shield]),source.uid);pulse(ctx,shield)
	near(b.own(ctx,0,source).stack,1,"current shield capability matches legacy actual shield actions")
	echo=p("whiff_fast");ctx=arena([echo]);b.buff(ctx,0,echo,echo,"base_percent",.35,0);near(pulse(ctx,echo),6*1.35,"legacy Echo receives capped base percent")
	b.buff(ctx,0,echo,echo,"last_percent",.4,ctx.time);near(pulse(ctx,echo),6+3*.4,"legacy Echo receives last-segment percent")
func test_hostile_delay_simultaneous_planning()->void:
	tested.append("hostile_delay_simultaneous_planning")
	var bird=p("青羽鹭");var sword=p("w_sword");var team=build(attach(bird,[sword]),sword.uid)
	var ctx=b.begin(team.duplicate(true),team.duplicate(true))
	for side in range(2):
		ctx.progress[side][bird.uid]=1;ctx.progress[side][sword.uid]=1;b.own(ctx,side,bird).delay=true
	b.step(ctx,.1)
	near(ctx.totals[0].damage,10,"ready mirror side zero sword and bird plan both commit")
	near(ctx.totals[1].damage,10,"ready mirror side one sword and bird plan both commit")
	near(ctx.states[0].hp,ctx.states[1].hp,"hostile delay never cancels other already-ready root")
	near(ctx.progress[0][sword.uid],ctx.progress[1][sword.uid],"mirrored next cooldown after queued delay")
	var pistol=p("w_pistol");team=build(attach(bird,[pistol]),pistol.uid)
	var result=b.simulate(team.duplicate(true),team.duplicate(true),1,false)
	check(result.winner==0,"untouched cyan and pistol linked mirror draws")
	near(result.totals[0].damage,result.totals[1].damage,"untouched linked mirror exact damage")
	for spec in [["青羽鹭","w_broadblade"],["青羽鹭","裁春"],["驭冕铸雷之权","rocksteady"],["鸣动仪-25型","medical"],["重破刃-41型","turtle"],["灼霜","echo_glacio"]]:
		var source=p(spec[0]);var partner=p(spec[1]);var items=[source,partner]
		if not b.inventory.stars(source).is_empty():items=attach(source,[partner])
		var primary=source.uid if C.is_tag(source.kind,"weapon") else partner.uid
		var mirrored=build(items,primary);var combined=b.simulate(mirrored.duplicate(true),mirrored.duplicate(true),31,false)
		check(combined.winner==0,str(spec)+" representative synergy mirror draws")
		near(combined.totals[0].damage,combined.totals[1].damage,str(spec)+" representative synergy mirror damage")
		near(combined.totals[0].heal,combined.totals[1].heal,str(spec)+" representative synergy mirror actual heal")
	ctx=arena([bird],"",[sword]);ctx.builds[1].primary=sword.uid
	ctx.progress[0][bird.uid]=1;ctx.progress[1][sword.uid]=1;b.own(ctx,0,bird).delay=true;b.step(ctx,.1)
	near(ctx.totals[1].damage,base(sword),"unilateral delay preserves enemy ready attack")
	near(ctx.progress[1][sword.uid],-.3/float(b.profile(sword).cd),"delay applies exact three tenths to next remaining cycle")
	var delays=ev(ctx,"delay")
	check(delays.size()==1 and delays[0].time==.1 and delays[0].target_uid==sword.uid,"committed delay replay time and actual target")
	ctx.progress[0].clear();advance(ctx,2.19)
	near(ev(ctx,"attack",sword.uid).size(),1,"delayed next attack waits complete extra three tenths")
	advance(ctx,2.2);near(ev(ctx,"attack",sword.uid).size(),2,"delayed next attack fires at exact extended deadline")
func _initialize()->void:
	var saved_catalogue=HISTORICAL.apply()
	test_openings_and_clocks();test_opening_attacks_and_stacks();test_charged_and_burst_groups();test_windows_and_conditions();test_star_resources_and_advances();test_distinct_echoes_and_recipients();test_actual_healing_and_shields();test_statuses_defenses_and_multihit();test_break_and_reactive();test_precise_reviews_and_roles();test_remaining_own_clauses();test_remaining_star_clauses();test_remaining_resource_and_timed_clauses();test_legacy_cross_version_events();test_hostile_delay_simultaneous_planning();test_every_profile_numerical_base_and_clocks();test_all_profiles_and_symmetry()
	print("BATTLE_V75_RULES: [historical V116 catalogue] ",checks," checks, ",failures," failures; groups=",tested)
	HISTORICAL.restore(saved_catalogue)
	quit(1 if failures else 0)
