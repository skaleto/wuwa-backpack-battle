#!/usr/bin/env python3
"""Compile the accepted design into explicit runtime actions; no prose parsing in combat."""
import json,copy,re,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=ROOT/'data/catalog.json'
seed=ROOT/'data/compat/design/catalog-v56.json'
if not seed.exists():shutil.copy2(p,seed)
C=json.loads(seed.read_text());D=json.loads((ROOT/'data/compat/design/approved-v2.json').read_text())
M=json.loads((ROOT/'assets/manifest.json').read_text())
TAGS={'武器':'weapon','声骸':'echo','攻击':'attack','治疗':'healing','护盾':'shielding','补给':'consumable','遗物':'relic','材料':'craft_material','口袋':'bag','充能':'charge','迅捷':'haste','光噪':'noise','霜渐':'frost','净化':'cleanse','反击':'counter','破盾':'breaker','体力':'stamina','生命上限':'max_hp'}
LABELS={'damage':'伤害','heal':'治疗','shield':'护盾','charge':'充能','haste':'迅捷','noise':'光噪','frost':'霜渐','cleanse':'净化','stamina':'体力','max_hp':'生命上限','break_shield':'额外削盾','stamina_discount':'体力消耗'}
variants={'whiff_fast':'whiff','turtle_clean':'turtle','rock_wall':'rocksteady','glacio_focus':'echo_glacio','contract_echo':'contract','nutrition_dense':'nutrition'}
for item in C['items'].values():item['v60']={'active':False}
def actions(**kw):return [{'type':k,'value':v} for k,v in kw.items()]
A={
 'whiff':actions(damage=6),'zig':actions(damage=2,haste=1),'turtle':actions(heal=4),'rocksteady':actions(damage=3,shield=4),
 'feilian':actions(damage=12,charge=2),'thundering':actions(damage=8,haste=1),'violet':actions(damage=3),'bellborne':actions(damage=6),
 'inferno':actions(break_shield=10,damage=8),'dreamless':actions(damage=14),'cyan_heron':actions(damage=5,frost=1),
 'echo_vanguard':actions(break_shield=4,damage=3),'echo_glacio':actions(damage=1,frost=1),'echo_spectro':actions(damage=1,noise=1),
 'echo_butterfly':actions(heal=1,cleanse=1),'flower':actions(shield=3),'glasses':actions(cleanse=1),
 'tea':actions(max_hp=15),'soup':actions(stamina=4),'nutrition':actions(heal=18),'revive':actions(heal=6,cleanse=1),
 'maocai':actions(shield=12),'rations':actions(stamina_discount=.15),'daily_tea':actions(haste=2),'salt_tea':actions(shield=8),
 'spicy_meat':actions(charge=3),'cool_tea':actions(haste=2,cleanse=3),'dragon_food':actions(shield=14,stamina_discount=.15),
 'whiff_fast':actions(damage=6),'turtle_clean':actions(heal=3,cleanse=1),'rock_wall':actions(damage=1,shield=8),
 'glacio_focus':actions(frost=2),'nutrition_dense':actions(heal=30),'contract_echo':[],
}
W={'w_broadblade':actions(charge=1),'weapon_21010044':actions(charge=1),'discord':actions(haste=1),'weapon_21010034':actions(break_shield=8),
'w_sword':actions(haste=1),'weapon_21020044':actions(charge=1),'weapon_21020034':actions(break_shield=6),'w_rectifier':actions(haste=1),
'weapon_21050044':actions(haste=1),'rectifier25':actions(shield=3),'w_pistol':[],'weapon_21030024':actions(haste=1),'weapon_21030034':actions(break_shield=5),'w_gauntlet':actions(shield=2),'weapon_21040034':actions(shield=3)}
S={
'w_broadblade':('attack',2,actions(charge=1)),'weapon_21010044':('attack',2,actions(charge=1)),'discord':('attack',3,actions(haste=1)),
'weapon_21010034':('attack',3,actions(charge=1)),'w_sword':('consume',0,actions(haste=2)),'weapon_21020044':('attack',3,actions(charge=1)),
'weapon_21020034':('consume',0,actions(haste=2)),'w_rectifier':('activate',3,actions(haste=1)),'weapon_21050044':('activate',2,actions(haste=1)),
'rectifier25':('heal',3,actions(shield=3)),'w_pistol':('consume',0,actions(shield=3)),'weapon_21030024':('consume',0,actions(haste=2)),
'weapon_21030034':('consume',0,actions(shield=4)),'w_gauntlet':('heal',4,actions(shield=2)),'weapon_21040034':('heal',4,actions(shield=4)),
'rocksteady':('heal',4,actions(shield=2)),'feilian':('attack',4,actions(charge=1)),'thundering':('attack',4,actions(haste=1)),
'violet':('shield',4,actions(shield=2)),'bellborne':('shield',4,actions(shield=2)),'inferno':('attack',3,actions(break_shield=2)),
'cyan_heron':('attack',6,actions(frost=1)),'echo_vanguard':('attack',4,actions(charge=1)),'echo_butterfly':('consume',0,actions(cleanse=1)),
'electro_coin':('attack',3,actions(charge=1)),'aero_coin':('consume',0,actions(haste=2)),'spectro_coin':('attack',2,actions(noise=1)),
'contract':('activate',3,actions(haste=1)),'lamp':('shield',3,actions(charge=1)),'answer':('attack',2,actions(break_shield=4)),
'glasses':('consume',0,actions(cleanse=1)),'rock_wall':('heal',4,actions(shield=2)),'contract_echo':('activate',3,actions(haste=1))}
SPECIAL={
'weapon_21010044':{'noise_consume':{'max_layers':2,'damage_per_layer':6,'requires_charge':True}},
'weapon_21050044':{'haste_damage':{'min_stacks':6,'value':2}},'weapon_21030024':{'haste_stamina':{'min_stacks':4,'multiplier':.8}},
'violet':{'shield_counter':{'damage':3,'interval':1.5}},'bellborne':{'shield_strike':{'consume':8,'multiplier':1.5}},
'dreamless':{'low_hp_damage':{'threshold':.35,'value':6}},'flower':{'matched_healer_shield':{'per_item':1,'max_items':2}},
'contract_echo':{'haste_derived':{'min_stacks':4,'value':3}}}
SUPPLY={'tea':'opening','soup':'stamina3','nutrition':'hp50','nutrition_dense':'hp50','revive':'first_debuff','maocai':'opening','rations':'opening','daily_tea':'opening','salt_tea':'hp60','spicy_meat':'opening','cool_tea':'time6','dragon_food':'opening'}
def rows_for(k,v,d):
 rows=[]
 trigger={'opening':'开场','hp50':'生命 <50%','hp60':'生命 <60%','stamina3':'体力 <3','first_debuff':'首次减益','time6':'第 6 秒'}.get(v['activation'],'')
 if trigger:rows.append(['发动',trigger+' · 一次'])
 for a in v['actions']:
  if a['type'] in ('damage','heal'):continue
  rows.append([LABELS[a['type']],('−15%' if a['type']=='stamina_discount' else '+'+str(a['value']))])
 if k in S:
  _,icd,aa=S[k];r=' · '.join(LABELS[a['type']]+' +'+str(a['value']) for a in aa)
  rows.append(['★ '+next((zh for zh,en in TAGS.items() if en==d['target']),d['target']),r])
  if icd:rows.append(['★ 同族间隔',str(icd)+' 秒'])
 extra={
 'weapon_21010044':[['充能命中 · 消耗光噪','最多 2 层 ×6 伤']], 'weapon_21050044':[['迅捷 6 层','伤害 +2']],
 'weapon_21030024':[['迅捷 ≥4','体力 −20%']], 'violet':[['盾吸收普攻 → 反击','3 伤 · 同族 1.5 秒']],
 'bellborne':[['消耗己方护盾','最多 8 点 ×1.5 伤']], 'dreamless':[['敌人生命 <35%','伤害 +6']],
 'flower':[['★ 治疗物品','每件护盾 +1 · 最多 2']], 'contract_echo':[['迅捷 ≥4 · 每 6 秒','追加 3 伤']]}
 rows.extend(extra.get(k,[]));return rows
for r in D['items']:
 k=r['id'];base=variants.get(k,k)
 d=copy.deepcopy(C['items'].get(base,{}))
 if not d:
  d={'element':'neutral','asset_path':'','original_rarity':1,'source_page':r.get('image_source','')}
  source=Path(r['image'])
  if source.exists():
   dest=ROOT/'art_sources/originals/references'/('design-'+k+source.suffix);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,dest);d['asset_path']=str(dest.relative_to(ROOT))
 d.update(name=r['name'],shape=r['shape'],stars=r['stars'],price=r['price'],round_min=r['round'],cooldown=r['cd'],
 tags=[TAGS[t] for t in r['tags']],target=TAGS.get(r['accept'],''),damage=0,heal=0,energy=0,concerto=0,desc='',effect=k,
 craft_only=r['obtain']=='合成',released=True,strict_signature=False,route=r['route'],canonical_cost=r.get('echo_cost',0),echo_cost=r.get('echo_cost',0))
 if r['cat']=='材料':d['tags'].append('material')
 rarity=2 if r['obtain']=='合成' else 1
 if r['cat']=='声骸':rarity={1:1,3:2,4:4}[r['echo_cost']]+(1 if k in variants else 0)
 if r['cat']=='武器':rarity=2 if r['obtain']=='商店' else 3
 d['rarity']=rarity;d['craft_tier']=1 if r['obtain']=='商店' else 2
 v={'active':True,'actions':copy.deepcopy(A.get(k,[])),'activation':'cooldown' if r['cd']>0 else 'none','special':copy.deepcopy(SPECIAL.get(k,{})),'rows':[]}
 if k in W:v['actions']=actions(damage=r['damage'])+W[k]
 if k in SUPPLY:v['activation']=SUPPLY[k]
 for a in v['actions']:
  if a['type'] in ('damage','heal'):d[a['type']]=a['value']
 if k in S:
  event,icd,acts=S[k];v['star']={'event':event,'interval':icd,'actions':acts,'family':('weapon_'+d['weapon_type']) if r['cat']=='武器' else 'contract' if k=='contract_echo' else 'rocksteady' if k=='rock_wall' else k}
 if r['cat']!='武器':d['stamina']=0
 if k in ['whiff','whiff_fast']:
  v['actions']=actions(damage=3)*2
 v['rows']=rows_for(k,v,d);d['v60']=v;C['items'][k]=d
 if k in variants and base in M['items']:
  M['items'][k]=copy.deepcopy(M['items'][base]);M['items'][k].update(name=d['name'],variant_of=base,shape=d['shape'],tags=d['tags'])
 # New source-based images get generated in a later explicit art pass.
 if k not in M['items'] and r['cat']!='口袋':M['items'][k]={'path':'assets/items/core/'+k+'.png','name':d['name'],'status':'pending_generation','reference':d['asset_path'],'shape':d['shape'],'angle':0}
C['recipes']=[]
for r in D['recipes']:
 b=r['inputs'][0];C['recipes'].append({'id':r['id'],'base':b,'materials':r['inputs'][1:],'target':r['out'],'round_min':r['round'],'type':C['items'][b].get('weapon_type','item'),'input_tier':1,'fee':0})
# Every recipe component unlocks no later than its first recipe, including variant materials.
for k,d in C['items'].items():
 if 'craft_material' in d['tags'] and d.get('v60',{}).get('active'):
  d['round_min']=min(r['round_min'] for r in C['recipes'] if k in r['materials'])
# Character identities are canonical; small opening bonuses and starting picks are Demo adaptations.
leaders=[('aemeath','role_1210','spicy_meat',actions(charge=2),'充能 +2'),('hsin','role_1311','daily_tea',actions(haste=2),'迅捷 +2'),('suisui','role_1110','salt_tea',actions(shield=6),'护盾 +6'),('qingxiao','role_1413','tea',actions(max_hp=8),'生命 +8'),('lu_hers','role_1510','maocai',actions(shield=6),'护盾 +6'),('yangyang_xuanling','role_1610','soup',actions(charge=2),'充能 +2')]
C['selectable_leaders']=[]
for i,(id,role,supply,opening,text) in enumerate(leaders):
 rr=C['roster'][role];typ=rr['weapon_type'];starter={'broadblade':'w_broadblade','sword':'w_sword','pistol':'w_pistol','gauntlet':'w_gauntlet','rectifier':'w_rectifier'}[typ]
 C['characters'][id]={'name':rr['name'],'sprite':i,'element':rr['element'],'starter':starter,'starter_supply':supply,'weapon_type':typ,'core':'','passive':'开场'+text,'burst':'','burst_damage':0,'roster_id':role,'avatar_path':rr['avatar_path'],'bust_path':rr['bust_path'],'route':'open','v60_opening':opening,'v60_traits':[['开场',text],['路线','由物品组合决定']],'adaptation_summary':'本作改编：开场'+text,'source_page':rr.get('source_page','')}
 C['selectable_leaders'].append(id);M['leaders'][id]=role
C['v60']={'version':60,'design':'approved-v2','status':'demo','three_buffs':['charge','haste','shield'],'two_debuffs':['noise','frost']}
p.write_text(json.dumps(C,ensure_ascii=False,indent=2)+'\n')
(ROOT/'assets/manifest.json').write_text(json.dumps(M,ensure_ascii=False,indent=2)+'\n')
print('Compiled',sum(x['v60']['active'] for x in C['items'].values()),'active items,',len(C['recipes']),'recipes,',len(leaders),'leaders')
