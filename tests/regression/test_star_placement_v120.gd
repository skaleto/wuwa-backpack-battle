extends SceneTree
const G=preload('res://tests/fixtures/travel_fixture_v64.gd')
const CAP=preload('res://tests/fixtures/capacity_fixture_v111.gd')
var checks=0
var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():
 root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true);call_deferred('test')
func test():
 var g=G.new();root.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
 ck(g.has_method('_placement_star_snapshot'),'placement uses real star projections')
 ck(g.Q_STAR.new().has_method('core_motion'),'star core has independent motion')
 if failures:
  g.queue_free();await process_frame;print('STAR_PLACEMENT_V120 ',checks,' checks, ',failures,' failures');quit(1);return
 var star=g.Q_STAR
 ck(star.core_motion(.12,0)!=star.core_motion(.12,3),'stars do not move as one flat layer')
 ck(star.core_motion(-1,0).scale==Vector2.ONE and star.core_motion(2,0).scale==Vector2.ONE,'independent motion settles and never loops')
 g.run=g.inventory.new_run('aemeath',120);g.run.bags=CAP.full_bags(g.inventory);g.run.serial=40;g.run.shop=[{},{},{},{},{},{}];g.run.stash=[]
 var source=g.piece('crew_pulse_grip','i1',1,1);var target=g.piece('w_sword','i2',4,4)
 g.run.items=[source,target];g.run.primary='i2'
 ck(g.inventory.validate_run(g.run),'legal placement fixture')
 var original=g.run.duplicate(true);var empty=g._placement_star_snapshot()
 ck(empty.is_empty() and g.run==original,'no false active stars in initial snapshot')
 target=target.duplicate(true);target.x=2;target.y=1
 var plan=g.inventory.plan_place(g.run,target)
 ck(plan.ok,'placing a weapon into grip star is legal')
 ck(g.placement_stars.pulses.is_empty(),'preview cannot play success')
 ck(g._commit_preparation(plan).ok,'real placement commits')
 var pulses=g._placement_star_markers()
 ck(pulses.size()==1 and pulses[0].source_uid=='i1' and pulses[0].target_uid=='i2','new incoming relationship lights source star')
 ck(pulses[0].cell==Vector2i(2,1),'lit star stays centered on matched slot')
 var snapshot=g.run.duplicate(true);g.placement_stars.update(.2)
 ck(g._placement_star_markers()[0].age>0 and g.run==snapshot,'animation has its own clock and no gameplay writes')
 var count=g.placement_stars.pulses.size();var age=g.placement_stars.pulses[0].age
 ck(g._commit_preparation(g.inventory.plan_place(g.run,target)).ok,'same position accepted')
 ck(g.placement_stars.pulses.size()==count and g.placement_stars.pulses[0].age==age,'unchanged placement does not replay pulse')
 var invalid=target.duplicate(true);invalid.x=-9
 ck(not g._commit_preparation(g.inventory.plan_place(g.run,invalid)).ok,'invalid placement rejected')
 ck(g.run==snapshot and g.placement_stars.pulses[0].age==age,'failed placement has no new success feedback')
 ck(g._commit_preparation(g.inventory.plan_stash(g.run,target)).ok,'target can move to storage')
 ck(g._placement_star_markers().is_empty(),'removed target cannot leave stale light')
 target=g.inventory.find_piece(g.run,'i2').duplicate(true);target.x=2;target.y=1
 ck(g._commit_preparation(g.inventory.plan_place(g.run,target)).ok,'stored target reconnects')
 ck(g._placement_star_markers().size()==1,'reconnection emits once')
 g.placement_stars.update(2)
 ck(g._placement_star_markers().is_empty(),'placement feedback disappears without hover')
 g._clear_feedback();ck(g.placement_stars.pulses.is_empty(),'scene transition clears placement feedback')
 # Shared projection, rotation and multicell target identity stay authoritative.
 var Feedback=preload('res://scripts/ui/items/star_feedback.gd')
 var f=preload('res://scripts/ui/items/placement_star_feedback.gd').new()
 var projected=Feedback.markers([Vector2i(2,2),Vector2i(3,2)],[{'uid':'wide','cells':[Vector2i(2,2),Vector2i(3,2)]}],64)
 var facts=[]
 for marker in projected:
  if marker.state=='lit':
   marker.source_uid='origin';facts.append(marker)
 var saved_facts=facts.duplicate(true);f.record([],facts)
 ck(f.markers().size()==1,'multicell target creates one lit incoming star')
 ck(facts==saved_facts,'pulse recording does not mutate projected facts')
 var second=facts[0].duplicate(true);second.source_uid='other'
 f.record(facts,facts+[second]);ck(f.pulses.size()==2 and f.markers().size()==1,'shared cell deduplicates display without changing relationships')
 f.record(facts+[second],[]);ck(f.pulses.is_empty(),'displaced sources cannot leave stale activation')
 # A real purchase follows the same commit path; an unrelated material never lights.
 g.run=g.inventory.new_run('aemeath',120);g.run.bags=CAP.full_bags(g.inventory);g.run.serial=30;g.run.round=2;g.run.gold=50;g.run.items=[g.piece('crew_pulse_grip','i1',1,1)];g.run.stash=[];g.run.primary=''
 g.run.shop=[{'kind':'w_sword','locked':false},{'kind':'mat_41100013','locked':false},{},{},{},{}]
 ck(g.inventory.validate_run(g.run),'shop fixture respects material availability')
 var bought=g.inventory.make_piece('w_sword','preview');bought.x=2;bought.y=1
 var purchase=g._commit_preparation(g.inventory.plan_purchase_at(g.run,0,bought,'board'))
 ck(purchase.ok and g._placement_star_markers().size()==1,'successful shop drop lights real assigned UID')
 ck(not g._placement_star_markers().is_empty() and purchase.ok and g._placement_star_markers()[0].target_uid==purchase.value.uid,'purchase feedback uses committed UID, not preview UID')
 g.placement_stars.clear();var material=g.inventory.make_piece('mat_41100013','preview');material.x=1;material.y=2
 ck(g._commit_preparation(g.inventory.plan_purchase_at(g.run,1,material,'board')).ok,'nonmatching item purchase is legal')
 ck(g._placement_star_markers().is_empty(),'material on weapon-only star never flashes')

 # A synthesis consumes the pulse source through a different successful commit.
 g._clear_feedback();g.run=g.inventory.new_run('aemeath',120);g.run.round=2;g.run.bags=CAP.full_bags(g.inventory);g.run.serial=40;g.run.shop=[{},{},{},{},{},{}];g.run.stash=[]
 g.run.items=[g.piece('w_sword','i1',0,0),g.piece('heron','i2',4,4),g.piece('mat_43020011','i3',3,0)];g.run.primary='i1'
 ck(g.inventory.validate_run(g.run),'craft pulse fixture is legal')
 var echo=g.run.items[1].duplicate(true);echo.x=1;echo.y=1
 ck(g._commit_preparation(g.inventory.plan_place(g.run,echo)).ok and g._placement_star_markers().size()==1,'placement before craft has active star')
 var ready=g.FORGE.ready_options(g.run,g.inventory)
 ck(not ready.is_empty(),'real recipe can consume active source')
 if not ready.is_empty():
  var crafted=g.FORGE.commit_ready(g.run,ready[0],g.inventory)
  ck(crafted.ok,'craft commits without changing placement rules')
  if crafted.ok:g._play_craft_result(crafted)
  ck(g._placement_star_markers().is_empty(),'consumed source cannot leave a lit placement star')

 g.queue_free();await process_frame
 print('STAR_PLACEMENT_V120 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
