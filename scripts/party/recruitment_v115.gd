extends RefCounted
## Free node drafts, automatic rewards and read-only projections.
const C=preload('res://scripts/data/catalog.gd')
const A=preload('res://scripts/party/crew_abilities_v115.gd')
static func enabled(run:Dictionary)->bool:return run.get('recruitment',{}).get('version',0)==115
static func initial()->Dictionary:
 return {'version':115,'node':0,'done':[],'candidates':[],'config':{},'return_round':0,'star_round':0,'supply_round':0,'return_pending':[],'star_pending':'','special_pending':[],'bonus_round':0}
static func profile(role:String)->Dictionary:return A.profile(role)
static func abilities(run:Dictionary)->Array:
 return run.get('supports',[]).map(func(r):return profile(r).get('ability_id','')) if enabled(run) else []
static func has_role(run:Dictionary,role:String)->bool:return enabled(run) and role in run.get('supports',[])
static func full_team(run:Dictionary)->Dictionary:
 return profile(run.supports[-1]) if enabled(run) and run.get('supports',[]).size()==2 else {}
static func bond_id(run:Dictionary,_extra:String='')->String:return full_team(run).get('family','')
static func special_kinds(group:String)->Array:return C.items.keys().filter(func(k):return C.items[k].get('crew_supply','')==group)
static func supply_allowed(run:Dictionary,group:String)->bool:
 return enabled(run) and run.get('supports',[]).any(func(r):return profile(r).get('supply_group','')==group)
static func pool(run:Dictionary)->Array:
 return A.ROLES.keys().filter(func(role):return role!=C.characters[run.leader].roster_id and role not in run.get('roster',[]))
static func open_draft(inv,run:Dictionary,node:int)->bool:
 if not enabled(run) or node not in [3,6] or run.get('phase','')!='shop' or int(run.round)!=node+1:return false
 if run.recruitment.done.map(func(n):return int(n))!=([3] if node==6 else []) or run.supports.size()!=(1 if node==6 else 0):return false
 var choices=pool(run)
 if choices.size()<3:return false
 var rng=RandomNumberGenerator.new();rng.seed=int(run.seed)
 for i in range(choices.size()-1,0,-1):
  var j=rng.randi_range(0,i);var old=choices[i];choices[i]=choices[j];choices[j]=old
 # Prefer three distinct approaches, without closing identities or same-family teams.
 var picks=[];var families=[]
 for role in choices:
  var family=profile(role).family
  if family in families:continue
  picks.append(role);families.append(family)
  if picks.size()==3:break
 var usable=choices.filter(func(r):return A.ready(r,run))
 if not usable.is_empty() and not picks.any(func(r):return r in usable):picks[0]=usable[0]
 run.seed=int(rng.randi());run.recruitment.node=node;run.recruitment.candidates=picks;run.phase='recruit'
 return true
static func model_for(inv,run:Dictionary,role:String,extra:bool)->Dictionary:
 var m=profile(role).duplicate(true)
 if m.is_empty():return m
 var full=profile(role) if extra and run.supports.size()==1 else full_team(run)
 m.bond_id=full.get('family','');m.bond_name=full.get('bond_name','');m.bond_text=full.get('bond_text','');m.bond_short=full.get('bond_short',m.bond_text)
 m.usable=A.ready(role,run);m.examples=[];m.specialties=special_kinds(m.supply_group)
 for p in run.get('items',[]):
  if m.examples.size()<3 and not C.is_tag(p.kind,'bag'):m.examples.append({'uid':p.uid,'kind':p.kind,'name':C.items[p.kind].name})
 m.reward_choices=[];m.gold_fallback=false
 m.future_bonds=[{'id':m.family,'name':profile(role).bond_name,'text':profile(role).bond_text}]
 return m
static func card_models(inv,run:Dictionary)->Array:
 return run.recruitment.candidates.map(func(r):return model_for(inv,run,r,true)) if enabled(run) and run.get('phase','')=='recruit' else []
static func team_models(inv,run:Dictionary)->Array:return run.get('supports',[]).map(func(r):return model_for(inv,run,r,false))
static func plan_confirm(inv,run:Dictionary,role:String,reward:String='')->Dictionary:
 if not enabled(run) or run.get('phase','')!='recruit' or not reward.is_empty() or role not in run.recruitment.candidates or role not in pool(run) or not valid_state(inv,run):return {'ok':false}
 var next=run.duplicate(true);var grant_gold=2 if profile(role).family=='economy' else 0
 next.roster.append(role);next.supports.append(role);next.recruited_round=int(next.round)
 if profile(role).family=='economy' and next.supports.size()==2:grant_gold+=3
 next.gold+=grant_gold;next.recruitment.done.append(int(next.recruitment.node));next.recruitment.candidates=[]
 var group=profile(role).supply_group
 if group not in next.recruitment.special_pending:next.recruitment.special_pending.append(group)
 next.phase='shop'
 var refresh=inv.plan_refresh(next)
 if not refresh.ok:return {'ok':false}
 return inv.operation_plan(run,refresh.run,{'role_id':role,'ability_id':profile(role).ability_id,'reward':{},'gold':grant_gold},true)
static func refresh_cost(run:Dictionary,charge:bool=true)->int:
 var allowance=2 if has_role(run,'role_1504') else 1
 return 1 if charge and int(run.get('refreshes',0))>=allowance else 0
static func after_craft(inv,source:Dictionary,next:Dictionary,consumed:Array,_output:Dictionary)->void:
 if not enabled(source):return
 if has_role(source,'role_1106') and int(source.recruitment.return_round)!=int(source.round):
  var pieces=(source.items+source.stash).filter(func(p):return p.uid in consumed and not C.is_tag(p.kind,'weapon') and not C.is_tag(p.kind,'echo') and not C.is_tag(p.kind,'bag') and int(C.items[p.kind].rarity)<=2 and int(C.items[p.kind].price)<=6)
  pieces.sort_custom(func(a,b):return str(a.uid)<str(b.uid) if int(C.items[a.kind].price)==int(C.items[b.kind].price) else int(C.items[a.kind].price)<int(C.items[b.kind].price))
  if not pieces.is_empty():
   var id=inv.next_identity(next)
   if not id.is_empty():
    var p=inv.make_piece(pieces[0].kind,id.uid);p.paid_cost=0;next.serial=id.serial;next.stash.append(p);next.recruitment.return_round=int(source.round)
 if full_team(source).get('family','')=='economy' and int(source.recruitment.bonus_round)!=int(source.round):
  next.gold+=1;next.recruitment.bonus_round=int(source.round)
static func guarantee_special(inv,run:Dictionary,offers:Array)->void:
 if not enabled(run):return
 var reserved=[]
 for group in run.recruitment.special_pending.duplicate():
  var kinds=special_kinds(group).filter(func(k):return inv.shop_eligible(run,k))
  var slots=[3,4].filter(func(i):return not offers[i].get('locked',false) and i not in reserved)
  if kinds.is_empty() or slots.is_empty():continue
  offers[slots[0]]={'kind':kinds[0],'locked':false,'specialty':group};reserved.append(slots[0]);run.recruitment.special_pending.erase(group)
static func valid_state(inv,run:Dictionary)->bool:
 if not enabled(run):return false
 var s=run.recruitment
 if not s.has_all(initial().keys()):return false
 if not s.done is Array or not s.candidates is Array or not s.special_pending is Array or not s.config is Dictionary or not s.config.is_empty() or s.return_pending!=[] or s.star_pending!='':return false
 if not inv.bounded_integer(s.node,0,6) or int(s.node) not in [0,3,6]:return false
 for field in ['return_round','star_round','supply_round','bonus_round']:
  if not inv.bounded_integer(s[field],0,int(run.round)):return false
 var done=[]
 for n in s.done:
  if not inv.bounded_integer(n,3,6) or int(n) not in [3,6]:return false
  done.append(int(n))
 if done not in [[],[3],[3,6]] or done.size()!=run.get('supports',[]).size():return false
 if not done.is_empty() and int(run.round)<=done[-1]:return false
 for role in run.get('supports',[]):
  if not A.ROLES.has(role):return false
 var seen=[]
 for role in s.candidates:
  if not role is String or role not in pool(run) or role in seen:return false
  seen.append(role)
 if run.get('phase','')=='recruit':
  if seen.size()!=3 or int(s.node)!=(3 if done.is_empty() else 6) or done.size()>=2 or int(run.round)!=int(s.node)+1:return false
 elif not seen.is_empty() or int(s.node)!=(0 if done.is_empty() else done[-1]):return false
 for group in s.special_pending:
  if not group is String or not supply_allowed(run,group) or s.special_pending.count(group)!=1:return false
 return true
