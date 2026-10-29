extends SceneTree
## Current catalogue procurement measurement. No Storage, battle, selling or rewards.
## Material-path search is exact over remaining owned counts; capacity and refresh
## costs are actual ledger entries, not predicted waiting-time costs.
const I=preload("res://scripts/inventory/inventory.gd")
const C=preload("res://scripts/data/catalog.gd")
const F=preload("res://scripts/crafting/craft.gd")
const SHOP=preload("res://scripts/shop/shop_v75.gd")
const RECRUIT=preload("res://scripts/party/recruitment.gd")
const CASES=[["aemeath", "relic_march_lunchbox"], ["aemeath", "relic_emergency_lunchbox"], ["aemeath", "provision_strong_tea"], ["aemeath", "provision_clear_tea"], ["aemeath", "relic_capacitor"], ["aemeath", "relic_pulse_gear"], ["aemeath", "elegance"], ["aemeath", "relic_echo_relay"], ["aemeath", "relic_layered_guard"], ["aemeath", "relic_recoil_guard"], ["aemeath", "relic_crack_driver"], ["aemeath", "relic_breach_scope"], ["aemeath", "relic_noise_chamber"], ["aemeath", "relic_noise_chime"], ["aemeath", "relic_frost_condenser"], ["aemeath", "relic_shatter_prism"]]
const MAX_SHELVES=16
var output="res://build/qa/families-v127/supply-current"
var material_slack=0
var inv=I.new()
var incoming={}
var outgoing={}
var allowed={}
var memo={}
var pool_cache={}
var failures=[]

func require(ok:bool,message:String)->bool:
 if not ok:failures.append(message);printerr("FAIL ",message)
 return ok

func _initialize():call_deferred("measure")
func measure():
 var args=OS.get_cmdline_user_args();var seed_count=int(args[0]) if not args.is_empty() else 6
 if args.has("--opportunistic"):
  material_slack=1;output="res://build/qa/families-v127/supply-opportunistic"
 if not require(seed_count>0,"positive seed count"):quit(1);return
 for recipe in C.combinations:
  if not incoming.has(recipe.target):incoming[recipe.target]=[]
  incoming[recipe.target].append(recipe)
  for kind in [recipe.base]+recipe.materials:outgoing[kind]=true
 for kind in incoming:incoming[kind].sort_custom(func(a,b):return str(a.id)<str(b.id))
 require(C.combinations.size()==202,"current 202 recipes included")
 var report={"catalogue_hash":C.catalogue_hash,"simulation_version":C.SIMULATION_VERSION,"supply_version":127,"seeds_per_case":seed_count,"seed_formula":"101 + index * 997","round_count":5,"shelf_limit_per_round":MAX_SHELVES,"recipe_count":C.combinations.size(),"policy":"targeted minimum additional material spend; exact owned-count DP across every incoming recipe and currently positive-probability purchasable intermediate; replan after each transaction; actual paid refresh/capacity; draw income, no combat, selling or recruitment rewards","classification":{"q5":"rarity == 5; distinct from numeric profile tier","terminal_weapon":"weapon has at least one incoming recipe and no outgoing use as base or material","appearance":"shop_seen and acquired are reported separately; any acquired intermediate counts even if consumed later"},"samples":[],"audit":[]}
 report.material_slack=material_slack
 if material_slack>0:report.policy+="; accept a currently available input costing at most one extra material coin if it strictly reduces remaining cost, avoiding repeated refreshes for an already sunk cheaper path"
 audit_paths(report)
 for mode in ["full"]:
  for pair in CASES:
   for seed_index in seed_count:
    report.samples.append(measure_run(str(pair[0]),str(pair[1]),mode,101+seed_index*997))
   print("MEASURE_V127 ",mode," ",pair[0]," ",seed_count," seeds")
 report.summary=summarize(report.samples)
 report.failures=failures.duplicate()
 require(report.samples.size()==CASES.size()*seed_count,"complete sample matrix")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/qa/families-v127"))
 FileAccess.open(output+".json",FileAccess.WRITE).store_string(JSON.stringify(report," "))
 FileAccess.open(output+".md",FileAccess.WRITE).store_string(markdown(report))
 print("SUPPLY_V127 ",report.samples.size()," runs, ",report.samples.size()*5," round observations, ",failures.size()," failures; ",output)
 quit(0 if failures.is_empty() else 1)

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
  if after.is_empty() or int(after[0].cost)>=int(plan.cost) or price+int(after[0].cost)>int(plan.cost)+material_slack:continue
  var row={"slot":slot,"price":price,"total":price+int(after[0].cost)}
  if best.is_empty() or row.total<best.total or (row.total==best.total and row.price<best.price):best=row
 if best.is_empty():return false
 var kind=str(run.shop[best.slot].kind);var prior=int(run.gold);var known=(run.items+run.stash).map(func(p):return p.uid)
 if not inv.buy(run,best.slot):return false
 var fresh=(run.items+run.stash).filter(func(p):return p.uid not in known)
 require(prior-int(run.gold)==int(best.price),"purchase matches public quote")
 sample.ledger.append({"round":run.round,"action":"buy","slot":best.slot,"kind":kind,"paid":prior-int(run.gold),"gold":run.gold,"acquired":fresh.duplicate(true),"minimum_remaining_before":plan.cost,"material_overpay":best.total-int(plan.cost)})
 acquired(sample,kind,int(run.round),"shop")
 return true

func measure_run(leader:String,target:String,mode:String,seed_value:int)->Dictionary:
 var run=inv.new_run_supply(leader,seed_value,mode,127)
 var sample={"mode":mode,"leader":leader,"target":target,"target_name":C.items[target].name,"seed":seed_value,"first_craft":0,"first_weapon_craft":0,"first_q5":0,"first_q5_weapon":0,"first_q5_nonterminal":0,"first_terminal":0,"first_shop_q5":0,"first_acquired":{},"ledger":[],"rounds":[]}
 var relevant={};descendants(target,relevant)
 for p in run.items+run.stash:acquired(sample,p.kind,1,"starting_inventory")
 for rn in range(1,6):
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

func audit_paths(report:Dictionary)->void:
 for pair in CASES:
  for mode in ["full"]:
   var run=inv.new_run_supply(pair[0],101,mode,127)
   for rn in range(1,6):
    run.round=rn;allowed=supply_allowed(run);var plan=choose(run,pair[1])
    report.audit.append({"leader":pair[0],"mode":mode,"round":rn,"kind":pair[1],"name":C.items[pair[1]].name,"rarity":C.items[pair[1]].rarity,"profile_tier":C.profile(pair[1]).get("tier",0),"terminal_weapon":terminal(pair[1]),"obtainable":not plan.is_empty(),"additional_cost_from_starting_inventory":null if plan.is_empty() else plan.cost,"tree":{} if plan.is_empty() else plan.node})
func summarize(samples:Array)->Dictionary:
 var summary={"runs":samples.size(),"first_craft_rounds":{},"first_weapon_craft_rounds":{},"by_round":[],"q5_acquired_r1":0,"q5_acquired_r2_cumulative":0,"q5_weapon_acquired_r2_cumulative":0,"q5_nonterminal_acquired_r2_cumulative":0,"terminal_weapon_acquired_r2_cumulative":0,"q5_shop_seen_r2_cumulative":0,"target_by_r5":0,"groups":[]}
 for sample in samples:
  for field in ["first_craft","first_weapon_craft"]:
   var bucket="first_craft_rounds" if field=="first_craft" else "first_weapon_craft_rounds"
   var key="not_obtained" if sample[field]==0 else str(sample[field]);summary[bucket][key]=int(summary[bucket].get(key,0))+1
  if sample.first_q5==1:summary.q5_acquired_r1+=1
  if sample.first_q5>0 and sample.first_q5<=2:summary.q5_acquired_r2_cumulative+=1
  if sample.first_q5_weapon>0 and sample.first_q5_weapon<=2:summary.q5_weapon_acquired_r2_cumulative+=1
  if sample.first_q5_nonterminal>0 and sample.first_q5_nonterminal<=2:summary.q5_nonterminal_acquired_r2_cumulative+=1
  if sample.first_terminal>0 and sample.first_terminal<=2:summary.terminal_weapon_acquired_r2_cumulative+=1
  if sample.first_shop_q5>0 and sample.first_shop_q5<=2:summary.q5_shop_seen_r2_cumulative+=1
  if sample.first_acquired.has(sample.target):summary.target_by_r5+=1
 for rn in range(1,6):
  var row={"round":rn,"runs_crafted":0,"runs_ever_crafted":0,"crafts":0,"buy_spend":0,"refresh_spend":0,"capacity_spend":0,"craft_spend":0,"q5_acquired_cumulative":0,"terminal_weapon_acquired_cumulative":0}
  for sample in samples:
   var actual=sample.rounds[rn-1]
   if actual.crafts>0:row.runs_crafted+=1
   if sample.first_craft>0 and sample.first_craft<=rn:row.runs_ever_crafted+=1
   row.crafts+=actual.crafts
   for kind in actual.spend:row[kind+"_spend"]+=int(actual.spend[kind])
   if sample.first_q5>0 and sample.first_q5<=rn:row.q5_acquired_cumulative+=1
   if sample.first_terminal>0 and sample.first_terminal<=rn:row.terminal_weapon_acquired_cumulative+=1
  row.spend_total=row.buy_spend+row.refresh_spend+row.capacity_spend+row.craft_spend
  summary.by_round.append(row)
 for mode in ["full"]:
  for pair in CASES:
   var group=samples.filter(func(s):return s.mode==mode and s.leader==pair[0] and s.target==pair[1])
   if group.is_empty():continue
   summary.groups.append({"mode":mode,"leader":pair[0],"target":pair[1],"runs":group.size(),"crafted_by_r5":group.filter(func(s):return s.first_craft>0).size(),"q5_by_r2":group.filter(func(s):return s.first_q5>0 and s.first_q5<=2).size(),"terminal_by_r2":group.filter(func(s):return s.first_terminal>0 and s.first_terminal<=2).size(),"target_by_r5":group.filter(func(s):return s.first_acquired.has(s.target)).size()})
 return summary
func pct(count:int,total:int)->String:return "%.1f%%"%(100.0*count/maxi(1,total))
func markdown(report:Dictionary)->String:
 var s=report.summary;var n=int(s.runs)
 var lines=["# V127 当前供给测量", "", "目录：`"+C.catalogue_hash+"`；模拟：`"+C.SIMULATION_VERSION+"`；供给：127；202 条配方。", "", "16 条分支 × full × "+str(report.seeds_per_case)+" 固定种子，共 "+str(n)+" 局、"+str(n*5)+" 个前五回合观测。只用公共购买、移动、刷新、扩容和精确配方合成事务；无真实 Storage。", "", "## 指标", "", "- 第一回合获得 Q5：%d/%d（%s）。"%[s.q5_acquired_r1,n,pct(s.q5_acquired_r1,n)], "- 第二回合结束前获得任意 Q5：%d/%d（%s）；Q5 武器：%d/%d。"%[s.q5_acquired_r2_cumulative,n,pct(s.q5_acquired_r2_cumulative,n),s.q5_weapon_acquired_r2_cumulative,n], "- 第二回合结束前获得非终极 Q5：%d/%d；终极武器：%d/%d。"%[s.q5_nonterminal_acquired_r2_cumulative,n,s.terminal_weapon_acquired_r2_cumulative,n], "- 第二回合结束前商店观察到 Q5：%d/%d。"%[s.q5_shop_seen_r2_cumulative,n], "- 五回合内达到指定目标：%d/%d（%s）。"%[s.target_by_r5,n,pct(s.target_by_r5,n)], "- 首次合成回合分布：`"+JSON.stringify(s.first_craft_rounds)+"`；首次武器合成：`"+JSON.stringify(s.first_weapon_craft_rounds)+"`。", "", "Q5 使用 `rarity == 5`；终极武器使用完整配方图中既有入边、又无任何出边（包括作为材料）的武器。获得统计包含后来被消耗的中间品；商店出现单独列出。", "", "| 回合 | 本轮有合成 | 累计曾合成 | 合成次数 | 人均购买 | 人均刷新 | 人均扩容 | 人均总花费 | 累计 Q5 | 累计终极武器 |", "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|"]
 for row in s.by_round:
  lines.append("| %d | %d/%d (%s) | %d/%d | %d | %.2f | %.2f | %.2f | %.2f | %d/%d | %d/%d |"%[row.round,row.runs_crafted,n,pct(row.runs_crafted,n),row.runs_ever_crafted,n,row.crafts,float(row.buy_spend)/n,float(row.refresh_spend)/n,float(row.capacity_spend)/n,float(row.spend_total)/n,row.q5_acquired_cumulative,n,row.terminal_weapon_acquired_cumulative,n])
 lines.append_array(["", "| 模式 | 领队 | 指定目标 | 五回合曾合成 | R1–2 Q5 | R1–2 终极武器 | 五回合达标 |", "|---|---|---|---:|---:|---:|---:|"])
 for row in s.groups:lines.append("| %s | %s | %s | %d/%d | %d/%d | %d/%d | %d/%d |"%[row.mode,row.leader,C.items[row.target].name,row.crafted_by_r5,row.runs,row.q5_by_r2,row.runs,row.terminal_by_r2,row.runs,row.target_by_r5,row.runs])
 lines.append_array(["", "## 获取路径与边界", "", "1. 从公共普通商品分布读取当前回合实际正概率的可购买物品。逐个目标枚举全部入边，并比较已有库存、直接购买中间品、递归合成。", "2. 动态规划按剩余库存数量保留最低额外材料金币方案；一件库存只能分配一次。每次真实交易后重新计算，货架购买允许最多多付 "+str(material_slack)+" 币材料成本，但必须减少剩余需求；同价按稳定顺序选择。", "3. 材料路径成本不含无法提前确定的刷新等待与扩容费；实际支出逐笔入账。空间阻挡时才购买当前货架可放置的容量，成品可按公共规则进入无限库存。", "4. 每回合最多观察 16 张货架；只取公开平局收入，不模拟战斗、消耗补给、招募或领取奖励，不出售；达到目标后停止采购。", "5. 这是16 条目标路线的固定策略小样本，不是无目标玩家、最短期望完成时间、全流派平衡或所有种子的概率保证。每个模式/领队仅 "+str(report.seeds_per_case)+" 个种子；新旧测量器路径及空间策略不同，不能直接当作配对因果比较。", "6. JSON 保存每次货架、真实购买/刷新/扩容/合成、准确 recipe_id、实际 paid_cost、各轮完整库存与金币守恒检查。路径审计使用当前 C.profile，覆盖 202 条配方的多入边。", "", "运行：", "", "```bash", "/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/scenarios/measure_supply_v127.gd -- "+str(report.seeds_per_case)+(" --opportunistic" if material_slack>0 else "")+"", "```", "", "验证失败数："+str(report.failures.size())+"。", ""])
 return "\n".join(lines)
