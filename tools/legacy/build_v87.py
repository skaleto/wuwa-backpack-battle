#!/usr/bin/env python3
"""Frozen V86 -> V87 data patch: card-written star effects for the early pool.

Every effect below is written on the card and executed by material_effects'
generic paths (opening/clock/star_event). No per-item battle code is added.
Teas keep their existing opening behavior; cool_tea finally gets one.
"""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
src=(ROOT/'data/compat/catalog-v86.json').read_text()
c=json.loads(src)

def ring(shape):
    cells={tuple(p) for p in shape}
    neighbors=set()
    for x,y in cells:
        for dx,dy in ((0,1),(0,-1),(1,0),(-1,0)):
            n=(x+dx,y+dy)
            if n not in cells:neighbors.add(n)
    return [list(p) for p in sorted(neighbors)]

# kind, cells, trigger, category, action, value, period, target, text, capability
rows=[
 ('w_broadblade',ring,   'star_attack','echo','charge',1,4,'',  '★声骸攻击时：获得1层充能，间隔4秒。','charge'),
 ('w_sword',     ring,   'star_attack','echo','advance',.25,3,'','★声骸攻击时：推进自身冷却0.25秒，间隔3秒。','haste'),
 ('w_pistol',    ring,   'star_attack','echo','flat',1,4,'',    '★声骸攻击时：下一击+1伤害，间隔4秒。','attack'),
 ('w_gauntlet',  ring,   'star_attack','echo','haste',1,5,'',   '★声骸攻击时：获得1层迅捷，间隔5秒。','haste'),
 ('w_rectifier', ring,   'star_attack','echo','heal',2,4,'',    '★声骸攻击时：治疗2点，间隔4秒。','healing'),
 ('whiff',       ring,   'star_attack','weapon','flat',1,4,'strongest_weapon','★武器攻击时：最强★武器下一击+1，间隔4秒。','attack'),
 ('echo_bloom',  ring,   'star_attack','weapon','frost',1,6,'', '★武器攻击时：施加1层霜渐，间隔6秒。','frost'),
 ('echo_glacio', ring,   'star_attack','weapon','shield',2,5,'','★武器攻击时：获得2点护盾，间隔5秒。','shielding'),
 ('turtle',      ring,   'star_attack','weapon','heal',1,4,'',  '★武器攻击时：治疗1点，间隔4秒。','healing'),
 ('echo_butterfly',ring, 'star_attack','weapon','advance',.5,4,'','★武器攻击时：推进自身治疗时钟0.5秒，间隔4秒。','healing'),
 ('wuka',        ring,   'star_attack','weapon','advance',.3,4,'','★武器攻击时：推进自身冷却0.3秒，间隔4秒。','haste'),
 ('zig',         ring,   'star_attack','weapon','damage',1,3,'', '★武器攻击时：造成1点衍生伤害，间隔3秒。','attack'),
 ('weapon_21020012',ring,'star_attack','echo','flat',1,4,'',    '★声骸攻击时：下一击+1伤害，间隔4秒。','attack'),
 ('weapon_21020011',ring,'star_attack','echo','advance',.2,3,'', '★声骸攻击时：推进自身冷却0.2秒，间隔3秒。','haste'),
 ('weapon_21050011',ring,'star_attack','echo','shield',1,4,'',  '★声骸攻击时：获得1点护盾，间隔4秒。','shielding'),
]
patch={}
for kind,cells_fn,trigger,category,action,value,period,target,text,cap in rows:
    d=c['items'][kind];n=d['v75']
    cells=cells_fn(d['shape'])
    effect={'trigger':trigger,'action':action,'value':value,'period':period,'category':category}
    if target:effect['target']=target
    n['material_effect']=effect
    n['capabilities']=[cap]
    n['star']=n['starText']=text
    n['extra']=n['ownExtra']=text+'同名间隔共享；战斗中不会消耗。'
    n['stars']=cells;d['stars']=cells
    d['desc']=text;d['adaptation_summary']='本作改编 · '+text
    patch[kind]={'name':d['name'],'effect':effect,'description':n['ownExtra'],'stars':cells}

# Teas: behavior already lives in battle opening branches; make the cards say it.
# cool_tea gets a real opening heal through the generic material path and is
# consumed like the other supplies.
tea=c['items']['cool_tea']
spec={'trigger':'opening','action':'shield','value':8,'category':'','consumed':True}
tea['v75']['material_effect']=spec
tea['v75']['capabilities']=['shielding']
tea['v75']['star']=tea['v75']['starText']='无额外星位规则。'
tea['v75']['extra']=tea['v75']['ownExtra']='开战时获得8点护盾，随后饮尽。'
tea['desc']='开战时获得8点护盾，随后饮尽。';tea['adaptation_summary']='本作改编 · 开战时治疗10点，随后饮尽。'
patch['cool_tea']={'name':tea['name'],'effect':spec,'description':tea['v75']['ownExtra'],'stars':[]}
daily=c['items']['daily_tea']
daily['desc']='开战时获得2层迅捷，随后饮尽。';daily['adaptation_summary']='本作改编 · 开战时获得2层迅捷，随后饮尽。'
daily['v75']['extra']=daily['v75']['ownExtra']='开战时获得2层迅捷，随后饮尽。'
patch['daily_tea']={'name':daily['name'],'effect':{'trigger':'opening','action':'haste','value':2},'description':daily['v75']['ownExtra'],'stars':[]}

c['design_version']=87
previous=json.loads((ROOT/'data/compat/design/v86.json').read_text())
design={'cards':patch,'weapon_rules':previous.get('weapon_rules',{}),'items':{k:v['v75'] for k,v in c['items'].items() if 'v75' in v},'legacy':previous.get('legacy',{})}
(ROOT/'data/compat/design/v87.json').write_text(json.dumps(design,ensure_ascii=False,indent=2)+'\n')
(ROOT/'data/catalog.json').write_text(json.dumps(c,ensure_ascii=False,indent=2)+'\n')
print('v87 cards:',len(patch),'profiles:',len(design['items']))
