extends SceneTree
const CASE='res://tests/fixtures/data/feedback-v120/input/hsin-round10.json'
const OUT='res://build/qa/feedback-v121/'
class Probe extends 'res://tests/fixtures/travel_fixture_v64.gd':
 var draw_us=0
 var query_us=0
 var queries=0
 func _draw():
  query_us=0;queries=0
  var start=Time.get_ticks_usec();super._draw();draw_us=Time.get_ticks_usec()-start
 func _craft_view_model()->Dictionary:
  var start=Time.get_ticks_usec();var result=super._craft_view_model();query_us+=Time.get_ticks_usec()-start;queries+=1;return result
var g
var viewport
func _initialize():
 root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true);call_deferred('test')
func test():
 if DisplayServer.get_name()=='headless':quit(2);return
 var tag='before'
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with('--tag='):tag=arg.trim_prefix('--tag=')
 viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 g=Probe.new();viewport.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
 var data=JSON.parse_string(FileAccess.get_file_as_string(CASE));var frozen=data.duplicate(true)
 var report={'tag':tag,'screens':{},'operations':{}}
 for page in ['camp','shop','details','recipes','catalogue','result','review']:
  g.run=data.duplicate(true);g.opponent=g.run.opponent.duplicate(true);g.combat=g.run.combat.duplicate(true)
  g._clear_feedback();g.overlay='';g.motion.modal_value=0;g.motion.modal_target=0;g.transition_image=null;g.motion.transition_left=0;g.review.close();g.screen='game';g.run.phase='shop';g.combat_time=g._replay_end()
  if page in ['camp','shop','details','recipes','catalogue']:
   g.run.erase('combat');g.run.erase('opponent') # Normal advance() also removes battle evidence.
  match page:
   'camp':g.screen='camp'
   'details':g._open_item_details(g.run.items[0],'board')
   'recipes':g._action('forge')
   'catalogue':g.overlay='catalogue';g.motion.modal_value=1;g.motion.modal_target=1
   'result':g.run.phase='result'
   'review':g.run.phase='result';g._open_battle_review()
  var state=g.run.duplicate(true)
  for n in 15:g._process(1.0/60);await process_frame
  var draws=[];var queries=[];var counts=[];var calls=[];var updates=[]
  for n in 60:
   var start=Time.get_ticks_usec();g._process(1.0/60);updates.append((Time.get_ticks_usec()-start)/1000.0);await process_frame
   draws.append(g.draw_us/1000.0);queries.append(g.query_us/1000.0);counts.append(g.queries);calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
  report.screens[page]={'draw_ms':stats(draws),'query_ms':stats(queries),'query_count':stats(counts),'calls':stats(calls),'update_ms':stats(updates),'run_unchanged':state==g.run}
  if page in ['shop','details','recipes']:RenderingServer.force_draw(true);await process_frame;viewport.get_texture().get_image().save_png(OUT+'native/'+tag+'-'+page+'.png')
 g.review.close();g.overlay='';g.screen='game';g.run=data.duplicate(true);g.run.phase='battle';g.combat=data.combat.duplicate(true)
 var start=Time.get_ticks_usec();g._transition();report.operations.transition_ms=(Time.get_ticks_usec()-start)/1000.0
 start=Time.get_ticks_usec();var result=g._application().finish_replay(g.run);report.operations.result_commit_ms=(Time.get_ticks_usec()-start)/1000.0;report.result_ok=result.ok
 start=Time.get_ticks_usec();g.engine.simulate(data,data.opponent,int(data.seed));report.operations.simulation_ms=(Time.get_ticks_usec()-start)/1000.0
 report.case_unchanged=data==frozen
 FileAccess.open(OUT+'ui-'+tag+'.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'))
 print(JSON.stringify(report));g.queue_free();await process_frame;quit(0)
func stats(values:Array)->Dictionary:
 values.sort();var total=0.0
 for v in values:total+=v
 return {'mean':total/values.size(),'p95':values[int(values.size()*.95)],'max':values[-1]}
