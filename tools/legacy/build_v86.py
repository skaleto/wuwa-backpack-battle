#!/usr/bin/env python3
"""Frozen V85 -> V86 data patch: no equipment ranks; useful crafting components."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
c=json.loads((ROOT/'data/compat/catalog-v85.json').read_text())
# kind: trigger, action, amount, period, category, description, capability
rows=[
 ('tuner','clock','advance',.2,8,'echo','每8秒使★冷却剩余最长的声骸提前0.2秒。','haste'),
 ('tube','clock','flat',1,8,'echo','每8秒使★基础伤害最高的声骸下一击伤害+1，不累积。','attack'),
 ('strategy','opening','flat',1,0,'weapon','开战使★基础伤害最高的武器前两击各+1伤害。','attack'),
 ('puppet','clock','damage',1,6,'','每6秒造成1点伤害。','attack'),
 ('city_photo','opening','max_hp',5,0,'','开战生命及上限+5。','max_hp'),
 ('field_notes','clock','stamina',1,8,'','每8秒恢复1点体力。','stamina'),
 ('mat_43020021','opening','charged',2,0,'weapon','开战使★基础伤害最高的武器首次充能攻击伤害+2。','charge'),
 ('mat_43020011','opening','shield',3,0,'','开战获得3点护盾。','shielding'),
 ('mat_43020031','clock','advance',.15,8,'weapon','每8秒使★冷却剩余最长的武器提前0.15秒。','haste'),
 ('mat_43020041','clock','shield',2,8,'','每8秒获得2点护盾。','shielding'),
 ('mat_43020051','clock','haste',1,8,'','每8秒获得1层迅捷，持续6秒。','haste'),
 ('mat_41100011','clock','noise',1,10,'','每10秒施加1层光噪。','noise'),
 ('mat_41100013','clock','noise',1,8,'','每8秒施加1层光噪。','noise'),
 ('mat_42500010','clock','break_shield',2,8,'','每8秒削除敌方2点护盾。','break_shield'),
 ('mat_42310090','clock','heal',2,8,'','每8秒恢复2点生命。','healing'),
 ('mat_42300030','clock','cleanse',1,10,'','每10秒净化1层减益。','cleanse'),
 ('mat_42300050','opening','max_hp',4,0,'','开战生命及上限+4。','max_hp'),
 ('mat_42300100','clock','frost',1,10,'','每10秒施加1层霜渐。','frost'),
 ('mat_42500030','clock','charge',1,10,'','每10秒获得1层充能。','charge'),
]
patch={}
for kind,trigger,action,value,period,category,text,cap in rows:
 d=c['items'][kind];n=d['v75']
 effect={'trigger':trigger,'action':action,'value':value,'period':period,'category':category,'count':2 if kind=='strategy' else 1}
 n['material_effect']=effect;n['capabilities']=[cap]
 n['extra']=n['ownExtra']=text+'同名材料不叠加；战斗中不会消耗。'
 n['star']=n['starText']='★位置放置'+('武器' if category=='weapon' else '声骸')+'可获得以上效果。' if category else '无额外星位规则。'
 n['stars']=d['stars']=[[0,max(p[1] for p in d['shape'])+1],[max(p[0] for p in d['shape'])+1,0]] if category else []
 n['baseText']='无自然攻击。';n['supportText']=text
 d['desc']=text;d['adaptation_summary']='本作改编 · '+text
 patch[kind]={'name':d['name'],'price':d['price'],'effect':effect,'description':n['ownExtra'],'stars':n['stars']}
# Player-facing current rule clauses: no equipment rank remains.
for kind,d in c['items'].items():
 n=d.get('v75',{})
 for key in ['extra','ownExtra','star','starText','baseText','supportText']:
  if key in n:n[key]=n[key].replace('★主武器','★武器').replace('主武器','武器').replace('副武器','武器')
# Single-target star rewards explicitly select within the item's own stars.
specific={
 '异响空灵':('star','★声骸每发动2次，推进★基础伤害最高的武器0.5秒，同名间隔3秒。没有★武器时推进自身0.25秒。'),
 '无常凶鹭':('extra','每6秒使★基础伤害最高的武器下一击伤害+5。'),
}
for d in c['items'].values():
 if d.get('name') in specific:
  key,text=specific[d['name']];d['v75'][key]=text;d['v75']['starText' if key=='star' else 'ownExtra']=text
# Replace only target wording, preserving unrelated per-item clauses.
for d in c['items'].values():
 n=d.get('v75',{})
 for key in ['extra','ownExtra','star','starText']:
  t=n.get(key,'')
  if d.get('name') in ['阳焰','奇幻变奏','那映照虚幻的燃灯']:
   t=t.replace('★武器','★基础伤害最高的武器')
  if d.get('name')=='光影双生':t=t.replace('武器下一次重击','本体下一次重击')
  n[key]=t
c['design_version']=86
c['weapon_rules']={'damage_multiplier':1.0,'charge':'共享6层；下一把实际出手的武器消耗一次，充能伤害按该武器计算。','equipment_roles':False}
(ROOT/'data/compat/design/v86.json').write_text(json.dumps({'materials':patch,'weapon_rules':c['weapon_rules'],'items':{k:v['v75'] for k,v in c['items'].items() if 'v75' in v},'legacy':json.loads((ROOT/'data/compat/design/v75.json').read_text())['legacy']},ensure_ascii=False,indent=2)+'\n')
(ROOT/'data/catalog.json').write_text(json.dumps(c,ensure_ascii=False,indent=2)+'\n')
