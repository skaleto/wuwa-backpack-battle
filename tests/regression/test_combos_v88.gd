extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const B=preload("res://scripts/battle/battle.gd")
const C=preload("res://scripts/data/catalog.gd")
var inv=I.new()
var checks=0
var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func build(specs:Array)->Dictionary:
 var r=inv.new_run("aemeath",19);r.items=[];r.bags=[];r.stash=[];r.shop=[{},{},{},{},{},{}];r.primary=""
 for y in [0,2,4]:
  for x in [0,3]:
   var p=inv.make_piece("satchel","bag_%d_%d"%[x,y]);p.x=x;p.y=y;r.bags.append(p)
 for s in specs:
  var p=inv.make_piece(s[0],s[1]);p.x=s[2];p.y=s[3];r.items.append(p)
 return r
func damage20(a,enemy)->float:
 var b=B.new();var ctx=b.begin(a,enemy,31)
 for s in ctx.states:s.hp=9900;s.max_hp=10000
 for n in range(1,201):b.step(ctx,n*.1)
 return float(ctx.totals[0].damage)
func _initialize():
 # Frozen prior rules; V125 replacements covered by ecosystem suites.
 preload("res://tests/fixtures/catalog_fixture_v124.gd").apply()
 var enemy=build([["w_sword","enemy",1,1]])
 var b=B.new();var r=build([["weapon_21020024","blade",1,1]])
 var c=b.begin(r,enemy,31);c.events=[]
 for n in 2:b.activate(c,0,r.items[0],float(n+1));b.commit_pending(c,float(n+1))
 ck(not c.events.any(func(e):return e.kind=="derived" and e.side==0),"cadence does not pay before third attack")
 b.activate(c,0,r.items[0],3);b.commit_pending(c,3)
 ck(c.events.filter(func(e):return e.kind=="derived" and e.side==0 and is_equal_approx(e.value,6)).size()==1,"third natural attack pays one 6-damage echo")
 ck(b.own(c,0,r.items[0]).get("combo_0",-1)==0,"derived hit never increments its own counter")
 r=build([["weapon_21040064","guard",1,1]])
 c=b.begin(r,enemy,31);c.events=[];c.states[0].shield=0
 b.deal_v75_damage(c,1,enemy.items[0],2,1,true,"attack");b.commit_pending(c,1)
 ck(not c.events.any(func(e):return e.kind=="counter" and e.side==0),"unblocked damage cannot counter")
 c.states[0].shield=10
 b.deal_v75_damage(c,1,enemy.items[0],2,2,true,"attack");b.commit_pending(c,2)
 ck(not c.events.any(func(e):return e.kind=="counter" and e.side==0),"one shield block stores one pip")
 b.deal_v75_damage(c,1,enemy.items[0],2,3,true,"attack");b.commit_pending(c,3)
 ck(c.events.any(func(e):return e.kind=="counter" and e.side==0 and is_equal_approx(e.value,4)),"two actual blocks release counter")
 var before=c.events.size();b.deal_v75_damage(c,1,enemy.items[0],2,4,false,"counter");b.commit_pending(c,4)
 ck(not c.events.slice(before).any(func(e):return e.kind=="counter" and e.side==0),"counter never bounces into another counter")
 r=build([["w_gauntlet","fist",1,1],["echo_glacio","shield",1,2]])
 c=b.begin(r,enemy,31);c.events=[]
 b.natural(c,0,r.items[0],"attack",1);b.natural(c,0,r.items[0],"attack",2)
 ck(c.events.any(func(e):return e.kind=="shield" and e.side==0 and is_equal_approx(e.value,3)),"two star weapon attacks charge the shield")
 ck(b.own(c,0,r.items[0]).buffs.values().any(func(v):return v.type=="flat" and is_equal_approx(v.value,3)),"actual star shield prepares the fist's next strike")
 var linked=build([["w_sword","blade",1,1],["whiff","partner",2,2]])
 var output=build([["weapon_21020024","blade",1,1]])
 var next=build([["weapon_21020015","blade",0,1]])
 ck(damage20(output,enemy)>damage20(linked,enemy),"first sword craft beats its consumed linked pair over 20s")
 ck(damage20(next,enemy)>damage20(output,enemy),"second sword craft improves the self-sustaining cadence")
 print("COMBOS_V88 ",checks," checks, ",failures," failures");quit(1 if failures else 0)
