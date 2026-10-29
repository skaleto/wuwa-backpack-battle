extends SceneTree
const I=preload("res://tests/fixtures/recruitment_fixture_v113.gd")
const B=preload("res://scripts/battle/battle.gd")
const C=preload("res://scripts/data/catalog.gd")
const FIX=preload("res://tests/fixtures/capacity_fixture_v111.gd")
var inv=I.new();var checks=0;var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func build(kinds:Array,roles:Array=[])->Dictionary:
 var r=inv.new_run("aemeath",19);r.round=8;r.bags=FIX.full_bags(inv);r.items=[];r.serial=200
 r.roster=roles.duplicate();r.supports=roles.duplicate();r.recruited_round=roles.size()+1 if not roles.is_empty() else 0
 for kind in kinds:
  var p=inv.make_piece(kind,"i%d"%r.items.size());var fit=inv.first_fit(p,r.items,r.bags)
  ck(not fit.is_empty(),"fixture fits")
  if not fit.is_empty():r.items.append(fit)
 r.primary=r.items[0].uid if not r.items.is_empty() else ""
 return r
func _initialize()->void:
 var exists=ResourceLoader.exists("res://scripts/party/crew_abilities.gd")
 ck(exists,"crew ability rules exist independently of weapon unlocks")
 var r=build(["w_sword","w_sword","w_sword","whiff"],["role_1510"])
 var battle=B.new();var dummy=build([]);var ctx=battle.begin(r,dummy,11)
 var before=r.duplicate(true)
 for state in ctx.states:state.hp=10000;state.max_hp=10000
 for tick in 300:battle.step(ctx,(tick+1)*.1)
 var events=ctx.events.filter(func(e):return e.kind=="crew_trigger")
 ck(not events.is_empty(),"a real multi-weapon battle triggers recruited stamina partner")
 ck(ctx.events.any(func(e):return e.kind=="stamina" and str(e.uid).begins_with("crew:")),"stamina gains have crew attribution")
 ck(r==before,"crew battle does not mutate the inventory")
 r.supports=[];var inactive=battle.begin(r,dummy,11)
 for state in inactive.states:state.hp=10000;state.max_hp=10000
 for tick in 300:battle.step(inactive,(tick+1)*.1)
 ck(not inactive.events.any(func(e):return e.kind=="crew_trigger"),"bench has no passive effects")
 ck(ctx.totals[0].stamina_wait_seconds<inactive.totals[0].stamina_wait_seconds,"partner reduces real stamina waiting")
 if exists:
  var abilities=load("res://scripts/party/crew_abilities.gd")
  for role in C.roster:
   var spec=abilities.profile(role)
   ck(not spec.is_empty() and not str(spec.get("effect","")).is_empty(),"every role has explicit ability: "+role)
  ck(abilities.profile("role_1108").id=="frost_hunt","Feixue follows frost identity")
  var cases={"role_1105":["w_sword","whiff"],"role_1211":["w_sword"],"role_1405":["w_sword","bellborne"],"role_1503":["w_sword","turtle"],"role_1108":["w_sword","echo_glacio"],"role_1506":["w_sword","weapon_21020056"],"role_1410":["w_sword","whiff"]}
  for role in cases:
   var own=build(cases[role],[role]);var enemy=build(["w_sword","w_sword"])
   var context=battle.begin(own,enemy,22)
   for state in context.states:state.hp=9000;state.max_hp=10000
   for tick in 450:battle.step(context,(tick+1)*.1)
   var fired=context.events.filter(func(e):return e.kind=="crew_trigger" and e.role_id==role)
   ck(not fired.is_empty(),"real committed roots activate "+role)
   var previous=-100.0
   for e in fired:
    ck(e.side==0 and e.get("actual_value",e.value)>0,"crew success is positive and on the source team")
    ck(e.time-previous+.00001>=abilities.profile(role).period,"ability interval limits recursive/rapid feedback")
    previous=e.time
   var repeated=battle.begin(own,enemy,22)
   ck(repeated.crew_state[0][role].count==0 and repeated.crew_state[0][role].next==0,"crew counters reset each battle")
  # Stance attacks count once; healing/frost-only legacy activations are not attacks.
  for kind in ["violet","whiff_fast","turtle_clean","glacio_focus"]:
   var source=build([kind],["role_1410"]);var edge=battle.begin(source,build([]),1)
   edge.states[0].hp=500;edge.states[0].max_hp=1000
   for tick in 350:battle.step(edge,(tick+1)*.1)
   var attacks=kind in ["violet","whiff_fast"]
   ck(edge.events.any(func(e):return e.kind=="crew_trigger")==attacks,"actual attack classification: "+kind)
  var stance=build(["w_sword","violet"])
  ck(not abilities.ready("role_1105",stance),"stance echo has no advanceable cooldown")
  for pair in [["role_1105","whiff_fast"],["role_1503","turtle_clean"],["role_1405","rock_wall"],["role_1108","glacio_focus"]]:
   ck(abilities.ready(pair[0],build(["w_sword",pair[1]])),"legacy capability recognized: "+pair[1])
  var fake_charge=build(["w_sword","mat_43020021"]);fake_charge.leader="hsin"
  fake_charge.items[0].x=0;fake_charge.items[0].y=0;fake_charge.items[1].x=1;fake_charge.items[1].y=1
  ck(not abilities.supplies(fake_charge.items[1],"charge",fake_charge),"charged damage modifier does not create charge")
  ck(not abilities.ready("role_1211",fake_charge),"thematic charge tag is not a real charge source")
  ck(abilities.ready("role_1405",build(["salt_tea"])),"threshold shield supply is recognized")
  var empty_pouch=build([]);empty_pouch.bags=[inv.make_piece("pouch","p0")]
  ck(not abilities.ready("role_1405",empty_pouch),"empty shield pocket is not a shield source")
  var partial=build(["w_sword","whiff"],["role_1105"]);var partial_ctx=battle.begin(partial,build([]),2)
  partial_ctx.progress[0].i1=1-.01/battle.cooldown(partial_ctx,0,partial.items[1])
  partial_ctx.crew_state[0].role_1105.count=2
  battle.activate(partial_ctx,0,partial.items[0],1)
  battle.commit_pending(partial_ctx,1)
  preload("res://scripts/party/crew_combat.gd").process(battle,partial_ctx,1)
  ck(partial_ctx.crew_state[0].role_1105.next==5,"positive sub-0.05 cooldown benefit spends interval")
  var exact_advance=partial_ctx.events.filter(func(e):return e.kind=="cooldown_advance" and str(e.get("source_uid","")).begins_with("crew:"))[0]
  ck(is_equal_approx(preload("res://scripts/ui/battle/battle_feedback.gd").advance_seconds(exact_advance),.01),"animation projection shares actual cooldown precision")
  var partial_rows=preload("res://scripts/battle/battle_review.gd").rows({"events":partial_ctx.events},[partial,build([])],0,1)
  ck(partial_rows.any(func(row):return row.uid=="crew:role_1105" and is_equal_approx(row.advance,.01)),"review retains exact cooldown gain")
  # A full-health echo-healer has no successful trigger or spent interval.
  var quiet=build(["whiff"],["role_1410"]);var q=battle.begin(quiet,build([]),1)
  for tick in 180:battle.step(q,(tick+1)*.1)
  ck(not q.events.any(func(e):return e.kind=="crew_trigger"),"full health never produces a false healing success")
  ck(q.crew_state[0].role_1410.next==0,"zero benefit does not spend the support interval")
  # Mirrored teams with the same role IDs remain symmetric.
  var symmetric=build(["w_sword","whiff","turtle"],["role_1105","role_1410"])
  var result=battle.simulate(symmetric,symmetric,15)
  ck(result.winner==0,"two support teams resolve symmetrically")
  var review=preload("res://scripts/battle/battle_review.gd")
  var rows=review.rows({"events":ctx.events},[before,dummy],0,30)
  ck(rows.any(func(row):return row.uid=="crew:role_1510" and row.get("stamina",0)>0),"review measures actual crew stamina")
 print("CREW_COMBAT_V113 ",checks," checks, ",failures," failures");quit(1 if failures else 0)
