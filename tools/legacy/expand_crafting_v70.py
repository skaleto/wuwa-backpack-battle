"""Extend the exact two-input recipe graph; preserve all existing active item data."""
from pathlib import Path
from copy import deepcopy
import json
root=Path(__file__).resolve().parents[2]
path=root/'data/catalog.json'; c=json.loads(path.read_text()); items=c['items']
manifest_path=root/'assets/manifest.json'; manifest=json.loads(manifest_path.read_text())
# base, partner, target, damage. Every target has exactly one incoming recipe.
weapons=[
 ('weapon_21010044','electro_coin','weapon_21010064',12.04),('discord','contract','weapon_21010074',12.04),
 ('weapon_21010034','answer','weapon_21010084',9.52),('weapon_21020044','electro_coin','weapon_21020064',7.74),
 ('weapon_21020034','aero_coin','weapon_21020074',6.12),('weapon_21050044','contract','variation',9.46),
 ('rectifier25','flower','weapon_21050064',8.8),('weapon_21030024','aero_coin','weapon_21030064',8.6),
 ('weapon_21030034','answer','weapon_21030044',6.8),('weapon_21040034','rocksteady','weapon_21040044',6.4)]
finals=[
 ('weapon_21010064','rock_wall','weapon_21010015',14.8),('weapon_21010074','contract_echo','weapon_21010045',14.8),
 ('weapon_21020064','whiff_fast','weapon_21020015',9.6),('weapon_21020074','whiff_fast','weapon_21020045',7.6),
 ('variation','contract_echo','weapon_21050015',11.8),('weapon_21050064','turtle_clean','weapon_21050045',10.8),
 ('weapon_21030064','whiff_fast','weapon_21030015',10.6),('weapon_21030044','rock_wall','weapon_21030045',8.4),
 ('weapon_21040044','turtle_clean','weapon_21040015',8.0)]
variants=[
 ('whiff_fast','tube','whiff_tempest','呼咻咻·疾风',[('damage',4),('damage',4)],3),
 ('turtle_clean','flower','turtle_pure','寒霜陆龟·澄净',[('heal',5),('cleanse',1),('shield',2)],4),
 ('rock_wall','tube','rock_fortress','坚岩斗士·坚城',[('damage',3),('shield',10)],5),
 ('glacio_focus','tuner','glacio_crystal','冷凝棱镜·晶凝',[('damage',2),('frost',2)],5),
 ('contract_echo','aero_coin','contract_oath','珍奇契约·共鸣',[],6),
 ('cool_tea','nutrition','cool_tea_pure','舒云凉茶·澄心',[('haste',3),('cleanse',4),('heal',6)],0),
 ('dragon_food','maocai','dragon_feast','龙抬头·盛宴',[('shield',20),('stamina_discount',.20)],0),
 ('nutrition_dense','flower','nutrition_complete','完备营养块',[('heal',42),('cleanse',1)],0)]
labels={'charge':'充能','haste':'迅捷','shield':'护盾','noise':'光噪','frost':'霜渐','cleanse':'净化','break_shield':'额外削盾','stamina_discount':'体力消耗'}
added=[]
def recipe(base,partner,target,tier):
 if any(r['target']==target for r in c['recipes']):return
 c['recipes'].append({'id':'R%02d'%(len(c['recipes'])+1),'base':base,'materials':[partner],'target':target,'round_min':3 if tier==3 else 5,'type':items[base].get('weapon_type','item'),'input_tier':tier-1,'fee':0})
 added.append({'base':base,'partner':partner,'target':target})
def finish(d,base,partner,tier):
 d.update(craft_only=True,released=True,strict_signature=False,craft_tier=tier,rarity=tier+1,round_min=3 if tier==3 else 5,price=items[base]['price']+items[partner]['price'])
 d['v60']['active']=True;d['damage']=sum(a['value'] for a in d['v60']['actions'] if a['type']=='damage');d['heal']=sum(a['value'] for a in d['v60']['actions'] if a['type']=='heal')
 for tag in ['attack','healing','shielding']:
  if tag in d['tags']:d['tags'].remove(tag)
 if d['damage']>0:d['tags'].append('attack')
 if d['heal']>0:d['tags'].append('healing')
 if any(a['type']=='shield' for a in d['v60']['actions']):d['tags'].append('shielding')
 d['v60']['rows']=[row for row in d['v60'].get('rows',[]) if row[0].startswith('★') or row[0]=='发动']
 for a in d['v60']['actions']:
  if a['type'] in labels:d['v60']['rows'].append([labels[a['type']],('−%d%%'%round(a['value']*100)) if a['type']=='stamina_discount' else '+%s'%a['value']])
 d['upgrade_from']=base
for tier,table in [(3,weapons),(4,finals)]:
 for base,partner,target,damage in table:
  identity=items[target];d=deepcopy(items[base])
  for k in ['name','id','asset_path','canonical_effect','canonical_summary','original_summary','original_desc','source_page','shape','draw_hint','original_rarity']:
   if k in identity:d[k]=deepcopy(identity[k])
  d['v60']['actions'][0]['value']=damage
  for a in d['v60']['actions']:
   if a['type']=='break_shield':a['value']+=2
   if a['type']=='shield' and tier==4:a['value']+=1
  if tier==4:
   if 'noise_consume' in d['v60']['special']:d['v60']['special']['noise_consume']['damage_per_layer']=7
   if 'haste_damage' in d['v60']['special']:d['v60']['special']['haste_damage']['value']=3
   if target=='weapon_21020015':d['v60']['special']['low_hp_damage']={'threshold':.35,'value':2}
   if target=='weapon_21010045':d['v60']['special']['haste_damage']={'min_stacks':6,'value':2}
  for star in d['stars']:
   while star in d['shape']:star[0]+=1
  finish(d,base,partner,tier);items[target]=d;recipe(base,partner,target,tier)
for base,partner,target,name,actions,cd in variants:
 d=deepcopy(items[base]);d['name']=name;d['cooldown']=cd
 d['v60']['actions']=[{'type':t,'value':v} for t,v in actions]
 if target=='rock_fortress':d['v60']['star']['actions'][0]['value']=3
 if target=='contract_oath':d['v60']['special']['haste_derived']['value']=5
 finish(d,base,partner,3);items[target]=d
 manifest['items'][target]=deepcopy(manifest['items'][base]);manifest['items'][target]['reuse_source']=base
 recipe(base,partner,target,3)
# Keep existing order and bytes' semantics; migration stores the previous hash.
path.write_text(json.dumps(c,ensure_ascii=False,indent=2)+'\n')
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
(root/'build/qa/ui-v70/new-recipes.json').write_text(json.dumps(added,ensure_ascii=False,indent=2))
print('new recipes',len(added),'total',len(c['recipes']),'active',sum(d.get('v60',{}).get('active',False) for d in items.values()))
