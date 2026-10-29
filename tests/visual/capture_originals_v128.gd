extends SceneTree
## Native render and real controller actions without front-window or user save access.
const OUT='res://build/qa/wuwa-items-v128/native/'
const C=preload('res://scripts/data/catalog.gd')
const CAP=preload('res://tests/fixtures/capacity_fixture_v111.gd')
const SPEC=preload('res://scripts/data/original_catalog_v128.gd')
var g
var viewport
var checks=0
var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():
 root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true);call_deferred('capture')
func shot(name):
 g.motion.modal_value=0 if g.overlay.is_empty() else 1;g.motion.modal_target=g.motion.modal_value;g.queue_redraw()
 await process_frame;RenderingServer.force_draw(true);await process_frame
 ck(viewport.get_texture().get_image().save_png(OUT+name+'.png')==OK,'capture '+name)
func button(p,down,id=MOUSE_BUTTON_LEFT):
 var e=InputEventMouseButton.new();e.position=p;e.button_index=id;e.pressed=down;g._input(e)
func move(p):
 var e=InputEventMouseMotion.new();e.position=p;g._input(e)
func empty_board():
 g.reset_slice();g.run.items=[];g.run.stash=[];g.run.primary='';g.run.bags=CAP.full_bags(g.inventory);g.run.gold=30;g.run.serial=200;g.run.round=7
 g.run.shop=[]
 for kind in ['mat_42310060','mat_42300020','mat_42500040','mat_41400054','mat_42300080','pouch']:g.run.shop.append({'kind':kind,'locked':false})
func fit(kind,uid):
 var p=g.inventory.first_fit(g.inventory.make_piece(kind,uid),g.run.items,g.run.bags)
 ck(not p.is_empty(),'fit '+kind)
 if not p.is_empty():g.run.items.append(p)
 return p
func capture():
 if DisplayServer.get_name()=='headless':quit(2);return
 DirAccess.make_dir_recursive_absolute(OUT)
 viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 g=preload('res://tests/fixtures/travel_fixture_v64.gd').new();viewport.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
 var kinds=SPEC.spec.new_items.keys()
 for page in 2:
  empty_board()
  for index in range(page*8,page*8+8):fit(kinds[index],'part'+str(index))
  fit('w_sword','weapon');fit('whiff','echo');g.run.primary='weapon'
  ck(g.inventory.validate_run(g.run),'valid original-item board '+str(page))
  var before=g.run.duplicate(true);await shot('01-items-page-'+str(page+1));ck(g.run==before,'drawing read-only')
  for index in [page*8,page*8+5,page*8+7]:
   g._open_item_details(g.inventory.find_piece(g.run,'part'+str(index)),'board');await shot('02-detail-'+kinds[index]);g._close_item_details()
 empty_board();fit('w_sword','weapon');g.run.primary='weapon'
 var before=g.run.duplicate(true);var start=g._offer_rect(0).position+Vector2(50,44);var at=g._board_to_screen(g.BOARD+Vector2(4.5,3.5)*g.CELL)
 button(start,true);move(at);button(at,true,MOUSE_BUTTON_RIGHT);button(at,false,MOUSE_BUTTON_RIGHT)
 ck(g.run==before,'held herb not purchased');await shot('03-herb-held-rotated');button(at,false)
 ck(g.run.items.any(func(p):return p.kind=='mat_42310060' and p.rotation==1) and g.run.gold==before.gold-C.profile('mat_42310060').cost,'rotated herb purchased only on drop');await shot('04-herb-bought')
 empty_board();fit('mat_42310030','herb');fit('daily_tea','drink');fit('mat_42310030','herb2')
 for recipe_id in ['W128-05','W128-06']:
  if g.fusion_view.active():g.fusion_view.finish()
  var row=SPEC.spec.recipes.filter(func(r):return r.id==recipe_id)[0]
  var base=g.run.items.filter(func(p):return p.kind==row.base)
  if not base.is_empty():g.FORGE.place_material(g.run,row.target,base[0].uid,row.materials[0],g.inventory,Callable(),recipe_id)
  await shot('05-ready-'+recipe_id)
  var entries=g.inline_craft.entries.filter(func(e):return e.recipe_id==recipe_id)
  ck(not entries.is_empty(),'native inline craft '+recipe_id)
  if entries.is_empty():continue
  var p=entries[0].rect.get_center();button(p,true);button(p,false)
  ck((g.run.items+g.run.stash).any(func(i):return i.kind==row.target),'actual craft produces '+row.target)
  for frame in 18:g._process(1.0/60)
  await shot('06-fusing-'+recipe_id);g.fusion_view.finish();await shot('07-crafted-'+recipe_id)
 ck((g.run.items+g.run.stash).any(func(i):return i.kind=='provision_clear_tea'),'two stages reach clear tea')
 empty_board()
 for kind in ['w_sword','w_broadblade','whiff','zig','mat_42310060','mat_42310070','mat_42300080','mat_42310080','mat_42310100','mat_42500040','mat_41400074','mat_41400054','provision_jinzhou_stew','provision_snow_lotus_pastry']:fit(kind,kind)
 g.run.primary='w_sword';ck(g.inventory.validate_run(g.run),'legal originals combat');g.opponent=g.inventory.snapshot(g.run,'v128-native','原作组合验收');g.opponent.leader='hsin'
 g._start_battle();ck(g.run.phase=='battle','normal battle start');g.battle_entry_age=1;g.motion.transition_left=0;g.transition_image=null
 for frame in 720:g._process(1.0/60)
 await shot('08-real-combat');ck(not g.combat.events.is_empty(),'battle events recorded')
 g.paused=true;var frozen=g.combat_vfx.impacts.duplicate(true);g._process(.5);ck(g.combat_vfx.impacts==frozen,'pause freezes visuals')
 FileAccess.open(OUT+'capture.txt',FileAccess.WRITE).store_string('Hidden unfocusable native viewport; isolated QA Storage; 16 original sprites, 6 details, purchase/drop/rotation, two-stage craft and 720 battle ticks. '+str(checks)+' checks, '+str(failures)+' failures.\n')
 g.queue_free();await process_frame;print('NATIVE_ORIGINALS_V128 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
