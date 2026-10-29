extends SceneTree
const OUT='res://build/qa/feedback-v120/'
class Probe extends 'res://tests/fixtures/travel_fixture_v64.gd':
 var timings={}
 var enabled=false
 var frame_draw_us=0
 func account(key:String,start:int)->void:
  if enabled:timings[key]=float(timings.get(key,0))+Time.get_ticks_usec()-start
 func _draw()->void:
  var start=Time.get_ticks_usec();super._draw();frame_draw_us=Time.get_ticks_usec()-start;account('draw',start)
 func _draw_board(build:Dictionary,origin:Vector2,side:int)->void:
  var start=Time.get_ticks_usec();super._draw_board(build,origin,side);account('boards',start)
 func _draw_piece(item:Dictionary,origin:Vector2,alpha:float=1.0,side:int=-1,preview:bool=false,valid:bool=true)->void:
  var start=Time.get_ticks_usec();super._draw_piece(item,origin,alpha,side,preview,valid);account('pieces',start)
 func _draw_arena()->void:
  var start=Time.get_ticks_usec();super._draw_arena();account('arena',start)
 func _battle_star_markers(item:Dictionary,build:Dictionary,side:int)->Array:
  var start=Time.get_ticks_usec();var result=super._battle_star_markers(item,build,side);account('star_queries',start);return result
 func _ensure_icon(kind:String)->bool:
  var start=Time.get_ticks_usec();var result=super._ensure_icon(kind);account('icon_loads',start);return result
 func _draw_effects(front:bool=false)->void:
  var start=Time.get_ticks_usec();super._draw_effects(front);account('effects',start)
var g
func _initialize():
 root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true);call_deferred('test')
func test():
 if DisplayServer.get_name()=='headless':
  printerr('Native renderer required for performance measurement');quit(2);return
 var viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 g=Probe.new();viewport.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
 var case_path=OUT+'input/hsin-round10.json'
 var tag='final';var verify=false;var full=false
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with('--case='):case_path=arg.trim_prefix('--case=')
  if arg.begins_with('--tag='):tag=arg.trim_prefix('--tag=')
  if arg=='--verify':verify=true
  if arg=='--full':full=true
 var source_text=FileAccess.get_file_as_string(case_path)
 var source_hash=source_text.sha256_text()
 var data=JSON.parse_string(source_text)
 if not data is Dictionary or not data.has('combat') or not data.has('opponent') or data.combat.get('frames',[]).is_empty():
  printerr('Performance case needs a complete run with combat and opponent');quit(2);return
 # Exercise normal resume compatibility in the fixture's independent QA store.
 # Raw historical hashes can render, but cannot commit an ending in the current app.
 if not g.storage.write_json(g.storage.root_path+'run.json',data):quit(2);return
 g.run=g.storage.resume()
 # Resume normalizes JSON numeric fields to ints; compare their JSON values.
 if g.run.is_empty() or g.run.get('combat',{})!=data.combat or JSON.parse_string(JSON.stringify(g.run.items))!=data.items or JSON.parse_string(JSON.stringify(g.run.bags))!=data.bags or JSON.parse_string(JSON.stringify(g.run.opponent.items))!=data.opponent.items:
  printerr('Performance case migration must preserve both layouts and frozen combat');quit(2);return
 g.opponent=g.run.opponent.duplicate(true);g.combat=g.run.combat.duplicate(true);g.run.phase='battle';g.combat_time=0;g.event_cursor=0;g.speed=1;g.paused=false;g.battle_entry_age=1
 var record=g.combat.duplicate(true)
 var step=minf(1.0/30.0,float(g.combat.duration)*.8/240.0)
 for n in 30:
  g.queue_redraw();await process_frame
 g.enabled=true
 var draws=[];var steps=[];var frames=[];var loads=[];var calls=[];var samples=[]
 var sample_limit=maxi(240,int(ceil(float(g.combat.duration)/step))*3) if full else 240
 for n in sample_limit:
  var phase_before=str(g.run.phase)
  var started=Time.get_ticks_usec();g._process(step);steps.append((Time.get_ticks_usec()-started)/1000.0)
  var frame_start=Time.get_ticks_usec();await process_frame
  draws.append(g.frame_draw_us/1000.0);frames.append((Time.get_ticks_usec()-frame_start)/1000.0)
  loads.append(g.SKIN.cache_metrics().frame_loads);calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
  samples.append({'index':n,'time':g.combat_time,'phase_before':phase_before,'phase_after':g.run.phase,'draw_ms':draws[-1],'process_ms':steps[-1],'wall_frame_ms':frames[-1],'texture_loads':loads[-1],'draw_calls':calls[-1]})
  if full and g.run.phase!='battle' and g.pending_impacts.is_empty():break
 var sample_count=draws.size()
 var report={'tag':tag,'leader':g.run.leader,'round':g.run.round,'item_counts':[g.run.items.size(),g.opponent.items.size()],'frames':sample_count,'full_battle':full,'reached_end':g.run.phase!='battle' and g.pending_impacts.is_empty(),'battle_duration':g.combat.duration,'presentation_end':g._replay_end(),'events_played':g.event_cursor,'pending_impacts':g.pending_impacts.size(),'final_phase':g.run.phase,'duration_sampled':g.combat_time,'draw_ms':stats(draws),'process_ms':stats(steps),'wall_frame_ms':stats(frames),'texture_loads':stats(loads),'draw_calls':stats(calls),'inclusive_cpu_ms_per_frame':{},'record_unchanged':g.combat==record,'renderer':DisplayServer.get_name(),'case_sha256':source_hash,'input_unchanged':FileAccess.get_file_as_string(case_path).sha256_text()==source_hash,'step_seconds':step}
 report.slowest_draw_frames=slowest(samples,'draw_ms');report.slowest_update_frames=slowest(samples,'process_ms')
 for key in g.timings:report.inclusive_cpu_ms_per_frame[key]=g.timings[key]/float(sample_count)/1000.0
 var gates={'draw_mean_under_12ms':report.draw_ms.mean<12,'draw_p95_under_20ms':report.draw_ms.p95<20,'process_p95_under_2ms':report.process_ms.p95<2,'calls_mean_under_1600':report.draw_calls.mean<1600,'no_repeated_texture_thrash':report.texture_loads.mean<.1,'frozen_record':report.record_unchanged and report.input_unchanged}
 if full:gates.completed_battle=report.reached_end and g.event_cursor==g.combat.events.size() and g._current_frame()==record.frames[-1]
 report.gates=gates;report.passed=gates.values().all(func(v):return v)
 FileAccess.open(OUT+'performance-'+tag+'.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'))
 if DisplayServer.get_name()!='headless':
  RenderingServer.force_draw(true);await process_frame;viewport.get_texture().get_image().save_png(OUT+'native/battle-'+tag+'.png')
 print(JSON.stringify(report));g.queue_free();await process_frame;quit(1 if verify and not report.passed else 0)
func stats(values:Array)->Dictionary:
 values.sort();var sum=0.0
 for v in values:sum+=v
 return {'mean':sum/maxi(1,values.size()),'p95':values[mini(values.size()-1,int(values.size()*.95))],'max':values[-1]}

func slowest(samples:Array,metric:String)->Array:
 var ranked=samples.duplicate()
 ranked.sort_custom(func(a,b):return float(a[metric])>float(b[metric]))
 return ranked.slice(0,5)
