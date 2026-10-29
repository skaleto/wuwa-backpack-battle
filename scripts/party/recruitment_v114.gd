extends RefCounted
## V114 recruitment, configuration and economy. Queries never allocate or draw RNG.
const C=preload('res://scripts/data/catalog.gd')
const PRIMARY_ROLES={'role_1302':'link','role_1207':'volley','role_1505':'guard','role_1106':'artisan','role_1504':'supply'}
const ROLES={'role_1302':'link','role_1207':'volley','role_1505':'guard','role_1106':'artisan','role_1504':'supply','role_1105':'link'}
const NAMES={'link':'串联','volley':'合击','guard':'守护','artisan':'工匠','supply':'补给'}
const BASE={
 'link':'将一颗已有星位连到远处兼容物品；占用原星位，同一物品只计一次。',
 'volley':'选两把相邻武器，等双方就绪且耐力足够后齐射；各增加20%基础伤害。',
 'guard':'选相邻治疗与产盾物品；指定治疗溢出的50%转盾，每4秒最多6点。',
 'artisan':'每轮首次符合条件的合成，取回一件消耗的小材料（品质≤2、标价≤6）。',
 'supply':'每轮一次定向付费刷新，为已有配方起点补一件当前可供应缺料。'}
const SHORT={
 'link':['移动一颗已有星位\n连接远处兼容物品','同一星位 · 类别条件不变'],
 'volley':['相邻双武器同步出手\n各增20%基础伤害','各自耗耐 · 快武器会等待'],
 'guard':['相邻治疗＋产盾\n50%溢出治疗转为护盾','每4秒最多6护盾'],
 'artisan':['每轮一次合成返还\n取回一件低阶功能材料','品质≤2 · 标价≤6'],
 'supply':['每轮一次定向刷新\n补一件可供应的缺料','定向刷新1币 · 商品另付费']}
const BOND_SHORT={
 'link+volley':'兼容双武器占用远程星位后，可隔空合击。',
 'guard+link':'守护组可占用唯一远程连接隔空配对。',
 'guard+volley':'转化盾实际挡伤强化下次齐射；每把加挡伤25%，上限6。',
 'artisan+link':'本轮首件有星位的合成品，可选四向增一星。',
 'artisan+volley':'同次合成返还可选低阶武器；品质≤2、标价≤6。',
 'artisan+guard':'同次返还可留治疗／产盾小物；品质≤3、标价≤8。',
 'link+supply':'按空缺星位定向；入队选一件匹配普通小物。',
 'supply+volley':'按真实冷却找拍档；入队选一把可供应武器。',
 'guard+supply':'定向治疗／产盾／回耐；入队选一件功能小物。',
 'artisan+supply':'入队选实际缺料；定向位可八折购买两件不同缺料。'}
const BONDS={
 'link+volley':['隔空合击','兼容武器占用唯一远程星位连接后，可隔空组成合击组。'],
 'guard+link':['遥相守护','守护组可占用唯一远程连接隔空配对；该用途不制造星位。'],
 'guard+volley':['守势齐射','转化盾实际挡伤后，下次齐射各加累计挡伤25%，每把最多6。'],
 'artisan+link':['星位锻造','每轮首件有星位的合成成品可选四向增一星；每件最多一颗。'],
 'artisan+volley':['再铸拍档','返还也可选本次消耗的低阶武器（品质≤2、标价≤6），共用一次机会。'],
 'artisan+guard':['留存守护','返还也可选治疗／产盾小物（品质≤3、标价≤8），不含武器声骸。'],
 'link+supply':['星位补给','可按空缺星位定向供给；入队选一件匹配普通小物。'],
 'supply+volley':['合击补给','可按真实冷却接近程度寻找拍档；入队选一把品质≤3、标价≤8的武器。'],
 'guard+supply':['守护补给','可定向治疗、产盾或回耐；入队选一件对应普通小物。'],
 'artisan+supply':['成套采购','入队选一件当前合法配方缺料；定向位可买两件不同缺料，合价八折。']}
static func enabled(run:Dictionary)->bool:return run.get('recruitment',{}).get('version',0)==114
static func initial()->Dictionary:return {'version':114,'node':0,'done':[],'candidates':[],'config':{},'return_round':0,'star_round':0,'supply_round':0,'return_pending':[],'star_pending':'','special_pending':[]}
static func profile(role:String)->Dictionary:
 if not ROLES.has(role):return {}
 var a=ROLES[role]
 return {'role_id':role,'name':C.roster[role].name,'ability_id':a,'ability_name':NAMES[a],'base_text':BASE[a],'base_short':SHORT[a][0],'tradeoff':SHORT[a][1]}
static func abilities(run:Dictionary)->Array:
 if not enabled(run):return []
 var out=[]
 for role in run.get('supports',[]):
  if ROLES.has(role) and ROLES[role] not in out:out.append(ROLES[role])
 return out
static func has_ability(run:Dictionary,a:String)->bool:return a in abilities(run)
static func bond_id(run:Dictionary,extra:String='')->String:
 var a=abilities(run)
 if not extra.is_empty() and extra not in a:a.append(extra)
 a.sort()
 return '+'.join(a) if a.size()==2 else ''
static func special_kinds(a:String)->Array:
 return C.items.keys().filter(func(k):return C.items[k].get('crew_supply','')==a)
static func functional(kind:String,type:String)->bool:return preload('res://scripts/battle/item_activity.gd').functional(kind,type)

static func missing(inv,run:Dictionary)->Array:
 var owned=run.get('items',[])+run.get('stash',[]);var out=[]
 for r in C.combinations:
  if not inv.craft_unlocked(run,r.target):continue
  var pair=[r.base,r.materials[0]]
  for n in 2:
   if owned.any(func(p):return p.kind==pair[n]) and not owned.any(func(p):return p.kind==pair[1-n]) and inv.shop_eligible(run,pair[1-n]) and pair[1-n] not in out:out.append(pair[1-n])
 out.sort();return out
static func small(kind:String,price:int=6,tier:int=3)->bool:
 var d=C.items[kind]
 return not C.is_tag(kind,'bag') and not C.is_tag(kind,'echo') and not C.is_tag(kind,'weapon') and int(d.rarity)<=tier and int(d.price)<=price
static func ready_ability(inv,run:Dictionary,a:String)->bool:
 var items=run.get('items',[]);var owned=items+run.get('stash',[])
 if a not in abilities(run) and bond_id(run,a).contains('supply'):return true # the actual new bond grants an item or explicit fallback gold
 match a:
  'link':
   for source in items:
    if not inv.stars(source).is_empty() and items.any(func(p):return inv.star_eligible(source,p)):return true
  'volley':return items.filter(func(p):return C.is_tag(p.kind,'weapon')).size()>=2
  'guard':return items.any(func(p):return functional(p.kind,'heal') and items.any(func(q):return q.uid!=p.uid and functional(q.kind,'shield')))
  'supply':return not missing(inv,run).is_empty()
  'artisan':
   for r in C.combinations:
    if owned.any(func(p):return p.kind==r.base) and owned.any(func(p):return p.kind==r.materials[0]) and (small(r.base,6,2) or small(r.materials[0],6,2)):return true
 return false
static func open_draft(inv,run:Dictionary,node:int)->bool:
 if not enabled(run) or node not in [3,6] or node in run.recruitment.done or run.supports.size()>=2:return false
 # One preferred identity per available ability; a leader never removes a rule.
 var choices=[];var groups=[]
 for role in ROLES:
  var a=ROLES[role]
  if role==C.characters[run.leader].roster_id or role in run.roster or a in abilities(run) or a in groups:continue
  choices.append(role);groups.append(a)
 if choices.size()<3:return false
 var rng=RandomNumberGenerator.new();rng.seed=int(run.seed)
 for i in range(choices.size()-1,0,-1):
  var j=rng.randi_range(0,i);var old=choices[i];choices[i]=choices[j];choices[j]=old
 var picks=choices.slice(0,3)
 var usable=choices.filter(func(role):return ready_ability(inv,run,ROLES[role]))
 if not usable.is_empty() and not picks.any(func(role):return role in usable):picks[0]=usable[0]
 if node==6 and not picks.any(func(role):return ROLES[role] in ['artisan','supply']):
  var economic=choices.filter(func(role):return ROLES[role] in ['artisan','supply'])
  if not economic.is_empty():
   var replace=2
   if picks[replace] in usable and picks.filter(func(role):return role in usable).size()==1:replace=1
   picks[replace]=economic[0]
 run.seed=int(rng.randi());run.recruitment.node=node;run.recruitment.candidates=picks;run.phase='recruit'
 return true
static func eligible_rewards(inv,run:Dictionary,role:String)->Array:
 var b=bond_id(run,ROLES.get(role,''));var out=[];var owned=run.get('items',[])+run.get('stash',[])
 if not b.contains('supply'):return out
 for kind in C.items:
  if not inv.shop_eligible(run,kind) or not C.items[kind].get('crew_supply','').is_empty():continue
  if b=='supply+volley':
   if C.is_tag(kind,'weapon') and int(C.items[kind].rarity)<=3 and int(C.items[kind].price)<=8 and owned.any(func(p):return C.is_tag(p.kind,'weapon')):out.append(kind)
  elif small(kind):
   if b=='artisan+supply' and kind in missing(inv,run):out.append(kind)
   elif b=='guard+supply' and (functional(kind,'heal') or functional(kind,'shield') or functional(kind,'stamina')):out.append(kind)
   elif b=='link+supply' and owned.any(func(p):return not inv.stars(p).is_empty() and inv.star_eligible(p,inv.make_piece(kind,'reward'))):out.append(kind)
 if b=='supply+volley':out.sort_custom(func(a,b):return partner_distance(run,a)<partner_distance(run,b) if not is_equal_approx(partner_distance(run,a),partner_distance(run,b)) else a<b)
 else:out.sort()
 return out.slice(0,3)
static func partner_distance(run:Dictionary,kind:String)->float:
 var best=1000.0
 for p in run.get('items',[])+run.get('stash',[]):
  if C.is_tag(p.kind,'weapon'):best=minf(best,absf(float(C.items[p.kind].v75.cd)-float(C.items[kind].v75.cd)))
 return best
static func model_for(inv,run:Dictionary,role:String,extra:bool)->Dictionary:
 var m=profile(role)
 if m.is_empty():return m
 var b=bond_id(run,m.ability_id if extra else '')
 m.bond_id=b;m.bond_name=BONDS.get(b,['',''])[0];m.bond_text=BONDS.get(b,['',''])[1];m.bond_short=BOND_SHORT.get(b,'')
 m.usable=ready_ability(inv,run,m.ability_id);m.examples=[];m.specialties=special_kinds(m.ability_id)
 for p in run.get('items',[])+run.get('stash',[]):
  var useful=(m.ability_id=='volley' and C.is_tag(p.kind,'weapon')) or (m.ability_id=='guard' and (functional(p.kind,'heal') or functional(p.kind,'shield'))) or (m.ability_id=='link' and not inv.stars(p).is_empty()) or m.ability_id in ['artisan','supply']
  if useful and m.examples.size()<3:m.examples.append({'uid':p.uid,'kind':p.kind,'name':C.items[p.kind].name})
 m.reward_choices=eligible_rewards(inv,run,role).map(func(k):return {'kind':k,'name':C.items[k].name,'price':C.items[k].price}) if extra else []
 m.gold_fallback=extra and b.contains('supply') and m.reward_choices.is_empty()
 m.future_bonds=[]
 for key in BONDS:
  if m.ability_id in key.split('+'):m.future_bonds.append({'id':key,'name':BONDS[key][0],'text':BONDS[key][1]})
 return m
static func card_models(inv,run:Dictionary)->Array:
 if not enabled(run) or run.get('phase','')!='recruit':return []
 return run.recruitment.candidates.map(func(r):return model_for(inv,run,r,true))
static func team_models(inv,run:Dictionary)->Array:return run.get('supports',[]).map(func(r):return model_for(inv,run,r,false)).filter(func(m):return not m.is_empty())
static func grant(inv,run:Dictionary,kind:String)->Dictionary:
 var id=inv.next_identity(run)
 if id.is_empty():return {}
 var piece=inv.make_piece(kind,id.uid);run.serial=id.serial;run.stash.append(piece);return piece.duplicate(true)
static func plan_confirm(inv,run:Dictionary,role:String,reward:String='')->Dictionary:
 if not enabled(run) or run.get('phase','')!='recruit' or role not in run.recruitment.candidates or role in run.roster or ROLES.get(role,'') in abilities(run) or run.supports.size()>=2:return {'ok':false}
 var rewards=eligible_rewards(inv,run,role);var b=bond_id(run,ROLES[role]);var needs=b.contains('supply')
 if needs and ((not rewards.is_empty() and reward not in rewards) or (rewards.is_empty() and reward!='gold')):return {'ok':false}
 if not needs and not reward.is_empty():return {'ok':false}
 var next=run.duplicate(true);var created={}
 next.roster.append(role);next.supports.append(role);next.recruited_round=int(next.round)
 next.recruitment.done.append(next.recruitment.node);next.recruitment.candidates=[];next.recruitment.special_pending.append(ROLES[role])
 if needs:
  if reward=='gold':next.gold+=3
  else:
   created=grant(inv,next,reward)
   if created.is_empty():return {'ok':false}
 next.phase='shop'
 var refresh=inv.plan_refresh(next)
 if not refresh.ok:return {'ok':false}
 next=refresh.run
 return inv.operation_plan(run,next,{'role_id':role,'ability_id':ROLES[role],'reward':created,'gold':3 if reward=='gold' else 0},true)
static func item_by_uid(run:Dictionary,uid:String)->Dictionary:
 for p in run.get('items',[]):
  if p.uid==uid:return p
 return {}
static func pair(run:Dictionary,key:String)->Array:
 if not enabled(run):return []
 var ids=run.recruitment.config.get(key,[])
 if not ids is Array or ids.size()!=2 or ids[0]==ids[1]:return []
 var a=item_by_uid(run,ids[0]);var b=item_by_uid(run,ids[1])
 return [] if a.is_empty() or b.is_empty() else [a,b]
static func valid_link(inv,run:Dictionary)->Dictionary:
 if not has_ability(run,'link'):return {}
 var link=run.recruitment.config.get('link',{})
 if not link is Dictionary or link.get('mode','star')!='star':return {}
 var a=item_by_uid(run,link.get('source',''));var b=item_by_uid(run,link.get('target',''))
 if a.is_empty() or b.is_empty() or not inv.star_eligible(a,b):return {}
 var index=int(link.get('star',-1))
 if index<0 or index>=inv.stars(a).size():return {}
 return link
static func valid_pair(inv,run:Dictionary,key:String)->Array:
 if not has_ability(run,key):return []
 var p=pair(run,key)
 if p.is_empty():return []
 if key=='volley' and not p.all(func(v):return C.is_tag(v.kind,'weapon')):return []
 if key=='guard' and not (functional(p[0].kind,'heal') and functional(p[1].kind,'shield')):return []
 if inv.adjacent(p[0],p[1]):return p
 if not has_ability(run,'link'):return []
 var l=run.recruitment.config.get('link',{})
 if key=='guard' and l.get('mode','')=='guard' and l.get('source','')==p[0].uid and l.get('target','')==p[1].uid:return p
 if key=='volley':
  var v=valid_link(inv,run)
  if not v.is_empty() and v.source in [p[0].uid,p[1].uid] and v.target in [p[0].uid,p[1].uid]:return p
 return []
static func choice(id:String,label:String,config:Dictionary,uids:Array=[])->Dictionary:return {'id':id,'label':label,'config':config,'uids':uids}
static func crew_setup_choices(inv,run:Dictionary)->Dictionary:
 var out={'link':[],'volley':[],'guard':[],'artisan_return':[],'artisan_star':[],'supply':[]}
 if not enabled(run) or run.get('phase','')!='shop':return out
 var items=run.items
 if has_ability(run,'link'):
  out.link.append(choice('off','关闭远程连接',{'link':{}}))
  for a in items:
   for i in inv.stars(a).size():
    for b in items:
     if inv.star_eligible(a,b):out.link.append(choice(a.uid+':'+str(i)+':'+b.uid,C.items[a.kind].name+' ★'+str(i+1)+' → '+C.items[b.kind].name,{'link':{'mode':'star','source':a.uid,'target':b.uid,'star':i}},[a.uid,b.uid]))
 for key in ['volley','guard']:
  if not has_ability(run,key):continue
  out[key].append(choice('off','关闭'+NAMES[key]+'配对',{key:[]}))
  for a in items:
   for b in items:
    if a.uid==b.uid or (key=='volley' and str(a.uid)>str(b.uid)):continue
    var test=run.duplicate(true);test.recruitment.config[key]=[a.uid,b.uid]
    if not valid_pair(inv,test,key).is_empty():out[key].append(choice(a.uid+':'+b.uid,C.items[a.kind].name+' ＋ '+C.items[b.kind].name,{key:[a.uid,b.uid]},[a.uid,b.uid]))
    elif key=='guard' and has_ability(run,'link') and functional(a.kind,'heal') and functional(b.kind,'shield'):
     out.guard.append(choice('remote:'+a.uid+':'+b.uid,'远程 '+C.items[a.kind].name+' ＋ '+C.items[b.kind].name,{'guard':[a.uid,b.uid],'link':{'mode':'guard','source':a.uid,'target':b.uid}},[a.uid,b.uid]))
 for kind in run.recruitment.get('return_pending',[]):out.artisan_return.append(choice(kind,'取回 '+C.items[kind].name,{'return':kind}))
 var pending=item_by_uid(run,run.recruitment.get('star_pending',''))
 if not pending.is_empty():
  for dir in 4:
   var p=extra_star(inv,pending,dir)
   if inv.in_bounds(p):out.artisan_star.append(choice(str(dir),['向右','向下','向左','向上'][dir]+'星位 '+str(p.x+1)+','+str(p.y+1),{'extra_star':dir},[pending.uid]))
 if has_ability(run,'supply') and int(run.recruitment.supply_round)!=int(run.round):
  for target in supply_targets(inv,run):out.supply.append(choice(str(target.id),str(target.label),{'supply':target},target.get('uids',[])))
 return out
static func extra_star(inv,piece:Dictionary,dir:int)->Vector2i:
 var candidate=piece.duplicate(true);candidate.crew_star=dir
 return inv.stars(candidate)[-1]

static func plan_configure(inv,run:Dictionary,config:Dictionary)->Dictionary:
 if not enabled(run) or run.get('phase','')!='shop':return {'ok':false}
 var options=crew_setup_choices(inv,run);var found=false
 for list in options.values():
  for option in list:
   if option.config==config:found=true
 if not found:return {'ok':false}
 if config.has('supply'):return plan_targeted_refresh(inv,run,config.supply)
 var next=run.duplicate(true);var result={'config':config.duplicate(true)}
 if config.has('return'):
  result.created=grant(inv,next,config['return'])
  if result.created.is_empty():return {'ok':false}
  next.recruitment.return_pending=[]
 elif config.has('extra_star'):
  var piece=inv.find_piece(next,next.recruitment.star_pending);piece.crew_star=int(config.extra_star);next.recruitment.star_pending=''
 else:next.recruitment.config.merge(config,true)
 return inv.operation_plan(run,next,result,true)
static func return_eligible(run:Dictionary,p:Dictionary)->bool:
 var d=C.items[p.kind]
 if C.is_tag(p.kind,'echo') or C.is_tag(p.kind,'bag'):return false
 if C.is_tag(p.kind,'weapon'):return has_ability(run,'volley') and int(d.rarity)<=2 and int(d.price)<=6
 return (int(d.rarity)<=2 and int(d.price)<=6) or (has_ability(run,'guard') and int(d.rarity)<=3 and int(d.price)<=8 and (functional(p.kind,'heal') or functional(p.kind,'shield')))
static func after_craft(inv,source:Dictionary,next:Dictionary,consumed:Array,output:Dictionary)->void:
 if not has_ability(next,'artisan'):return
 if int(next.recruitment.return_round)!=int(next.round):
  var kinds=[]
  for p in source.items:
   if p.uid in consumed and return_eligible(source,p) and p.kind not in kinds:kinds.append(p.kind)
  if not kinds.is_empty():
   next.recruitment.return_round=int(next.round);next.recruitment.return_pending=kinds
   if kinds.size()==1:
    if not grant(inv,next,kinds[0]).is_empty():next.recruitment.return_pending=[]
 if has_ability(next,'link') and int(next.recruitment.star_round)!=int(next.round) and not C.items[output.kind].get('stars',[]).is_empty():
  next.recruitment.star_round=int(next.round);next.recruitment.star_pending=output.uid
static func supply_targets(inv,run:Dictionary)->Array:
 var out=[];var miss=missing(inv,run)
 for kind in miss:out.append({'id':'missing:'+kind,'label':'缺料 · '+C.items[kind].name,'kinds':[kind]})
 var b=bond_id(run)
 if b=='artisan+supply':
  for i in miss.size():
   for j in range(i+1,miss.size()):out.append({'id':miss[i]+'+'+miss[j],'label':C.items[miss[i]].name+' ＋ '+C.items[miss[j]].name+' · 八折','kinds':[miss[i],miss[j]]})
 if b=='guard+supply':
  for f in ['heal','shield','stamina']:
   var pool=C.items.keys().filter(func(k):return inv.shop_eligible(run,k) and functional(k,f))
   if not pool.is_empty():out.append({'id':f,'label':{'heal':'治疗','shield':'产盾','stamina':'回耐'}[f],'pool':pool})
 if b=='supply+volley':
  var pool=C.items.keys().filter(func(k):return inv.shop_eligible(run,k) and C.is_tag(k,'weapon') and partner_distance(run,k)<1000)
  pool.sort_custom(func(a,b):return partner_distance(run,a)<partner_distance(run,b) if not is_equal_approx(partner_distance(run,a),partner_distance(run,b)) else a<b)
  if not pool.is_empty():out.append({'id':'partner','label':'冷却接近的合击拍档','pool':pool.slice(0,3)})
 if b=='link+supply':
  for p in run.items:
   var stars=inv.stars(p)
   if stars.any(func(cell):return not run.items.any(func(other):return inv.star_eligible(p,other) and cell in inv.occupied(other))):
    var pool=C.items.keys().filter(func(k):return inv.shop_eligible(run,k) and not C.is_tag(k,'bag') and inv.star_eligible(p,inv.make_piece(k,'target')))
    if not pool.is_empty():out.append({'id':'star:'+p.uid,'label':C.items[p.kind].name+' · 星位搭档','pool':pool,'uids':[p.uid]})
 return out
static func plan_targeted_refresh(inv,run:Dictionary,target:Dictionary)->Dictionary:
 if not has_ability(run,'supply') or int(run.recruitment.supply_round)==int(run.round) or run.get('phase','')!='shop':return {'ok':false}
 if not supply_targets(inv,run).any(func(t):return t==target):return {'ok':false}
 var slots=[4,3].filter(func(i):return not run.shop[i].get('locked',false))
 if slots.is_empty():return {'ok':false}
 var next=run.duplicate(true)
 # A targeted refresh is explicitly paid, including when the ordinary free refresh is unused.
 if int(next.gold)<1:return {'ok':false}
 next.gold-=1
 next.recruitment.supply_reservation=slots[0]
 var p=inv.plan_refresh(next,false)
 if not p.ok:return {'ok':false}
 next=p.run;next.recruitment.erase('supply_reservation')
 # Buying the targeted refresh does not forfeit an unused ordinary free refresh.
 if int(next.refreshes)>0:next.refreshes=int(next.refreshes)+1
 var kinds=target.get('kinds',[]).duplicate()
 if kinds.is_empty():
  var rng=RandomNumberGenerator.new();rng.seed=int(next.seed);kinds=[target.pool[rng.randi_range(0,target.pool.size()-1)]];next.seed=int(rng.randi())
 var offer={'kind':kinds[0],'locked':false,'directed':true}
 if kinds.size()==2:offer.bundle=kinds;offer.bundle_price=int(ceil((int(C.items[kinds[0]].price)+int(C.items[kinds[1]].price))*.8))
 next.shop[slots[0]]=offer;next.recruitment.supply_round=int(next.round)
 return inv.operation_plan(run,next,{'target':target,'slot':slots[0],'offer':offer,'cost':1},true)
static func guarantee_special(inv,run:Dictionary,offers:Array)->void:
 if not enabled(run):return
 var pending=run.recruitment.get('special_pending',[])
 var reserved=[]
 for a in pending.duplicate():
  var pool=special_kinds(a).filter(func(k):return inv.shop_eligible(run,k))
  var slots=[3,4].filter(func(i):return not offers[i].get('locked',false) and i not in reserved and i!=int(run.recruitment.get('supply_reservation',-1)))
  if pool.is_empty() or slots.is_empty():continue
  offers[slots[0]]={'kind':pool[0],'locked':false,'specialty':a};pending.erase(a);reserved.append(slots[0])
static func migrate(old:Dictionary)->Dictionary:
 var next=old.duplicate(true)
 if enabled(next):return next
 # Existing paid rosters stay playable under their earned rules until this run
 # ends. Only newly started runs enter the free draft system.
 next.recruitment_legacy=true;next.catalogue_hash=C.catalogue_hash
 return next

static func valid_state(inv,run:Dictionary)->bool:
 if not run.has('recruitment'):return true
 if not run.recruitment is Dictionary or not enabled(run):return false
 var state=run.recruitment
 if not state.has_all(['node','done','candidates','config','return_round','star_round','supply_round','return_pending','star_pending','special_pending']):return false
 if not state.done is Array or not state.candidates is Array or not state.config is Dictionary or not state.return_pending is Array or not state.special_pending is Array or not state.star_pending is String:return false
 if not inv.bounded_integer(state.node,0,6) or int(state.node) not in [0,3,6]:return false
 for key in ['return_round','star_round','supply_round']:
  if not inv.bounded_integer(state[key],0,int(run.round)):return false
 # JSON restores numbers as floats, while Array membership compares types.
 # Validate without mutating raw input, then compare canonical integer nodes.
 var done_nodes=[]
 for node in state.done:
  if not inv.bounded_integer(node,3,6) or int(node) not in [3,6] or int(node) in done_nodes:return false
  done_nodes.append(int(node))
 var active=[]
 for role in run.get('supports',[]):
  if not ROLES.has(role) or ROLES[role] in active:return false
  active.append(ROLES[role])
 for key in state.config:
  if key not in ['link','volley','guard']:return false
  if key=='link':
   var link=state.config[key]
   if not link is Dictionary:return false
   if not link.is_empty():
    if link.get('mode','star') not in ['star','guard'] or not link.get('source',null) is String or not link.get('target',null) is String or link.source==link.target:return false
    if link.get('mode','star')=='star' and not inv.bounded_integer(link.get('star',null),0,63):return false
  if key in ['volley','guard'] and (not state.config[key] is Array or state.config[key].size() not in [0,2] or not state.config[key].all(func(v):return v is String)):return false
 var seen=[]
 for role in state.candidates:
  if not role is String or not ROLES.has(role) or role in run.get('roster',[]) or role==C.characters[run.leader].roster_id or ROLES[role] in seen or ROLES[role] in active:return false
  seen.append(ROLES[role])
 if run.get('phase','')=='recruit':
  if state.candidates.size()!=3 or int(state.node) not in [3,6] or int(state.node) in done_nodes or int(run.round)!=int(state.node)+1:return false
 elif not state.candidates.is_empty() or (int(state.node) in [3,6] and int(state.node) not in done_nodes):return false
 for kind in state.return_pending:
  if not kind is String or not C.items.has(kind) or state.return_pending.count(kind)!=1 or not return_eligible(run,{'kind':kind}):return false
 for a in state.special_pending:
  if a not in abilities(run) or state.special_pending.count(a)!=1:return false
 return true

static func link_model(inv,run:Dictionary)->Dictionary:
 if not has_ability(run,'link'):return {}
 var config=run.recruitment.config.get('link',{})
 if config.get('mode','')=='guard':
  var p=valid_pair(inv,run,'guard')
  if p.is_empty():return {}
  return {'mode':'guard','source_uid':p[0].uid,'target_uid':p[1].uid,'source_cells':inv.occupied(p[0]),'target_cells':inv.occupied(p[1])}
 var link=valid_link(inv,run)
 if link.is_empty():return {}
 return {'mode':'star','source_uid':link.source,'target_uid':link.target,'star':link.star,'source_cell':inv.stars(item_by_uid(run,link.source))[int(link.star)],'target_cells':inv.occupied(item_by_uid(run,link.target))}
