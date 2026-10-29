extends SceneTree
## Controlled late fixtures, NOT acquired runs, probability estimates, or optimal builds.
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const B=preload("res://scripts/battle/battle.gd")
const P=preload("res://scripts/shop/practice_budget.gd")
var inv=I.new();var checks=0;var failures=[]
const PACKS={
 "charge_wing":["weapon_21020104","heron","feilian","tea","turtle"],
 "charge_collapse":["weapon_21020084","heron","echo_vanguard","medical","turtle"],
 "charge_traveler":["weapon_21020043","feilian","heron","whiff","tea"],
 "haste_flow":["weapon_21020015","cyan_heron","contract","whiff","turtle"],
 "haste_flying":["weapon_21020074","cyan_heron","whiff","echo_glacio","tea"],
 "haste_march":["weapon_21020024","echo_tianqui","cyan_heron","turtle"],
 "shield_slash":["weapon_21020034","bellborne","rocksteady","flower"],
 "shield_source":["weapon_21020023","rocksteady","flower","turtle","medical"],
 "shield_break":["weapon_21020043","echo_wankui","rocksteady","turtle"]}
func ck(ok,label):
 checks+=1
 if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize():call_deferred("test")
func build(kinds:Array,linked:bool=true)->Dictionary:
 var r=inv.new_run("aemeath",1);r.items=[];r.stash=[];r.bags=[];r.round=6;r.gold=0;r.serial=100;r.primary="i1"
 for y in [0,2]:
  for x in [0,3]:
   var b=inv.make_piece("satchel","b%d-%d"%[x,y]);b.x=x;b.y=y;r.bags.append(b)
 for kind in kinds:
  var fit=inv.first_fit(inv.make_piece(kind,"i"+str(r.items.size()+1)),r.items,r.bags)
  ck(not fit.is_empty(),"controlled capacity "+kind)
  if not fit.is_empty():r.items.append(fit)
 if linked:P.arrange(inv,r)
 ck(inv.validate_run(r),"controlled legal state")
 var cost=kinds.reduce(func(total,kind):return total+int(C.items[kind].v75.cost),0)
 ck(cost<=24,"recursive cost ceiling24")
 return r
func summary(result):
 var counts=[{},{}]
 for e in result.events:counts[e.side][e.kind]=int(counts[e.side].get(e.kind,0))+1
 return {"winner":result.winner,"duration":result.duration,"totals":result.totals,"events":counts,"used":result.used}
func duel(a,b,seed_value=31):
 var original_a=a.duplicate(true);var original_b=b.duplicate(true)
 var result=B.new().simulate(a,b,seed_value,false)
 ck(a==original_a and b==original_b,"controlled simulation read-only")
 return result
func unlinked(run):
 var r=run.duplicate(true)
 for item in r.items.duplicate(true):
  var best=item;var minimum=P.bonds(inv,r)
  for rotation in 4:
   for y in 4:
    for x in 6:
     var v=item.duplicate(true);v.merge({"rotation":rotation,"x":x,"y":y},true)
     if not inv.can_place(v,r.items,r.bags):continue
     var candidate=r.duplicate(true)
     if not inv.place(candidate,v):continue
     var value=P.bonds(inv,candidate)
     if value<minimum:minimum=value;best=v
  inv.place(r,best)
 ck(inv.validate_run(r),"unlinked legal spatial counterfactual")
 return r
func test():
 var builds={};var report={"scope":"controlled fixtures, same aemeath leader,24 neutral cells,recursive item cost<=24; unequal item costs disclosed; no acquisition claims; no exhaustive optimizer","packs":{},"pairs":[],"probes":[]}
 for name in PACKS:
  var r=build(PACKS[name]);builds[name]=r
  report.packs[name]={"cost":PACKS[name].reduce(func(sum,k):return sum+int(C.items[k].v75.cost),0),"bonds":P.bonds(inv,r),"items":r.items,"bags":r.bags}
 for a in PACKS:
  for b in PACKS:
   var result=duel(builds[a],builds[b]);report.pairs.append({"a":a,"b":b,"result":summary(result)})
   if a==b:ck(result.winner==0 and is_equal_approx(result.totals[0].damage,result.totals[1].damage),"linked exact mirror "+a)
 # Every ordered pair above includes the swapped side. Check the actual outcomes.
 for row in report.pairs:
  var swapped=report.pairs.filter(func(v):return v.a==row.b and v.b==row.a)[0]
  ck(row.result.winner==-swapped.result.winner,"side-swapped winner "+row.a+"/"+row.b)
 for name in ["charge_wing","haste_flow","shield_source"]:
  var alternate=unlinked(builds[name]);var enemy=builds.shield_slash
  var linked_result=duel(builds[name],enemy);var unlinked_result=duel(alternate,enemy)
  ck(P.bonds(inv,alternate)<P.bonds(inv,builds[name]),"remove real stars "+name)
  report.probes.append({"name":"stars_"+name,"linked_bonds":P.bonds(inv,builds[name]),"unlinked_bonds":P.bonds(inv,alternate),"linked":summary(linked_result),"unlinked":summary(unlinked_result),"unlinked_items":alternate.items})
 var extra={
  "no_shield":["w_sword","whiff","medical","tea"],
  "shield":["w_sword","turtle","medical","tea"],
  "repeat_bell":["w_sword","bellborne","bellborne","turtle"],
  "single_bell":["w_sword","bellborne","turtle"],
  "repeat_tianqui":["w_sword","echo_tianqui","echo_tianqui","turtle"],
  "single_tianqui":["w_sword","echo_tianqui","turtle"],
  "multi_weapon":["w_sword","weapon_21020011","weapon_21020011","weapon_21020011","weapon_21020011","weapon_21020012","whiff"],
  "single_weapon":["w_sword","whiff"],
  "noise_frost":["w_sword","echo_glacio","thundering","whiff"],
  "cleanse":["w_sword","salt_tea","glasses","medical"],
  "fullhealth_support":["medical","flower","tea"]}
 var extras={}
 for name in extra:
  extras[name]=build(extra[name]);report.packs[name]={"cost":extra[name].reduce(func(sum,k):return sum+int(C.items[k].v75.cost),0),"bonds":P.bonds(inv,extras[name]),"items":extras[name].items}
 for pair in [["repeat_bell","single_bell"],["repeat_tianqui","single_tianqui"],["multi_weapon","single_weapon"],["noise_frost","cleanse"],["fullhealth_support","fullhealth_support"]]:
  var a=extras[pair[0]];var b=extras[pair[1]];var result=duel(a,b);var swap=duel(b,a)
  ck(result.winner==-swap.winner,"controlled probe symmetry "+str(pair))
  report.probes.append({"name":str(pair),"forward":summary(result),"reverse":summary(swap)})
  if pair[0]=="multi_weapon":ck(result.totals[0].stamina_wait_seconds>0 and result.totals[1].stamina_wait_seconds==0,"six weapon stamina pressure vs single weapon")
  if pair[0]=="fullhealth_support":
   ck(not result.events.any(func(e):return e.time<22 and e.kind in ["heal","star_trigger"]),"full health before22s pressure creates no effective heal or healing star")
   report.probes[-1].full_health_before22={"heal_events":result.events.filter(func(e):return e.time<22 and e.kind=="heal").size(),"star_events":result.events.filter(func(e):return e.time<22 and e.kind=="star_trigger").size(),"note":"22s onward HP pressure permits actual healing; full fight retained above"}
 for name in ["charge_wing","haste_flow","shield_break"]:
  for enemy in ["shield","no_shield"]:
   report.probes.append({"name":name+"_against_"+enemy,"forward":summary(duel(builds[name],extras[enemy])),"reverse":summary(duel(extras[enemy],builds[name]))})
 report.checks=checks;report.failures=failures
 var file=FileAccess.open("res://build/qa/gameplay-v75/checks/balance.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
 print("BALANCE_V75 ",checks," checks, ",failures.size()," failures;81 ordered route pairs,14 probes")
 quit(1 if not failures.is_empty() else 0)
