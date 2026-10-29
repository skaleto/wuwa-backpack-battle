#!/usr/bin/env python3
"""Deterministic V87 -> V88 combo playtest. All assets and recipes are retained."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
c=json.loads((ROOT/'data/compat/catalog-v87.json').read_text())
patch={}
def card(kind,stars=None,star=None,own=None,**values):
 d=c['items'][kind];n=d['v75'];n.update(values)
 if stars is not None:d['stars']=n['stars']=stars
 if star is not None:n['star']=n['starText']=star
 if own is not None:n['extra']=n['ownExtra']=own
 d['desc']=n['ownExtra'];d['adaptation_summary']='本作改编 · '+n['ownExtra']
 patch[kind]={'name':d['name'],'stars':d['stars'],'profile':n}
def effect(root,category,action,value,period=0,count=1,target='self'):
 return {'trigger':root,'category':category,'action':action,'value':value,'period':period,'threshold':count,'target':target}
card('w_broadblade',[[0,1],[2,1]],'★声骸攻击时：获得2层充能，间隔4秒。','',material_effect=effect('star_attack','echo','charge',2,4),capabilities=['charge'])
card('zig',[[0,1],[1,0]],'★武器累计攻击2次：获得1层充能。','',material_effect=effect('star_attack','weapon','charge',1,count=2),hasteEvery=0,capabilities=['charge'])
card('weapon_21010104',[[0,1],[3,1]],'★声骸攻击时：获得2层充能，间隔4秒。','开战获得3层充能；充能攻击后，下2次普通攻击各+2伤害。',material_effect=effect('star_attack','echo','charge',2,4))
card('weapon_21010036',[[0,1],[4,1]],'★声骸攻击时：下次充能攻击+3伤害，间隔4秒，不累积。',material_effect=effect('star_attack','echo','charged',3,4))
card('w_sword',[[1,1],[3,0]],'★声骸攻击时：推进自身冷却0.25秒，间隔3秒。','')
card('whiff',[[0,-1],[0,-2],[1,0]],'★武器累计攻击3次：最强★武器下一击+3伤害，不累积。','',material_effect=effect('star_attack','weapon','flat',3,count=3,target='strongest_weapon'))
card('weapon_21020024',[[0,1],[3,1]],own='自身每攻击3次：追加6点伤害。',combo_effects=[effect('self_attack','','damage',6,count=3)])
card('weapon_21020015',[[0,1],[4,1]],own='自身每攻击3次：追加7点伤害。每2次攻击，攻击伤害+1，最多2层，持续6秒。',combo_effects=[effect('self_attack','','damage',7,count=3)],hasteEvery=2)
card('w_gauntlet',[[0,1],[1,1]],'★物品实际获得护盾时：自身下一击+3伤害，间隔3秒，不累积。','',material_effect=effect('star_shield','shield','flat',3,3),capabilities=['attack'])
card('echo_glacio',[[0,-1],[1,0]],'★武器累计攻击2次：获得3点护盾。','',material_effect=effect('star_attack','weapon','shield',3,count=2),capabilities=['shielding'])
card('weapon_21040064',[[0,1],[1,1]],'★物品实际获得护盾时：自身下一击+2伤害，间隔3秒，不累积。','充能攻击后获得3点减伤，每次敌方武器命中消耗1点。护盾累计挡伤2次后：反击4点伤害，间隔2秒。',shieldPeriod=6,shieldAmount=3,material_effect=effect('star_shield','shield','flat',2,3),combo_effects=[effect('blocked','','counter',4,2,2)],capabilities=['shielding','counter'])
card('weapon_21040046',own='护盾累计挡伤2次后：反击6点伤害，间隔2秒。充能攻击消耗穿透层，每层削盾4并追加1伤害。',shieldPeriod=6,shieldAmount=3,combo_effects=[effect('blocked','','counter',6,2,2)],capabilities=['shielding','counter','break_shield'])
for route,ids in {
 '充能重击':['w_broadblade','zig','weapon_21010104','weapon_21010036'],
 '迅捷联动':['w_sword','whiff','weapon_21020024','weapon_21020015'],
 '护盾反击':['w_gauntlet','echo_glacio','weapon_21040064','weapon_21040046'],
}.items():
 for k in ids:c['items'][k]['v75']['route']=route
# Zero-damage supports have only their true healing/shield clocks; no attack root.
for k in ['turtle','echo_butterfly']:
 c['items'][k]['v75']['cd']=0;c['items'][k]['cooldown']=0
c['items']['cool_tea']['adaptation_summary']='本作改编 · 开战获得8点护盾，随后饮尽。'
# Remove the duplicated star text and implementation boilerplate on V87 cards.
for d in c['items'].values():
 n=d.get('v75',{})
 if not n:continue
 own=n.get('ownExtra','');star=n.get('starText','')
 if own.startswith(star) and star.startswith('★'):
  own=own[len(star):].replace('同名间隔共享；战斗中不会消耗。','')
  n['extra']=n['ownExtra']=own
 cdesc=n.get('ownExtra','')+' '+(star if star.startswith('★') else '')
 if d.get('material_effect') or n.get('material_effect'):d['desc']=cdesc.strip()
c['design_version']=88
pool=['w_broadblade','w_sword','w_gauntlet','w_pistol','w_rectifier',
 'zig','whiff','echo_glacio','wuka','turtle','echo_butterfly','echo_vanguard',
 'mat_43020041','mat_43020011','mat_43020051','mat_41100011','mat_42500010','mat_42300050','mat_42300100',
 'mat_42310090','mat_42500030','mat_43020021','tuner','tube',
 'spicy_meat','maocai','tea','daily_tea','lamp','electro_coin']
assert len(pool)==30 and len(set(pool))==30
assert all(k in c['items'] for k in pool)
previous=json.loads((ROOT/'data/compat/design/v87.json').read_text())
design={'cards':patch,'focused_pool':pool,'shop_partner_probability':0.5,'weapon_rules':previous['weapon_rules'],'legacy':previous.get('legacy',{}),'items':{k:d['v75'] for k,d in c['items'].items() if 'v75' in d}}
(ROOT/'data/catalog.json').write_text(json.dumps(c,ensure_ascii=False,indent=2)+'\n')
(ROOT/'data/compat/design/v88.json').write_text(json.dumps(design,ensure_ascii=False,indent=2)+'\n')
print('V88:',len(patch),'core cards;',len(pool),'direct-shop entries; recipes retained:',len(c.get('recipes',[])))
