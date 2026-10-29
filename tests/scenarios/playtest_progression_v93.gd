extends SceneTree
## Real new-run acquisition and Battle/finish. No Storage and no fixture injection.
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://tests/scenarios/procurement_audit_v75.gd")
const P=preload("res://scripts/shop/practice_budget.gd")
const B=preload("res://scripts/battle/battle.gd")
var inv=I.new();var checks=0;var failures=[];var samples=[]
var opponents={}
func ck(ok,label):
 checks+=1
 if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize():call_deferred("test")
func owned(r):return r.items+r.stash
func events(result,side):
 var counts={}
 for e in result.events:
  if e.side==side:counts[e.kind]=int(counts.get(e.kind,0))+1
 return counts
func play(leader,route,seed_value):
 var r=inv.new_run(leader,seed_value,"focused");r.practice_ledger=[]
 var sample={"leader":leader,"route":route,"seed":seed_value,"rounds":[],"ledger":[],"first_fusion":0,"max_lineage_depth":0,"fusions":[],"income":0,"spent":0}
 var lineage={"i1":0,"i2":0};var cash=9
 ck(r.gold==9 and r.round==1 and r.wins==0 and r.losses==0,"normal new run")
 while r.phase=="shop" and sample.rounds.size()<I.PROGRESSION.MAX_ROUNDS:
  var round_number=int(r.round);var start_ledger=r.practice_ledger.size()
  P.procure(inv,r,route,false)
  var shelves=[]
  for index in range(start_ledger,r.practice_ledger.size()):
   var entry=r.practice_ledger[index];cash-=int(entry.gold);sample.spent+=int(entry.gold)
   ck(cash==int(entry.balance),"every public transaction cash ledger")
   if entry.purpose=="shelf":shelves=entry.offers.duplicate(true)
   if entry.purpose in ["shop","capacity"]:
    ck(not shelves.is_empty() and shelves[entry.slot].get("kind","")==entry.kind,"purchase from latest visible shelf")
    ck(entry.gold==int(C.items[entry.kind].price),"full public purchase price")
    shelves[entry.slot]={};lineage[entry.uid]=0
   if entry.purpose=="craft":
    var recipe=C.combinations.filter(func(v):return v.id==entry.recipe)[0]
    var kinds=entry.inputs.map(func(v):return v.kind);kinds.sort()
    var expected=[recipe.base,recipe.materials[0]];expected.sort()
    ck(kinds==expected and entry.consumed.size()==2,"fusion exact distinct input provenance")
    ck(inv.adjacent(entry.inputs[0],entry.inputs[1]) and not inv.occupied(entry.inputs[0]).any(func(cell):return cell in inv.occupied(entry.inputs[1])),"actual fusion input placement ledger")
    var depth=0;var paid=0
    for input in entry.inputs:depth=maxi(depth,int(lineage.get(input.uid,0)));paid+=int(input.paid_cost)
    depth+=1;lineage[entry.output.uid]=depth
    ck(int(entry.output.paid_cost)==paid,"fusion preserves paid investment")
    sample.max_lineage_depth=maxi(sample.max_lineage_depth,depth)
    if sample.first_fusion==0:sample.first_fusion=round_number
    sample.fusions.append({"round":round_number,"target":entry.kind,"depth":depth})
  ck(inv.validate_run(r) and cash==r.gold and r.gold==9+sample.income-sample.spent,"legal procurement and full budget")
  # Replay purchases cannot mutate failed drop or purchase state.
  for slot in r.shop.size():
   if r.shop[slot].is_empty():continue
   var before=r.duplicate(true);var bad=inv.make_piece(r.shop[slot].kind,"preview");bad.x=8
   ck(inv.purchase_at(r,slot,bad,"board").is_empty() and r==before,"illegal drop atomic")
   break
  var opponent_seed=int(r.seed)%31
  var key=str(round_number)+":"+str(opponent_seed)
  if not opponents.has(key):opponents[key]=P.build(inv,round_number,opponent_seed,"focused")
  var enemy=opponents[key].duplicate(true)
  ck(enemy.practice_spend+enemy.practice_unspent==I.ECONOMY.budget(round_number),"synthetic opponent public budget")
  var before=r.duplicate(true);var battle_seed=seed_value*100+round_number
  var result=B.new().simulate(r,enemy,battle_seed,false)
  ck(r==before and result.winner in [-1,0,1] and result.duration>0,"real simulation read-only valid outcome")
  if round_number==1:ck(result==B.new().simulate(r,enemy,battle_seed,false),"seeded replay deterministic")
  var data={"round":round_number,"gold":r.gold,"bonds":P.bonds(inv,r),"items":r.items.duplicate(true),"bags":r.bags.duplicate(true),"stash":r.stash.duplicate(true),"winner":result.winner,"duration":result.duration,"events":[events(result,0),events(result,1)],"totals":result.totals,"used":result.used,"initial_state":result.frames[0].sides,"final_state":result.frames[-1].sides,"opponent":{"seed":opponent_seed,"method":enemy.practice_method,"spend":enemy.practice_spend,"unspent":enemy.practice_unspent,"items":enemy.items,"ledger":enemy.practice_ledger}}
  sample.rounds.append(data)
  var possessions=owned(r).duplicate(true);var before_gold=int(r.gold);var wins=int(r.wins);var losses=int(r.losses)
  r.phase="result";r.combat=result
  r.history.append({"round":round_number,"winner":result.winner,"duration":result.duration,"build":inv.snapshot(r,"qa-v75"),"totals":result.totals})
  var settled=inv.finish(r,result.winner)
  ck(not settled.is_empty(),"real finish transaction")
  var income=int(r.gold)-before_gold;cash+=income;sample.income+=income
  ck(income==(0 if r.phase=="ending" else I.ECONOMY.income(result.winner,r.round)),"actual winner determines next income")
  ck(r.wins==wins+(1 if result.winner==1 else 0) and r.losses==losses+(0 if result.winner==1 else 1),"actual win/loss counted")
  ck(possessions.all(func(i):return owned(r).any(func(v):return v.uid==i.uid and v.kind==i.kind)),"all provisions and equipment persist")
  ck(owned(r).all(func(i):return possessions.any(func(v):return v.uid==i.uid)),"no owned item removed or injected on settlement")
  ck(inv.validate_run(r) and r.gold==cash,"legal settlement")
  P.record(r,"settlement","",-income,{"battle_round":round_number,"winner":result.winner,"used":result.used[0]})
 var kinds=owned(r).map(func(i):return i.kind);kinds.sort()
 sample.final_build_hash=JSON.stringify(kinds).sha256_text()
 sample.acquisition_hash=JSON.stringify(r.practice_ledger.filter(func(e):return e.purpose in ["shop","capacity","craft","recruit"]).map(func(e):return [e.round,e.purpose,e.kind])).sha256_text()
 sample.route_composition={}
 for item in r.items:
  var actual=C.items[item.kind].get("v75",{}).get("route","legacy")
  sample.route_composition[actual]=int(sample.route_composition.get(actual,0))+1
 sample.final_snapshot=inv.snapshot(r,"qa-v75-final");sample.ledger=r.practice_ledger;sample.wins=r.wins;sample.losses=r.losses;sample.final_gold=r.gold;sample.ending=r.phase
 ck(r.phase=="ending" and (r.wins==I.PROGRESSION.WIN_TARGET or r.losses==I.PROGRESSION.LOSS_LIMIT),"actual eight wins or four losses terminal")
 print("RUN ",leader," / ",route," / ",seed_value," => ",r.wins,"W ",r.losses,"L depth ",sample.max_lineage_depth)
 return sample
func test():
 for leader in C.selectable_leaders():
  for route in P.ROUTES:
   for seed_value in [19,73]:samples.append(play(leader,route,seed_value))
  samples.append(play(leader,"通用",137))
 ck(samples.size()==42,"six leaders three biases two seeds plus flexible")
 ck(inv.audit_failures.is_empty(),"all public mutation audits")
 var report={"mutation_audits":inv.audits,"scope":"42 focused-mode synthetic diagnostics; uses UI fallback matchmaking seed modulo and actual current shop seed; no real ghost archives or player input; not population win rate","catalogue_hash":C.catalogue_hash,"checks":checks,"failures":failures,"samples":samples}
 var file=FileAccess.open("res://tests/fixtures/data/gameplay-v93/reports/focused-ui-match-playthrough.json",FileAccess.WRITE)
 ck(file!=null,"report writable")
 if file:
  report.checks=checks;report.failures=failures;file.store_string(JSON.stringify(report,"\t"));file.close()
 print("PLAYTHROUGH_V75 ",checks," checks, ",failures.size()," failures")
 quit(1 if not failures.is_empty() else 0)
