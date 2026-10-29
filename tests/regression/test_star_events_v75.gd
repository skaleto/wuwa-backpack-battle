extends SceneTree
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const B=preload("res://scripts/battle/battle.gd")
const P=preload("res://scripts/shop/practice_budget.gd")
class SilentFeedback extends "res://scripts/battle/battle.gd":
 func emit_star(_ctx:Dictionary,_side:int,_source:Dictionary,_trigger:Dictionary,_time:float)->void:pass
var inv=I.new();var checks=0;var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func fixture(kind):
 var r=inv.new_run("aemeath",19);r.items=[];r.stash=[];r.bags=[];r.serial=20
 for y in range(0,6,2):
  for x in range(0,8,2):
   var bag=inv.make_piece("pouch","b%d%d"%[x,y]);bag.x=x;bag.y=y;r.bags.append(bag)
 var source=inv.make_piece(kind,"source");var weapon=inv.make_piece("w_sword","main")
 source.x=2;source.y=2;r.items=[source]
 var targets=inv.stars(source)
 for point in targets:
  weapon.x=point.x;weapon.y=point.y
  if inv.can_place(weapon,r.items,r.bags) and inv.star_links(source,[source,weapon],r).size()==1:break
 r.items.append(weapon);r.primary="main"
 ck(inv.validate_run(r) and P.bonds(inv,r)>0,"legal linked fixture "+kind)
 return r
func natural_fixture(kind):
 var r=fixture("heron");r.items=[];r.primary="main"
 var source=inv.make_piece(kind,"source");var main=inv.make_piece("w_sword","main")
 var echo=inv.make_piece("whiff","echo");var other=inv.make_piece("zig","other")
 if kind=="discord":
  main.x=3;main.y=2;echo.y=2;other.x=7;other.y=5
 elif kind=="variation":
  main.x=3;echo.y=2;other.x=1;other.y=2
 else:
  main.x=2;main.y=3;echo.y=3;other.y=2
 r.items=[source,main,echo,other]
 ck(inv.validate_run(r),"natural fixture is legal "+kind)
 var links=inv.star_links(source,r.items,r)
 ck(links.any(func(i):return i.uid=="main") and links.any(func(i):return i.uid=="echo"),"natural fixture links recipient and trigger "+kind)
 return r
func test_natural_advances():
 for spec in [["discord",.5],["variation",.6],["echo_tianqui",.4]]:
  var kind=spec[0];var r=natural_fixture(kind);var b=B.new();var silent=SilentFeedback.new()
  var enemy=inv.new_run("aemeath",4);var ctx=b.begin(r,enemy);var quiet=silent.begin(r,enemy)
  ctx.progress[0].main=.2;quiet.progress[0].main=.2
  var sequence=[2,2] if kind=="discord" else [2,3,2] if kind=="variation" else [2,3]
  for index in sequence.size():
   b.natural(ctx,0,r.items[sequence[index]],"attack",index+1)
   silent.natural(quiet,0,r.items[sequence[index]],"attack",index+1)
  var advances=ctx.events.filter(func(e):return e.kind=="cooldown_advance" and e.target_uid=="main")
  ck(advances.size()==1 and advances[0].source_uid=="source","natural advancement has true source "+kind)
  ck(advances.size()==1 and absf(float(advances[0].value)-float(spec[1]))<.00001,"natural exact seconds "+kind)
  ck(absf(float(ctx.progress[0].main)-(.2+float(spec[1])/b.cooldown(ctx,0,r.items[1])))<.00001,"natural exact progress "+kind)
  ck(ctx.events.filter(func(e):return e.kind=="star_trigger" and e.source_uid=="source" and e.target_uid=="main").size()==1,"natural recipient receives one star "+kind)
  ck(ctx.progress==quiet.progress and ctx.timers==quiet.timers and ctx.states==quiet.states and ctx.totals==quiet.totals,"natural feedback changes no numerical state "+kind)
 # Discord's legal no-primary fallback still advances itself without self-star feedback.
 var r=natural_fixture("discord");r.items.remove_at(1);r.primary=""
 var b=B.new();var ctx=b.begin(r,inv.new_run("aemeath",4));ctx.progress[0].source=.2
 ck(inv.validate_run(r),"discord fallback legal")
 b.natural(ctx,0,r.items[1],"attack",1);b.natural(ctx,0,r.items[1],"attack",2)
 ck(absf(float(ctx.progress[0].source)-(.2+.25/b.cooldown(ctx,0,r.items[0])))<.00001,"discord fallback exact quarter second")
 ck(not ctx.events.any(func(e):return e.kind=="star_trigger" and e.source_uid==e.target_uid),"discord fallback creates no self star")
func _initialize():
 test_natural_advances()
 for kind in ["heron","feilian","cyan_heron"]:
  var r=fixture(kind);var enemy=inv.new_run("aemeath",31);var before=r.duplicate(true)
  var result=B.new().simulate(r,enemy,31,true)
  var quiet=SilentFeedback.new().simulate(r,enemy,31,true)
  ck(result.totals==quiet.totals and result.frames==quiet.frames and result.winner==quiet.winner and result.duration==quiet.duration,"feedback preserves damage clocks and outcome "+kind)
  var stars=result.events.filter(func(e):return e.kind=="star_trigger" and e.source_uid=="source" and e.target_uid=="main")
  ck(not stars.is_empty(),"actual grant publishes both endpoints "+kind)
  var keys={}
  for e in result.events:
   if e.kind!="star_trigger":continue
   var key=str(e.side)+":"+e.source_uid+":"+e.target_uid+":"+str(e.time)
   ck(not keys.has(key),"no duplicate star feedback");keys[key]=true
  var moved=r.items[1].duplicate(true);moved.x=0;moved.y=5
  ck(inv.place(r,moved) and P.bonds(inv,r)==0,"legal link removed")
  result=B.new().simulate(r,enemy,31,false)
  ck(not result.events.any(func(e):return e.kind=="star_trigger" and e.source_uid=="source"),"unlinked source no false event "+kind)
  ck(before.items[0]==r.items[0],"only target moved")
 var b=B.new();var r=fixture("heron");var source=r.items[0];var target=r.items[1];var ctx=b.begin(r,inv.new_run("aemeath",4))
 ck(not ctx.events.any(func(e):return e.kind=="star_trigger" and e.uid=="source"),"unmet own activation has no early star")
 b.buff(ctx,0,source,source,"flat",5,1)
 ck(not ctx.events.any(func(e):return e.kind=="star_trigger"),"self buff is not star feedback")
 b.buff(ctx,0,target,source,"flat",5,2)
 b.emit_star(ctx,0,source,target,2)
 ck(ctx.events.filter(func(e):return e.kind=="star_trigger" and e.time==2).size()==1,"grant plus existing fired path deduplicated")
 ctx.progress[0][target.uid]=0.2
 b.advance_item(ctx,0,target,.3,3,source)
 ck(ctx.events.any(func(e):return e.kind=="star_trigger" and e.time==3 and e.target_uid=="main"),"direct legal progression publishes target")
 var count=ctx.events.filter(func(e):return e.kind=="star_trigger").size()
 ctx.progress[0][target.uid]=1
 b.advance_item(ctx,0,target,.3,4,source)
 ck(ctx.events.filter(func(e):return e.kind=="star_trigger").size()==count,"saturated clock has no false successful advance")
 print("STAR_EVENTS_V75 ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
