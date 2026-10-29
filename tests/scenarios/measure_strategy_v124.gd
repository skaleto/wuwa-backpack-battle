extends SceneTree
## Reproducible equal-investment diagnostic. No Storage, production changes or RNG tuning.
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const B=preload("res://scripts/battle/battle.gd")
const REVIEW=preload("res://scripts/battle/battle_review.gd")
const OUT="res://build/qa/strategy-v124/"
const SEEDS=[124,661,2026]
const DIAGNOSTIC_HP=300.0
const LOADOUTS={
	"heavy":["weapon_21020076","w_broadblade","whiff","zig","spicy_meat","tea","soup"],
	"relay":["weapon_21020045","w_sword","whiff","tea","soup"],
	"guard":["weapon_21010076","rocksteady","w_gauntlet","tea","turtle"],
	"frost":["weapon_21020086","w_sword","echo_glacio","whiff","tea","soup"],
	"echo":["weapon_21020106","whiff","zig","w_broadblade","electro_coin"],
	"rarity":["weapon_21020076","weapon_21020045","tea"],
	"shield_break":["verdant","w_broadblade","rocksteady","electro_coin"],
	"affliction_break":["weapon_21020045","answer","echo_glacio","zig","tea"]
}
const NAMES={"heavy":"充能重击","relay":"强化接力","guard":"护盾反击","frost":"霜渐联动","echo":"异种声骸","rarity":"双高品质武器","shield_break":"盾转重击破盾","affliction_break":"减益应答破盾"}
var inv=I.new()
var battle=B.new()
var checks=0
var failures=[]
var costs={}
var paths={}
var candidates={}
var links_allowed=[]

func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("MEASURE ERROR ",label)

func minimum_costs()->void:
	# Fixed-point relaxation is equivalent to recursively taking every recipe's
	# input sum, but safely handles any future cyclic alternate recipe graph.
	for kind in C.items:
		var item=C.items[kind];var n=item.get("v75",{})
		if not n.is_empty() and n.get("active",false) and not n.get("craft_only",true) and not C.is_tag(kind,"bag"):
			costs[kind]=int(item.price)
			paths[kind]={"kind":kind,"name":item.name,"cost":int(item.price),"via":"shop","inputs":[]}
	for pass_index in C.items.size():
		var changed=false
		for recipe in C.combinations:
			var inputs=[recipe.base]+recipe.get("materials",[])
			if not inputs.all(func(kind):return costs.has(kind)):continue
			var amount=inputs.reduce(func(total,kind):return total+int(costs[kind]),0)
			if costs.has(recipe.target) and int(costs[recipe.target])<=amount:continue
			costs[recipe.target]=amount
			paths[recipe.target]={"kind":recipe.target,"name":C.items[recipe.target].name,"cost":amount,"via":"recipe","recipe_id":recipe.id,"fee":0,"inputs":inputs.map(func(kind):return paths[kind].duplicate(true))}
			changed=true
		if not changed:break

func base_board()->Dictionary:
	var run=inv.new_run("hsin",124)
	run.round=7;run.items=[];run.stash=[];run.bags=[];run.serial=100;run.primary="";run.shop=[{},{},{},{},{},{}]
	run.simulation_version=C.SIMULATION_VERSION
	# All builds have the same 54 neutral cells. Capacity is an experimental
	# control, not a claim that nine starter satchels can be purchased in a run.
	for y in [0,2,4]:
		for x in [0,3,6]:
			var bag=inv.make_piece("satchel","bag_%s_%s"%[x,y]);bag.x=x;bag.y=y;run.bags.append(bag)
	return run

func mask(points:Array)->int:
	var out=0
	for p in points:
		if p.x>=0 and p.x<9 and p.y>=0 and p.y<6:out|=1<<(p.y*9+p.x)
	return out

func placements(kind:String)->Array:
	if candidates.has(kind):return candidates[kind]
	var out=[]
	for rotation in 4:
		for y in 6:
			for x in 9:
				var p=inv.make_piece(kind,"candidate");p.x=x;p.y=y;p.rotation=rotation
				var cells=inv.occupied(p)
				if not cells.all(func(v):return v.x>=0 and v.x<9 and v.y>=0 and v.y<6):continue
				out.append({"piece":p,"cells":mask(cells),"stars":mask(inv.stars(p))})
	candidates[kind]=out
	return out

func geometry_score(layout:Array,high:bool)->int:
	var score=0
	for a in layout.size():
		for b in layout.size():
			if links_allowed[a][b] and (int(layout[a].stars)&int(layout[b].cells))!=0:
				# Core links are prioritized, then all other eligible links. The
				# same objective applies to the two expensive weapons control.
				score+=(10 if high and C.items[layout[a].piece.kind].has("v124") else 1)
	return score

func arrange(key:String,high:bool)->Dictionary:
	var kinds=LOADOUTS[key];var run=base_board();var options=[]
	links_allowed=[]
	for a in kinds.size():
		options.append(placements(kinds[a]));var row=[]
		for b in kinds.size():row.append(a!=b and inv.star_eligible({"kind":kinds[a],"uid":str(a)},{"kind":kinds[b],"uid":str(b)}))
		links_allowed.append(row)
	var rng=RandomNumberGenerator.new();rng.seed=124
	var best=[];var best_score=-1 if high else 10000
	for restart in 8:
		var layout=[];var occupied=0
		for choices in options:
			var legal=choices.filter(func(p):return (int(p.cells)&occupied)==0)
			ck(not legal.is_empty(),"placement search has space "+key)
			if legal.is_empty():return {}
			var chosen=legal[rng.randi_range(0,legal.size()-1)];layout.append(chosen);occupied|=int(chosen.cells)
		for sweep in 4:
			var improved=false
			for index in layout.size():
				occupied=0
				for other in layout.size():
					if other!=index:occupied|=int(layout[other].cells)
				var selected=layout[index];var selected_score=geometry_score(layout,high)
				for candidate in options[index]:
					if (int(candidate.cells)&occupied)!=0:continue
					layout[index]=candidate;var score=geometry_score(layout,high)
					if (high and score>selected_score) or (not high and score<selected_score):selected=candidate;selected_score=score;improved=true
				layout[index]=selected
			if not improved:break
		var score=geometry_score(layout,high)
		if (high and score>best_score) or (not high and score<best_score):best=layout.duplicate(true);best_score=score
		if not high and best_score==0:break
	for index in best.size():
		var p=best[index].piece.duplicate(true);p.uid="i"+str(index+1);run.items.append(p)
	run.golden_acquired=run.items.any(func(p):return C.is_tag(p.kind,"golden"))
	ck(inv.validate_run(run),"legal run "+key+(" linked" if high else " separated"))
	ck(inv.validate_ghost(inv.snapshot(run,"v124-benchmark",key)),"legal ghost "+key)
	ck(not high or geometry_score(best,high)>0,"intended core links exist "+key)
	ck(high or geometry_score(best,high)==0,"separated layout has zero eligible links "+key)
	if high:
		var expected={"heavy":{"weapon_21020076":["w_broadblade","whiff","zig"]},"relay":{"weapon_21020045":["w_sword"]},"guard":{"weapon_21010076":["rocksteady"],"rocksteady":["weapon_21010076","w_gauntlet"]},"frost":{"weapon_21020086":["w_sword"]},"echo":{"weapon_21020106":["whiff","zig"]},"rarity":{"weapon_21020076":["weapon_21020045"],"weapon_21020045":["weapon_21020076"]},"shield_break":{"verdant":["rocksteady"],"rocksteady":["verdant","w_broadblade"]},"affliction_break":{"answer":["weapon_21020045"]}}
		for source_kind in expected[key]:
			var source=run.items.filter(func(p):return p.kind==source_kind)[0]
			var linked=inv.star_links(source,run.items,run).map(func(p):return p.kind)
			ck(expected[key][source_kind].all(func(kind):return kind in linked),"explicit intended partners "+key+" "+source_kind)
	return run

func overview(run:Dictionary)->Dictionary:
	var amount=0;var items=[];var core_links=0;var all_links=0
	for p in run.items:
		amount+=int(costs[p.kind]);var linked=inv.star_links(p,run.items,run)
		all_links+=linked.size()
		if C.items[p.kind].has("v124"):core_links+=linked.size()
		items.append({"uid":p.uid,"kind":p.kind,"name":C.items[p.kind].name,"rarity":C.items[p.kind].rarity,"minimum_cost":costs[p.kind],"acquisition":paths[p.kind],"x":p.x,"y":p.y,"rotation":p.rotation,"links":linked.map(func(target):return {"uid":target.uid,"kind":target.kind,"name":C.items[target.kind].name})})
	return {"item_cost":amount,"core_links":core_links,"all_links":all_links,"items":items,"fixture":run}

func metrics(ctx:Dictionary,side:int)->Dictionary:
	var state=ctx.states[side];var total=ctx.totals[side]
	var out={"hp":state.hp,"max_hp":state.max_hp,"shield_remaining":state.shield,"damage":total.damage,"healing":total.heal,"shield_gained":total.shield,"stamina_wait":total.stamina_wait_seconds,"hp_damage":0.0,"absorbed":0.0,"counter_damage":0.0,"advance_seconds":0.0,"core_star_triggers":0,"natural_attacks":0,"charged_attacks":0,"prepared_attacks":0,"fatigue":total.get("fatigue",0),"core_events":{}}
	out.per_uid={};out.break_shield=0.0
	var core_uids={}
	for p in ctx.builds[side].items:
		if C.items[p.kind].has("v124"):core_uids[p.uid]=p.kind
		out.per_uid[p.uid]={"kind":p.kind,"name":C.items[p.kind].name,"damage":0.0,"hp_damage":0.0,"shield_gained":0.0,"healing":0.0,"counter_damage":0.0,"break_shield":0.0,"star_triggers":0}
	for ev in ctx.events:
		if int(ev.side)==1-side:out.absorbed+=float(ev.get("absorbed",0))
		if int(ev.side)!=side:continue
		if ev.kind!="fatigue":out.hp_damage+=float(ev.get("hp_damage",0))
		if ev.kind=="counter":out.counter_damage+=float(ev.get("hp_damage",0))+float(ev.get("absorbed",0))
		if ev.kind=="cooldown_advance":out.advance_seconds+=float(ev.get("actual_value",ev.value))
		if ev.kind=="trigger" and ev.get("ordinary",false):
			out.natural_attacks+=1
			if ev.get("charged",false):out.charged_attacks+=1
			if ev.get("prepared",false):out.prepared_attacks+=1
		var source=REVIEW.source_uid(ev)
		if ev.kind=="break_shield":out.break_shield+=float(ev.get("actual_value",ev.value))
		if out.per_uid.has(source):
			var row=out.per_uid[source];row.damage+=REVIEW.damage(ev);row.hp_damage+=float(ev.get("hp_damage",0))
			if ev.kind=="counter":row.counter_damage+=REVIEW.damage(ev)
			if ev.kind=="shield":row.shield_gained+=float(ev.get("actual_value",ev.value))
			if ev.kind in ["heal","intro_heal"]:row.healing+=float(ev.get("actual_value",ev.value))
			if ev.kind=="break_shield":row.break_shield+=float(ev.get("actual_value",ev.value))
			if ev.kind=="star_trigger":row.star_triggers+=1
		if core_uids.has(source):
			if ev.kind=="star_trigger":out.core_star_triggers+=1
			var kind=core_uids[source]
			if not out.core_events.has(kind):out.core_events[kind]={}
			out.core_events[kind][ev.kind]=int(out.core_events[kind].get(ev.kind,0))+1
	for pair in [["damage","damage"],["healing","healing"],["shield_gained","shield_gained"],["counter_damage","counter_damage"]]:
		var summed=out.per_uid.values().reduce(func(value,row):return value+float(row[pair[0]]),0.0)
		ck(absf(summed-float(out[pair[1]]))<.00001,"per-UID totals reconcile "+pair[0])
	return out

func measure(a:Dictionary,b:Dictionary,seed_value:int,limit:float=45,fixed_hp:float=0)->Dictionary:
	var before=[a.duplicate(true),b.duplicate(true)];var ctx=battle.begin(a,b,seed_value)
	# Separate finite-HP diagnostics avoid censored 20-second layout windows.
	# Normalize current AND maximum HP together, never continue after death.
	if fixed_hp>0:
		for state in ctx.states:state.hp=fixed_hp;state.max_hp=fixed_hp
	var out={"seed":seed_value,"initial_hp":ctx.states.map(func(s):return {"hp":s.hp,"max_hp":s.max_hp}),"at20":{},"winner":0,"duration":limit}
	for tick in range(1,int(limit*10)+1):
		var time=tick*.1;battle.step(ctx,time)
		if tick==200:out.at20={"sides":[metrics(ctx,0),metrics(ctx,1)],"time":time}
		if ctx.states[0].hp<=0 or ctx.states[1].hp<=0:
			out.winner=0 if ctx.states[0].hp<=0 and ctx.states[1].hp<=0 else 1 if ctx.states[1].hp<=0 else -1
			out.duration=snappedf(time,.1);break
	if out.duration>=45:
		var difference=ctx.states[0].hp/ctx.states[0].max_hp-ctx.states[1].hp/ctx.states[1].max_hp
		out.winner=0 if absf(difference)<.000001 else 1 if difference>0 else -1
	out.sides=[metrics(ctx,0),metrics(ctx,1)]
	out.event_sha256=JSON.stringify(ctx.events).sha256_text()
	ck(a==before[0] and b==before[1],"battle keeps fixtures unchanged")
	if fixed_hp>0:ck(not out.at20.is_empty(),"20-second finite-HP diagnostic completes")
	return out

func same_outcome(a:Dictionary,b:Dictionary)->bool:
	var first=a.duplicate(true);var second=b.duplicate(true);first.erase("seed");second.erase("seed")
	return first==second

func numeric_delta(high:Dictionary,low:Dictionary)->Dictionary:
	var out={}
	for key in high:
		if high[key] is float or high[key] is int:out[key]=float(high[key])-float(low[key])
	return out

func average_samples(samples:Array)->Dictionary:
	var out={}
	if samples.is_empty():return out
	for key in samples[0]:
		if samples[0][key] is float or samples[0][key] is int:out[key]=samples.reduce(func(total,row):return total+float(row[key]),0.0)/samples.size()
	out.per_uid={}
	for uid in samples[0].per_uid:
		out.per_uid[uid]=samples[0].per_uid[uid].duplicate(true)
		for key in samples[0].per_uid[uid]:
			if samples[0].per_uid[uid][key] is float or samples[0].per_uid[uid][key] is int:out.per_uid[uid][key]=samples.reduce(func(total,row):return total+float(row.per_uid[uid][key]),0.0)/samples.size()
	return out

func _initialize()->void:call_deferred("run_measurement")
func run_measurement()->void:
	var started=Time.get_ticks_msec();minimum_costs()
	var quick=OS.get_cmdline_user_args().has("--quick");var seeds=[SEEDS[0]] if quick else SEEDS
	var high={};var low={}
	var report={"simulation_version":C.SIMULATION_VERSION,"catalogue_hash":C.catalogue_hash,"strategy_sha256":FileAccess.get_file_as_string("res://data/items/strategy.json").sha256_text(),"seeds":SEEDS,"scope":{"budget":22,"leader":"hsin","round":7,"supports":[],"capacity":"same 54 neutral cells, nine satchels, capacity cost excluded","cost":"minimum ordinary direct shop price (active, not craft_only) or every recursively costed recipe, zero crafting fee; no starter credit, discount or refresh costs","availability":"all ingredients available; acquisition ordering and supply odds excluded","layout":"deterministic geometry search: eight starts, four coordinate sweeps; core eligible links weight 10, other links weight 1; no battle-result tuning; control minimizes all eligible links","full_combat_hp":"normal begin() HP and max_hp, including item HP; no combat-stat overrides","diagnostic_hp":DIAGNOSTIC_HP,"diagnostic_max_hp":DIAGNOSTIC_HP,"diagnostic_hp_reason":"natural round-7 fights can end before 20s; finite equal HP/max_hp isolates layout before fatigue, not full-fight survivability","window_seconds":20,"limitations":"eight selected builds, not an exhaustive strategy search or a full-run win rate"},"builds":{},"matrix":[],"layout_pairs":[],"summary":{},"determinism":{"identical_across_seeds":true,"seed_repeats_are_not_independent_samples":true}}
	for key in LOADOUTS:
		high[key]=arrange(key,true);low[key]=arrange(key,false)
		report.builds[key]={"name":NAMES[key],"linked":overview(high[key]),"separated":overview(low[key])}
		ck(report.builds[key].linked.item_cost==22 and report.builds[key].separated.item_cost==22,"exact 22-gold minimum cost "+key)
		ck(high[key].items.map(func(p):return p.kind)==low[key].items.map(func(p):return p.kind),"same items in layout pair "+key)
		report.summary[key]={"wins":0,"losses":0,"draws":0,"games":0,"opponents":{},"mean_layout_delta_20":{},"mean_linked_20":{}}
	print("V124 benchmark fixtures ready; cost and layout validation failures=",failures.size())
	var first_results={}
	for a in LOADOUTS:
		for b in LOADOUTS:
			if a==b:continue
			var first={}
			for seed_value in seeds:
				var result=measure(high[a],high[b],seed_value)
				if first.is_empty():first=result;first_results[a+":"+b]=result
				elif not same_outcome(first,result):report.determinism.identical_across_seeds=false
				report.matrix.append({"left":a,"right":b,"result":result})
				for key in [a,b]:
					var score=int(result.winner)*(1 if key==a else -1);var summary=report.summary[key]
					summary.games+=1;summary["wins" if score>0 else "losses" if score<0 else "draws"]+=1
					var other=b if key==a else a
					if not summary.opponents.has(other):summary.opponents[other]={"wins":0,"losses":0,"draws":0}
					summary.opponents[other]["wins" if score>0 else "losses" if score<0 else "draws"]+=1
	for key in LOADOUTS:
		var full_samples=[]
		for opponent in LOADOUTS:
			if opponent==key:continue
			for side in 2:
				var result=first_results[key+":"+opponent] if side==0 else first_results[opponent+":"+key]
				var sample=result.sides[side].duplicate(true);sample.duration=result.duration;sample.initial_hp=result.initial_hp[side].hp
				full_samples.append(sample)
		report.summary[key].mean_natural_full=average_samples(full_samples)
	if quick:
		print("QUICK_STRATEGY_V124 ",JSON.stringify({"catalogue_hash":C.catalogue_hash,"elapsed_seconds":(Time.get_ticks_msec()-started)/1000.0,"checks":checks,"failures":failures,"summary":report.summary}))
		quit(1 if not failures.is_empty() else 0);return
	print("V124 full-combat matrix ready; measuring same-item rearrangements")
	var window_results={}
	for a in LOADOUTS:
		for b in LOADOUTS:
			if a!=b:window_results[a+":"+b]=measure(high[a],high[b],SEEDS[0],20,DIAGNOSTIC_HP)
	for key in LOADOUTS:
		var deltas=[];var linked_samples=[]
		for opponent in LOADOUTS:
			if key==opponent:continue
			for side in 2:
				var good=window_results[key+":"+opponent] if side==0 else window_results[opponent+":"+key]
				var separated=measure(low[key],high[opponent],SEEDS[0],20,DIAGNOSTIC_HP) if side==0 else measure(high[opponent],low[key],SEEDS[0],20,DIAGNOSTIC_HP)
				ck(good.initial_hp==separated.initial_hp,"layout comparison preserves initial HP and max_hp")
				if good.at20.is_empty() or separated.at20.is_empty():continue
				var linked_metrics=good.at20.sides[side];var separated_metrics=separated.at20.sides[side]
				var delta=numeric_delta(linked_metrics,separated_metrics);deltas.append(delta);linked_samples.append(linked_metrics)
				report.layout_pairs.append({"build":key,"opponent":opponent,"side":side,"seed":SEEDS[0],"linked":linked_metrics,"separated":separated_metrics,"delta":delta})
		for metric in deltas[0] if not deltas.is_empty() else []:
			report.summary[key].mean_layout_delta_20[metric]=deltas.reduce(func(total,row):return total+float(row[metric]),0.0)/deltas.size()
			report.summary[key].mean_linked_20[metric]=linked_samples.reduce(func(total,row):return total+float(row[metric]),0.0)/linked_samples.size()
	report.determinism.swapped_side_result_differences=0
	for a in LOADOUTS:
		for b in LOADOUTS:
			if a<b and int(first_results[a+":"+b].winner)!=-int(first_results[b+":"+a].winner):report.determinism.swapped_side_result_differences+=1
	report.determinism.ordered_matchups=LOADOUTS.size()*(LOADOUTS.size()-1);report.determinism.seed_repeated_games=report.matrix.size();report.determinism.same_item_layout_pairs=report.layout_pairs.size()
	report.checks=checks;report.failures=failures;report.elapsed_seconds=(Time.get_ticks_msec()-started)/1000.0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	FileAccess.open(OUT+"balance.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	FileAccess.open(OUT+"balance.md",FileAccess.WRITE).store_string(markdown(report))
	print("STRATEGY_MEASUREMENT_V124 ",checks," checks, ",failures.size()," failures; ",report.elapsed_seconds," seconds")
	for key in report.summary:print(key," ",JSON.stringify(report.summary[key]))
	quit(1 if not failures.is_empty() else 0)

func markdown(report:Dictionary)->String:
	var out="# V124 等投入组合基准\n\n"
	out+="入口：`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/scenarios/measure_strategy_v124.gd`。快速复测加 `-- --quick`，只跑首个种子的完整胜负矩阵并打印结果，不覆盖报告。原始数据与每件物品的最低成本路径、坐标、旋转及实际星位连接保存在 [balance.json](balance.json)。\n\n"
	out+="模拟版本 `%s`；目录 `%s`；策略文件 `%s`。\n\n"%[report.simulation_version,report.catalogue_hash,report.strategy_sha256]
	out+="## 控制条件与边界\n\n每套物品按当前完整配方图的最低获取成本恰为 **22 金币**。算法比较可直接出售物品的实际 `price` 与全部配方输入的递归成本；合成不加费用，不使用旧 `v75.cost` 作为购买价。无开局免费物品抵扣、折扣、刷新成本。假定材料已经可得，不能据此推断商店供给或完整局胜率。\n\n"
	out+="同一领队心、回合 7、无队友、九只中性行囊提供相同 9×6 空间。容量是共同实验条件，未计入物品预算，也不声称游戏内可买九只初始行囊。完整战斗用正常 `begin()` 的生命与最大生命，保留物品自身生命收益，未改战斗状态。每套均通过 `validate_run` 和 `validate_ghost`，并断言核心指定搭档确实连星。\n\n"
	out+="关联摆位由同一确定性几何搜索产生：8 个起点、最多 4 轮单物品坐标改进，优先核心星位连接，其余合资格连接其次，不按战斗胜负调位置。双高品质对照也同样寻找相互连星。搜索不是全局最优证明。分离摆位保持同一物品、UID、金币和口袋，合法消除所有可生效星位连接。\n\n"
	out+="## 成本与连接\n\n|构筑|物品最低成本|核心连接 / 全部连接|分离连接|\n|---|---|---:|---:|\n"
	for key in LOADOUTS:
		var build=report.builds[key];var names=[]
		for item in build.linked.items:names.append("%s %d"%[item.name,item.minimum_cost])
		out+="|%s|%s = 22|%d / %d|%d|\n"%[NAMES[key]," + ".join(names),build.linked.core_links,build.linked.all_links,build.separated.all_links]
	out+="\n## 正常完整战斗\n\n每对构筑交换左右位置，使用种子 124、661、2026；共 168 场，每套参加 42 场。种子重复是否完全相同（包括事件哈希）：**%s**。若相同，重复只验证确定性，不能当作 3 倍独立样本。交换左右后胜负变化的配对数：%d。疲劳按真实规则从 22 秒开始。\n\n"%[str(report.determinism.identical_across_seeds),report.determinism.swapped_side_result_differences]
	out+="|构筑|胜 / 负 / 平|"
	for key in LOADOUTS:out+=NAMES[key]+"|"
	out+="\n|---|---|"+"---|".repeat(LOADOUTS.size())+"\n"
	for key in LOADOUTS:
		var summary=report.summary[key];out+="|%s|%d / %d / %d|"%[NAMES[key],summary.wins,summary.losses,summary.draws]
		for opponent in LOADOUTS:
			if key==opponent:out+="—|";continue
			var matchup=summary.opponents[opponent];out+="%d / %d / %d|"%[matchup.wins,matchup.losses,matchup.draws]
		out+="\n"
	out+="\n自然完整战斗的均值（只取首种子、双方位置各一次；战斗时长不同，以下不能直接当固定窗口 DPS）：\n\n|构筑|初始 HP|时长秒|伤害|获得盾|实际挡伤|治疗|反击伤害|结束 HP|\n|---|---:|---:|---:|---:|---:|---:|---:|---:|\n"
	for key in LOADOUTS:
		var m=report.summary[key].mean_natural_full
		out+="|%s|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|\n"%[NAMES[key],m.initial_hp,m.duration,m.damage,m.shield_gained,m.absorbed,m.healing,m.counter_damage,m.hp]
	out+="\n护盾反击的实际来源拆分（自然完整战斗均值；反击列是伤害列的一部分）：\n\n|来源|伤害|其中反击|获得盾|治疗|\n|---|---:|---:|---:|---:|\n"
	for row in report.summary.guard.mean_natural_full.per_uid.values():out+="|%s|%.2f|%.2f|%.2f|%.2f|\n"%[row.name,row.damage,row.counter_damage,row.shield_gained,row.healing]
	out+="\n实际挡伤只可归属团队，不按护盾来源臆造分摊。完整 per-UID 量在 JSON 中；削盾事件按引擎的实际攻击者归因，材料给攻击附加的削盾不能仅凭其自身 UID 的零值判为无效。\n"
	out+="\n## 同物品换摆位：20 秒边际收益\n\n自然回合 7 对战有早于 20 秒结束的案例，因此这里单独进行有限生命诊断：在 `begin()` 后将双方 **HP 和 max_hp 同时设为 300**，其余战斗状态保持原值。该诊断用于隔离摆位价值，不表示自然生存能力，也不混入上方胜负矩阵；不在阵亡后继续计数。\n\n下表为关联摆位减去零连接摆位，对其余七套关联构筑分别交换左右，共 14 个对照的均值。双方使用相同初始生命与最大生命，20 秒窗口早于疲劳；所有诊断必须存活至窗口结束。伤害含敌方实际吸收，挡伤只统计真正被己方护盾吸收的伤害，耐力等待按全队时间计。负数保留。\n\n"
	out+="|构筑|伤害 Δ|HP 伤害 Δ|挡伤 Δ|治疗 Δ|获得盾 Δ|耐力等待秒 Δ|自然攻击 Δ|核心亮星次数 Δ|\n|---|---:|---:|---:|---:|---:|---:|---:|---:|\n"
	for key in LOADOUTS:
		var d=report.summary[key].mean_layout_delta_20
		if d.is_empty():continue
		out+="|%s|%+.2f|%+.2f|%+.2f|%+.2f|%+.2f|%+.2f|%+.2f|%+.2f|\n"%[NAMES[key],d.damage,d.hp_damage,d.absorbed,d.healing,d.shield_gained,d.stamina_wait,d.natural_attacks,d.core_star_triggers]
	out+="\n关联摆位在同一 300 HP 诊断下的绝对量（七对手、两侧均值）：\n\n|构筑|20 秒伤害|实际挡伤|反击伤害|自然攻击数|耐力等待秒|\n|---|---:|---:|---:|---:|---:|\n"
	for key in LOADOUTS:
		var m=report.summary[key].mean_linked_20
		if not m.is_empty():out+="|%s|%.2f|%.2f|%.2f|%.2f|%.2f|\n"%[NAMES[key],m.damage,m.absorbed,m.counter_damage,m.natural_attacks,m.stamina_wait]
	out+="\n## 结果解释与建议\n\n"
	for key in LOADOUTS:
		var summary=report.summary[key];var weak=[];var strong=[]
		for other in summary.opponents:
			var row=summary.opponents[other]
			if row.losses>row.wins:weak.append(NAMES[other])
			elif row.wins>row.losses:strong.append(NAMES[other])
		out+="- **%s**：优势对手 %s；弱势对手 %s。"%[NAMES[key],"、".join(strong) if not strong.is_empty() else "无","、".join(weak) if not weak.is_empty() else "无"]
		if not summary.mean_layout_delta_20.is_empty():out+="同物品连星平均增加 %.2f 伤害、%.2f 实际挡伤。"%[summary.mean_layout_delta_20.damage,summary.mean_layout_delta_20.absorbed]
		if summary.wins==summary.games:out+=" **本样本全胜，是优势集中警报，不支持已平衡结论。**"
		out+="\n"
	out+="\n新增的两套破盾构筑分别检验苍鳞千嶂的盾转伤害与削盾、镭射切变＋应答的减益条件削盾。应答组合为维持 22 币而没有第二把武器，主动放弃镭射的伙伴推进；它并非无代价的反制插件。物品 ID、条件搭档与连星证据全部保存在 JSON。\n\n"
	out+="建议先用上方来源量检验千般渡反击、坚岩供盾、陆龟治疗的共同收益，不能只因名称叫反击就把全部优势归于反击伤害。破盾路线需要以实际削掉的护盾和机会成本衡量；只增加破盾文案或名义数值不证明克制成立。耐力等待的实测值很少时，也不能把弱构筑的失败解释为严重缺耐。\n\n"
	out+="本轮只测量，不改生产数值。不能以品质、配方层数或点亮星位的数量直接代替战斗价值；优先复核全胜／全败构筑和零收益星效，随后扩大到同投入替代组件、队友、不同回合与真实供给采购。此处八套都是人工选择样本，尚不能宣称全部路线均衡，也不能声称任一套是全局最优。\n\n"
	out+="验证：%d 检查，%d 失败；耗时 %.2f 秒。未读写真实 Storage，未改生产规则。\n"%[report.checks,report.failures.size(),report.elapsed_seconds]
	return out
