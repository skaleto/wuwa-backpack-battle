extends SceneTree
const I=preload('res://scripts/inventory/inventory.gd')
const C=preload('res://scripts/data/catalog.gd')
const P=preload('res://scripts/shop/practice_budget.gd')
const R=preload('res://scripts/party/recruitment_v115.gd')
const B=preload('res://scripts/battle/battle.gd')
var inv=I.new();var checks=0;var failures=0;var samples=[];var opponents={}
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():call_deferred('test')
func test():
 for leader in C.selectable_leaders():
  for seed_value in [19,73]:
   var run=inv.new_run(leader,seed_value);run.practice_ledger=[]
   var record={'leader':leader,'seed':seed_value,'rounds':[],'drafts':[]}
   for step in 12:
    ck(run.phase=='shop','preparation ready')
    P.procure(inv,run,'通用',false)
    ck(inv.validate_run(run),'procurement remains legal')
    var id='%d:%d'%[run.round,seed_value]
    if not opponents.has(id):opponents[id]=P.build(inv,run.round,seed_value+run.round*17)
    var before=run.duplicate(true);var combat=B.new().simulate(run,opponents[id],seed_value*100+run.round,false)
    ck(run==before,'combat does not mutate build')
    record.rounds.append({'round':run.round,'winner':combat.winner,'duration':combat.duration,'gold':run.gold,'crew':run.supports.duplicate(),'crew_triggers':combat.events.filter(func(e):return e.side==0 and e.kind=='crew_trigger').size(),'fusions':run.practice_ledger.filter(func(e):return e.round==run.round and e.purpose=='craft').size(),'items':run.items.map(func(p):return p.kind)})
    run.phase='result';var finish=inv.plan_finish(run,combat.winner)
    ck(finish.ok,'settlement plan succeeds');run=finish.run
    if run.phase=='ending':break
    if run.phase=='recruit':
     var cards=R.card_models(inv,run);cards.sort_custom(func(a,b):return int(a.usable)>int(b.usable))
     var node=int(run.recruitment.node);var choice=cards[0]
     var confirm=R.plan_confirm(inv,run,choice.role_id)
     ck(confirm.ok,'actual node selection succeeds');run=confirm.run
     record.drafts.append({'node':node,'role':choice.role_id})
     ck(run.recruitment.config.is_empty(),'ordinary play needs no targeting')
    ck(inv.validate_run(run),'new round valid')
   record.wins=run.wins;record.losses=run.losses;record.phase=run.phase
   ck(run.phase=='ending','complete a full run')
   samples.append(record);print('V115 RUN ',leader,' seed ',seed_value,' ',run.wins,'W ',run.losses,'L drafts ',record.drafts.size())
 ck(samples.size()==10,'five leaders two seeds')
 ck(samples.all(func(s):return s.drafts.size()>=1),'every measured run reaches first recruitment')
 ck(samples.any(func(s):return s.drafts.size()==2),'full-team progression reached naturally')
 FileAccess.open('res://build/qa/recruitment-v115/playthrough.json',FileAccess.WRITE).store_string(JSON.stringify({'checks':checks,'failures':failures,'samples':samples},'\t'))
 print('PLAYTHROUGH_V115 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
