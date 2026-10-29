extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const B=preload("res://scripts/battle/battle.gd")
const C=preload("res://scripts/data/catalog.gd")
const FIX=preload("res://tests/fixtures/capacity_fixture_v111.gd")
var inv=I.new();var checks=0;var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func build(kinds:Array)->Dictionary:
 var r=inv.new_run("aemeath",19);r.round=8;r.bags=FIX.full_bags(inv);r.items=[];r.serial=200
 # Basic pockets for this resource test: no regional cooldown/power bonus.
 for bag in r.bags:
  if bag.kind=="travel":bag.kind="satchel"
 for kind in kinds:
  var piece=inv.make_piece(kind,"s%d"%r.items.size());var placed=inv.first_fit(piece,r.items,r.bags)
  ck(not placed.is_empty(),"resource case fits real acquired capacity")
  if not placed.is_empty():r.items.append(placed)
 r.primary=r.items[0].uid
 ck(inv.validate_run(r),"resource case is a valid playable inventory")
 return r
func measure(kinds:Array)->Dictionary:
 var battle=B.new();var run=build(kinds);var dummy=build(["w_sword"]);dummy.items=[]
 var before=run.duplicate(true);var ctx=battle.begin(run,dummy,19)
 for state in ctx.states:state.hp=10000;state.max_hp=10000
 var minimum=float(ctx.states[0].stamina)
 for tick in 300:
  battle.step(ctx,(tick+1)*.1);minimum=minf(minimum,ctx.states[0].stamina)
 var waits=ctx.events.filter(func(e):return e.side==0 and e.kind=="tired")
 ck(run==before,"resource simulation is read-only")
 return {"wait":ctx.totals[0].stamina_wait_seconds,"first":waits[0].time if not waits.is_empty() else -1,"damage":ctx.totals[0].damage,"minimum":minimum,"events":ctx.events}
func _initialize()->void:
 var battle=B.new();var run=build(["w_sword"]);var ctx=battle.begin(run,run,19)
 ck(is_equal_approx(ctx.states[0].stamina,8.0),"public endurance starts at eight")
 ctx.states[0].stamina=0;battle.step(ctx,.1)
 ck(is_equal_approx(ctx.states[0].stamina,.1),"public recovery is one per second")
 ctx.states[0].stamina=7.5;ctx.events=[];battle.resource(ctx,0,run.items[0],"stamina",4,.2)
 ck(is_equal_approx(ctx.states[0].stamina,8.0),"recovery cannot overfill the new cap")
 var recovery=ctx.events.filter(func(e):return e.kind=="stamina")
 ck(recovery.size()==1 and is_equal_approx(recovery[0].value,.5),"replay reports actual restored stamina")
 var frame=battle.frame(.2,ctx)
 ck(frame.sides[0].get("stamina_max",0)==8.0,"replay carries its own resource cap")
 var single=measure(["w_sword"]);var pair=measure(["w_sword","w_sword"])
 var multi=measure(["w_sword","w_sword","w_sword","whiff"])
 var supplied=measure(["w_sword","w_sword","w_sword","whiff","rations","soup"])
 ck(single.wait==0 and pair.wait==0,"ordinary early single/double swords can sustain")
 ck(multi.wait>0 and multi.first>6,"fast multiple weapons eventually require sustain without stalling opening")
 ck(supplied.wait<multi.wait and supplied.damage>multi.damage,"existing recovery and discount produce real sustained gains")
 ck(C.SIMULATION_VERSION=="resonance-v128","resource rebalance remains isolated from historical matchmaking versions")
 FileAccess.open("res://build/qa/feedback-v112/stamina-actual.json",FileAccess.WRITE).store_string(JSON.stringify({"single":single,"pair":pair,"multi":multi,"supplied":supplied},"\t"))
 print("STAMINA_V112 ",checks," checks, ",failures," failures");quit(1 if failures else 0)
