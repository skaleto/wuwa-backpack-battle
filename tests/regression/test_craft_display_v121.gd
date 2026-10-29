extends SceneTree
const CAP=preload('res://tests/fixtures/capacity_fixture_v111.gd')
class Probe extends 'res://tests/fixtures/travel_fixture_v64.gd':
 var builds=0
 func _build_craft_view_model()->Dictionary:
  builds+=1;return super._build_craft_view_model()
var checks=0
var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():
 root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true);call_deferred('test')
func test():
 var g=Probe.new();root.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
 g.run=g.inventory.new_run('aemeath',121);g.run.round=2;g.run.serial=40;g.run.bags=CAP.full_bags(g.inventory);g.run.items=[g.piece('w_sword','i1',0,0),g.piece('mat_43020011','i2',2,1)];g.run.primary='i1';g.run.stash=[];g.run.shop=[{},{},{},{},{},{}]
 ck(g.inventory.validate_run(g.run),'legal actual recipe fixture')
 var original=g.run.duplicate(true);g.builds=0;g.queue_redraw();await process_frame;await process_frame
 ck(g.builds==1,'all consumers of one native draw build one model')
 ck(not g._craft_frame_open and g._craft_frame_model.is_empty(),'draw cache cannot survive into input')
 ck(g.run==original,'painting leaves gameplay untouched')
 var before=g._craft_view_model();ck(before.entries.size()==1,'actual adjacent recipe visible')
 var remembered=before.duplicate(true)
 var item=g.run.items[1].duplicate(true);item.x=6;item.y=4
 ck(g._commit_preparation(g.inventory.plan_place(g.run,item)).ok,'actual move succeeds outside paint')
 var after=g._craft_view_model()
 ck(after.entries.is_empty() and after.key!=before.key,'next input query sees changed state immediately')
 ck(before==remembered,'new query cannot mutate prior read model')
 var value=g.run.duplicate(true);ck(not g.FORGE.commit_ready(g.run,before.entries[0],g.inventory).ok and g.run==value,'old confirmation still fails full authoritative validation')
 item.x=2;item.y=1;ck(g._commit_preparation(g.inventory.plan_place(g.run,item)).ok,'material returns beside weapon')
 var fresh=g._craft_view_model();ck(fresh.entries.size()==1,'return placement restores visible recipe immediately')
 var result=g.FORGE.commit_ready(g.run,fresh.entries[0],g.inventory)
 ck(result.ok,'fresh confirmation still consumes exact actual pair')
 ck(g._craft_view_model().entries.is_empty(),'craft consumption invalidates display cache')
 g.queue_free();await process_frame;print('CRAFT_DISPLAY_V121 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
