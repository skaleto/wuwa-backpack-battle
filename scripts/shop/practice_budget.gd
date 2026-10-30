extends RefCounted
## Public procurement. Permanent supplies carry across rounds like other equipment.
const C=preload("res://scripts/data/catalog.gd")
const F=preload("res://scripts/crafting/craft.gd")
const SUP=preload("res://scripts/party/supports.gd")
const CRAFT_RULES=preload("res://scripts/crafting/craft_rules.gd")
const PLACEMENT=preload("res://scripts/shop/practice_placement.gd")
const METHOD="shop-procurement-v116"
const RECRUIT=preload("res://scripts/party/recruitment.gd")
const PROGRESSION=preload("res://scripts/run/run_progression.gd")
const OPENING_RESERVE=[4,6,6]
const ROUTES=["充能重击","迅捷联动","护盾反击"]
static func build(inv,round_number:int,seed_value:int,pool_mode:String="full",legacy:bool=false,version:int=115,supply_version:int=0)->Dictionary:
 var run=make_run(inv,round_number,seed_value,pool_mode,legacy,version,supply_version)
 var ghost=inv.snapshot(run,"practice","演练 · "+C.characters[run.leader].name)
 ghost.source="practice"
 for key in ["practice_budget","practice_spend","practice_unspent","practice_method","practice_seed","practice_ledger"]:ghost[key]=run[key].duplicate(true) if run[key] is Array else run[key]
 return ghost
static func make_run(inv,round_number:int,seed_value:int,pool_mode:String="full",legacy:bool=false,version:int=115,supply_version:int=0)->Dictionary:
 var target=clampi(round_number,1,PROGRESSION.MAX_ROUNDS);var leaders=["aemeath","hsin","suisui","qingxiao","lu_hers","yangyang_xuanling"] if legacy or version==114 else C.selectable_leaders()
 var run=inv.new_run(leaders[posmod(seed_value,leaders.size())],posmod(seed_value,4294967296),pool_mode)
 # Preserve historical constructor overrides, but select supply before the first
 # procurement shelf. Restart that shelf from its original seed, without a cost.
 run.erase('supply_version')
 if supply_version!=0:run.supply_version=supply_version
 run.seed=posmod(seed_value,4294967296);run.shop=[];inv.refresh(run)
 if version==114:run.recruitment=preload("res://scripts/party/recruitment_v114.gd").initial()
 if legacy:run.erase("recruitment");run.recruitment_legacy=true
 run.simulation_version=RECRUIT.simulation_version(run)
 run.practice_method=METHOD+"-crew114" if version==114 else METHOD+"-legacy" if legacy else METHOD;run.practice_seed=seed_value;run.practice_ledger=[]
 if supply_version!=0:run.practice_method+='-supply'+str(supply_version)
 var route=ROUTES[posmod(seed_value,3)]
 for current in range(1,target+1):
  run.round=current
  if current>1:
   run.gold+=inv.ECONOMY.income(0,current);run.refreshes=0
   if RECRUIT.open_draft(inv,run,current-1):
    var cards=RECRUIT.card_models(inv,run)
    cards.sort_custom(func(a,b):return int(a.usable)>int(b.usable))
    var card=cards[0];var reward=card.reward_choices[0].kind if not card.reward_choices.is_empty() else 'gold' if card.gold_fallback else ''
    var result=inv.commit_operation(run,RECRUIT.plan_confirm(inv,run,card.role_id,reward))
    assert(result.ok)
    record(run,'recruit',card.role_id,0,{'node':current-1,'reward':result.value.reward,'gold_reward':result.value.gold})
   else:inv.refresh(run)
  procure(inv,run,route,true)
 run.practice_budget=inv.ECONOMY.budget(target)+run.practice_ledger.reduce(func(total,row):return total+int(row.get("gold_reward",0)),0)
 run.practice_spend=run.practice_ledger.reduce(func(sum,row):return sum+int(row.gold),0)
 run.practice_unspent=run.gold
 assert(inv.validate_run(run),"Generated practice build is invalid")
 assert(run.practice_spend+run.gold==run.practice_budget)
 return run
static func record(run:Dictionary,purpose:String,kind:String,paid:int,detail:Dictionary={})->void:
 if not run.has("practice_ledger"):run.practice_ledger=[]
 var entry={"round":run.round,"purpose":purpose,"kind":kind,"gold":paid,"balance":run.gold,"source":"public_transaction"}
 entry.merge(detail,true);run.practice_ledger.append(entry)
static func route_match(kind:String,route:String)->bool:
 return route=="通用" or C.profile(kind).get("route","") in [route,"通用"]
static func target_unlocked(_run:Dictionary,kind:String)->bool:
 return C.items.has(kind) and CRAFT_RULES.unlocked(C.items[kind],[],[])
static func missing_recipes(run:Dictionary,kind:String)->Array:
 var owned=run.items+run.stash;var result=[]
 for recipe in C.combinations:
  if not target_unlocked(run,recipe.target):continue
  var pair=[recipe.base,recipe.materials[0]]
  if kind not in pair or owned.any(func(i):return i.kind==kind):continue
  var other=pair[1] if kind==pair[0] else pair[0]
  if owned.any(func(i):return i.kind==other):result.append(recipe)
 return result
static func utility(run:Dictionary,slot:int,route:String)->float:
 if slot>=run.shop.size() or run.shop[slot].is_empty():return -1
 var kind=run.shop[slot].kind;var d=C.items[kind]
 if d.price>run.gold:return -1
 var owned=run.items+run.stash
 var recipes=missing_recipes(run,kind)
 if not recipes.is_empty():
  return 14+(6 if recipes.any(func(r):return route_match(r.target,route)) else 0)-float(d.price)*.25
 if owned.any(func(i):return i.kind==kind):return -1
 if C.is_tag(kind,"craft_material"):
  var component=C.profile(kind).get("material_effect",{})
  if component.is_empty():return -1
  var category=str(component.category)
  if not category.is_empty() and not run.items.any(func(i):return C.is_tag(i.kind,category)):return -1
  # Useful stopgap, below a dedicated weapon/echo or a ready recipe partner.
  return 2.5-float(d.price)*.35
 if C.is_tag(kind,"weapon"):
  var same=owned.filter(func(i):return C.is_tag(i.kind,"weapon") and C.items[i.kind].weapon_type==d.weapon_type)
  if not same.is_empty() and same.any(func(i):return float(C.items[i.kind].get("damage",0))/maxf(.1,C.items[i.kind].get("cooldown",1))>=float(d.damage)/maxf(.1,d.cooldown)):return -1
  return 8+(4 if route_match(kind,route) else 0)-float(d.price)*.3
 return 5+(4 if route_match(kind,route) else 0)+(2 if C.is_tag(kind,"echo") else 0)-float(d.price)*.35
static func purchase(inv,run:Dictionary,slot:int,purpose:String,conservative:bool=true)->bool:
 if slot>=run.shop.size() or run.shop[slot].is_empty():return false
 var kind=run.shop[slot].kind
 if conservative and run.round<=3 and int(run.gold)-int(inv.purchase_price(run,slot))<OPENING_RESERVE[int(run.round)-1]:return false
 if C.is_tag(kind,"bag") and inv.coverage(run.bags).size()>=mini(42,6+run.round*5):return false
 var fit=inv.first_fit(inv.make_piece(kind,"candidate"),run.items,run.bags)
 var before=int(run.gold);var item={};var destination="board"
 var known=(run.items+run.stash).map(func(p):return p.uid)
 if not fit.is_empty():item=inv.purchase_at(run,slot,fit,"board")
 elif not C.is_tag(kind,"bag") and not missing_recipes(run,kind).is_empty():
  destination="stash";item=inv.purchase_at(run,slot,inv.make_piece(kind,"candidate"),"stash")
 if item.is_empty():return false
 record(run,purpose,kind,before-int(run.gold),{"slot":slot,"uid":item.uid,"destination":destination,"placement":[item.x,item.y,item.rotation],"acquired":(run.items+run.stash).filter(func(p):return p.uid not in known).duplicate(true)})
 return true
static func procure(inv,run:Dictionary,route:String,conservative:bool=true)->void:
 var faces=1 if conservative and run.round<=3 else 2
 for shelf in faces:
  record(run,"shelf","",0,{"offers":run.shop.duplicate(true)})
  if int(run.get("supply_version",0))>=140:
   for slot in 6:
    if C.is_tag(run.shop[slot].get("kind",""),"bag") and purchase(inv,run,slot,"capacity",conservative):break
  else:purchase(inv,run,5,"capacity",conservative)
  craft_owned(inv,run,route)
  var bought=0
  # Rescore after every purchase/fusion; newly missing inputs can be on this shelf.
  for attempt in 5:
   if conservative and run.round<=3 and bought>=run.round:break
   var picks=range(6).filter(func(n):return not C.is_tag(run.shop[n].get("kind",""),"bag")) if int(run.get("supply_version",0))>=140 else [0,1,2,3,4]
   picks.sort_custom(func(a,b):return utility(run,a,route)>utility(run,b,route))
   var success=false
   for slot in picks:
    if utility(run,slot,route)>0 and purchase(inv,run,slot,"shop",conservative):
     bought+=1;success=true;craft_owned(inv,run,route);break
   if not success:break
  if shelf+1<faces and run.gold>=2:
   var before=int(run.gold)
   if not directed_refresh(inv,run) and inv.refresh(run,true):record(run,"refresh","",before-int(run.gold))
 # The bounded legacy mode retains its original optional paid-roster policy.
 if not RECRUIT.enabled(run) and not conservative and run.round>=3 and run.gold>=7 and run.supports.size()<SUP.MAX_SUPPORTS:
  for role in SUP.candidates(run):
   var before=int(run.gold)
   if inv.recruit(run,role):record(run,"recruit",role,before-int(run.gold));break
 for item in run.stash.duplicate(true):
  if C.is_tag(item.kind,"bag"):continue
  var fit=inv.first_fit(item,run.items,run.bags)
  if not fit.is_empty() and inv.place(run,fit):record(run,"place",item.kind,0,{"uid":item.uid,"placement":[fit.x,fit.y,fit.rotation]})
 arrange(inv,run)
 configure(inv,run)
static func directed_refresh(inv,run:Dictionary)->bool:
 if not RECRUIT.has_ability(run,'supply'):return false
 for option in RECRUIT.crew_setup_choices(inv,run).supply:
  var target=option.config.supply;var kinds=target.get('kinds',target.get('pool',[]))
  var price=0
  if target.get('kinds',[]).size()==2:price=int(ceil(kinds.reduce(func(total,k):return total+int(C.items[k].price),0)*.8))
  else:
   for kind in kinds:price=maxi(price,int(C.items[kind].price))
  if kinds.is_empty() or int(run.gold)<price+1:continue
  var result=inv.commit_operation(run,RECRUIT.plan_configure(inv,run,option.config))
  if result.ok:
   record(run,'refresh','',1,{'target':target.duplicate(true),'offer':result.value.offer.duplicate(true)})
   return true
 return false
static func configure(inv,run:Dictionary)->void:
 for key in ['artisan_return','artisan_star','link','guard','volley']:
  var options=RECRUIT.crew_setup_choices(inv,run)[key]
  var choices=options.filter(func(o):return o.id!='off')
  if not choices.is_empty():
   var result=inv.commit_operation(run,RECRUIT.plan_configure(inv,run,choices[0].config))
   if result.ok:record(run,'crew_setup',key,0,{'config':choices[0].config,'reward':result.get('value',{}).get('created',{})})
static func craft_owned(inv,run:Dictionary,route:String="通用")->void:
 var recipes=C.combinations.duplicate()
 recipes.sort_custom(func(a,b):return int(route_match(a.target,route))>int(route_match(b.target,route)))
 for step in 12:
  var changed=false
  for recipe in recipes:
   if not inv.craft_unlocked(run,recipe.target):continue
   var owned=run.items+run.stash
   var bases=owned.filter(func(i):return i.kind==recipe.base)
   if bases.is_empty() or not owned.any(func(i):return i.kind==recipe.materials[0]):continue
   for base in bases:
    var candidate=run.duplicate(true)
    if not candidate.items.any(func(i):return i.uid==base.uid):
     var fit=inv.first_fit(base,candidate.items,candidate.bags)
     if fit.is_empty() or not inv.place(candidate,fit):continue
    F.place_material(candidate,recipe.target,base.uid,recipe.materials[0],inv,Callable(),recipe.id)
    var placed_inputs=candidate.items.duplicate(true)
    # Keep the established opponent procurement policy: only take an upgrade
    # that can be equipped now, rather than consuming active gear into storage.
    var preview=F.preview(candidate,recipe.target,base.uid,inv,{},recipe.id)
    if not preview.ok or preview.get("destination","board")=="stash":continue
    var before_craft_gold=int(candidate.gold)
    var tx=F.transact(candidate,recipe.target,base.uid,inv,{},Callable(),recipe.id)
    if not tx.ok:continue
    var inputs=placed_inputs.filter(func(i):return i.uid in tx.consumed)
    run.clear();run.merge(candidate,true)
    record(run,"craft",recipe.target,0,{"recipe":recipe.id,"inputs":inputs,"consumed":tx.consumed,"output":tx.output,"crew_rewards":tx.get("crew_rewards",[]),"gold_reward":int(candidate.gold)-before_craft_gold})
    changed=true;break
   if changed:break
  if not changed:break
static func bonds(inv,run:Dictionary)->int:
 var total=0
 for item in run.items:total+=inv.star_links(item,run.items,run).size()
 return total
static func arrange(inv,run:Dictionary)->void:
 var before=run.items.duplicate(true)
 PLACEMENT.arrange(inv,run)
 for item in run.items:
  var old=before.filter(func(i):return i.uid==item.uid)
  if not old.is_empty() and item!=old[0]:record(run,"move",item.kind,0,{"uid":item.uid,"from":[old[0].x,old[0].y,old[0].rotation],"placement":[item.x,item.y,item.rotation]})
