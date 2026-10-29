extends "res://tests/regression/test_ecosystem_v125.gd"
const S=preload("res://scripts/storage/storage.gd")
const SHOP=preload("res://scripts/shop/shop_v75.gd")
const FAMILY=preload("res://scripts/shop/supply_policy_v125.gd")
func _initialize():
 preload('res://tests/fixtures/catalog_fixture_v125.gd').apply()
 var b=B.new();var enemy=build([["w_sword","enemy",0,0]])
 var r=build([["echo_sorrow","sorrow",1,1],["rocksteady","rock",2,1]])
 var ctx=b.begin(r,enemy,125);ctx.events=[]
 b.natural(ctx,0,r.items[1],"shield",1,{"amount":0})
 ck(not b.own(ctx,0,r.items[0]).get("eco_ready",false),"zero shield cannot prepare frost")
 b.natural(ctx,0,r.items[1],"shield",2,{"amount":2})
 ctx.states[1].frost_immune_until=20
 b.activate(ctx,0,r.items[0],3);b.commit_pending(ctx,3)
 ck(b.own(ctx,0,r.items[0]).get("eco_ready",false),"immune frost does not consume prepared control")
 ctx.states[1].frost_immune_until=0;b.activate(ctx,0,r.items[0],7);b.commit_pending(ctx,7)
 ck(ctx.states[1].frost==1 and not b.own(ctx,0,r.items[0]).eco_ready,"one frost for whole two-hit root")
 r=build([["echo_gliding_sentry","guard",1,1],["rocksteady","rock",3,1]])
 ctx=b.begin(r,enemy,125);ctx.events=[]
 b.natural(ctx,0,r.items[1],"shield",1,{"amount":2})
 var hp=ctx.states[0].hp
 var actions=[]
 for i in 6:actions.append({"type":"damage","value":2,"item":enemy.items[0],"ordinary":true,"kind":"attack"})
 ctx.pending.append({"side":1,"root_item":enemy.items[0],"actions":actions});b.commit_pending(ctx,2)
 ck(is_equal_approx(hp-ctx.states[0].hp,10),"parry reduces exactly two across a six-hit attack")
 b.commit_pending(ctx,2)
 ck(ctx.events.filter(func(e):return e.kind=="counter" and e.uid=="guard").size()==1,"parry counter once per natural root")
 ck(ctx.states[1].frost==1,"sentry retains sorrow control")
 var guards=ctx.events.filter(func(e):return e.kind=="guard")
 ck(guards.reduce(func(total,e):return total+e.actual_value,0.0)==2,"precise guard attribution recorded")
 ck(C.profile("echo_gliding_sentry").counter_damage==4 and C.profile("echo_gliding_sentry").star_period==6,"measured counter budget is four per six seconds")
 for weapon_kind in ["weapon_21030056","weapon_21010026","weapon_21020026"]:
  var damages=[]
  for connected in [false,true]:
   r=build([["answer","answer",1 if connected else 6,1],[weapon_kind,"weapon",1,3]])
   ctx=b.begin(r,enemy,125);ctx.events=[];ctx.states[1].shield=100
   b.apply_noise(ctx,0,r.items[0],1,0);ctx.states[0].charge=6;ctx.states[0].haste=3;b.own(ctx,0,r.items[1]).ready=true
   b.activate(ctx,0,r.items[1],1);b.commit_pending(ctx,1)
   var hits=ctx.events.filter(func(e):return e.uid=="weapon" and e.kind=="attack")
   damages.append(hits.reduce(func(total,e):return total+e.hp_damage,0.0))
  ck(damages[1]+.0001>=damages[0],"answer never weakens innate pierce "+weapon_kind)
  if weapon_kind!="weapon_21030056":ck(is_equal_approx(damages[1],4),"whole natural attack receives four pierce across fixed extra segments "+weapon_kind)
 for ward in [false,true]:
  r=build([["answer","answer",1,1],["w_sword","weapon",1,3]])
  var guarded=build([["echo_gliding_sentry","sentry",1,1],["rocksteady","rock",3,1]])
  ctx=b.begin(r,guarded,125);ctx.events=[];ctx.states[1].shield=100;b.apply_noise(ctx,0,r.items[0],1,0)
  b.own(ctx,1,guarded.items[0]).eco_ready=true
  if ward:ctx.team[1].ward=1;ctx.team[1].ward_until=10
  b.activate(ctx,0,r.items[1],1);b.commit_pending(ctx,1)
  var hits=ctx.events.filter(func(e):return e.uid=="weapon" and e.kind=="attack")
  var damage=hits.reduce(func(total,e):return total+e.hp_damage+e.absorbed,0.0)
  var bypass=hits.reduce(func(total,e):return total+e.hp_damage,0.0)
  ck(is_equal_approx(bypass,damage*.3),"pierce uses post-parry damage with ward="+str(ward))
 r=build([["echo_moth","moth",1,1],["w_sword","blade",3,1]])
 ctx=b.begin(r,enemy,125);ctx.events=[]
 b.apply_noise(ctx,0,r.items[0],3,0);var next=ctx.states[1].noise_next
 b.natural(ctx,0,r.items[1],"charged",1)
 b.activate(ctx,0,r.items[0],2);b.commit_pending(ctx,2)
 ck(ctx.events.filter(func(e):return e.uid=="moth" and e.kind=="derived").size()==1,"moth emits a single derived noise tick")
 ck(ctx.states[1].noise==4 and ctx.states[1].noise_next==next,"extra tick neither adds layers nor moves original timer")
 r=build([["relic_lunchbox","lunch",1,1],["soup","food",1,0],["cool_tea","tea",2,0]])
 ctx=b.begin(r,enemy,125);ctx.events=[]
 b.own(ctx,0,r.items[0]).material_next=12;ctx.icd[0]["relic_lunchbox:material_clock"]=12.0
 b.material_cycle(ctx,0,r.items[1],7,true);b.material_cycle(ctx,0,r.items[1],8,true)
 ck(b.own(ctx,0,r.items[0]).material_next==12,"same food twice cannot form varied meal")
 b.material_cycle(ctx,0,r.items[2],9,true)
 ck(b.own(ctx,0,r.items[0]).material_next==10,"two different foods advance lunchbox")
 ctx.states[0].stamina=0;ctx.time=9.9;b.step(ctx,10)
 ck(ctx.events.any(func(e):return e.uid=="lunch" and e.kind=="stamina" and e.actual_value>0),"advanced material clock really fires before old interval")
 r=build([["echo_porcelain","porcelain",1,1],["turtle","turtle",2,1]])
 ctx=b.begin(r,enemy,125);ctx.events=[]
 b.activate(ctx,0,r.items[0],1);b.activate(ctx,0,r.items[0],2)
 ck(is_equal_approx(b.own(ctx,0,r.items[1]).clocks.heal,3.6),"porcelain supports nonattacking echo clocks too")
 r=build([["aero_coin","coin",0,0],["soup","food",0,1]])
 ctx=b.begin(r,enemy,125);ctx.events=[]
 b.material_cycle(ctx,0,r.items[1],6,true);b.material_cycle(ctx,0,r.items[1],12,true)
 ck(ctx.events.filter(func(e):return e.uid=="coin" and e.kind=="haste").size()==1,"periodic supply preserves first activation reward exactly once")
 # Budget family probabilities remain constant despite adding alternatives.
 var old=FAMILY.shares(["whiff","zig","echo_glacio"])
 var expanded=FAMILY.shares(["whiff","echo_porcelain","zig","echo_anger","echo_glacio","echo_sorrow"])
 for pair in [["whiff","echo_porcelain"],["zig","echo_anger"],["echo_glacio","echo_sorrow"]]:ck(abs(old[pair[0]]-expanded[pair[0]]-expanded[pair[1]])<.000001,"family retains probability "+pair[0])
 r=inv.new_run_supply("aemeath",912,"full",125)
 ck(r.supply_version==125 and inv.validate_run(r),"current run is valid V125 supply")
 var legacy=inv.new_run_supply("aemeath",912,"full",122)
 for k in NEW:ck(not inv.shop_eligible(legacy,k),"legacy shelf excludes new ID "+k)
 for round_number in range(1,13):
  r.round=round_number
  for slot in 5:
   var dist=SHOP.distribution(r,slot,inv);var total=0.0
   for k in dist:total+=dist[k];ck(inv.shop_eligible(r,k),"shop only eligible items")
   ck(abs(total-1)<.000001,"normalized current shelf")
 ck(not inv.shop_eligible(r,"echo_singilum"),"terminal echo is crafted, never directly offered")
 r=inv.new_run_supply("aemeath",432,"full",122);r.catalogue_hash=C.v124_hash;r.simulation_version="resonance-v124"
 var frozen=r.duplicate(true);var storage=S.new("user://qa-ecosystem125/")
 var migrated=storage.migrate_v125(r)
 ck(not migrated.is_empty() and inv.validate_run(migrated),"exact previous hash migrates")
 ck(r==frozen and migrated.get("supply_version",0)==122 and migrated.seed==r.seed,"migration retains old RNG, supply, original input")
 ck(storage.migrate_v125(dict_hash(r,"unknown")).is_empty(),"unknown hash is not silently accepted")
 r.simulation_version="resonance-v113"
 ck(not storage.migrate_v125(r).is_empty(),"valid V124 saves retain earlier battle provenance")
 finish()
func dict_hash(r:Dictionary,value:String)->Dictionary:
 var copy=r.duplicate(true);copy.catalogue_hash=value;return copy
