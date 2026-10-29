extends RefCounted
## Additive catalogue overlay. Existing 216 items and 136 recipes are never rewritten.
const REVISION='v114-specialty-1'
static func apply(data:Dictionary)->Dictionary:
 var out=data.duplicate(true)
 var specs=[
  ['link','relay_pin','引线针','tuner','advance',.35,6,'weapon'],
  ['link','relay_spool','回响线轴','tube','flat',2,7,'echo'],
  ['volley','pulse_grip','齐鸣握柄','tuner','stamina',1.2,6,'weapon'],
  ['volley','pulse_sight','协奏准星','tube','flat',1.5,5,'weapon'],
  ['guard','dew_vial','晨露瓶','nutrition','heal',3,4,''],
  ['guard','ward_token','潮汐护符','tea','shield',3,5,''],
  ['artisan','forge_spring','调律发条','tuner','advance',.4,7,'echo'],
  ['artisan','forge_pad','温养垫片','nutrition','heal',2,3,''],
  ['supply','reserve_flask','续航壶','tea','stamina',1.5,7,''],
  ['supply','supply_lens','寻隙透镜','tube','flat',2,8,'weapon']]
 for spec in specs:
  var kind='crew_'+spec[1];var d=data.items[spec[3]].duplicate(true)
  d.name=spec[2];d.effect=kind;d.shape=[[0,0]];d.price=4;d.rarity=2;d.round_min=4;d.crew_supply=spec[0];d.tags=['relic'];d.stars=[[1,0],[0,1]] if not spec[7].is_empty() else [];d.target='';d.owner='';d.desc='本作组合物品';d.source_id='v114:'+kind
  d.v75=data.items.nutrition.v75.duplicate(true)
  d.v75.merge({'id':kind,'tier':2,'cost':4,'shop_price':4,'shop_round':4,'open_round':4,'emergency':0,'stars':d.stars,'capabilities':[spec[4]],'inputs':[],'leaves':{kind:1},'depth':0,'ownExtra':'','starText':'','supportText':''},true)
  d.v114={'action':spec[4],'value':spec[5],'period':spec[6],'category':spec[7]}
  if spec[4]=='heal':d.v75.healPeriod=spec[6];d.v75.healAmount=spec[5];d.v75.hps=float(spec[5])/float(spec[6]);d.tags.append('heal');d.v114={}
  elif spec[4]=='shield':d.v75.shieldPeriod=spec[6];d.v75.shieldAmount=spec[5];d.v75.sps=float(spec[5])/float(spec[6]);d.tags.append('shield');d.v114={}
  elif not spec[7].is_empty():d.v75.material_effect={'trigger':'clock','action':spec[4],'value':spec[5],'period':spec[6],'category':spec[7],'count':1};d.v114={}
  var action_name={'advance':'冷却提前','flat':'下一击伤害增加','stamina':'回复耐力','heal':'治疗','shield':'护盾'}[spec[4]]
  d.desc='每%s秒%s%s%s。' % [spec[6],('★'+('武器' if spec[7]=='weapon' else '声骸')+' ' if not spec[7].is_empty() else ''),action_name,spec[5]]
  d.v75.ownExtra=d.desc;d.v75.supportText=d.desc;d.v75.starText='★'+spec[7] if not spec[7].is_empty() else '';d.adaptation_summary='本作改编 · '+d.desc
  out.items[kind]=d
 # Distinct upgrade ingredients and effects retain each ability's own identity.
 var upgrades={
  'link':{'material':'tube','name':'回响引线器','text':'每6秒使★冷却剩余最长的武器提前0.6秒；三颗武器星位。'},
  'volley':{'material':'rations','name':'齐奏握柄','text':'每6秒，★有武器时回复1.8耐力。'},
  'guard':{'material':'tea','name':'满溢晨露','text':'每4秒治疗3；自身实际溢出的25%变为护盾，每6秒最多2点。'},
  'artisan':{'material':'mat_43020011','name':'回环发条','text':'每4秒使★冷却剩余最长的声骸提前0.4秒。'},
  'supply':{'material':'daily_tea','name':'远行水壶','text':'每6秒回复耐力2。'}}
 for a in upgrades:
  var base=''
  for candidate in out.items:
   if out.items[candidate].get('crew_supply','')==a:base=candidate;break
  var kind=base+'_plus';var u=upgrades[a];var d=out.items[base].duplicate(true)
  var investment=int(out.items[base].v75.cost)+int(data.items[u.material].v75.cost)
  d.name=u.name;d.price=investment;d.rarity=3;d.crew_supply=a;d.v75.id=kind;d.effect=kind;d.v75.tier=3;d.v75.cost=investment;d.v75.shop_price=investment;d.v75.craft_only=true;d.craft_only=true;d.v75.inputs=[base,u.material];d.v75.depth=1;d.v75.leaves={base:1,u.material:1}
  match a:
   'link':d.v75.material_effect.value=.6;d.stars=[[1,0],[0,1],[-1,0]];d.v75.stars=d.stars.duplicate(true)
   'volley':d.v75.material_effect.value=1.8
   'guard':d.v114={'action':'overflow_shield','value':.25,'period':6,'cap':2};d.tags.append('shield');d.v75.capabilities.append('shield')
   'artisan':d.v75.material_effect.period=4
   'supply':d.v114.value=2;d.v114.period=6
  d.desc=u.text;d.v75.ownExtra=u.text;d.v75.supportText=u.text;d.adaptation_summary='本作改编 · '+u.text
  out.items[kind]=d;out.recipes.append({'id':'V114_'+a,'base':base,'materials':[u.material],'target':kind,'round_min':4,'type':'relic','input_tier':2,'fee':0,'route':'通用','trade':u.text})
 return out
