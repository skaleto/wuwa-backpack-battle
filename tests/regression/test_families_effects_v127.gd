extends SceneTree
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const B=preload("res://scripts/battle/battle_v127.gd")
const M=preload("res://scripts/battle/material_effects.gd")
var inv=I.new()
var failures=0
var checks=0
var spec:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/items/families.json"))
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func empty()->Dictionary:
	var r=inv.new_run("hsin",127);r.items=[];r.bags=[];r.primary="";r.roster=[];r.supports=[]
	for y in [0,2,4]:
		for x in [0,3,6]:
			var bag=inv.make_piece("satchel","bag_%d_%d"%[x,y]);bag.x=x;bag.y=y;r.bags.append(bag)
	return r
func put(r:Dictionary,kind:String,uid:String)->Dictionary:
	var p=inv.first_fit(inv.make_piece(kind,uid),r.items,r.bags)
	ck(not p.is_empty(),"legal placement exists: "+kind)
	if not p.is_empty():r.items.append(p)
	return p
func linked_run(kind:String,targets:Array=["w_sword"])->Dictionary:
	var r=empty();var source=inv.make_piece(kind,"part");source.x=1;source.y=1;r.items.append(source)
	for index in targets.size():
		var found={}
		for rotation in 4:
			if not found.is_empty():break
			for y in 6:
				if not found.is_empty():break
				for x in 9:
					var target=inv.make_piece(targets[index],"partner"+str(index));target.x=x;target.y=y;target.rotation=rotation
					if not inv.can_place(target,r.items,r.bags):continue
					if inv.star_links(source,r.items+[target],r).any(func(i):return i.uid==target.uid):found=target;break
		ck(not found.is_empty(),"real star placement: "+kind+" / "+targets[index])
		if not found.is_empty():r.items.append(found)
	ck(inv.bags_legal(r.bags) and r.items.all(func(i):return inv.can_place(i,r.items,r.bags)),"nonoverlapping legal board: "+kind)
	return r
func simple(kind:String)->Dictionary:
	var r=empty();put(r,kind,"part");return r
func events(ctx:Dictionary,uid:String,kind:String)->Array:
	return ctx.events.filter(func(e):return e.uid==uid and e.kind==kind)
func sum_event(ctx:Dictionary,uid:String,kind:String)->float:
	return events(ctx,uid,kind).reduce(func(v,e):return v+float(e.get("actual_value",e.value)),0.0)
func roots(b,ctx:Dictionary,attacker:Dictionary,t:float,pieces:int=1)->void:
	var actions=[]
	for _i in pieces:actions.append({"type":"damage","value":1,"item":attacker,"ordinary":true,"kind":"attack"})
	ctx.pending.append({"side":1,"root_item":attacker,"actions":actions});b.commit_pending(ctx,t)
func noise_plan_cases(b)->void:
	# The same pre-tick noise must price the replay in both seats, even if
	# this tick adds a layer or cleanses one before the other side activates.
	for entry in [[3,false,true],[2,true,false],[0,true,false],[3,true,true],[1,false,true],[3,false,false,true]]:
		for boosted in [false,true]:
			var attack=linked_run("relic_noise_chime");var defense=simple("provision_clear_tea");var outcomes=[]
			for side in 2:
				var ctx=b.begin(attack,defense,127) if side==0 else b.begin(defense,attack,127)
				if entry[0]>0:b.apply_noise_internal(ctx,side,attack.items[0],entry[0],0,false)
				var expires=entry.size()>3 and entry[3]
				if expires:ctx.states[1-side].noise_until=.1
				if boosted:ctx.team[side].noise_boost_until=1
				ctx.events=[];ctx.states[side].charge=6;ctx.progress[side][attack.items[1].uid]=1
				if entry[1]:b.own(ctx,side,attack.items[0]).clocks.noise=.1
				if entry[2]:b.own(ctx,1-side,defense.items[0]).material_next=.1
				b.step(ctx,.1)
				var reward=events(ctx,"part","derived").reduce(func(total,e):return total+float(e.hp_damage)+float(e.absorbed),0.0)
				var expected=0.0 if expires else minf(4,float(entry[0])*(1.25 if boosted else 1.0))
				ck(is_equal_approx(reward,expected),"noise replay uses pre-source contributions and bonus, side="+str(side)+" case="+str(entry)+" boost="+str(boosted))
				ck(ctx.states[1-side].noise==(0 if expires else entry[0]+int(entry[1])-int(entry[2])),"same-tick noise application, cleansing and expiry still commit")
				ck(ctx.icd[side].has("relic_noise_chime:family")==bool(expected>0),"same-tick new or expired noise cannot consume a gate absent at planning")
				ck(not ctx.has("family_plan"),"planning contribution snapshot never leaks beyond its tick")
				outcomes.append(reward)
			ck(outcomes[0]==outcomes[1],"noise payoff is seat independent")
func _initialize()->void:
	preload("res://tests/fixtures/catalog_fixture_v127.gd").apply()
	ck(spec.new_items.size()==24 and spec.recipes.size()==36,"24 additions and 36 meaningful recipe IDs")
	if spec.new_items.keys().any(func(k):return not C.items.has(k)):
		ck(false,"V127 catalog overlay must be installed before combat suite");finish();return
	var families={};var purchasable=0
	for k in spec.new_items:
		var n=C.profile(k);families[n.family]=int(families.get(n.family,0))+1
		if not n.craft_only:purchasable+=1
		ck(int(n.introduced_version)==127 and not C.is_tag(k,"weapon"),"new nonweapon profile: "+k)
	ck(families.size()==8 and families.values().all(func(v):return v==3),"eight families with three additions each")
	ck(purchasable==8,"only eight new bases enter natural supply")
	var b=B.new();var enemy=simple("w_sword")
	var bird=simple("violet");var bird_ctx=b.begin(bird,enemy,127)
	ck(sum_event(bird_ctx,"part","haste")==1 and b.own(bird_ctx,0,bird.items[0]).clocks.has("stance"),"violet retains one opening haste alongside existing parry clock")
	# Every addition has a useful real combat output before it is used as an ingredient.
	for k in spec.new_items:
		var definition=spec.new_items[k];var has_stars=not definition.stars.is_empty()
		var targets=["whiff","zig"] if definition.profile.family=="acoustics" else ["w_sword"]
		var r=linked_run(k,targets) if has_stars and definition.profile.get("star_categories",[])!=["provision"] else simple(k)
		if definition.profile.family=="food":put(r,"w_broadblade","blade")
		var unchanged=r.duplicate(true);var ctx=b.begin(r,enemy,127)
		ctx.states[0].max_hp=300;ctx.states[0].hp=120;ctx.states[0].stamina=0;ctx.states[1].max_hp=300;ctx.states[1].hp=300;ctx.states[1].shield=40
		for tick in range(1,181):b.step(ctx,float(tick)/10)
		var useful=ctx.events.any(func(e):return (e.uid=="part" and float(e.value)>0 and e.kind in ["heal","shield","charge","stamina","noise","frost","derived","counter","break_shield"]) or (e.kind=="star_trigger" and e.get("source_uid","")=="part") or (e.kind=="cooldown_advance" and e.get("source_uid","")=="part"))
		ck(useful,"standalone effect in live combat: "+k)
		ck(r==unchanged,"combat does not consume or rewrite item: "+k)
		ck(ctx.events.size()<1500,"bounded event output: "+k)
		ck(not ctx.events.any(func(e):return e.uid=="part" and e.kind in ["derived","counter"] and e.get("ordinary",false)),"family payoff stays derived: "+k)
	# Star links restrict reactions, not the source's unconditional baseline.
	for k in ["relic_march_lunchbox","relic_emergency_lunchbox","relic_pulse_gear","relic_breaker_wedge","relic_crack_driver","relic_breach_scope","relic_noise_chime","relic_frost_condenser","relic_shatter_prism"]:
		var alone=simple(k);var alone_ctx=b.begin(alone,enemy,127)
		alone_ctx.states[0].max_hp=300;alone_ctx.states[0].hp=120;alone_ctx.states[0].stamina=0
		for tick in range(1,121):b.step(alone_ctx,float(tick)/10)
		ck(alone_ctx.events.any(func(e):return e.uid=="part" and float(e.get("actual_value",e.value))>0 and e.kind in ["heal","shield","charge","stamina","noise","frost"]),"unlinked star source retains its unconditional output: "+k)
	# Core inheritance and mutually distinct terminal choices.
	for k in ["relic_lunchbox","relic_march_lunchbox","relic_emergency_lunchbox","dragon_food"]:
		ck(C.profile(k).material_effect.value>=2 and C.profile(k).material_effect.period==6,"fish soup core survives: "+k)
	ck(C.profile("relic_march_lunchbox").get("emergency",0)==0 and C.profile("relic_emergency_lunchbox").get("opening_stamina_discount",0)==0,"meal branches do not inherit each other's payoff")
	ck(C.profile("provision_strong_tea").healAmount>C.profile("provision_clear_tea").healAmount and C.profile("provision_strong_tea").get("material_effect",{}).is_empty(),"tea branches trade healing rate for cleansing")
	var r=empty();put(r,"relic_march_lunchbox","part");put(r,"rations","rations");var blade=put(r,"w_broadblade","blade")
	var ctx=b.begin(r,enemy,127)
	ck(is_equal_approx(ctx.states[0].stamina_discount,.15) and is_equal_approx(b.stamina_cost(ctx,0,blade),C.profile("w_broadblade").stamina*.85),"march ration discount retains shared maximum, never stacks")
	r=empty();put(r,"relic_emergency_lunchbox","part");put(r,"nutrition","nutrition");ctx=b.begin(r,enemy,127);ctx.events=[];ctx.states[0].hp=20
	b.use_threshold_provisions(ctx,0,1);b.use_threshold_provisions(ctx,0,2)
	ck(is_equal_approx(sum_event(ctx,"part","heal")+sum_event(ctx,"nutrition","heal"),18),"inherited emergency and nutrition share one real rescue")
	# No noise means no gate, no feedback; a later valid charged root still pays.
	r=linked_run("relic_noise_chime");ctx=b.begin(r,enemy,127);ctx.events=[];ctx.states[0].charge=6
	b.activate(ctx,0,r.items[1],1);b.commit_pending(ctx,1)
	ck(not ctx.icd[0].has("relic_noise_chime:family") and events(ctx,"part","derived").is_empty(),"empty noise does not consume interval")
	b.apply_noise(ctx,0,r.items[0],3,1.5);var noise_next=ctx.states[1].noise_next;ctx.states[0].charge=6
	b.activate(ctx,0,r.items[1],2);b.natural(ctx,0,r.items[1],"charged",2);b.commit_pending(ctx,2)
	ck(events(ctx,"part","derived").size()==1 and is_equal_approx(sum_event(ctx,"part","derived"),3),"one charged natural root pays exactly one current noise tick")
	ck(ctx.states[1].noise==3 and ctx.states[1].noise_next==noise_next,"noise replay changes neither layers nor tick clock")
	noise_plan_cases(b)
	r=linked_run("relic_recorder",["dreamless"]);ctx=b.begin(r,enemy,127);ctx.events=[]
	b.activate(ctx,0,r.items[1],1);b.commit_pending(ctx,1)
	ck(events(ctx,"part","derived").is_empty() and b.own(ctx,0,r.items[0]).eco_count==1,"six-hit echo supplies one recorder root")
	b.activate(ctx,0,r.items[1],5);b.commit_pending(ctx,5)
	ck(events(ctx,"part","derived").size()==1 and is_equal_approx(sum_event(ctx,"part","derived"),5),"recorder pays once at the whole-attack copy cap")
	# Relay observes roots during its reward interval; only the payout is gated.
	for repeated in [false,true]:
		r=linked_run("relic_echo_relay",["whiff","zig"]);ctx=b.begin(r,enemy,127);ctx.events=[]
		b.activate(ctx,0,r.items[1],.5);b.commit_pending(ctx,.5)
		b.activate(ctx,0,r.items[2],1);b.commit_pending(ctx,1)
		b.activate(ctx,0,r.items[1],4);b.commit_pending(ctx,4)
		b.activate(ctx,0,r.items[1] if repeated else r.items[2],5);b.commit_pending(ctx,5)
		var advances=ctx.events.filter(func(e):return e.kind=="cooldown_advance" and e.get("source_uid","")=="part")
		ck(advances.size()==(1 if repeated else 2),"relay uses actual previous root across interval, repeated="+str(repeated))
	# Conditional damage cannot spend a gate while the target lacks its condition.
	for pair in [["relic_breach_scope","shield",2],["relic_shatter_prism","frost",3]]:
		r=linked_run(pair[0]);ctx=b.begin(r,enemy,127);ctx.events=[]
		if pair[1]=="shield":ctx.states[1].shield=100
		b.activate(ctx,0,r.items[1],1);b.commit_pending(ctx,1)
		ck(events(ctx,"part","derived").is_empty() and not ctx.icd[0].has(pair[0]+":family"),"absent target condition does not pay: "+pair[0])
		if pair[1]=="shield":ctx.states[1].shield=0
		else:b.apply_frost_internal(ctx,0,r.items[0],2,1.5,true)
		b.activate(ctx,0,r.items[1],2);b.commit_pending(ctx,2)
		ck(is_equal_approx(sum_event(ctx,"part","derived"),pair[2]),"condition enables bounded added damage: "+pair[0])
	# Pending frost only spends count/interval after successful resolution.
	r=linked_run("relic_frost_condenser");ctx=b.begin(r,enemy,127);ctx.events=[];ctx.states[1].frost_immune_until=100
	for t in [1,2,3]:b.activate(ctx,0,r.items[1],t);b.commit_pending(ctx,t)
	ck(b.own(ctx,0,r.items[0]).card_count==3 and not ctx.icd[0].has("relic_frost_condenser:card_star"),"immune target preserves prepared frost and interval")
	ctx.states[1].frost_immune_until=0;b.activate(ctx,0,r.items[1],5);b.commit_pending(ctx,5)
	ck(ctx.states[1].frost==1 and b.own(ctx,0,r.items[0]).card_count==0,"prepared frost pays once after immunity ends")
	# Recoil uses real absorption, one root per multihit, and spends actual remaining shield.
	r=simple("relic_recoil_guard");ctx=b.begin(r,enemy,127);ctx.states[0].shield=20;ctx.events=[]
	roots(b,ctx,enemy.items[0],1,6)
	ck(events(ctx,"part","counter").is_empty() and b.own(ctx,0,r.items[0]).family_count==1,"six segments count as one blocked natural attack")
	roots(b,ctx,enemy.items[0],2)
	ck(events(ctx,"part","counter").size()==1 and is_equal_approx(sum_event(ctx,"part","counter"),4) and is_equal_approx(sum_event(ctx,"part","shield_spend"),2),"two shield points buy exactly four counter damage")
	ck(b.own(ctx,0,r.items[0]).family_count==0 and ctx.pending.is_empty(),"derived counter cannot feed its own root")
	ctx=b.begin(r,enemy,127);ctx.states[0].shield=1;ctx.events=[];b.own(ctx,0,r.items[0]).family_count=1
	roots(b,ctx,enemy.items[0],1)
	ck(not ctx.icd[0].has("relic_recoil_guard:family") and b.own(ctx,0,r.items[0]).family_count==2,"no remaining shield preserves counter threshold and interval")
	ctx.states[0].shield=5;roots(b,ctx,enemy.items[0],2)
	ck(is_equal_approx(sum_event(ctx,"part","counter"),4),"counter can pay on the next real block")
	# An unused prepared hit should not flash again just because its clock passed.
	for prepared_kind in ["relic_breaker_wedge","magnifier"]:
		r=linked_run(prepared_kind);ctx=b.begin(r,enemy,127);ctx.events=[]
		var period=float(C.profile(prepared_kind).material_effect.period)
		M.tick(b,ctx,0,r.items[0],period);M.tick(b,ctx,0,r.items[0],period*2)
		ck(ctx.events.filter(func(e):return e.kind=="star_trigger" and e.get("source_uid","")=="part").size()==1,"unchanged permanent preparation does not announce a second benefit: "+prepared_kind)
	r=simple("relic_breaker_wedge");ctx=b.begin(r,enemy,127);ctx.events=[]
	ctx.icd[0].erase("relic_breaker_wedge:family_opening_shield");ctx.states[0].shield=ctx.states[0].max_hp*.4
	b.opening(ctx,0,r.items[0])
	ck(not ctx.icd[0].has("relic_breaker_wedge:family_opening_shield") and events(ctx,"part","shield").is_empty(),"full shield does not consume the small opening-shield gate or announce a benefit")
	ctx.states[0].shield-=3;b.opening(ctx,0,r.items[0])
	ck(is_equal_approx(sum_event(ctx,"part","shield"),3),"opening shield consumes its gate only with a real gain")
	# Both sides see the same conditions and bounded behavior under a full live loop.
	var left=linked_run("relic_noise_chime");var right=linked_run("relic_shatter_prism")
	var left_copy=left.duplicate(true);var right_copy=right.duplicate(true)
	var ab=b.simulate(left,right,127,false);var ba=b.simulate(right,left,127,false)
	ck(ab.duration>0 and ba.duration>0,"full simulation completes with both seat orders")
	ck(left==left_copy and right==right_copy,"full simulation remains read-only")
	if "--measure" in OS.get_cmdline_user_args():measure_recipes()
	finish()

func useful_place(r:Dictionary,kind:String,uid:String)->void:
	var best={};var best_score=-1
	for rotation in 4:
		for y in 6:
			for x in 9:
				var p=inv.make_piece(kind,uid);p.x=x;p.y=y;p.rotation=rotation
				if not inv.can_place(p,r.items,r.bags):continue
				var score=inv.star_links(p,r.items+[p],r).size()
				for source in r.items:
					if inv.star_links(source,r.items+[p],r).any(func(i):return i.uid==p.uid):score+=1
				if score>best_score:best=p;best_score=score
	ck(not best.is_empty(),"comparison has legal room: "+kind)
	if not best.is_empty():r.items.append(best)

func measure_build(kinds:Array,reinforced:bool=false)->Dictionary:
	var first=str(kinds[0]);var n=C.profile(first)
	var acoustic=n.get("family","")=="acoustics" or first in ["tuner","tube","puppet","elegance"]
	var r=empty()
	# Shared weapons never move between the ingredient and product cases.
	# Echo allies stay on the right so these ordinary weapon stars cannot gain
	# unrelated charge/haste from a different greedy packing of the new part.
	for entry in [["w_sword",0,0],["w_broadblade",0,2],["w_pistol",0,4],["cool_tea",5,0],["spicy_meat",6,0]]:
		var p=inv.make_piece(entry[0],"common_"+entry[0]);p.x=entry[1];p.y=entry[2];r.items.append(p)
	if acoustic:
		var source=inv.make_piece(first,"part");source.x=5;source.y=1;r.items.append(source)
		for k in ["echo_jade_snake","echo_aureate"]:
			var found={}
			for y in 6:
				if not found.is_empty():break
				for x in range(5,9):
					var p=inv.make_piece(k,"common_"+k);p.x=x;p.y=y
					if inv.can_place(p,r.items,r.bags) and inv.star_links(source,r.items+[p],r).any(func(i):return i.uid==p.uid):found=p;break
			ck(not found.is_empty(),"comparison has two real echo links: "+first)
			if not found.is_empty():r.items.append(found)
	else:
		var echo=inv.make_piece("echo_jade_snake","common_echo_jade_snake");echo.x=8;echo.y=4;r.items.append(echo)
		useful_place(r,first,"part")
	for index in range(1,kinds.size()):useful_place(r,kinds[index],"ingredient"+str(index))
	if reinforced:useful_place(r,"rocksteady","reinforcement")
	ck(inv.collection_legal(r.items,r.leader) and r.items.all(func(i):return inv.can_place(i,r.items,r.bags)),"comparison board and ownership are legal")
	return r

func probe(r:Dictionary,enemy:Dictionary,side:int)->Dictionary:
	var b=B.new();var ctx=b.begin(r,enemy,127) if side==0 else b.begin(enemy,r,127)
	for state in ctx.states:state.hp=300;state.max_hp=300
	for tick in range(1,301 if "--long" in OS.get_cmdline_user_args() else 201):b.step(ctx,float(tick)/10)
	var out={"dealt":0.0,"lost":300-float(ctx.states[side].hp),"shield":float(ctx.states[side].shield),"heal":0.0,"stamina":0.0,"noise":0.0,"frost":0.0,"counter":0.0,"wait":float(ctx.totals[side].stamina_wait_seconds),"part_derived":0.0,"part_advance":0.0,"charged":0.0}
	for e in ctx.events:
		if int(e.side)!=side:continue
		var v=float(e.get("actual_value",e.value))
		if e.kind in ["attack","derived","counter","noise_tick"]:out.dealt+=v
		if e.kind in ["heal","stamina","noise","frost","counter"]:out[e.kind]+=v
		if e.kind=="derived" and e.uid=="part":out.part_derived+=v
		if e.kind=="cooldown_advance" and e.get("source_uid","")=="part":out.part_advance+=v
		if e.kind=="trigger" and e.get("charged",false):out.charged+=1
	return out

func measure_recipes()->void:
	# Same acquisition: before contains the exact two ingredients, after their
	# zero-fee product. Shared allies and opponents are identical in both forms.
	# This is a fixed 20-second combat diagnostic, not a shop or win-rate claim.
	var ids=["F127-01","F127-02","F127-03","F127-07","F127-08","F127-11","F127-12","F127-13","F127-16","F127-17","F127-18","F127-21","F127-22","F127-25","F127-26","F127-27","F127-28","F127-31","F127-32","F127-33","F127-36","F127-37","F127-38"]
	if "--focus" in OS.get_cmdline_user_args():ids=["F127-12","F127-16","F127-17","F127-18","F127-22","F127-37"]
	var opponent=empty()
	for k in ["w_sword","w_broadblade","w_pistol","relic_layered_guard"]:put(opponent,k,"enemy_"+k)
	for id in ids:
		var recipe=spec.recipes.filter(func(r):return r.id==id)[0]
		for reinforced in ([false,true] if id=="F127-22" else [false]):
			var before=measure_build([recipe.base]+recipe.materials,reinforced);var after=measure_build([recipe.target],reinforced)
			var row={"recipe":id,"reinforced":reinforced,"before":{},"after":{}}
			for label in ["before","after"]:
				var run=before if label=="before" else after;var unchanged=run.duplicate(true)
				var left=probe(run,opponent,0);var right=probe(run,opponent,1)
				for key in left:row[label][key]=snappedf((left[key]+right[key])*.5,.01)
				ck(run==unchanged,"ingredient comparison preserves owned state")
			print("F127_COMPARE ",JSON.stringify(row))
	# Acquisition lower bound: buy the currently purchasable leaves at their
	# listed prices, then relax real recipes. Excludes rerolls/availability.
	var minimum={};var acquisition_run=empty();acquisition_run.round=99
	for k in C.items:
		var n=C.profile(k)
		minimum[k]=float(n.get("shop_price",n.get("cost",INF))) if inv.shop_eligible(acquisition_run,k) and not C.is_tag(k,"keepsake") else INF
	for _pass in C.items.size():
		var changed=false
		for recipe in C.combinations:
			var price=float(minimum.get(recipe.base,INF))+float(recipe.get("fee",0))
			for material in recipe.materials:price+=float(minimum.get(material,INF))
			if price<float(minimum.get(recipe.target,INF)):minimum[recipe.target]=price;changed=true
		if not changed:break
	var costs={}
	for k in spec.new_items:costs[k]=minimum[k];ck(is_finite(float(minimum[k])),"new part has a purchasable-leaf recipe route: "+k)
	for recipe in spec.recipes:
		for ingredient in [recipe.base]+recipe.materials:ck(is_finite(float(minimum.get(ingredient,INF))),"recipe ingredient has an actual shop acquisition route: "+recipe.id+" / "+ingredient)
	print("F127_ACQUISITION_LOWER_BOUND ",JSON.stringify(costs))
func finish()->void:
	print("FAMILIES_EFFECTS_V127 ",checks," checks, ",failures," failures");quit(1 if failures else 0)
