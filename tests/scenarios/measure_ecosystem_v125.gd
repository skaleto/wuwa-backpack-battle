extends SceneTree
## Isolated measurements. Writes only build/qa/ecosystem-v125/balance*. No Storage.
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const B=preload("res://scripts/battle/battle.gd")
const REVIEW=preload("res://scripts/battle/battle_review.gd")
const SHOP=preload("res://scripts/shop/shop_v75.gd")
const OUT="res://build/qa/ecosystem-v125/"
const SEEDS=[125,661,2026]
const HP=300.0
var inv=I.new()
var checks=0
var failures=[]
var costs={}
var paths={}
var earliest={}
var earliest_paths={}
var leaves={}
var candidates={}
var links_allowed=[]
var current_key=""
var required_links={"heavy_anger":{"weapon_21020076":["whiff","zig"],"echo_anger":["w_broadblade"]},"heavy_wrong_target":{"weapon_21020076":["whiff","zig"],"echo_anger":["weapon_21020076"]},"heavy_moth":{"echo_moth":["weapon_21020076"]},"relay_porcelain":{"weapon_21020106":["zig","whiff"],"echo_porcelain":["zig"]},"guard_sentry":{"echo_gliding_sentry":["rocksteady"],"weapon_21010076":["rocksteady"]},"guard_sorrow":{"echo_sorrow":["rocksteady"],"weapon_21010076":["rocksteady"]}}
var loadouts={}
var names={}
var fixtures={}
var separated={}
var cpu_ms=[]
var report={}
var simulation_counts={"calls":0,"natural":0,"diagnostic":0,"full_trace_events":0,"maximum_events_per_trace":0}

# Instrumentation records attempted resources without changing production events.
# Only fixed-window diagnostics normalize BOTH initial and maximum health.
class ProbeBattle extends B:
 var fixed_hp=0.0
 var no_sentry_frost=false
 func apply_frost_internal(ctx:Dictionary,side:int,item:Dictionary,layers:int,t:float,ordinary:bool)->int:
  if no_sentry_frost and item.kind=="echo_gliding_sentry":return 0
  return super.apply_frost_internal(ctx,side,item,layers,t,ordinary)
 var attempts=[]
 var checkpoint={}
 func step(ctx:Dictionary,t:float)->void:
  super.step(ctx,t)
  if is_equal_approx(t,20.0):checkpoint={"states":ctx.states.duplicate(true),"totals":ctx.totals.duplicate(true),"events":ctx.events.duplicate(true),"builds":ctx.builds}
 func begin(a:Dictionary,b:Dictionary,seed_value:int=1)->Dictionary:
  attempts=[]
  var ctx=super.begin(a,b,seed_value)
  if fixed_hp>0:
   for state in ctx.states:state.hp=fixed_hp;state.max_hp=fixed_hp
  return ctx
 func resource(ctx:Dictionary,side:int,item:Dictionary,key:String,value:float,t:float)->void:
  var before=float(ctx.states[side].get(key,0));var expiry=float(ctx.states[side].get(key+"_until",0))
  super.resource(ctx,side,item,key,value,t)
  var actual=float(ctx.states[side].get(key,0))-before
  attempts.append({"side":side,"uid":item.uid,"kind":item.kind,"resource":key,"time":t,"requested":value,"actual":actual,"overflow":maxf(0,value-actual) if value>0 else 0.0,"noop":is_zero_approx(actual) and is_equal_approx(expiry,float(ctx.states[side].get(key+"_until",0)))})
 func support_heal(ctx:Dictionary,side:int,item:Dictionary,amount:float,t:float)->float:
  var actual=super.support_heal(ctx,side,item,amount,t)
  attempts.append({"side":side,"uid":item.uid,"kind":item.kind,"resource":"heal","time":t,"requested":amount,"actual":actual,"overflow":maxf(0,amount-actual),"noop":actual<=EPS})
  return actual

func ck(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);printerr("MEASURE ERROR ",label)

func minimum_costs()->void:
 var run=inv.new_run("hsin",125);run.pool_mode="full";run.supply_version=125;run.items=[];run.stash=[]
 for round_index in range(1,13):
  run.round=round_index
  var facts=SHOP.facts(run,inv)
  for slot in 5:
   var pool=SHOP.ordinary_pool(facts,slot)
   for kind in pool:
    if float(pool[kind])>0 and not leaves.has(kind):
     leaves[kind]={"round":round_index,"slot":slot,"probability":pool[kind],"price":int(C.items[kind].price)}
 for kind in leaves:
  costs[kind]=leaves[kind].price;earliest[kind]=leaves[kind].round
  paths[kind]={"kind":kind,"cost":costs[kind],"via":"shop","earliest_leaf_round":earliest[kind],"inputs":[]}
  earliest_paths[kind]=paths[kind].duplicate(true)
 for pass_index in C.items.size():
  var changed=false
  for recipe in C.combinations:
   var inputs=[recipe.base]+recipe.get("materials",[])
   if not inputs.all(func(kind):return costs.has(kind)):continue
   var amount=inputs.reduce(func(total,kind):return total+int(costs[kind]),int(recipe.get("fee",0)))
   var round_index=inputs.reduce(func(latest,kind):return maxi(latest,int(earliest[kind])),1)
   var cost_round=inputs.reduce(func(latest,kind):return maxi(latest,int(paths[kind].earliest_leaf_round)),1)
   if not costs.has(recipe.target) or int(costs[recipe.target])>amount:
    costs[recipe.target]=amount
    paths[recipe.target]={"kind":recipe.target,"cost":amount,"via":"recipe","recipe_id":recipe.id,"fee":int(recipe.get("fee",0)),"earliest_leaf_round":cost_round,"inputs":inputs.map(func(kind):return paths[kind].duplicate(true))}
    changed=true
   if not earliest.has(recipe.target) or int(earliest[recipe.target])>round_index:
    earliest[recipe.target]=round_index
    earliest_paths[recipe.target]={"kind":recipe.target,"via":"recipe","recipe_id":recipe.id,"earliest_leaf_round":round_index,"inputs":inputs.map(func(kind):return earliest_paths[kind].duplicate(true))}
    changed=true
  if not changed:break

func visit_graph(kind:String,visiting:Array,done:Dictionary,cycles:Array)->void:
 if kind in visiting:
  cycles.append(visiting.slice(visiting.find(kind))+[kind]);return
 if done.has(kind):return
 var next=visiting+[kind]
 for recipe in C.combinations:
  if recipe.target==kind:
   for ingredient in [recipe.base]+recipe.get("materials",[]):visit_graph(ingredient,next,done,cycles)
 done[kind]=true

func recipe_report()->Dictionary:
 var cycles=[];var done={};var result=[]
 var baseline={}
 for kind in leaves:
  if int(C.profile(kind).get("introduced_version",0))<125:baseline[kind]=int(leaves[kind].price)
 for pass_index in C.items.size():
  var changed=false
  for r in C.combinations:
   if str(r.id).begins_with("E125-"):continue
   var inputs=[r.base]+r.get("materials",[])
   if not inputs.all(func(k):return baseline.has(k)):continue
   var amount=inputs.reduce(func(v,k):return v+int(baseline[k]),int(r.get("fee",0)))
   if not baseline.has(r.target) or baseline[r.target]>amount:baseline[r.target]=amount;changed=true
  if not changed:break
 var discounts=[]
 for kind in baseline:
  if costs.has(kind) and int(costs[kind])<int(baseline[kind]):discounts.append({"kind":kind,"before":baseline[kind],"after":costs[kind]})
 ck(discounts.is_empty(),"new recipes introduce no cheaper paths to existing products")
 ck(int(costs.echo_singilum)>=int(baseline.heron)+int(baseline.starfall),"singilum retains full preexisting heron plus starfall minimum cost")
 for kind in C.items:visit_graph(kind,[],done,cycles)
 ck(cycles.is_empty(),"full recipe graph has no directed cycle")
 for recipe in C.combinations:
  if not str(recipe.id).begins_with("E125-"):continue
  var inputs=[recipe.base]+recipe.get("materials",[])
  var known=inputs.all(func(kind):return costs.has(kind))
  ck(known,"public shop leaves reach "+recipe.id)
  if not known:continue
  result.append({"id":recipe.id,"target":recipe.target,"name":C.items[recipe.target].name,"minimum_input_cost":inputs.reduce(func(total,kind):return total+int(costs[kind]),int(recipe.get("fee",0))),"target_minimum_cost":costs[recipe.target],"target_earliest_leaf_round_any_path":earliest[recipe.target],"this_recipe_earliest_leaf_round":inputs.reduce(func(latest,kind):return maxi(latest,int(earliest[kind])),1),"input_paths":inputs.map(func(kind):return paths[kind].duplicate(true)),"target_cheapest_path":paths[recipe.target],"target_earliest_path":earliest_paths[recipe.target]})
 return {"cycles":cycles,"discounts_to_existing_products":discounts,"preexisting_minimum_costs":baseline,"recipes":result,"singilum":paths.get("echo_singilum",{}),"singilum_earliest":earliest_paths.get("echo_singilum",{}),"public_shop_leaves":leaves,"limitations":"Earliest means every leaf has positive ordinary-shop probability by that round, not enough gold, refresh luck, space, or a guaranteed acquisition. Recipe round_min is not a craft gate. Cheapest and earliest routes are computed independently. No starter credits, sale returns, refresh costs or bag costs."}

func base_board()->Dictionary:
 var run=inv.new_run("hsin",125)
 run.round=7;run.supply_version=125;run.pool_mode="full";run.items=[];run.stash=[];run.bags=[];run.serial=100;run.primary="";run.shop=[{},{},{},{},{},{}]
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
    score+=(10 if high and (C.profile(layout[a].piece.kind).has("ecosystem_rule") or C.items[layout[a].piece.kind].has("v124")) else 1)
    if high and layout[b].piece.kind in required_links.get(current_key,{}).get(layout[a].piece.kind,[]):score+=1000
 return score

func arrange(key:String,high:bool)->Dictionary:
 current_key=key
 var kinds=loadouts[key];var run=base_board();var options=[]
 links_allowed=[]
 for a in kinds.size():
  options.append(placements(kinds[a]));var row=[]
  for b in kinds.size():row.append(a!=b and inv.star_eligible({"kind":kinds[a],"uid":str(a)},{"kind":kinds[b],"uid":str(b)}))
  links_allowed.append(row)
 var rng=RandomNumberGenerator.new();rng.seed=125
 var best=[];var best_score=-1 if high else 10000
 var pinned=porcelain_seed(options) if key=="relay_porcelain" and high else {}
 for restart in 10:
  var layout=[];var occupied=0
  for fixed in pinned.values():occupied|=int(fixed.cells)
  for index in options.size():
   var choices=options[index]
   if pinned.has(index):layout.append(pinned[index]);continue
   var legal=choices.filter(func(p):return (int(p.cells)&occupied)==0)
   ck(not legal.is_empty(),"placement search has space "+key)
   if legal.is_empty():return {}
   var chosen=legal[rng.randi_range(0,legal.size()-1)];layout.append(chosen);occupied|=int(chosen.cells)
  for sweep in 5:
   var improved=false
   for index in layout.size():
    if pinned.has(index):continue
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
  for kind in required_links.get(key,{}):
   var source=run.items.filter(func(p):return p.kind==kind)[0]
   var linked=inv.star_links(source,run.items,run).map(func(p):return p.kind)
   ck(required_links[key][kind].all(func(k):return k in linked),"intended combo partners "+key+"/"+kind)
 return run


func add_build(key:String,title:String,kinds:Array)->void:
 loadouts[key]=kinds;names[key]=title

func configure()->void:
 add_build("heavy_anger","重击·怒与密音筒",["weapon_21020076","w_broadblade","whiff","zig","echo_anger","spicy_meat","tea","soup","tube","tuner"])
 add_build("heavy_wrong_target","怒·错误跟进对象",["weapon_21020076","w_broadblade","whiff","zig","echo_anger","spicy_meat","tea","soup","tube","tuner"])
 add_build("heavy_moth","重击·幻蛾光噪",["weapon_21020076","echo_moth","zig","whiff","spicy_meat","tea","soup","puppet"])
 add_build("relay_porcelain","联动·瓷庭候声骸",["weapon_21020106","echo_porcelain","zig","whiff","tuner","tube","puppet","w_sword"])
 add_build("relay_blades","联动·双快武器",["weapon_21020045","w_sword","whiff","tea","soup","echo_anger","echo_glacio","mat_42500010"])
 add_build("guard_sentry","反击·机枢招架",["weapon_21010076","rocksteady","echo_gliding_sentry","turtle","electro_coin","w_gauntlet"])
 add_build("guard_sorrow","反击·心傀霜渐",["weapon_21010076","rocksteady","w_gauntlet","turtle","echo_sorrow","echo_glacio","tea","mat_42500010"])
 add_build("control_rarity","对照·双高品质",["weapon_21020076","weapon_21020045","tea","soup","whiff","zig"])
 add_build("control_break","对照·削盾穿盾",["weapon_21020045","answer","w_sword","echo_glacio","mat_42500010","zig","tea"])
 add_build("gear_heavy","齿轮·重击供能",["weapon_21020076","w_sword","relic_diverter","zig","whiff","spicy_meat","tea","soup"])
 add_build("gear_fast","齿轮·三快供能",["w_sword","w_pistol","w_gauntlet","relic_diverter","zig","whiff","spicy_meat","tea","soup"])
 add_build("gear_sparse","齿轮·无外部供能",["w_sword","w_pistol","w_gauntlet","relic_diverter","echo_porcelain","whiff","rations","tea","soup"])
 for count in [2,3]:
  var core=["weapon_21020045","w_sword","whiff","spicy_meat","cool_tea"]
  if count==3:core.append("w_pistol")
  add_build("fast%d_none"%count,"%d快·无回耐"%count,core+["echo_porcelain","puppet"])
  add_build("fast%d_soup"%count,"%d快·鱼汤"%count,core+["soup","puppet"])
  add_build("fast%d_lunch"%count,"%d快·配餐盒"%count,core+["relic_lunchbox"])
 add_build("resource_idle","零耗耐资源对照",["soup","relic_lunchbox","spicy_meat","cool_tea"])
 add_build("guard_old","旧物品护盾组",["weapon_21010076","rocksteady","w_gauntlet","turtle","tea","whiff","zig","spicy_meat"])
 add_build("guard_replace","机枢等价换医疗茶",["weapon_21010076","rocksteady","medical","tea","turtle","electro_coin","w_gauntlet"])
 add_build("singilum","辛吉勒姆·双重击",["echo_singilum","weapon_21020076","zig","whiff","spicy_meat","tube"])

func overview(run:Dictionary)->Dictionary:
 var amount=0;var items=[];var all_links=0
 for p in run.items:
  amount+=int(costs[p.kind]);var linked=inv.star_links(p,run.items,run);all_links+=linked.size()
  items.append({"uid":p.uid,"kind":p.kind,"name":C.items[p.kind].name,"minimum_cost":costs[p.kind],"acquisition":paths[p.kind],"x":p.x,"y":p.y,"rotation":p.rotation,"links":linked.map(func(target):return {"uid":target.uid,"kind":target.kind})})
 return {"item_cost":amount,"all_links":all_links,"items":items,"fixture":run.duplicate(true),"fixture_sha256":var_to_bytes(run).hex_encode().sha256_text()}

func unlink_only(run:Dictionary,kind:String)->Dictionary:
 var out=run.duplicate(true);var index=out.items.find(out.items.filter(func(p):return p.kind==kind)[0]);var occupied=0
 for i in out.items.size():
  if i!=index:occupied|=mask(inv.occupied(out.items[i]))
 var original_links={}
 for p in run.items:original_links[p.uid]=inv.star_links(p,run.items,run).map(func(target):return target.uid)
 for choice in placements(kind):
  if int(choice.cells)&occupied:continue
  var p=choice.piece.duplicate(true);p.uid=out.items[index].uid;out.items[index]=p
  if not inv.star_links(p,out.items,out).is_empty():continue
  var unaffected=true
  for other in out.items:
   if other.uid==p.uid:continue
   if original_links[other.uid]!=inv.star_links(other,out.items,out).map(func(target):return target.uid):unaffected=false;break
  if unaffected:
   ck(inv.validate_run(out),"isolated link control legal "+kind);return out
 ck(false,"can isolate only links of "+kind);return run.duplicate(true)

func metrics(ctx:Dictionary,side:int,attempts:Array=[])->Dictionary:
 var state=ctx.states[side];var total=ctx.totals[side]
 var out={"hp":state.hp,"max_hp":state.max_hp,"damage":total.damage,"healing":total.heal,"shield_gained":total.shield,"stamina_wait":total.stamina_wait_seconds,"hp_damage":0.0,"absorbed":0.0,"guard_prevented":0.0,"counter_damage":0.0,"derived_damage":0.0,"advance_seconds":0.0,"star_triggers":0,"natural_attacks":0,"charged_attacks":0,"prepared_attacks":0,"break_shield":0.0,"charge_gained":0.0,"charge_spent":0.0,"gear_charge_spent":0.0,"stamina_actual":0.0,"stamina_attempted":0.0,"stamina_overflow":0.0,"stamina_noops":0,"charge_overflow":0.0,"charge_noops":0,"heal_overflow":0.0,"heal_noops":0,"resource_noops":0,"supply_cycles":0,"per_uid":{}}
 for p in ctx.builds[side].items:out.per_uid[p.uid]={"kind":p.kind,"name":C.items[p.kind].name,"damage":0.0,"healing":0.0,"shield_gained":0.0,"guard_prevented":0.0,"counter_damage":0.0,"derived_damage":0.0,"star_triggers":0,"natural_attacks":0,"charged_attacks":0,"advance_seconds":0.0,"stamina_actual":0.0,"stamina_attempted":0.0,"stamina_overflow":0.0,"stamina_noops":0,"charge_gained":0.0,"charge_spent":0.0,"resource_noops":0,"supply_cycles":0}
 for ev in ctx.events:
  if int(ev.side)==1-side:out.absorbed+=float(ev.get("absorbed",0))
  if int(ev.side)!=side:continue
  var source=REVIEW.source_uid(ev);var row=out.per_uid.get(source,{})
  var changes={}
  if ev.kind!="fatigue":out.hp_damage+=float(ev.get("hp_damage",0))
  if REVIEW.damage(ev)>0:changes.damage=REVIEW.damage(ev)
  if ev.kind=="counter":changes.counter_damage=REVIEW.damage(ev)
  if ev.kind=="derived":changes.derived_damage=REVIEW.damage(ev)
  if ev.kind=="shield":changes.shield_gained=float(ev.get("actual_value",ev.value))
  if ev.kind in ["heal","intro_heal"]:changes.healing=float(ev.get("actual_value",ev.value))
  if ev.kind=="guard":changes.guard_prevented=float(ev.get("actual_value",ev.value))
  if ev.kind=="cooldown_advance":changes.advance_seconds=float(ev.get("actual_value",ev.value))
  if ev.kind=="star_trigger":changes.star_triggers=1
  if ev.kind=="supply" and ev.get("cyclic",false):changes.supply_cycles=1
  if ev.kind=="stamina":changes.stamina_actual=float(ev.get("actual_value",ev.value))
  if ev.kind=="charge":
   if ev.value>0:changes.charge_gained=ev.value
   elif ev.value<0:
    changes.charge_spent=-ev.value
    if row.get("kind","")=="relic_diverter":out.gear_charge_spent-=float(ev.value)
  if ev.kind=="trigger" and ev.get("ordinary",false):
   changes.natural_attacks=1
   if ev.get("charged",false):changes.charged_attacks=1
   if ev.get("prepared",false):out.prepared_attacks+=1
  if ev.kind=="break_shield":out.break_shield+=float(ev.get("actual_value",ev.value))
  for key in changes:
   if key not in ["damage","healing","shield_gained"]:out[key]+=changes[key]
   if not row.is_empty() and row.has(key):row[key]+=changes[key]
 for a in attempts:
  if a.side!=side:continue
  var row=out.per_uid.get(a.uid,{})
  if a.noop:
   out.resource_noops+=1
   if not row.is_empty():row.resource_noops+=1
  if a.resource=="stamina":
   out.stamina_attempted+=a.requested;out.stamina_overflow+=a.overflow;out.stamina_noops+=int(a.noop)
   if not row.is_empty():row.stamina_attempted+=a.requested;row.stamina_overflow+=a.overflow;row.stamina_noops+=int(a.noop)
  if a.resource=="charge":out.charge_overflow+=a.overflow;out.charge_noops+=int(a.noop)
  if a.resource=="heal":out.heal_overflow+=a.overflow;out.heal_noops+=int(a.noop)
 for key in ["damage","healing","shield_gained"]:
  var summed=out.per_uid.values().reduce(func(value,row):return value+float(row[key]),0.0)
  ck(absf(summed-float(out[key]))<.00001,"per UID reconciles "+key)
 return out

func simulate(a:Dictionary,b:Dictionary,seed_value:int=125,diagnostic:bool=false,no_sentry_frost:bool=false)->Dictionary:
 var before=[a.duplicate(true),b.duplicate(true)];var engine=ProbeBattle.new() if diagnostic or no_sentry_frost else B.new()
 if no_sentry_frost:engine.no_sentry_frost=true
 if diagnostic:engine.fixed_hp=HP
 var start=Time.get_ticks_usec();var result=engine.simulate(a,b,seed_value,false)
 simulation_counts.calls+=1;simulation_counts["diagnostic" if diagnostic else "natural"]+=1
 simulation_counts.full_trace_events+=result.events.size();simulation_counts.maximum_events_per_trace=maxi(simulation_counts.maximum_events_per_trace,result.events.size())
 var elapsed=(Time.get_ticks_usec()-start)/1000.0
 if not diagnostic:cpu_ms.append(elapsed)
 ck(a==before[0] and b==before[1],"simulation input immutability")
 var ctx={"states":result.frames.back().sides,"totals":result.totals,"events":result.events,"builds":[a,b]}
 var out={"seed":seed_value,"winner":result.winner,"duration":result.duration,"event_sha256":var_to_bytes(result.events).hex_encode().sha256_text(),"event_count":result.events.size(),"sides":[]}
 if diagnostic:
  ck(not engine.checkpoint.is_empty(),"finite HP diagnostic survives to 20 seconds")
  if engine.checkpoint.is_empty():return out
  ctx=engine.checkpoint;out.window=20;out.fixed_hp=HP
  out.attempts=engine.attempts.filter(func(a):return a.time<=20)
  for side in 2:out.sides.append(metrics(ctx,side,out.attempts))
  out.erase("winner");out.erase("duration")
 else:
  for side in 2:out.sides.append(metrics(ctx,side))
 return out

func average(samples:Array)->Dictionary:
 var out={}
 if samples.is_empty():return out
 for key in samples[0]:
  if samples[0][key] is float or samples[0][key] is int:out[key]=samples.reduce(func(total,row):return total+float(row[key]),0.0)/samples.size()
 out.per_uid={}
 for uid in samples[0].get("per_uid",{}):
  out.per_uid[uid]=samples[0].per_uid[uid].duplicate(true)
  for key in samples[0].per_uid[uid]:
   if samples[0].per_uid[uid][key] is float or samples[0].per_uid[uid][key] is int:out.per_uid[uid][key]=samples.reduce(func(total,row):return total+float(row.per_uid[uid][key]),0.0)/samples.size()
 return out
func delta(a:Dictionary,b:Dictionary)->Dictionary:
 var out={}
 for key in a:
  if a[key] is float or a[key] is int:out[key]=float(a[key])-float(b[key])
 return out

func diagnostic_pair(key:String,control:Dictionary,opponents:Array)->Dictionary:
 var samples=[];var linked=[];var unlinked=[]
 for opponent in opponents:
  for side in 2:
   var a=fixtures[key] if side==0 else fixtures[opponent];var b=fixtures[opponent] if side==0 else fixtures[key]
   var high=simulate(a,b,125,true)
   var low=simulate(control,fixtures[opponent],125,true) if side==0 else simulate(fixtures[opponent],control,125,true)
   linked.append(high.sides[side]);unlinked.append(low.sides[side])
   samples.append({"opponent":opponent,"side":side,"linked":high.sides[side],"control":low.sides[side],"delta":delta(high.sides[side],low.sides[side])})
 return {"samples":samples,"linked_mean":average(linked),"control_mean":average(unlinked),"mean_delta":delta(average(linked),average(unlinked)),"control_fixture":overview(control)}

func _initialize()->void:call_deferred("run_measurement")
func run_measurement()->void:
 if OS.get_cmdline_user_args().has("--geometry-audit"):
  geometry_audit();return
 if OS.get_cmdline_user_args().has("--procurement"):
  measure_procurement();return
 var started=Time.get_ticks_msec();var original_catalog=var_to_bytes(C.items);minimum_costs();configure()
 var matrix_keys=["heavy_anger","heavy_moth","relay_porcelain","relay_blades","guard_sentry","guard_sorrow","control_rarity","control_break"]
 var opponents=["heavy_moth","guard_sentry"]
 var seeds=[125] if OS.get_cmdline_user_args().has("--quick") else SEEDS
 report={"simulation_version":C.SIMULATION_VERSION,"catalogue_hash":C.catalogue_hash,"spec_sha256":FileAccess.get_file_as_string("res://data/items/ecosystem.json").sha256_text(),"scope":{"main_budget":28,"round":7,"leader":"hsin","supports":[],"fixed_window_hp":HP,"fixed_window_max_hp":HP,"window_seconds":20,"capacity":"54 neutral satchel cells, identical; excludes bag purchase and refresh costs","full_combat":"B.new().simulate on exact immutable legal fixtures, natural HP, both side swaps","diagnostic":"production inherited simulate with both HP and max_hp set to 300; resource/heal calls instrumented without changing events; 20 seconds before fatigue","layout":"fixed seed125, 10 geometry starts, 5 coordinate sweeps, V124/125 links weighted10 and intended combo partners weighted1000; no battle optimization","limits":"selected synthetic round7 builds; no team supports, exhaustive optimal strategy, actual acquisition trajectory or online win rate; three seeds verify determinism rather than independent samples; star_trigger may prepare an effect and is not proof of later damage"},"seeds":seeds,"recipes":recipe_report(),"builds":{},"matrix":[],"matrix_summary":{},"layout":{},"gear":{},"stamina":{},"turtle_ab":{},"singilum":{},"deterministic":true}
 report.engine_sha256={}
 for path in ["scripts/battle/battle_v60.gd","scripts/battle/battle_v75.gd","scripts/battle/battle_v124.gd","scripts/battle/battle_v125.gd","scripts/battle/material_effects.gd"]:report.engine_sha256[path]=FileAccess.get_file_as_string("res://"+path).sha256_text()
 for key in loadouts:
  fixtures[key]=arrange(key,true);report.builds[key]={"name":names[key],"linked":overview(fixtures[key])}
  if key in matrix_keys:ck(report.builds[key].linked.item_cost==28,"main exact 28 gold "+key)
  print("FIXTURE ",key," cost ",report.builds[key].linked.item_cost," links ",report.builds[key].linked.all_links)
 for key in matrix_keys:report.matrix_summary[key]={"wins":0,"losses":0,"draws":0,"games":0,"natural_samples":[]}
 for ai in matrix_keys.size():
  for bi in range(ai+1,matrix_keys.size()):
   var akey=matrix_keys[ai];var bkey=matrix_keys[bi]
   for swapped in [false,true]:
    var left=bkey if swapped else akey;var right=akey if swapped else bkey;var first={}
    for seed_value in seeds:
     var sample=simulate(fixtures[left],fixtures[right],seed_value)
     if first.is_empty():first=sample.duplicate(true)
     else:
      var repeat=sample.duplicate(true);var baseline=first.duplicate(true);repeat.erase("seed");baseline.erase("seed")
      if repeat!=baseline:report.deterministic=false
     for side in 2:
      var key=[left,right][side];var summary=report.matrix_summary[key];summary.games+=1
      var result=int(sample.winner)*(1 if side==0 else -1)
      summary["wins" if result>0 else "losses" if result<0 else "draws"]+=1
      if seed_value==seeds[0]:summary.natural_samples.append(sample.sides[side])
     sample.left=left;sample.right=right;report.matrix.append(sample)
   print("MATRIX ",akey," / ",bkey)
 report.side_swap_differences=[]
 var swapped_results={}
 for sample in report.matrix:
  if sample.seed!=seeds[0]:continue
  var pair=[sample.left,sample.right];pair.sort();var key="/".join(pair)
  var canonical=int(sample.winner)*(1 if sample.left==pair[0] else -1)
  if swapped_results.has(key) and swapped_results[key]!=canonical:report.side_swap_differences.append(key)
  swapped_results[key]=canonical
 for key in matrix_keys:
  report.matrix_summary[key].mean=average(report.matrix_summary[key].natural_samples)
  separated[key]=arrange(key,false);report.builds[key].separated=overview(separated[key])
  report.layout[key]=diagnostic_pair(key,separated[key],opponents)
  print("LAYOUT ",key)
 for key in ["gear_heavy","gear_fast","gear_sparse"]:
  report.gear[key]=diagnostic_pair(key,unlink_only(fixtures[key],"relic_diverter"),opponents)
 for key in loadouts:
  if not key.begins_with("fast"):continue
  var samples=[]
  for opponent in opponents:
   for side in 2:
    var result=simulate(fixtures[key],fixtures[opponent],125,true) if side==0 else simulate(fixtures[opponent],fixtures[key],125,true)
    samples.append(result.sides[side])
  report.stamina[key]={"mean":average(samples),"samples":samples}
  if key.ends_with("lunch"):report.stamina[key].links=diagnostic_pair(key,unlink_only(fixtures[key],"relic_lunchbox"),opponents)
 var prior=C.items.turtle.v125.duplicate(true)
 for amount in [4,2]:
  C.items.turtle.v125.healAmount=amount;C.items.turtle.v125.hps=float(amount)/4.0
  report.turtle_ab[str(amount)]={}
  for key in ["guard_sentry","guard_sorrow"]:
   var samples=[];var full=[]
   for opponent in ["heavy_anger","relay_blades","control_break"]:
    for side in 2:
     var a=fixtures[key] if side==0 else fixtures[opponent];var b=fixtures[opponent] if side==0 else fixtures[key]
     var diag=simulate(a,b,125,true);samples.append(diag.sides[side])
     var normal=simulate(a,b);full.append({"opponent":opponent,"side":side,"winner_for_build":int(normal.winner)*(1 if side==0 else -1),"duration":normal.duration,"metrics":normal.sides[side]})
   report.turtle_ab[str(amount)][key]={"mean20":average(samples),"samples20":samples,"full":full}
 C.items.turtle.v125=prior
 report.singilum=diagnostic_pair("singilum",arrange("singilum",false),opponents)
 report.sentry_ablation=measure_sentry_ablation(matrix_keys)
 var idle=simulate(fixtures.resource_idle,fixtures.heavy_moth,125,true)
 report.resource_idle=idle.sides[0]
 report.anger_target_control=diagnostic_pair("heavy_anger",fixtures.heavy_wrong_target,opponents)
 var anger_row=report.anger_target_control.linked_mean.per_uid.values().filter(func(r):return r.kind=="echo_anger")[0]
 ck(anger_row.star_triggers>0,"anger chosen charged weapon actually prepares follow-up")
 ck(is_zero_approx(report.resource_idle.stamina_actual) and report.resource_idle.stamina_noops>0,"full stamina has actual zero recovery and observable no-ops")
 # Probe equivalence: the instrumentation itself must preserve production combat.
 var probe=ProbeBattle.new();var probed=probe.simulate(fixtures.heavy_moth,fixtures.guard_sentry,125,false)
 var normal=B.new().simulate(fixtures.heavy_moth,fixtures.guard_sentry,125,false)
 ck(probed==normal,"resource probe with natural HP equals production result exactly")
 ck(var_to_bytes(C.items)==original_catalog,"process-only turtle profile restored exactly")
 cpu_ms.sort()
 report.cpu_logic_ms={"samples":cpu_ms.size(),"mean":cpu_ms.reduce(func(total,v):return total+v,0.0)/maxi(1,cpu_ms.size()),"p95":cpu_ms[int(cpu_ms.size()*.95)],"peak":cpu_ms.back(),"conditions":"headless, capture_replay=false, full simulation+metrics output allocation excluded after return; in-process wall-clock CPU logic proxy, no render/GPU claim, no baseline comparison"}
 report.simulation_counts=simulation_counts.duplicate(true)
 report.checks=checks;report.failures=failures;report.elapsed_seconds=(Time.get_ticks_msec()-started)/1000.0
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 FileAccess.open(OUT+"balance.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 FileAccess.open(OUT+"balance.md",FileAccess.WRITE).store_string(markdown())
 print("V125 BALANCE ",checks," checks ",failures.size()," failures ",report.elapsed_seconds," seconds")
 quit(0 if failures.is_empty() else 1)

func markdown()->String:
 var out="# V125 物品生态测量\n\n目录哈希：`%s`。全量机器可读输入、逐侧结果、每物品实际贡献与配方树见 [balance.json](balance.json)。\n\n"%report.catalogue_hash
 out+="这是人工选择的回合7构筑诊断。主矩阵每套28金币最低原料投入、同54格中性口袋、心领队、无队友；口袋费用、刷新、获取先后与随机采购均不计入投入。布局只按合法星位几何搜索，未按输赢调优。云琅采用4件合法接力：云琅连接阿嗞嗞与呼咻咻，瓷庭候推进阿嗞嗞；提案中云琅同时连接瓷庭候与呼咻咻且瓷庭候再连呼咻咻的3件布局，穷举当前星位和四旋转后无解。所有自然完整战斗使用真实 `B.new().simulate()`，输入逐次校验不变，双方交换位置。重复种子结果一致：**%s**；种子重复不当独立样本。\n\n"%str(report.deterministic)
 out+="## 28金币自然完整战斗\n\n|构筑|胜/负/平|伤害|治疗|实际挡伤|招架减伤|耐力等待秒|\n|---|---:|---:|---:|---:|---:|---:|\n"
 for key in report.matrix_summary:
  var s=report.matrix_summary[key];var m=s.mean
  out+="|%s|%d/%d/%d|%.2f|%.2f|%.2f|%.2f|%.2f|\n"%[names[key],s.wins,s.losses,s.draws,m.damage,m.healing,m.absorbed,m.guard_prevented,m.stamina_wait]
 out+="\n不同构筑自然战斗时长不同，以上伤害不等于固定窗口DPS。所有实际挡伤按团队统计；招架减伤独立列出，不混作护盾吸收。\n\n## 同物品连星与零连接\n\n以下诊断把双方初始HP及max_hp同时设为300，在真实模拟第20秒采样；所有对照活到窗口末，疲劳尚未开始。不将这些胜负用于自然矩阵。每套对幻蛾与机枢两个固定对手并交换位置，共4个配对。\n\n|构筑|伤害Δ|挡伤Δ|治疗Δ|亮星Δ|冷却推进Δ秒|耐力等待Δ秒|\n|---|---:|---:|---:|---:|---:|---:|\n"
 for key in report.layout:
  var d=report.layout[key].mean_delta
  out+="|%s|%+.2f|%+.2f|%+.2f|%+.2f|%+.2f|%+.2f|\n"%[names[key],d.damage,d.absorbed,d.healing,d.star_triggers,d.advance_seconds,d.stamina_wait]
 out+="\n## 分流齿轮的供能取舍\n\n每套27金币。只移动齿轮取消自身连接，其余物品坐标及全部其他连接相同。无外部供能仍保留齿轮每10秒自身1充能；不能把它描述成完全零充能。\n\n|构筑|连星伤害|断星伤害|伤害Δ|充能攻击连/断|齿轮耗充能|回耐实际/溢出|\n|---|---:|---:|---:|---:|---:|---:|\n"
 for key in report.gear:
  var g=report.gear[key];var h=g.linked_mean;var l=g.control_mean
  out+="|%s|%.2f|%.2f|%+.2f|%.2f/%.2f|%.2f|%.2f/%.2f|\n"%[names[key],h.damage,l.damage,h.damage-l.damage,h.charged_attacks,l.charged_attacks,h.gear_charge_spent,h.stamina_actual,h.stamina_overflow]
 out+="\n## 两／三把快武器的回耐\n\n两把组29金币，三把组33金币；每组同价5金币配套分别是瓷庭候＋人偶、鱼汤＋人偶、配餐盒。共同含肉片与凉茶两种周期补给。替换同时改变伤害、空间及供给组合，是采购机会成本对照，不应全归因于回耐。\n\n|构筑|20秒伤害|自然攻击|耐力等待秒|回耐实际/尝试|溢出|回耐无效次数|补给周期|\n|---|---:|---:|---:|---:|---:|---:|---:|\n"
 for key in report.stamina:
  var m=report.stamina[key].mean
  out+="|%s|%.2f|%.2f|%.2f|%.2f/%.2f|%.2f|%.2f|%.2f|\n"%[names[key],m.damage,m.natural_attacks,m.stamina_wait,m.stamina_actual,m.stamina_attempted,m.stamina_overflow,m.stamina_noops,m.supply_cycles]
 out+="\n配餐盒只断自身星位的同物品对照：\n\n|构筑|伤害Δ|等待Δ秒|实际回耐Δ|自身推进Δ秒|\n|---|---:|---:|---:|---:|\n"
 for key in report.stamina:
  if not report.stamina[key].has("links"):continue
  var d=report.stamina[key].links.mean_delta
  out+="|%s|%+.2f|%+.2f|%+.2f|%+.2f|\n"%[names[key],d.damage,d.stamina_wait,d.stamina_actual,d.advance_seconds]
 out+="\n## 寒霜陆龟4/4秒与2/4秒\n\n只在测量进程临时覆盖陆龟基础治疗与派生hps，双方同样采用该档规则，结束后逐字节验证目录恢复；生产文件和真实存档不变。固定窗口及正常完整战斗独立报告。\n\n|构筑|基础治疗/4秒|20秒实际治疗|20秒伤害|20秒实际挡伤|自然胜/负/平|\n|---|---:|---:|---:|---:|---:|\n"
 for amount in ["4","2"]:
  for key in report.turtle_ab[amount]:
   var d=report.turtle_ab[amount][key];var w=0;var l=0;var t=0
   for x in d.full:
    if x.winner_for_build>0:w+=1
    elif x.winner_for_build<0:l+=1
    else:t+=1
   out+="|%s|%s|%.2f|%.2f|%.2f|%d/%d/%d|\n"%[names[key],amount,d.mean20.healing,d.mean20.damage,d.mean20.absorbed,w,l,t]
 out+="\n## 辛吉勒姆与配方全图\n\n辛吉勒姆构筑%d金币，全构筑零连接对照（并非只隔离辛吉勒姆）：20秒伤害Δ%+.2f，自然攻击Δ%+.2f；本体供能保持，实际触发与逐物品量见JSON。\n\n"%[report.builds.singilum.linked.item_cost,report.singilum.mean_delta.damage,report.singilum.mean_delta.natural_attacks]
 out+="|新配方|产物|该路径最低投入|产物全图最低投入|该路径最早叶子回合|产物全图最早叶子回合|\n|---|---|---:|---:|---:|---:|\n"
 for r in report.recipes.recipes:out+="|%s|%s|%d|%d|%d|%d|\n"%[r.id,r.name,r.minimum_input_cost,r.target_minimum_cost,r.this_recipe_earliest_leaf_round,r.target_earliest_leaf_round_any_path]
 out+="\n全图有向循环：%d。相较移除全部E125配方与新叶子的原图，既有产物没有新增最低成本折价；辛吉勒姆保留原有凶鹭5＋坠星7共12投入。最早叶子回合按真实普通商店分布中非零概率计算；含所有替代配方，独立求最低投入与最早可达。它不是足够金币、刷新运气、合法合成摆位或实际买齐的证明。当前旧图多种高阶成品的叶子已在R1可供给；辛吉勒姆即便不直接上架，仍有R1叶子供给路径；这不表示首轮经济可完成。不能把成品shop_round或craft_only当终局绝对晚出保证。本轮没有改旧图，也没有用合成回合锁掩盖这一点。[首轮真实采购](balance-procurement.md)另证当前开局最多11金币、最低原料12金币的预算阻断。\n\n"%report.recipes.cycles.size()
 out+=effect_markdown()
 var anger_good=report.anger_target_control.linked_mean.per_uid.values().filter(func(r):return r.kind=="echo_anger")[0]
 var anger_wrong=report.anger_target_control.control_mean.per_uid.values().filter(func(r):return r.kind=="echo_anger")[0]
 out+="怒的跟进对象反例：同28金币双武器组，连接实际消耗充能的长刃，20秒怒平均亮星%.2f、归因伤害%.2f；连接启明星的替代布局亮星%.2f、归因伤害%.2f。两种完整合法布局可能还有其它连接差异，所以只将它作为\"连到武器不保证该武器真的打出重击\"的反例，不把全部团队伤害差归于单一星位。两套输入保存在JSON。\n\n"%[anger_good.star_triggers,anger_good.damage,anger_wrong.star_triggers,anger_wrong.damage]
 out+=sentry_markdown()
 out+="零耗耐对照（鱼汤、配餐盒、肉片、凉茶，无武器）20秒实际回耐%.2f／尝试%.2f、回耐无效调用%d；推进时钟或亮星不等于实际回复。\n\n"%[report.resource_idle.stamina_actual,report.resource_idle.stamina_attempted,report.resource_idle.stamina_noops]
 out+="## 测量边界\n\n实际资源、溢出和无效调用由同一引擎的只读探针记录，探针在自然HP下与生产模拟结果精确相等。自然战斗只记录事件已有的实际量；未记录的尝试/无效量不能从自然矩阵零值推断。准备亮星与收益交付分别看，派生伤害不充当自然攻击次数。完整逐UID数据保留。\n\n"
 out+="本次经测量封装调用真实完整模拟%d次（自然%d、有限HP诊断%d），完整轨迹共%d事件、单场最高%d事件；窗口诊断只取其中前20秒用于效果比较。另有两次探针精确等价检查未计入该调用数。\n\n"%[report.simulation_counts.calls,report.simulation_counts.natural,report.simulation_counts.diagnostic,report.simulation_counts.full_trace_events,report.simulation_counts.maximum_events_per_trace]
 out+="CPU逻辑样本%d，平均%.2fms/P95 %.2fms/峰值%.2fms；headless、capture_replay=false，仅本机逻辑诊断，无旧版配对，不代表渲染/GPU或全设备性能。\n\n"%[report.cpu_logic_ms.samples,report.cpu_logic_ms.mean,report.cpu_logic_ms.p95,report.cpu_logic_ms.peak]
 out+="[独立结论与建议](balance-findings.md)结合以上证据，不能用这些选定样本宣称长期平衡或全局最优。验证%d项、失败%d项，耗时%.2f秒。命令：`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/scenarios/measure_ecosystem_v125.gd`；`-- --quick`只缩减主矩阵重复种子。\n"%[report.checks,report.failures.size(),report.elapsed_seconds]
 return out

func measure_sentry_ablation(matrix_keys:Array)->Dictionary:
 var out={"variants":{},"old_builds":{},"baseline_profile":{"guard":3,"counter_damage":6,"star_period":5},"tuned_profile":{"guard":2,"counter_damage":4,"star_period":6}}
 var prior=C.items.echo_gliding_sentry.v125.duplicate(true)
 var targets=["heavy_anger","heavy_moth","relay_porcelain","relay_blades","control_rarity","control_break","guard_old","guard_replace","guard_sorrow"]
 for variant in ["baseline","no_frost","guard2_counter4_icd6","guard2_counter4_icd6_no_frost"]:
  C.items.echo_gliding_sentry.v125=prior.duplicate(true)
  C.items.echo_gliding_sentry.v125.guard=3;C.items.echo_gliding_sentry.v125.counter_damage=6;C.items.echo_gliding_sentry.v125.star_period=5
  if variant.begins_with("guard2"):
   C.items.echo_gliding_sentry.v125.guard=2;C.items.echo_gliding_sentry.v125.counter_damage=4;C.items.echo_gliding_sentry.v125.star_period=6
  var no_frost=variant.ends_with("no_frost")
  out.variants[variant]=ablation_vs("guard_sentry",targets,no_frost)
  print("SENTRY ABLATION ",variant," ",out.variants[variant].wins,"/",out.variants[variant].losses,"/",out.variants[variant].draws," dmg20 ",out.variants[variant].mean20.damage)
 C.items.echo_gliding_sentry.v125=prior
 for key in ["guard_old","guard_replace"]:
  ck(report.builds[key].linked.item_cost==28,"old support control 28 gold "+key)
  out.old_builds[key]=ablation_vs(key,matrix_keys,false)
  print("OLD GUARD ",key," ",out.old_builds[key].wins,"/",out.old_builds[key].losses,"/",out.old_builds[key].draws)
 return out

func ablation_vs(key:String,targets:Array,no_frost:bool)->Dictionary:
 var out={"wins":0,"losses":0,"draws":0,"full":[],"samples20":[]}
 for target in targets:
  for side in 2:
   var a=fixtures[key] if side==0 else fixtures[target];var b=fixtures[target] if side==0 else fixtures[key]
   var natural=simulate(a,b,125,false,no_frost);var diagnostic=simulate(a,b,125,true,no_frost)
   var winner=int(natural.winner)*(1 if side==0 else -1)
   out["wins" if winner>0 else "losses" if winner<0 else "draws"]+=1
   out.full.append({"opponent":target,"side":side,"winner_for_build":winner,"duration":natural.duration,"metrics":natural.sides[side],"opponent_metrics":natural.sides[1-side]})
   out.samples20.append(diagnostic.sides[side])
 out.mean20=average(out.samples20)
 return out

func sentry_markdown()->String:
 var out="## 机枢消融与旧护盾配套\n\n所有组28金币。机枢四档只临时修改减伤/反击/间隔；去霜由测量子类阻止该来源的附霜动作（含其伤害与控制），其它引擎路径不变。每档对相同9个对手双侧18场，既有28金币护盾组及用医疗3＋茶2替机枢5的组各对主矩阵双侧16场。两组对手集合不同，不能直接比较原始胜场数。旧组表示当前V125规则下的旧物品组合，并非冻结旧版数值。\n\n|机枢配置|胜/负/平|20秒伤害|其中反击|20秒招架减伤|20秒挡伤|\n|---|---:|---:|---:|---:|---:|\n"
 for key in report.sentry_ablation.variants:
  var a=report.sentry_ablation.variants[key];var m=a.mean20
  out+="|%s|%d/%d/%d|%.2f|%.2f|%.2f|%.2f|\n"%[key,a.wins,a.losses,a.draws,m.damage,m.counter_damage,m.guard_prevented,m.absorbed]
 out+="\n|当前规则旧物品组|胜/负/平|20秒伤害|20秒治疗|20秒挡伤|\n|---|---:|---:|---:|---:|\n"
 for key in report.sentry_ablation.old_builds:
  var a=report.sentry_ablation.old_builds[key];var m=a.mean20
  out+="|%s|%d/%d/%d|%.2f|%.2f|%.2f|\n"%[names[key],a.wins,a.losses,a.draws,m.damage,m.healing,m.absorbed]
 return out+"\n"

func porcelain_seed(options:Array)->Dictionary:
 # Four-item legal relay: Yunlang sees Zig and Whiff; Porcelain advances Zig.
 # Yunlang's spaced star cells cannot hold the proposed adjacent 3-item loop.
 for weapon in options[0]:
  for partner in options[2]:
   if int(weapon.cells)&int(partner.cells) or not (int(weapon.stars)&int(partner.cells)):continue
   for porcelain in options[1]:
    if int(porcelain.cells)&(int(weapon.cells)|int(partner.cells)):continue
    if int(porcelain.stars)&int(partner.cells):return {0:weapon,1:porcelain,2:partner}
 ck(false,"geometrically possible four-item porcelain relay")
 return {}

class Procurement extends RefCounted:
 const F=preload("res://scripts/crafting/craft.gd")
 const RECRUIT=preload("res://scripts/party/recruitment.gd")
 const MAX_SHELVES=16
 var inv=I.new()
 var incoming={}
 var outgoing={}
 var allowed={}
 var memo={}
 var pool_cache={}
 var failures=[]
 var checks=0
 func _init()->void:
  for recipe in C.combinations:
   if not incoming.has(recipe.target):incoming[recipe.target]=[]
   incoming[recipe.target].append(recipe)
   for kind in [recipe.base]+recipe.materials:outgoing[kind]=true
  for kind in incoming:incoming[kind].sort_custom(func(a,b):return str(a.id)<str(b.id))
 func require(ok:bool,message:String)->bool:
  checks+=1
  if not ok:failures.append(message);printerr("PROCUREMENT ERROR ",message)
  return ok
 func counts(run:Dictionary)->Dictionary:
  var result={}
  for p in run.items+run.stash:result[p.kind]=int(result.get(p.kind,0))+1
  return result
 func state_key(owned:Dictionary)->String:
  var keys=owned.keys();keys.sort();var values=[]
  for key in keys:
   if int(owned[key])>0:values.append([key,int(owned[key])])
  return JSON.stringify(values)
 func cheaper(a:Dictionary,b:Dictionary)->bool:
  if int(a.cost)!=int(b.cost):return int(a.cost)<int(b.cost)
  return str(a.key)<str(b.key)
 func preserve(options:Dictionary,row:Dictionary)->void:
  var key=state_key(row.left)
  if not options.has(key) or cheaper(row,options[key]):options[key]=row

 func paths(kind:String,owned:Dictionary,stack:Array=[])->Array:
  var key=kind+":"+state_key(owned)
  if memo.has(key):return memo[key]
  if kind in stack:return []
  var result={}
  if int(owned.get(kind,0))>0:
   var left=owned.duplicate();left[kind]-=1
   preserve(result,{"cost":0,"left":left,"key":"0:"+kind,"node":{"kind":kind,"method":"owned","cost":0}})
  if allowed.has(kind):
   var price=int(C.items[kind].price)
   preserve(result,{"cost":price,"left":owned.duplicate(),"key":"1:"+kind,"node":{"kind":kind,"method":"buy","cost":price}})
  for recipe in incoming.get(kind,[]):
   var partial=[{"cost":int(recipe.get("fee",0)),"left":owned.duplicate(),"children":[],"key":str(recipe.id)}]
   for input in [recipe.base]+recipe.materials:
    var next=[]
    for prior in partial:
     for child in paths(str(input),prior.left,stack+[kind]):
      next.append({"cost":int(prior.cost)+int(child.cost),"left":child.left,"children":prior.children+[child.node],"key":prior.key+"/"+child.key})
    partial=next
   for option in partial:
    preserve(result,{"cost":option.cost,"left":option.left,"key":"2:"+option.key,"node":{"kind":kind,"method":"craft","recipe_id":recipe.id,"cost":option.cost,"children":option.children}})
  var out=result.values();out.sort_custom(cheaper);memo[key]=out
  return out
 func choose(run:Dictionary,target:String)->Dictionary:
  memo.clear()
  var options=paths(target,counts(run))
  return {} if options.is_empty() else options[0]
 func supply_allowed(run:Dictionary)->Dictionary:
  var key=str(run.leader)+":"+str(run.pool_mode)+":"+str(run.round)
  if pool_cache.has(key):return pool_cache[key]
  var facts=SHOP.facts(run,inv);var positive={}
  for slot in 5:
   var pool=SHOP.ordinary_pool(facts,slot)
   for kind in pool:
    if float(pool[kind])>0:positive[kind]=true
  pool_cache[key]=positive
  return positive
 func descendants(kind:String,seen:Dictionary)->void:
  if seen.has(kind):return
  seen[kind]=true
  for recipe in incoming.get(kind,[]):
   for input in [recipe.base]+recipe.materials:descendants(str(input),seen)
 func ready_recipe(node:Dictionary)->Dictionary:
  if node.get("method","")!="craft":return {}
  for child in node.children:
   var ready=ready_recipe(child)
   if not ready.is_empty():return ready
  if node.children.all(func(child):return child.method=="owned"):
   for recipe in incoming[node.kind]:
    if recipe.id==node.recipe_id:return recipe
  return {}
 func selected_recipes(node:Dictionary)->Array:
  if node.get("method","")!="craft":return []
  var result=[node.recipe_id]
  for child in node.children:result.append_array(selected_recipes(child))
  return result

 func terminal(kind:String)->bool:
  return C.is_tag(kind,"weapon") and incoming.has(kind) and not outgoing.has(kind)
 func acquired(sample:Dictionary,kind:String,rn:int,source:String)->void:
  if sample.first_acquired.has(kind):return
  sample.first_acquired[kind]={"round":rn,"source":source}
  if int(C.items[kind].rarity)==5:
   if sample.first_q5==0:sample.first_q5=rn
   if C.is_tag(kind,"weapon") and sample.first_q5_weapon==0:sample.first_q5_weapon=rn
   if not terminal(kind) and sample.first_q5_nonterminal==0:sample.first_q5_nonterminal=rn
  if terminal(kind) and sample.first_terminal==0:sample.first_terminal=rn
 func record_shelf(run:Dictionary,sample:Dictionary,index:int)->void:
  sample.ledger.append({"round":run.round,"action":"shelf","shelf":index+1,"gold":run.gold,"seed":run.seed,"offers":run.shop.duplicate(true)})
  for offer in run.shop:
   if not offer.is_empty() and int(C.items[offer.kind].rarity)==5 and sample.first_shop_q5==0:sample.first_shop_q5=run.round

 func craft(run:Dictionary,recipe:Dictionary,sample:Dictionary)->bool:
  var matching=(run.items+run.stash).filter(func(p):return p.kind==recipe.base)
  var materials=(run.items+run.stash).filter(func(p):return p.kind==recipe.materials[0])
  if matching.is_empty() or materials.is_empty():return false
  # Search all legal base placements after public stash moves; each material
  # placement and craft carries the exact selected incoming recipe identity.
  for base in matching:
   var clean=run.duplicate(true)
   for piece in clean.items.duplicate(true):
    if not inv.stash(clean,piece):return false
   for rotation in 4:
    for cell in inv.coverage(clean.bags):
     var positioned=base.duplicate(true);positioned.x=cell.x;positioned.y=cell.y;positioned.rotation=rotation
     if not inv.can_place(positioned,[],clean.bags):continue
     var candidate=clean.duplicate(true)
     if not inv.place(candidate,positioned):continue
     var placement=F.place_material(candidate,recipe.target,base.uid,recipe.materials[0],inv,Callable(),str(recipe.id))
     if not placement.ok:continue
     var before=candidate.duplicate(true)
     var result=F.transact(candidate,recipe.target,base.uid,inv,{},Callable(),str(recipe.id))
     if not result.ok:continue
     var inputs=before.items.filter(func(p):return p.uid in result.consumed)
     require(str(result.recipe_id)==str(recipe.id),"exact recipe identity "+str(recipe.id))
     require(result.output.paid_cost==inputs.reduce(func(total,p):return total+int(p.get("paid_cost",0)),0),"craft paid-cost conservation "+str(recipe.id))
     var paid=int(before.gold)-int(candidate.gold)
     run.clear();run.merge(candidate,true)
     sample.ledger.append({"round":run.round,"action":"craft","recipe_id":recipe.id,"kind":recipe.target,"inputs":inputs,"output":result.output.duplicate(true),"paid":paid,"gold":run.gold,"destination":result.get("destination","board"),"q5":int(C.items[recipe.target].rarity)==5,"terminal":terminal(recipe.target)})
     if sample.first_craft==0:sample.first_craft=run.round
     if C.is_tag(recipe.target,"weapon") and sample.first_weapon_craft==0:sample.first_weapon_craft=run.round
     acquired(sample,recipe.target,int(run.round),"craft")
     return true
  return false
 func buy_capacity(run:Dictionary,sample:Dictionary)->bool:
  if run.shop[5].is_empty():return false
  var kind=run.shop[5].kind;var candidate=run.duplicate(true)
  for piece in candidate.items.duplicate(true):
   if not inv.stash(candidate,piece):return false
  var fit=inv.first_fit(inv.make_piece(kind,"fit"),candidate.items,candidate.bags)
  if fit.is_empty():return false
  var before=int(candidate.gold);var bought=inv.purchase_at(candidate,5,fit,"board")
  if bought.is_empty():return false
  run.clear();run.merge(candidate,true)
  sample.ledger.append({"round":run.round,"action":"capacity","kind":kind,"uid":bought.uid,"paid":before-int(run.gold),"gold":run.gold,"output":bought.duplicate(true)})
  return true
 func purchase(run:Dictionary,target:String,relevant:Dictionary,plan:Dictionary,sample:Dictionary)->bool:
  var best={};var owned=counts(run)
  for slot in 5:
   var offer=run.shop[slot]
   if offer.is_empty() or not relevant.has(offer.kind):continue
   var price=inv.purchase_price(run,slot)
   if price>run.gold:continue
   var plus=owned.duplicate();plus[offer.kind]=int(plus.get(offer.kind,0))+1
   memo.clear();var after=paths(target,plus)
   if after.is_empty() or price+int(after[0].cost)>int(plan.cost):continue
   var row={"slot":slot,"price":price,"total":price+int(after[0].cost)}
   if best.is_empty() or row.total<best.total or (row.total==best.total and row.price<best.price):best=row
  if best.is_empty():return false
  var kind=str(run.shop[best.slot].kind);var prior=int(run.gold);var known=(run.items+run.stash).map(func(p):return p.uid)
  if not inv.buy(run,best.slot):return false
  var fresh=(run.items+run.stash).filter(func(p):return p.uid not in known)
  require(prior-int(run.gold)==int(best.price),"purchase matches public quote")
  sample.ledger.append({"round":run.round,"action":"buy","slot":best.slot,"kind":kind,"paid":prior-int(run.gold),"gold":run.gold,"acquired":fresh.duplicate(true),"minimum_remaining_before":plan.cost})
  acquired(sample,kind,int(run.round),"shop")
  return true

 func measure_run(leader:String,target:String,mode:String,seed_value:int,liquidate:bool=false)->Dictionary:
  var run=inv.new_run_supply(leader,seed_value,mode,125)
  var sample={"mode":mode,"leader":leader,"target":target,"target_name":C.items[target].name,"seed":seed_value,"first_craft":0,"first_weapon_craft":0,"first_q5":0,"first_q5_weapon":0,"first_q5_nonterminal":0,"first_terminal":0,"first_shop_q5":0,"first_acquired":{},"ledger":[],"rounds":[]}
  sample.starter_liquidation=liquidate
  if liquidate:
   for piece in (run.items+run.stash).duplicate(true):
    var before=int(run.gold)
    require(inv.sell(run,piece),"public starter liquidation")
    sample.ledger.append({"round":1,"action":"sell","kind":piece.kind,"paid":before-int(run.gold),"gold":run.gold})
  var relevant={};descendants(target,relevant)
  for p in run.items+run.stash:acquired(sample,p.kind,1,"starting_inventory")
  for rn in range(1,2):
   var start_index=sample.ledger.size()
   if rn>1:
    var grant=inv.ECONOMY.income(0,rn);run.round=rn;run.gold+=grant;run.refreshes=0
    require(inv.refresh(run),"public next-round refresh")
    sample.ledger.append({"round":rn,"action":"income","amount":grant,"paid":0,"gold":run.gold})
   allowed=supply_allowed(run)
   var opening=choose(run,target)
   var opening_plan={} if opening.is_empty() else {"additional_material_cost":opening.cost,"recipe_ids":selected_recipes(opening.node)}
   var stop="shelf_limit"
   for shelf in MAX_SHELVES:
    record_shelf(run,sample,shelf)
    var blocked=false
    for step in 64:
     var plan=choose(run,target)
     if plan.is_empty():stop="no_currently_obtainable_path";break
     if plan.node.method=="owned":stop="target_acquired";break
     var ready=ready_recipe(plan.node)
     if not ready.is_empty():
      if craft(run,ready,sample):continue
      if buy_capacity(run,sample):continue
      blocked=true
     if purchase(run,target,relevant,plan,sample):continue
     break
    if stop in ["no_currently_obtainable_path","target_acquired"]:break
    if shelf==MAX_SHELVES-1:break
    var min_price=999
    for kind in relevant:
     if allowed.has(kind):min_price=mini(min_price,int(C.items[kind].price))
    if blocked:
     for kind in inv.available_bags(run):min_price=mini(min_price,int(C.items[kind].price))
    var quote=RECRUIT.refresh_cost(run,true)
    if int(run.gold)<min_price+quote:stop="insufficient_refresh_reserve";break
    var before=int(run.gold)
    if not inv.refresh(run,true):stop="refresh_rejected";break
    sample.ledger.append({"round":rn,"action":"refresh","paid":before-int(run.gold),"gold":run.gold,"seed":run.seed})
   var rows=sample.ledger.slice(start_index);var spend={"buy":0,"refresh":0,"capacity":0,"craft":0};var craft_count=0
   for row in rows:
    if spend.has(row.action):spend[row.action]+=int(row.get("paid",0))
    if row.action=="craft":craft_count+=1
   var total_paid=sample.ledger.reduce(func(total,row):return total+int(row.get("paid",0)),0)
   require(inv.validate_run(run),"valid run "+leader+mode+str(seed_value)+"/"+str(rn))
   require(inv.ECONOMY.budget(rn)-total_paid==int(run.gold),"full public gold ledger "+leader+mode+str(seed_value)+"/"+str(rn))
   sample.rounds.append({"round":rn,"gold":run.gold,"budget":inv.ECONOMY.budget(rn),"spend":spend,"total_spent":total_paid,"crafts":craft_count,"opening_plan":opening_plan,"stop":stop,"items":run.items.duplicate(true),"stash":run.stash.duplicate(true),"bags":run.bags.duplicate(true)})
  return sample


func measure_procurement()->void:
 var start=Time.get_ticks_msec();minimum_costs()
 var engine=Procurement.new();var sample_count=32
 var output={"simulation_version":C.SIMULATION_VERSION,"catalogue_hash":C.catalogue_hash,"seeds_per_leader_policy":sample_count,"seed_formula":"101+index*997","rounds":1,"max_shelves":16,"target":"echo_singilum","minimum_material_cost":costs.echo_singilum,"earliest_leaf_round":earliest.echo_singilum,"samples":[],"summary":{},"policy":"Public transactions only; exact owned-count minimum-additional-spend DP over all current recipes/positive-probability intermediates, copied from V124 procurement measurement; replan after every purchase/craft; pay refresh and required capacity; optional complete starter liquidation; no combat/income/gifts. Full pool only. A bounded strategy diagnostic, not population risk or optimal procurement."}
 for liquidate in [false,true]:
  var group="liquidate_starter" if liquidate else "keep_starter"
  var summary={"runs":0,"completed":0,"materials_bought_cost":0.0,"refresh_spent":0.0,"capacity_spent":0.0,"sales_received":0.0,"ending_gold":0.0,"completed_seeds":[]}
  for leader in ["aemeath","hsin","jingran","zani","lynae"]:
   for index in sample_count:
    var sample=engine.measure_run(leader,"echo_singilum","full",101+index*997,liquidate)
    output.samples.append(sample);summary.runs+=1
    if sample.first_acquired.has("echo_singilum"):summary.completed+=1;summary.completed_seeds.append({"leader":leader,"seed":sample.seed})
    for entry in sample.ledger:
     if entry.action=="buy":summary.materials_bought_cost+=int(entry.paid)
     if entry.action=="refresh":summary.refresh_spent+=int(entry.paid)
     if entry.action=="capacity":summary.capacity_spent+=int(entry.paid)
     if entry.action=="sell":summary.sales_received-=int(entry.paid)
    summary.ending_gold+=int(sample.rounds[0].gold)
   print("R1 PROCUREMENT ",group," ",leader," ",sample_count)
  for key in ["materials_bought_cost","refresh_spent","capacity_spent","sales_received","ending_gold"]:summary[key]/=summary.runs
  output.summary[group]=summary
 output.starting_gold=inv.ECONOMY.starting_gold()
 output.liquidated_starting_cash=output.starting_gold+output.summary.liquidate_starter.sales_received
 output.minimum_opening_additional_cost=output.samples.map(func(a):return a.rounds[0].opening_plan.additional_material_cost).min()
 output.budget_blocks_r1=output.minimum_opening_additional_cost>output.liquidated_starting_cash
 output.checks=engine.checks;output.failures=engine.failures;output.elapsed_seconds=(Time.get_ticks_msec()-start)/1000.0
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 FileAccess.open(OUT+"balance-procurement.json",FileAccess.WRITE).store_string(JSON.stringify(output," "))
 var md="# 辛吉勒姆首轮采购诊断\n\n目录 `%s`。最低原料投入%d金币，最早叶子正概率回合%d。五个主角各32种子，保留开局物品／全部变卖开局物品两策略，共320局；真实初始货架，最多16架，付费刷新与必要扩容，所有买卖／移动／合成走公开事务。全物品池，无收入或战斗奖励。每步在全部候选配方中按已有数量重算最低新增原料投入；获取记录和每笔金币见 [JSON](balance-procurement.json)。\n\n"%[output.catalogue_hash,output.minimum_material_cost,output.earliest_leaf_round]
 md+="|策略|首轮完成/局数|平均购料|平均刷新费|平均扩容费|平均卖出收入|平均余款|\n|---|---:|---:|---:|---:|---:|---:|\n"
 for group in output.summary:
  var x=output.summary[group]
  md+="|%s|%d/%d|%.2f|%.2f|%.2f|%.2f|%.2f|\n"%[group,x.completed,x.runs,x.materials_bought_cost,x.refresh_spent,x.capacity_spent,x.sales_received,x.ending_gold]
 md+="\n保留开局物品时仅9金币，且开局物品不抵扣辛吉勒姆的最低12金币原料树，因此这一策略无法首轮完成；实际变卖全部开局物品只回收2金币（起始paid_cost=0，只有武器salvage_credit=2），最高可用11金币，仍低于所有替代路径的最低12金币。这是当前五主角、真实新局、无额外奖励的首轮预算阻断，不能只按叶子非零概率宣称首轮能完成；刷新费用只会进一步降低可用原料预算。320局零观察与预算边界一致。该结论不外推到额外授予物品/金币、自定义开局或后续回合；只测首轮风险，不替代多回合供给易用性、完成回合或全局最优策略。\n\n%d检查，%d失败；%.2f秒。命令：`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/scenarios/measure_ecosystem_v125.gd -- --procurement`。\n"%[output.checks,output.failures.size(),output.elapsed_seconds]
 FileAccess.open(OUT+"balance-procurement.md",FileAccess.WRITE).store_string(md)
 print("R1 PROCUREMENT COMPLETE ",output.summary," failures ",engine.failures.size())
 quit(0 if engine.failures.is_empty() else 1)

func effect_markdown()->String:
 var out="## 新组件实际发动与归因\n\n以下均为同两个固定对手双侧的20秒均值；每行选择含该组件的关联构筑。亮星可能只准备下一次攻击，不等于收益已经交付；附加伤害按引擎归属实际攻击者，不能用材料自身0伤害判无效。\n\n|组件 / 样本|亮星|自然攻击|归因伤害|其中反击|招架减伤|冷却推进秒|实际回耐|\n|---|---:|---:|---:|---:|---:|---:|---:|\n"
 var samples={"echo_porcelain":report.layout.relay_porcelain.linked_mean,"echo_anger":report.layout.heavy_anger.linked_mean,"echo_sorrow":report.layout.guard_sorrow.linked_mean,"echo_gliding_sentry":report.layout.guard_sentry.linked_mean,"echo_moth":report.layout.heavy_moth.linked_mean,"echo_singilum":report.singilum.linked_mean,"relic_diverter":report.gear.gear_heavy.linked_mean,"relic_lunchbox":report.stamina.fast3_lunch.mean}
 for kind in samples:
  for row in samples[kind].per_uid.values():
   if row.kind!=kind:continue
   out+="|%s|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|\n"%[row.name,row.star_triggers,row.natural_attacks,row.damage,row.counter_damage,row.guard_prevented,row.advance_seconds,row.stamina_actual]
 return out+"\n"

func geometry_audit()->void:
 var kinds=["weapon_21020106","echo_porcelain","zig","whiff"]
 var options=kinds.map(func(k):return placements(k))
 var inspected=0;var solutions=0
 for weapon in options[0]:
  for porcelain in options[1]:
   if int(weapon.cells)&int(porcelain.cells) or not (int(weapon.stars)&int(porcelain.cells)):continue
   for partner in options[3]:
    if int(partner.cells)&(int(weapon.cells)|int(porcelain.cells)):continue
    if not (int(weapon.stars)&int(partner.cells)):continue
    inspected+=1
    if int(porcelain.stars)&int(partner.cells):solutions+=1
 var output={"catalogue_hash":C.catalogue_hash,"board":"9x6 neutral covered cells","rotations":4,"proposed_three_item_graph":{"weapon_21020106":["echo_porcelain","whiff"],"echo_porcelain":["whiff"]},"nonoverlapping_triples_with_both_yunlang_links":inspected,"triples_also_linking_porcelain_to_whiff":solutions,"four_item_graph":{"weapon_21020106":["zig","whiff"],"echo_porcelain":["zig"]},"geometric_definitions":{}}
 for kind in kinds:
  var piece=inv.make_piece(kind,"audit")
  output.geometric_definitions[kind]={"cells":inv.occupied(piece).map(func(v):return [v.x,v.y]),"stars":inv.stars(piece).map(func(v):return [v.x,v.y])}
 ck(solutions==0,"current proposed three-item closed relay is geometrically impossible")
 configure();var legal=arrange("relay_porcelain",true)
 output.four_item_legal_fixture=legal
 output.checks=checks;output.failures=failures
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 FileAccess.open(OUT+"balance-geometry.json",FileAccess.WRITE).store_string(JSON.stringify(output,"  "))
 print("GEOMETRY AUDIT ",inspected," candidate triples, ",solutions," closed triples, ",checks," checks, ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
