extends SceneTree
## Diagnostic acquisition through actual random shelves; no fixture inventory grants.
const I=preload('res://tests/fixtures/recruitment_fixture_v114.gd')
const R=preload('res://scripts/party/recruitment_v114.gd')
const P=preload('res://scripts/shop/practice_budget.gd')
const B=preload('res://scripts/battle/battle.gd')
var inv=I.new();var failures=0
func _initialize():
 var report={'scope':'12 seeded natural-shop diagnostics; not a population balance estimate','reached_round3':0,'reached_round6':0,'samples':[]}
 for seed_value in range(12):
  var r=inv.new_run(I.C.selectable_leaders()[seed_value%I.C.selectable_leaders().size()],114+seed_value);r.practice_ledger=[]
  var sample={'seed':seed_value,'drafts':[],'rounds':[]}
  while r.phase!='ending' and sample.rounds.size()<11:
   if r.phase=='recruit':
    var cards=R.card_models(inv,r);var index=seed_value%cards.size();var card=cards[index]
    var reward=card.reward_choices[seed_value%card.reward_choices.size()].kind if not card.reward_choices.is_empty() else 'gold' if card.gold_fallback else ''
    var before_gold=int(r.gold);var node=int(r.recruitment.node);var commit=inv.commit_operation(r,R.plan_confirm(inv,r,card.role_id,reward))
    if not commit.ok:failures+=1;break
    sample.drafts.append({'node':node,'role':card.role_id,'usable':card.usable,'reward':reward,'gold_delta':r.gold-before_gold})
    report['reached_round'+str(node)]+=1
   var ledger_start=r.practice_ledger.size()
   P.procure(inv,r,P.ROUTES[seed_value%3],true)
   var enemy=P.build(inv,int(r.round),seed_value+31)
   var result=B.new().simulate(r,enemy,seed_value+int(r.round)*13,false)
   sample.rounds.append({'round':r.round,'gold':r.gold,'items':r.items.map(func(p):return p.kind),'crew':r.supports.duplicate(),'crew_config':r.recruitment.config.duplicate(true),'crew_transactions':r.practice_ledger.slice(ledger_start).filter(func(row):return row.purpose=='crew_setup' or (row.purpose=='refresh' and row.has('target')) or (row.purpose=='craft' and not row.get('crew_rewards',[]).is_empty()) or (row.purpose=='shop' and not I.C.items[row.kind].get('crew_supply','').is_empty())),'crew_triggers':result.events.filter(func(e):return e.kind=='crew_trigger' and e.side==0).size(),'winner':result.winner})
   r.phase='result';r.combat=result
   if inv.finish(r,result.winner).is_empty():failures+=1;break
  if r.phase!='ending':failures+=1
  sample.wins=r.wins;sample.losses=r.losses;report.samples.append(sample)
 report.failures=failures
 var file=FileAccess.open('res://build/qa/recruitment-v114/acquisition-measurement.json',FileAccess.WRITE);file.store_string(JSON.stringify(report,'\t'));file.close()
 print('MEASURE_RECRUITMENT_V114 reached nodes ',report.reached_round3,'/12 and ',report.reached_round6,'/12; failures ',failures)
 quit(1 if failures else 0)
