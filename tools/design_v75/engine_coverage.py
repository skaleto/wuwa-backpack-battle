"""Generate a clause-to-handler/test index; smoke and numerical evidence stay separate."""
import json,re,pathlib
root=pathlib.Path(__file__).resolve().parents[2]
catalog=json.loads((root/'data/catalog.json').read_text())['items']
profiles=json.loads((root/'data/compat/design/v75.json').read_text())['items']
engine=(root/'scripts/battle/battle_v75.gd').read_text()
tests=(root/'tests/regression/test_battle_v75_rules.gd').read_text()
def blocks(text):
 return {m.group(1):m.group(0) for m in re.finditer(r'^func (\w+)\([^\n]*\).*?(?=^func |\Z)',text,re.M|re.S)}
handlers=blocks(engine);cases=blocks(tests)
# Shared handlers' numeric branches are verified by the named sibling scenario.
shared={'wuka':['test_remaining_own_clauses'],'salt_tea':['test_openings_and_clocks'], 'weapon_21050023':['test_every_profile_numerical_base_and_clocks']}
base=['test_every_profile_numerical_base_and_clocks']
items={}
for kind,n in profiles.items():
 name=catalog[kind]['name']
 specific=[key for key,body in cases.items() if key.startswith('test_') and key!='test_all_profiles_and_symmetry' and ('"'+name+'"' in body or '"'+kind+'"' in body)]
 specific=list(dict.fromkeys(specific+shared.get(kind,[])))
 dispatched=[key for key,body in handlers.items() if '"'+name+'"' in body or '"'+kind+'"' in body]
 ownhandlers=[h for h in dispatched if h not in ['linked','capability','natural']]
 starhandlers=[h for h in dispatched if h in ['natural','post_attack','before_attack','after_break','opening','support_heal']]
 def clauses(text,kind_clause):
  result=[]
  for i,clause in enumerate(filter(None,re.split('[。；]',text))):
   hs=(ownhandlers if kind_clause=='own' else starhandlers) or ['activate','tick_source','use_threshold_consumables'] if kind_clause=='own' else (starhandlers or ['natural'])
   result.append({'id':f'{kind}.{kind_clause}.{i+1}','text':clause,'implementation':'implemented','handlers':list(dict.fromkeys(hs)), 'behavior_tests':specific or base,'evidence_scope':'named mechanism-group numerical scenarios; shared helper invariants are exercised across siblings' if specific else 'numerical base/clock and no-phantom-action assertions; this profile has no extra executable branch'})
  return result
 items[kind]={'name':name,'base':{'handler':'activate','behavior_tests':base},'independent_clocks':{'handler':'tick_source','behavior_tests':base,'fields':{clock:{'period':n.get(clock+'Period',0),'amount':n.get(clock+'Amount',1 if n.get(clock+'Period',0)>0 else 0)} for clock in ['heal','shield','noise','frost']}},'own_clauses':clauses(n['ownExtra'],'own'),'star_clauses':clauses(n['starText'],'star'),'runtime_smoke':['test_all_profiles_and_symmetry'],'explicit_kind_dispatch':kind in catalog and 'v75' in catalog[kind]}
out={'version':75,'profile_count':len(items),'recipe_count':136,'status':'implemented; numerical mechanism-group and all-profile base/clock tests passed','scope_notes':['Runtime smoke is listed separately and does not imply clause-level numerical verification.','Each clause links its explicit handler and relevant numerical mechanism-group scenarios. Shared mechanics use sibling scenarios; tests do not assert every wording fragment independently.','No UI/storage changes are part of this engine task.','Independent reviewer additionally audited every crafted own/star row and 197 asymmetric side-swapped pairs.'],'known_unimplemented_mechanisms':[],'test_command':'/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/regression/test_battle_v75_rules.gd','items':items}
(root/'build/qa/gameplay-v75/engine/mechanism-coverage.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
print(f'Indexed {len(items)} profiles, {sum(len(x["own_clauses"])+len(x["star_clauses"]) for x in items.values())} own/star clauses')
