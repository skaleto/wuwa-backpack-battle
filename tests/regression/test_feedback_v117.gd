extends SceneTree
const G=preload('res://tests/fixtures/travel_fixture_v64.gd')
var STAR:Variant=preload('res://scripts/ui/items/chibi_effect_star.gd').new()
var Q:Variant=preload('res://scripts/ui/items/item_quality.gd').new()
var checks=0
var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():
 root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true);call_deferred('test')
func test():
 ck(STAR.has_method('click_wave'),'click has its own expanding one-shot wave')
 ck(Q.has_method('surface_bands'),'rarity follows the artwork surface')
 if failures:print('FEEDBACK_V117 ',checks,' checks, ',failures,' failures');quit(1);return
 var first=STAR.click_wave(STAR.WAVE_DURATION*.05);var middle=STAR.click_wave(STAR.WAVE_DURATION*.37);var last=STAR.click_wave(STAR.WAVE_DURATION*.8)
 ck(first.scale<middle.scale and middle.scale<last.scale,'wave expands independently of item lift')
 ck(middle.alpha>last.alpha and last.alpha>0,'wave fades as it spreads')
 ck(STAR.click_wave(-1).alpha==0 and STAR.click_wave(2).alpha==0,'no ambient repeating halo')
 var g=G.new();root.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
 var item=g.run.items[0];var before=g.run.duplicate(true)
 g.dragging=item.duplicate(true);g.drag_origin='board';g._start_held_pose()
 ck(g._star_click_age(item,'board')==0,'grabbing starts one wave')
 g._process(.12);var elapsed=g._star_click_age(item,'board')
 g._open_item_details(item,'board')
 ck(g._star_click_age(item,'board')==elapsed,'release into details does not restart the wave')
 ck(g._star_click_age(item,'enemy')<0,'opponent with same uid cannot borrow wave')
 g._process(.8);ck(STAR.click_wave(g._star_click_age(item,'board')).alpha==0,'holding details settles')
 g._close_item_details();g.hovered={'origin':'board','item':item};g._process(.1)
 ck(STAR.click_wave(g._star_click_age(item,'board')).alpha==0,'hover does not restart')
 g.dragging=item.duplicate(true);g.drag_origin='board';g._start_held_pose()
 ck(g._star_click_age(item,'board')==0,'next physical press restarts once')
 g._clear_feedback();ck(g._star_click_age(item,'board')<0,'seeking/changing scene clears click feedback')
 for origin in ['board','enemy','shop','stash']:
  g._open_item_details(item,origin);g._process(.12)
  var model=g._item_star_snapshot(item,origin)
  ck(is_equal_approx(model.click_age,.12),'detail star diagram receives same click age '+origin)
  g._process(.8)
  ck(STAR.click_wave(g._item_star_snapshot(item,origin).click_age).alpha==0,'detail star diagram settles '+origin)
 ck(g.run==before,'visual gestures leave run unchanged')
 for kind in ['w_sword','satchel']:
  ck(Q.surface_bands(kind,Vector2(500,100),1).is_empty(),'low quality and bags stay quiet '+kind)
 for kind in ['heron','weapon_21020086']:
  var frames=[]
  for n in 30:
   var bands=Q.surface_bands(kind,Vector2(500,160),n*.2);frames.append(bands)
   ck(bands.size()<=16,'bounded surface draw count')
   ck(bands==Q.surface_bands(kind,Vector2(500,160),n*.2),'deterministic display time')
   for band in bands:ck(band.left>=0 and band.right<=500 and band.left<band.right,'band clipped to source texture')
  ck(frames.any(func(f):return not f.is_empty()),'high quality has moving surface light')
  ck(frames[0]!=frames[5] or frames[5]!=frames[10],'sweep changes with time')
 g.queue_free();await process_frame
 print('FEEDBACK_V117 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
