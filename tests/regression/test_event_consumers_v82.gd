extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
var game;var checks=0;var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():call_deferred("test")
func test():
 game=G.new();root.add_child(game);await process_frame;game.set_process(false);game.set_process_input(false)
 game.reset_slice();var r=game.run;r.bags=[];r.stash=[];r.serial=20
 for y in range(0,6,2):
  for x in range(0,8,2):r.bags.append(game.piece("pouch","b%d%d"%[x,y],x,y))
 r.items=[game.piece("discord","source",0,0),game.piece("w_sword","main",3,2),game.piece("whiff","echo",0,2)];r.primary="main"
 ck(game.inventory.validate_run(r),"real advancement fixture legal")
 game.opponent=r.duplicate(true)
 game.combat=game.B.new().simulate(r,game.opponent,21);r.phase="battle"
 var before=r.duplicate(true);var recorded=game.combat.duplicate(true)
 var events=game.combat.events.filter(func(e):return e.kind=="cooldown_advance" and e.side==0 and e.source_uid=="source" and float(e.value)>0)
 ck(not events.is_empty(),"simulation produces positive recipient advancement")
 if not events.is_empty():
  var total=events.reduce(func(sum,e):return sum+float(e.value),0.0)
  var rows=game._chase_summary_rows()
  ck(rows!=null and rows.any(func(row):return row.uid=="source" and is_equal_approx(float(row.advance),total)),"result reads actual advancement seconds")
  var ev=events[0];game.combat_time=float(ev.time);game.advance_cues=[]
  var settled=game._cooldown_progress(0,"main")
  var item=r.items[1];var cd=float(game.C.items[item.kind].cooldown)*(1.0-game.inventory.modifiers(item,r.items,r).speed)
  game._play_event(ev)
  var shown=game._cooldown_progress(0,"main")
  ck(is_equal_approx(shown,clampf(settled-float(ev.value)/cd,0,1)),"pending arrival uses event value without missing historical fields")
  game.advance_cues=[]
  game.flashes.clear()
  var noop=ev.duplicate(true);noop.value=0;noop.actual_value=0
  game._play_event(noop)
  ck(game.advance_cues.is_empty() and game.flashes.is_empty(),"zero advancement queues no arrival or item flash")
  game.advance_cues=[]
  var other_events=game.combat.events.filter(func(e):return e.kind=="cooldown_advance" and e.side==1 and float(e.value)>0)
  ck(not other_events.is_empty(),"opponent simulation emits the same contract")
  var opposing=other_events[0]
  game._play_event(opposing)
  ck(is_equal_approx(game._cooldown_progress(0,"main"),settled),"other side with same target UID cannot change player cooldown")
  game.advance_cues=[]
  ck(is_equal_approx(game._cooldown_progress(0,"main"),settled),"arrival restores snapshot cooldown progress")
 # Two real engine actions in one tick must accumulate.
 var engine=game.B.new();var ctx=engine.begin(r,game.opponent,21);ctx.events=[];ctx.progress[0].main=.2
 engine.advance_item(ctx,0,r.items[1],.3,0,r.items[0]);engine.advance_item(ctx,0,r.items[1],.4,0,r.items[0])
 var paired=ctx.events.filter(func(e):return e.kind=="cooldown_advance")
 ck(paired.size()==2 and is_equal_approx(paired[0].value+paired[1].value,.7),"same-tick producer retains both actual grants")
 var simulated=game.combat;game.combat={"events":paired,"frames":[engine.frame(0,ctx),engine.frame(.1,ctx)]};game.combat_time=0
 game.advance_cues=[];var settled=game._cooldown_progress(0,"main")
 for ev in paired:game._play_event(ev)
 var cd=engine.cooldown(ctx,0,r.items[1])
 ck(is_equal_approx(game._cooldown_progress(0,"main"),clampf(settled-.7/cd,0,1)),"same-tick animation subtracts both grants once")
 var rows=game._chase_summary_rows()
 ck(rows.size()==1 and is_equal_approx(rows[0].advance,.7),"same-tick summary sums actual grants")
 ctx.events=[];ctx.progress[0].main=.9
 engine.advance_item(ctx,0,r.items[1],1,0,r.items[0])
 var capped=ctx.events.filter(func(e):return e.kind=="cooldown_advance")
 ck(capped.size()==1 and is_equal_approx(capped[0].value,snappedf(.1*cd,.1)),"near-ready producer records capped seconds at event precision")
 game.combat.events=capped;rows=game._chase_summary_rows()
 ck(rows.size()==1 and is_equal_approx(rows[0].advance,.1*cd),"summary uses capped gain rather than requested seconds")
 game.combat=simulated;game.advance_cues=[]
 ck(r==before and game.combat==recorded,"all consumers leave run and battle recording unchanged")
 print("EVENT_CONSUMERS_V82 ",checks," checks, ",failures," failures")
 game.queue_free();await process_frame;quit(1 if failures else 0)
