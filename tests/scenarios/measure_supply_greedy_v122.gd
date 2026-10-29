extends SceneTree
## An untargeted shopper uses the established public practice purchasing and
## crafting policy, with its opening restraint disabled and all routes equal.
const I=preload('res://scripts/inventory/inventory.gd')
const C=preload('res://scripts/data/catalog.gd')
const P=preload('res://scripts/shop/practice_budget.gd')
var inv=I.new()
func _initialize():
 var report={'policy':'existing practice procure; conservative=false, route=通用, two shelves/round, real bag purchases, all recipes; draw income, no recruit rewards','samples':[]}
 for supply_version in [0,122]:
  for mode in ['full','focused']:
   for leader in C.selectable_leaders():
    for index in 8:
     var seed_value=37+index*997
     var run=inv.new_run_supply(leader,seed_value,mode,supply_version)
     var sample={'supply_version':supply_version,'mode':mode,'leader':leader,'seed':seed_value,'rounds':[],'first_upgrade':0,'first_quality4':0,'first_terminal':0}
     for rn in range(1,6):
      if rn>1:run.round=rn;run.gold+=I.ECONOMY.income(0,rn);run.refreshes=0;assert(inv.refresh(run))
      P.procure(inv,run,'通用',false)
      assert(inv.validate_run(run))
      var spent=run.practice_ledger.reduce(func(total,row):return total+int(row.gold),0)
      assert(spent+int(run.gold)==I.ECONOMY.budget(rn))
      for row in run.practice_ledger:
       if row.purpose!='craft' or not C.is_tag(row.kind,'weapon'):continue
       if sample.first_upgrade==0:sample.first_upgrade=row.round
      for item in run.items+run.stash:
       if not C.is_tag(item.kind,'weapon'):continue
       if int(C.items[item.kind].rarity)>=4 and sample.first_quality4==0:sample.first_quality4=rn
       if int(C.items[item.kind].v75.tier)==5 and sample.first_terminal==0:sample.first_terminal=rn
      sample.rounds.append({'round':rn,'gold':run.gold,'spent':spent,'items':(run.items+run.stash).map(func(p):return p.kind)})
     sample.ledger=run.practice_ledger;report.samples.append(sample)
    print('GREEDY ',supply_version,' ',mode,' ',leader)
 var f=FileAccess.open('res://build/qa/feedback-v122/supply-greedy.json',FileAccess.WRITE);f.store_string(JSON.stringify(report,' '));f.close()
 print('SUPPLY_GREEDY ',report.samples.size());quit()
