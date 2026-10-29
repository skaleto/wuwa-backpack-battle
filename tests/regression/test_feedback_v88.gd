extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const B=preload("res://scripts/battle/battle.gd")
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const P=preload("res://scripts/ui/items/item_presentation_v75.gd")
var inv=I.new()
var checks=0
var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func build(pieces:Array)->Dictionary:
 var r=inv.new_run("aemeath",19);r.items=[];r.bags=[];r.stash=[];r.shop=[{},{},{},{},{},{}];r.primary=""
 for y in [0,2,4]:
  for x in [0,3]:
   var p=inv.make_piece("satchel","bag_%d_%d"%[x,y]);p.x=x;p.y=y;r.bags.append(p)
 for s in pieces:
  var p=inv.make_piece(s[0],s[1]);p.x=s[2];p.y=s[3];r.items.append(p)
 return r
func stars(ctx,uid):return ctx.events.filter(func(e):return e.kind=="star_trigger" and int(e.side)==0 and e.get("source_uid","")==uid)
func _initialize():call_deferred("test")
func test():
 # Frozen prior rules; V125 replacements covered by ecosystem suites.
 preload("res://tests/fixtures/catalog_fixture_v124.gd").apply()
 var enemy=build([["w_sword","enemy",1,1]])
 var r=build([["w_rectifier","source",1,1],["whiff","partner",3,1]])
 var b=B.new();var c=b.begin(r,enemy,31);c.events=[];c.states[0].hp=c.states[0].max_hp
 b.natural(c,0,r.items[1],"attack",1)
 ck(stars(c,"source").is_empty(),"full-health healing does not flash or count a successful star")
 c.states[0].hp-=5;b.natural(c,0,r.items[1],"attack",6)
 ck(stars(c,"source").size()==1,"effective healing emits one star")
 r=build([["w_sword","source",1,1],["whiff","partner",2,2]])
 c=b.begin(r,enemy,31);c.events=[];c.progress[0].source=1.0
 b.natural(c,0,r.items[1],"attack",1)
 ck(stars(c,"source").is_empty(),"already-ready weapon does not flash for zero advance")
 c=b.begin(r,enemy,31);c.events=[]
 for t in [1.0,5.0,9.0]:b.natural(c,0,r.items[0],"attack",t)
 ck(stars(c,"partner").size()==1,"third partner attack grants exactly one star")
 ck(stars(c,"partner")[0].get("beneficiary_uid","")=="source","feedback records the actual buff recipient")
 var seen={}
 for e in stars(c,"partner"):
  var key=str(e.source_uid)+":"+str(e.trigger_uid)+":"+str(e.time)
  ck(not seen.has(key),"cross-item buff emits one star per effective grant");seen[key]=true
 r=build([["turtle","support",1,1]])
 c=b.begin(r,enemy,31)
 for n in range(1,61):b.step(c,n*.1)
 ck(not c.events.any(func(e):return e.kind=="attack" and e.side==0 and e.uid=="support"),"zero-damage support has no fake attack clock")
 var lines=P.effects("w_sword");var unique={}
 for line in lines:unique[line]=true
 ck(lines.size()==unique.size(),"star clause appears once")
 ck(not P.chips("cool_tea").any(func(chip):return chip[0] in ["haste","cleanse"]),"cool tea does not advertise effects it cannot grant")
 var g=G.new();root.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
 g.combat={"events":[{"kind":"star_trigger","source_uid":"same","trigger_uid":"p","side":0,"time":1},{"kind":"star_trigger","source_uid":"enemy","trigger_uid":"p","side":1,"time":1}]}
 ck(g._star_trigger_count()==1,"result counts only own side")
 g.queue_free();await process_frame
 print("FEEDBACK_V88 ",checks," checks, ",failures," failures");quit(1 if failures else 0)
