extends SceneTree
## Historical rules: use the exact V116 catalogue before intentional V124 redesigns.
const HISTORICAL=preload("res://tests/fixtures/catalog_fixture_v116.gd")
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const B=preload("res://scripts/battle/battle.gd")
const FILTERS=preload("res://scripts/battle/star_filters.gd")
const CHANGED=["weapon_21010045","weapon_21020016","weapon_21020036","weapon_21020045","weapon_21020046","weapon_21020056","weapon_21020076","weapon_21020086","weapon_21020096","weapon_21030016","weapon_21030066","weapon_21040026","weapon_21040036","weapon_21050045","weapon_21050046","weapon_21050096","weapon_21050116"]
var inv=I.new();var checks=0;var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func board(kind:String,partner_kind:String="whiff")->Dictionary:
 var r=inv.new_run("aemeath",19);r.items=[];r.stash=[];r.bags=[];r.primary="source"
 for y in range(0,6,2):
  for x in range(0,8,2):
   var bag=inv.make_piece("pouch","b%d%d"%[x,y]);bag.x=x;bag.y=y;r.bags.append(bag)
 var source=inv.make_piece(kind,"source");source.x=2;source.y=2;r.items.append(source)
 var partner=inv.make_piece(partner_kind,"partner")
 for turn in range(4):
  partner.rotation=turn
  for y in range(6):
   for x in range(8):
    partner.x=x;partner.y=y
    if inv.can_place(partner,r.items,r.bags) and inv.star_links(source,[source,partner],r).size()==1:
     r.items.append(partner);return r
 return r
func stars(events:Array,side:int=0)->Array:
 return events.filter(func(e):return e.kind=="star_trigger" and e.side==side and e.source_uid=="source")
func test_audit():
 var before=JSON.parse_string(FileAccess.get_file_as_string("res://data/compat/catalog-v93.json"));var count=0
 # V116 adjusts only declared footprints/star coordinates; the old combat
 # profiles and every non-revised identity field still compare exactly.
 before=preload("res://scripts/data/space_catalog_v116.gd").apply(before)
 for kind in C.items:
  var d=C.items[kind]
  if not C.is_tag(kind,"weapon") or int(d.rarity)!=5:continue
  count+=1;ck(not d.stars.is_empty(),"every Q5 has meaningful stars "+kind)
  ck(not FILTERS.for_kind(kind).is_empty(),"Q5 has a real eligibility category "+kind)
  for field in ["shape","price","damage","cooldown","stamina"]:
   ck(d.get(field)==before.items[kind].get(field),"preserves base "+kind+"/"+field)
  for field in ["damage","cd","stamina","shop_price","inputs"]:
   ck(d.v75.get(field)==before.items[kind].v75.get(field),"preserves profile "+kind+"/"+field)
  if kind not in CHANGED:ck(d==before.items[kind],"retains working Q5 identity "+kind)
 ck(count==42,"audit includes all 42 Q5 weapons")
 ck(C.items.weapon_21020076.stars.size()==4,"morning star has four echo positions")
 ck(C.items.weapon_21020045.stars.size()==4,"laser retains four weapon positions")
 ck(C.items.weapon_21020086.stars.size()==4,"frost branch has four weapon positions")
func test_actual_simulations():
 for kind in CHANGED:
  var category=FILTERS.for_kind(kind)
  var partner="spectro_coin" if "noise" in category else "turtle" if "heal" in category else "w_gauntlet" if "weapon" in category else "whiff"
  var r=board(kind,partner);ck(r.items.size()==2,"place real eligible partner "+kind)
  if r.items.size()!=2:continue
  var saved=r.duplicate(true);var enemy=inv.new_run("aemeath",31)
  var sim=B.new().simulate(r,enemy,31,true)
  ck(not stars(sim.events).is_empty(),"actual simulation fires Q5 star "+kind)
  for e in stars(sim.events):
   ck(e.trigger_uid==("source" if kind=="weapon_21020045" else "partner") and e.target_uid=="partner","star identifies exact root and partner "+kind)
   ck(e.get("beneficiary_uid","") in ["source","partner"],"star identifies beneficiary "+kind)
  var dark=r.duplicate(true);dark.items.resize(1)
  var alone=B.new().simulate(dark,enemy,31,false)
  ck(stars(alone.events).is_empty(),"no eligible partner gives no star effect "+kind)
  var wrong=r.duplicate(true)
  wrong.items[1]=inv.make_piece("tea","partner")
  wrong.items[1].x=r.items[1].x;wrong.items[1].y=r.items[1].y
  ck(inv.star_links(wrong.items[0],wrong.items,wrong).is_empty(),"wrong category cannot light a star "+kind)
  var unqualified=B.new().simulate(wrong,enemy,31,false)
  ck(stars(unqualified.events).is_empty(),"wrong category cannot execute a star "+kind)
  var swapped=B.new().simulate(enemy,r,31,true)
  ck(not stars(swapped.events,1).is_empty(),"same effect executes on opponent side "+kind)
  for turn in range(4):
   var piece=r.items[0].duplicate(true);piece.rotation=turn
   ck(inv.stars(piece).size()==C.items[kind].stars.size(),"rotation preserves authored stars "+kind)
   inv.star_links(piece,r.items,r)
  ck(r==saved,"queries and simulation leave inventory and RNG unchanged "+kind)
func test_prepared_attack():
 var r=board("weapon_21020076");var b=B.new();var ctx=b.begin(r,r)
 ck(r.items.size()==2,"morning star partner fixture")
 if r.items.size()!=2:return
 var source=r.items[0];var partner=r.items[1]
 ctx.states[0].charge=0;ctx.states[1].shield=100
 b.activate(ctx,0,partner,1);b.commit_pending(ctx,1)
 ck(stars(ctx.events).is_empty(),"one natural echo does not complete preparation")
 b.activate(ctx,0,partner,2);b.commit_pending(ctx,2)
 ck(stars(ctx.events).size()==1,"two natural echo attacks prepare once")
 ck(ctx.events.any(func(e):return e.kind=="combo_ready" and e.uid=="source" and e.get("effect","")=="prepare_attack"),"preparation has a visible readiness cue")
 var ready_count=stars(ctx.events).size()
 b.natural(ctx,0,partner,"attack",2)
 b.activate(ctx,0,partner,2.5,false,"derived");b.commit_pending(ctx,2.5)
 ck(stars(ctx.events).size()==ready_count,"duplicate root and derived attack cannot prepare again")
 ctx.states[0].charge=0
 b.activate(ctx,0,source,3);b.commit_pending(ctx,3)
 var hit=ctx.events.filter(func(e):return e.kind=="attack" and e.uid=="source" and e.time==3)
 ck(hit.size()==1 and hit[0].hp_damage>0 and hit[0].get("prepared",false),"prepared natural attack pierces without global charge")
 ck(hit.size()==1 and not hit[0].charged,"own preparation is not mislabeled as shared charge")
 ck(is_equal_approx(float(ctx.states[0].charge),2),"prepared attack spends no global charge and keeps natural generation")
 b.activate(ctx,0,source,4);b.commit_pending(ctx,4)
 var next=ctx.events.filter(func(e):return e.kind=="attack" and e.uid=="source" and e.time==4)
 ck(next.size()==1 and not next[0].get("prepared",false) and next[0].hp_damage==0,"prepared reward is consumed exactly once")
 b.activate(ctx,0,partner,5);b.commit_pending(ctx,5)
 ck(stars(ctx.events).size()==ready_count,"no duplicate or derived carryover toward the next preparation")
 b.activate(ctx,0,partner,6);b.commit_pending(ctx,6);ctx.states[0].charge=6
 b.activate(ctx,0,source,7);b.commit_pending(ctx,7)
 var spent=ctx.events.filter(func(e):return e.kind=="charge" and e.uid=="source" and e.time==7 and e.value<0)
 ck(spent.size()==1 and spent[0].value==-6 and ctx.states[0].charge==2,"shared charge is spent once when both rewards coincide")
 var both=ctx.events.filter(func(e):return e.kind=="attack" and e.uid=="source" and e.time==7)
 ck(both.size()==1 and both[0].charged and both[0].get("prepared",false),"replay carries both independent attack facts")
 var sharing=r.duplicate(true);var consumer=inv.make_piece("w_gauntlet","consumer");consumer.x=0;consumer.y=5;sharing.items.append(consumer)
 var shared=b.begin(sharing,r)
 for t in [1,2]:b.activate(shared,0,partner,t);b.commit_pending(shared,t)
 shared.states[0].charge=6;shared.states[1].shield=100
 b.activate(shared,0,consumer,3);b.commit_pending(shared,3)
 ck(shared.states[0].charge<6,"another equal-status weapon consumes shared charge first")
 b.activate(shared,0,source,4);b.commit_pending(shared,4)
 var independent=shared.events.filter(func(e):return e.kind=="attack" and e.uid=="source" and e.time==4)
 ck(independent.size()==1 and independent[0].get("prepared",false) and not independent[0].charged and independent[0].hp_damage>0,"local preparation survives another weapon spending shared charge")
 var mirrored=b.begin(r,r)
 for side in range(2):
  mirrored.states[side].charge=0;mirrored.states[side].shield=100
 for t in [1,2]:
  for side in range(2):b.activate(mirrored,side,partner,t)
  b.commit_pending(mirrored,t)
 for side in range(2):b.activate(mirrored,side,source,3)
 b.commit_pending(mirrored,3)
 ck(mirrored.states[0].hp==mirrored.states[1].hp and mirrored.states[0].shield==mirrored.states[1].shield,"mirrored preparation and damage are symmetric")
func test_multicell_and_derived():
 var r=board("weapon_21020076","feilian")
 # One 2x2 echo covers two authored star cells.
 if r.items.size()!=2:ck(false,"multi-cell echo fixture");return
 r.items[1].x=2;r.items[1].y=3;r.items[1].rotation=0
 var points=inv.stars(r.items[0]);var covered=inv.occupied(r.items[1]).filter(func(p):return p in points)
 ck(covered.size()>=2 and inv.star_links(r.items[0],r.items,r).size()==1,"one UID spanning multiple cells counts once")
 var b=B.new();var ctx=b.begin(r,r);b.activate(ctx,0,r.items[1],1);b.commit_pending(ctx,1)
 ck(stars(ctx.events).is_empty(),"multi-segment echo is one natural activation")
 b.activate(ctx,0,r.items[1],2);b.commit_pending(ctx,2)
 ck(stars(ctx.events).size()==1,"second multi-segment activation prepares once")
 var frost=board("weapon_21020086","w_sword")
 if frost.items.size()!=2:ck(false,"frost partner fixture");return
 ctx=b.begin(frost,frost);ctx.states[1].frost=4
 for t in [1,2,3]:b.activate(ctx,0,frost.items[1],t);b.commit_pending(ctx,t)
 ck(ctx.events.any(func(e):return e.kind=="freeze" and e.uid=="source"),"frost star pushes actual enemy into freeze")
 ck(ctx.events.size()<100,"derived freeze cannot create an unbounded attack loop")
func test_laser():
 var r=board("weapon_21020045","w_sword")
 if r.items.size()!=2:ck(false,"laser partner fixture");return
 var b=B.new();var ctx=b.begin(r,r)
 for t in [1,2,3]:b.activate(ctx,0,r.items[0],t);b.commit_pending(ctx,t)
 ctx.progress[0].partner=0.1
 b.activate(ctx,0,r.items[0],4);b.commit_pending(ctx,4)
 var advance=ctx.events.filter(func(e):return e.kind=="cooldown_advance" and e.time==4 and e.source_uid=="source" and e.target_uid=="partner")
 ck(advance.size()==1 and is_equal_approx(float(advance[0].value),0.4),"laser enhanced strike advances a real partner by 0.4 seconds")
 ck(stars(ctx.events).size()==1,"laser collaboration emits a real star")
 var exact=stars(ctx.events)[0] if not stars(ctx.events).is_empty() else {}
 ck(exact.get("trigger_uid","")=="source" and exact.get("target_uid","")=="partner" and exact.get("beneficiary_uid","")=="partner","own-burst feedback separates root source from partner recipient")
func test_no_false_feedback():
 var b=B.new();var r=board("weapon_21020086","w_sword")
 if r.items.size()!=2:return
 var ctx=b.begin(r,r)
 ctx.states[1].frost=4
 # A previously planned application freezes first. The star's pending frost
 # then meets actual immunity and must not be reported as a successful link.
 ctx.pending.append({"side":0,"actions":[{"type":"frost","value":1,"item":r.items[1],"ordinary":false,"kind":"derived"}]})
 for t in [1,2,3]:b.natural(ctx,0,r.items[1],"attack",t)
 b.commit_pending(ctx,3)
 ck(stars(ctx.events).is_empty(),"pending frost blocked by earlier freeze has no false star")
 ck(int(b.own(ctx,0,r.items[0]).card_count)==3,"failed queued frost preserves its completed natural-attack count")
 ck(float(ctx.icd[0].get("weapon_21020086:card_star",-100))<6.7,"failed queued frost cannot consume its same-kind interval")
 b.natural(ctx,0,r.items[1],"attack",6.7)
 b.natural(ctx,0,r.items[1],"attack",6.8)
 b.natural(ctx,0,r.items[1],"attack",6.9)
 b.commit_pending(ctx,6.9)
 ck(ctx.states[1].frost==1 and stars(ctx.events).size()==1,"first valid root after immunity retries once without rebuilding the lost count")
 ck(int(b.own(ctx,0,r.items[0]).card_count)==0 and is_equal_approx(float(ctx.icd[0].get("weapon_21020086:card_star",0)),11.9),"only successful commit consumes count and starts interval")
 b.natural(ctx,0,r.items[1],"attack",7.0);b.natural(ctx,0,r.items[1],"attack",7.1);b.natural(ctx,0,r.items[1],"attack",7.2);b.commit_pending(ctx,7.2)
 ck(ctx.states[1].frost==1 and stars(ctx.events).size()==1,"successful queued effect still enforces the same-kind interval")
 ctx=b.begin(r,r);ctx.states[1].frost_immune_until=10
 for t in [1,2,3]:b.natural(ctx,0,r.items[1],"attack",t)
 b.commit_pending(ctx,3)
 ck(stars(ctx.events).is_empty(),"known frost immunity has no false star")
 var heal=board("weapon_21020046","turtle")
 if heal.items.size()==2:
  ctx=b.begin(heal,heal);b.support_heal(ctx,0,heal.items[1],4,1)
  ck(stars(ctx.events).is_empty(),"full-health healing does not activate healing stars")
 var laser=board("weapon_21020045","w_sword")
 if laser.items.size()==2:
  ctx=b.begin(laser,laser);ctx.progress[0].partner=1
  b.natural(ctx,0,laser.items[0],"attack",1,{"burst":true})
  ck(stars(ctx.events).is_empty(),"already-ready partner cannot produce fake advancement feedback")
func test_applied_then_cleansed_feedback():
 var b=B.new();var r=board("weapon_21040036");var enemy=board("w_sword")
 enemy.items=[inv.make_piece("revive","revive")]
 var ctx=b.begin(r,enemy)
 b.natural(ctx,0,r.items[1],"attack",1);b.natural(ctx,0,r.items[1],"attack",2);b.commit_pending(ctx,2)
 ck(ctx.states[1].noise==0,"enemy supply immediately cleanses the newly applied noise")
 ck(ctx.events.any(func(e):return e.kind=="noise" and e.side==0 and e.uid=="source" and e.value==1),"the star actually applied one noise before cleansing")
 ck(ctx.events.any(func(e):return e.kind=="supply" and e.side==1 and e.uid=="revive"),"the real application triggers the enemy supply")
 ck(stars(ctx.events).size()==1 and stars(ctx.events)[0].trigger_uid=="partner","later cleansing cannot erase the successful star feedback")
 ck(int(b.own(ctx,0,r.items[0]).card_count)==0 and is_equal_approx(float(ctx.icd[0].get("weapon_21040036:card_star",0)),7),"applied-then-cleansed noise consumes its successful count and interval")
func _initialize():
 var saved_catalogue=HISTORICAL.apply()
 test_audit();test_actual_simulations();test_prepared_attack();test_multicell_and_derived();test_laser();test_no_false_feedback();test_applied_then_cleansed_feedback()
 HISTORICAL.restore(saved_catalogue)
 print("HIGH_TIER_STARS_V101 [historical V116 catalogue] ",checks," checks, ",failures," failures");quit(1 if failures else 0)
