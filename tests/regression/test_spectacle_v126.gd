extends SceneTree
const G=preload('res://tests/fixtures/travel_fixture_v64.gd')
const V=preload('res://scripts/ui/battle/combat_vfx.gd')
class EffectsProbe extends Node2D:
 var clock=0.0
 func _draw():
  var kinds=['sword','broadblade','gauntlet','pistol','rectifier','echo']
  var fx=preload('res://scripts/ui/battle/combat_vfx.gd')
  for n in 6:
   for side in 2:
    var at=Vector2(120+n*215,280+side*320)
    fx.paper_impact(self,{'position':at,'side':side,'weapon':kinds[n],'color':Color.CYAN,'strong':true,'age':clock,'duration':.68})
    if clock<.3:fx.projectile(self,{'weapon':kinds[n],'life':.3-clock,'color':Color.CYAN,'strong':true},at-Vector2(30,90),at)
var checks=0
var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():
 root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true);call_deferred('run_tests')
func run_tests():
 var viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var g=G.new();viewport.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
 g.screen='camp';g.saved={};g.camp_age=3;g.mouse=Vector2.ZERO
 g.queue_redraw();await process_frame;RenderingServer.force_draw(true);await process_frame
 if DisplayServer.get_name()!='headless':
  ck(g.buttons.filter(func(b):return str(b.action).begins_with('pool_')).is_empty(),'opening exposes no pool selector')
 # A stale UI action cannot put a new run in a different catalogue.
 g._action('pool_focused')
 if DisplayServer.get_name()!='headless':
  for down in [true,false]:
   var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=g.ACTION_BUTTON.START.get_center();g._input(event)
 else:g._action('start')
 ck(g.screen=='game','start remains reachable through real input')
 ck(g.run.pool_mode=='full','every new UI run uses full pool')
 var state=g.run.duplicate(true)
 var renderer=V.new()
 ck(renderer.has_method('flight_position'),'family-specific travel geometry available')
 if renderer.has_method('flight_position'):
  for kind in ['sword','broadblade','gauntlet','pistol','rectifier','echo']:
   var a=Vector2(220,700);var b=Vector2(1100,280)
   ck(renderer.call('flight_position',kind,a,b,0).is_equal_approx(a),'flight begins at item '+kind)
   ck(renderer.call('flight_position',kind,a,b,1).is_equal_approx(b),'flight arrives at actual impact '+kind)
   for n in 11:
    var p=n/10.0;var left=renderer.call('flight_position',kind,a,b,p);var right=renderer.call('flight_position',kind,Vector2(1440-a.x,a.y),Vector2(1440-b.x,b.y),p)
    ck(left.is_finite() and right.is_finite() and is_equal_approx(left.x,1440-right.x) and is_equal_approx(left.y,right.y),'fair mirrored paths '+kind)
  ck(renderer.call('flight_position','pistol',Vector2.ZERO,Vector2(100,0),.5)==Vector2(50,0),'gun tracer travels straight')
  ck(renderer.call('flight_position','rectifier',Vector2.ZERO,Vector2(100,0),.5).y<0,'energy bolt has its own arc')
 seed(15626);var expected=randf();seed(15626)
 for n in 60:renderer.spawn(Vector2(600,300),n%2,['sword','broadblade','gauntlet','pistol','rectifier','echo'][n%6],Color.CYAN,n%3==0)
 ck(renderer.impacts.size()<=18,'impact count bounded under burst')
 ck(randf()==expected,'effects do not consume simulation RNG')
 var frozen=renderer.impacts.duplicate(true);renderer.update(0)
 ck(renderer.impacts==frozen,'paused impact clock frozen')
 renderer.update(.18);ck(not renderer.impacts.is_empty(),'impact has readable follow-through')
 renderer.update(1);ck(renderer.impacts.is_empty(),'all transient effects expire')
 ck(g.run==state,'effect state never mutates run')
 renderer.clear();ck(renderer.impacts.is_empty(),'seek reset clears effects')
 if DisplayServer.get_name()!='headless':
  g.visible=false
  var probe=EffectsProbe.new();viewport.add_child(probe)
  # Real CanvasItem calls cover the compressed first frame and near-expiry
  # meshes; runner treats native triangulation errors as failures.
  for n in 40:
   probe.clock=n*.018;probe.queue_redraw();await process_frame;RenderingServer.force_draw(true);await process_frame
  probe.queue_free();await process_frame
 g.queue_free();await process_frame
 print('SPECTACLE_V126 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
