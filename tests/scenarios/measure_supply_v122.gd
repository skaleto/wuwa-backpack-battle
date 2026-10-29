extends SceneTree
## Budgeted adversarial procurement. All purchases, moves, refreshes and crafts
## use public transactions. No Storage, combat rewards, free rerolls or bags.
const I=preload('res://scripts/inventory/inventory.gd')
const C=preload('res://scripts/data/catalog.gd')
const F=preload('res://scripts/crafting/craft.gd')
var inv=I.new()
var recipes={}
const CASES=[['aemeath','weapon_21020106'],['hsin','weapon_21050045'],['jingran','weapon_21010036'],['zani','weapon_21040046'],['lynae','weapon_21030066']]
func _initialize():
 for recipe in C.combinations:recipes[recipe.target]=recipe
 var args=OS.get_cmdline_user_args()
 var label=args[0] if args.size()>0 else 'baseline'
 var count=int(args[1]) if args.size()>1 else 24
 var report={'label':label,'seeds':count,'rounds':5,'policy':'targeted public procurement; no selling, paid capacity as needed, no recruitment rewards; draw income only','samples':[],'audit':[]}
 for recipe in C.combinations:
  var k=recipe.target
  if not C.is_tag(k,'weapon'):continue
  var leaves=leaf_kinds(k);var cost=0;var rounds={}
  for leaf in leaves:cost+=int(C.items[leaf].price);rounds[leaf]=C.items[leaf].v75.shop_round
  report.audit.append({'kind':k,'name':C.items[k].name,'rarity':C.items[k].rarity,'tier':C.items[k].v75.tier,'terminal':not C.combinations.any(func(r):return r.base==k or k in r.materials),'leaf_cost':cost,'leaves':leaves,'leaf_rounds':rounds})
 for mode in ['full','focused']:
  for pair in CASES:
   for seed_index in count:
    var run=inv.new_run_supply(pair[0],101+seed_index*997,mode,122 if label=='current' else 0)
    if label=='current':
     assert(run.get('supply_version',0)==122)
    var sample={'mode':mode,'leader':pair[0],'target':pair[1],'seed':101+seed_index*997,'first_upgrade':0,'first_quality4':0,'first_terminal':0,'ledger':[],'rounds':[]}
    for rn in range(1,6):
     if rn>1:
      run.round=rn;run.gold+=inv.ECONOMY.income(0,rn);run.refreshes=0
      assert(inv.refresh(run))
     for shelf in 16:
      buy_capacity(run,pair[1],sample)
      sample.ledger.append({'round':rn,'action':'shelf','gold':run.gold,'offers':run.shop.duplicate(true)})
      for step in 8:
       craft_target(run,pair[1],sample)
       var needed=needed_kinds(run,pair[1]);var bought=false
       for slot in 5:
        if run.shop[slot].is_empty() or run.shop[slot].kind not in needed:continue
        var kind=run.shop[slot].kind;var before=int(run.gold)
        if inv.buy(run,slot):sample.ledger.append({'round':rn,'action':'buy','kind':kind,'paid':before-int(run.gold),'gold':run.gold});bought=true;break
       if not bought:break
      craft_target(run,pair[1],sample)
      if (run.items+run.stash).any(func(p):return p.kind==pair[1]):break
      var needed=needed_kinds(run,pair[1]);var minimum=999
      for kind in needed:minimum=mini(minimum,int(C.items[kind].price))
      var refresh_price=preload('res://scripts/party/recruitment.gd').refresh_cost(run,true)
      if run.gold<minimum+refresh_price:break
      var before=int(run.gold)
      if not inv.refresh(run,true):break
      sample.ledger.append({'round':rn,'action':'refresh','paid':before-int(run.gold),'gold':run.gold})
     assert(inv.validate_run(run))
     sample.rounds.append({'round':rn,'gold':run.gold,'items':(run.items+run.stash).map(func(p):return p.kind)})
    report.samples.append(sample)
   print('MEASURE ',label,' ',mode,' ',pair[0],' ',count)
 var path='res://build/qa/feedback-v122/supply-'+label+'.json'
 var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(report,' '));file.close()
 print('SUPPLY_METRICS ',path,' ',report.samples.size())
 quit()
func leaf_kinds(kind:String)->Array:
 if not recipes.has(kind):return [kind]
 return leaf_kinds(recipes[kind].base)+leaf_kinds(recipes[kind].materials[0])
func needed_kinds(run:Dictionary,target:String)->Array:
 var owned={}
 for p in run.items+run.stash:owned[p.kind]=int(owned.get(p.kind,0))+1
 return missing_tree(target,owned)
func missing_tree(kind:String,owned:Dictionary)->Array:
 if int(owned.get(kind,0))>0:owned[kind]-=1;return []
 if not recipes.has(kind):return [kind]
 return [kind]+missing_tree(recipes[kind].base,owned)+missing_tree(recipes[kind].materials[0],owned)
func craft_target(run:Dictionary,target:String,sample:Dictionary)->void:
 if not recipes.has(target) or (run.items+run.stash).any(func(p):return p.kind==target):return
 var recipe=recipes[target]
 craft_target(run,recipe.base,sample);craft_target(run,recipe.materials[0],sample)
 var owned=run.items+run.stash
 var bases=owned.filter(func(p):return p.kind==recipe.base)
 if bases.is_empty() or not owned.any(func(p):return p.kind==recipe.materials[0]):return
 var base=bases[0]
 for p in run.items.duplicate(true):
  if p.uid!=base.uid:assert(inv.stash(run,p))
 if not run.items.any(func(p):return p.uid==base.uid):
  var fit=inv.first_fit(base,run.items,run.bags)
  if fit.is_empty() or not inv.place(run,fit):return
 F.place_material(run,target,base.uid,recipe.materials[0],inv)
 var result=F.transact(run,target,base.uid,inv)
 if not result.ok:return
 sample.ledger.append({'round':run.round,'action':'craft','kind':target,'gold':run.gold,'destination':result.get('destination','board')})
 if C.is_tag(target,'weapon'):
  if sample.first_upgrade==0:sample.first_upgrade=run.round
  if int(C.items[target].rarity)>=4 and sample.first_quality4==0:sample.first_quality4=run.round
  if int(C.items[target].v75.tier)==5 and sample.first_terminal==0:sample.first_terminal=run.round

func buy_capacity(run:Dictionary,target:String,sample:Dictionary)->void:
 if not needs_capacity(run,target):return
 if run.shop[5].is_empty():return
 var kind=run.shop[5].kind;var fit=inv.first_fit(inv.make_piece(kind,'fit'),run.items,run.bags)
 if fit.is_empty():return
 var before=int(run.gold)
 if not inv.purchase_at(run,5,fit,'board').is_empty():sample.ledger.append({'round':run.round,'action':'capacity','kind':kind,'paid':before-int(run.gold),'gold':run.gold})
func needs_capacity(run:Dictionary,target:String)->bool:
 if not recipes.has(target):return false
 var recipe=recipes[target]
 if inv.occupied(inv.make_piece(recipe.base,'base')).size()+inv.occupied(inv.make_piece(recipe.materials[0],'mat')).size()>inv.coverage(run.bags).size():return true
 var pair_fits=false
 for turn in 4:
  var base=inv.make_piece(recipe.base,'base');base.rotation=turn
  base=inv.first_fit(base,[],run.bags)
  if base.is_empty():continue
  var mat=inv.first_fit(inv.make_piece(recipe.materials[0],'mat'),[base],run.bags)
  if not mat.is_empty() and inv.adjacent(base,mat):pair_fits=true;break
 if not pair_fits:return true
 if inv.first_fit(inv.make_piece(target,'fit'),[],run.bags).is_empty():return true
 return needs_capacity(run,recipes[target].base) or needs_capacity(run,recipes[target].materials[0])
