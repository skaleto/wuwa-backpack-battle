extends SceneTree
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const B=preload("res://scripts/battle/battle_v125.gd")
const NEW=["echo_porcelain","echo_anger","echo_sorrow","echo_gliding_sentry","echo_moth","echo_singilum","relic_diverter","relic_lunchbox"]
var inv=I.new()
var failures=0
var checks=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func build(specs:Array)->Dictionary:
 var r=inv.new_run("hsin",125);r.items=[];r.bags=[];r.primary=""
 for y in [0,2,4]:
  for x in [0,3,6]:
   var bag=inv.make_piece("satchel","b%d_%d"%[x,y]);bag.x=x;bag.y=y;r.bags.append(bag)
 for a in specs:
  var it=inv.make_piece(a[0],a[1]);it.x=a[2];it.y=a[3];r.items.append(it)
 return r
func _initialize():
 preload('res://tests/fixtures/catalog_fixture_v125.gd').apply()
 ck(C.v125_hash=='4c78d2a99b31442730432dcf7359fedf40f858baffea67b8f56ed06aa07e933a','frozen V125 hash')
 for kind in NEW:ck(C.items.has(kind),"new item "+kind)
 ck(is_equal_approx(C.profile("tuner").material_effect.period,6),"tuner revised period")
 ck(C.profile("cool_tea").healAmount>0 and C.profile("cool_tea").openingShield==0,"tea keeps healing instead of unrelated shield")
 if NEW.any(func(k):return not C.items.has(k)):
  finish();return
 var b=B.new();var enemy=build([["w_sword","enemy",0,0]])
 var r=build([["soup","soup",0,0],["spicy_meat","meat",2,0],["cool_tea","tea",4,0]])
 var ctx=b.begin(r,enemy,125);ctx.states[0].stamina=0;ctx.events=[]
 b.step(ctx,6)
 ck(ctx.events.any(func(e):return e.kind=="stamina" and e.uid=="soup" and e.value>0),"fish soup restores stamina on its cycle")
 ctx.states[0].stamina=0;b.step(ctx,12)
 ck(ctx.events.filter(func(e):return e.kind=="supply" and e.uid=="soup").size()==2,"cyclic supply can fire repeatedly")
 ck(r.items.size()==3,"provisions remain owned")
 # Charged and noncharged attacks use the same weapon; no owner/primary privilege.
 r=build([["relic_diverter","gear",1,1],["w_sword","blade",3,1]])
 ctx=b.begin(r,enemy,125);ctx.states[0].charge=3;ctx.events=[]
 b.activate(ctx,0,r.items[1],1);b.commit_pending(ctx,1)
 ck(ctx.events.any(func(e):return e.kind=="charge" and e.uid=="gear" and e.value<0),"diverter spends charge for its starred weapon")
 ctx=b.begin(r,enemy,125);ctx.states[0].charge=6;ctx.events=[]
 b.activate(ctx,0,r.items[1],1);b.commit_pending(ctx,1)
 ck(not ctx.events.any(func(e):return e.kind=="charge" and e.uid=="gear" and e.value<0),"diverter never steals full heavy attack")
 # Own natural echo cycle advances another echo, never itself.
 r=build([["echo_porcelain","porcelain",1,1],["zig","echo",2,1]])
 ctx=b.begin(r,enemy,125);ctx.progress[0].echo=0;ctx.events=[]
 b.activate(ctx,0,r.items[0],1);b.commit_pending(ctx,1)
 b.activate(ctx,0,r.items[0],2);b.commit_pending(ctx,2)
 ck(ctx.events.any(func(e):return e.kind=="cooldown_advance" and e.get("source_uid","")=="porcelain" and e.get("target_uid","")=="echo"),"porcelain advances real star echo")
 # A helper must be usable without a recipe, and multihits count once.
 r=build([["puppet","puppet",1,1],["dreamless","echo",3,1]])
 ctx=b.begin(r,enemy,125);ctx.events=[]
 b.activate(ctx,0,r.items[1],1);b.commit_pending(ctx,1)
 ck(not ctx.events.any(func(e):return e.uid=="puppet" and e.kind=="derived"),"one multihit attack is not three echo roots")
 b.activate(ctx,0,r.items[1],2);b.commit_pending(ctx,2)
 b.activate(ctx,0,r.items[1],3);b.commit_pending(ctx,3)
 ck(ctx.events.any(func(e):return e.uid=="puppet" and e.kind=="derived"),"puppet copies on the third natural echo root")
 # A ready charge reaction cannot be repeatedly stacked by duplicate publications.
 r=build([["echo_anger","anger",1,1],["w_sword","blade",2,1]])
 ctx=b.begin(r,enemy,125);ctx.events=[]
 b.natural(ctx,0,r.items[1],"charged",1);b.natural(ctx,0,r.items[1],"charged",1)
 ck(ctx.events.filter(func(e):return e.kind=="star_trigger" and e.get("source_uid","")=="anger").size()==1,"one charged root grants one reaction")
 # Ingredients for anti-shield crafting preserve their noise supply.
 ck(C.profile("answer").noisePeriod>0,"answer retains an independent noise source")
 finish()
func finish():
 print("ECOSYSTEM_V125 ",checks," checks, ",failures," failures");quit(1 if failures else 0)
