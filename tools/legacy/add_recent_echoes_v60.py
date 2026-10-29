#!/usr/bin/env python3
import json
from pathlib import Path
R=Path(__file__).resolve().parents[2]
p=R/'data/catalog.json';C=json.loads(p.read_text());sources=json.loads((R/'build/qa/v60/research/echo-proposal-manifest.json').read_text())['echoes'];M=json.loads((R/'assets/manifest.json').read_text())
def a(**kv):return [{'type':k,'value':v} for k,v in kv.items()]
def star(tag,event,positions,actions,interval):return dict(target=tag,stars=positions,event=event,actions=actions,interval=interval)
q=[[0,0],[1,0],[0,1],[1,1]];wide=[[x,y] for y in range(2) for x in range(3)]
# (local id, source index, shape, price, round, cd, ordinary actions, star, special, card rows)
rows=[
('echo_bloom',0,[[0,0],[0,1]],3,1,5,a(damage=4,frost=1),{}, {},[['霜渐','+1']]),
('echo_jade_snake',1,[[0,0]],2,1,5,a(damage=2,charge=1),{}, {},[['充能','+1']]),
('echo_aureate',2,[[0,0]],2,1,5,a(damage=2,heal=2),{}, {},[]),
('echo_soulfrayer',3,q,4,2,5,a(damage=5,haste=1),star('attack','attack',[[3,0],[3,1]],a(charge=1),4),{},[['迅捷','+1'],['★ 攻击 → 充能','+1 · 同族 4 秒']]),
('echo_formrender',4,q,4,2,5,a(break_shield=6,damage=5),star('weapon','attack',[[0,-2],[1,-2]],a(charge=1),4),{},[['额外削盾','6'],['★ 武器 → 充能','+1 · 同族 4 秒']]),
('echo_lionarch',5,q,4,2,5,a(damage=3,shield=4),star('healing','heal',[[0,3],[1,3]],a(cleanse=1),6),{},[['护盾','+4'],['★ 治疗 → 净化','1 层 · 同族 6 秒']]),
('echo_shuxin',6,q,8,4,6,a(damage=10,noise=1),star('shielding','shield',[[-2,0],[-2,1]],a(noise=1),4),{},[['光噪','+1'],['★ 护盾 → 光噪','+1 · 同族 4 秒']]),
('echo_hecaton',7,wide,8,3,6,a(damage=8,shield=6),star('attack','attack',[[0,-1],[2,-1]],a(shield=2),4),{},[['护盾','+6'],['★ 攻击 → 护盾','+2 · 同族 4 秒']]),
('echo_tianqui',8,wide,8,3,6,a(damage=6,haste=2),star('echo','activate',[[0,3],[2,3]],a(charge=1),4),{},[['迅捷','+2'],['★ 声骸 → 充能','+1 · 同族 4 秒']]),
('echo_wankui',9,wide,9,4,7,a(break_shield=12,damage=8),{}, {'shield_strike':{'consume':6,'multiplier':2}},[['额外削盾','12'],['消耗己方护盾','最多 6 点 ×2 伤']]),
]
for id,index,shape,price,rnd,cd,acts,spec,special,facts in rows:
 src=sources[index];tagmap={'damage':'attack','heal':'healing','shield':'shielding','break_shield':'breaker'};tags=['echo']
 for action in acts:
  t=tagmap.get(action['type'],action['type'])
  if t not in tags:tags.append(t)
 v={'active':True,'actions':acts,'activation':'cooldown','special':special,'rows':facts,'recent':True}
 if spec:v['star']={'event':spec['event'],'actions':spec['actions'],'interval':spec['interval'],'family':id}
 d={'name':src['name'],'source_id':src['stable_source_id'],'source_page':src['evidence_page'],'asset_path':src['repository_detail_reference']['path'],
 'canonical_reference':src['main_reference']['path'],'original_summary':'原作声骸；战斗数值为本作改编','canonical_cost':src['cost'],'echo_cost':src['cost'],'element':src['element'],
 'shape':shape,'price':price,'round_min':rnd,'cooldown':cd,'tags':tags,'rarity':{1:1,3:2,4:4}[src['cost']],'original_rarity':src['cost'],
 'stars':spec.get('stars',[]),'target':spec.get('target',''),'desc':'','damage':sum(x['value'] for x in acts if x['type']=='damage'),'heal':sum(x['value'] for x in acts if x['type']=='heal'),
 'energy':0,'concerto':0,'stamina':0,'released':True,'craft_only':False,'effect':id,'v60':v}
 C['items'][id]=d
 M['items'].setdefault(id,{'path':'assets/items/core/'+id+'.png','name':d['name'],'status':'pending_generation','reference':src['main_reference']['path'],'shape':shape,'tags':tags,'angle':0})
p.write_text(json.dumps(C,ensure_ascii=False,indent=2)+'\n');(R/'assets/manifest.json').write_text(json.dumps(M,ensure_ascii=False,indent=2)+'\n')
print('Added 10 recent echoes:',sum(i.get('v60',{}).get('active',False) for i in C['items'].values()),'active items')
