extends SceneTree
## Native render + real controller events, in a hidden unfocusable viewport.
const OUT='res://build/qa/families-v127/native/'
const C=preload('res://scripts/data/catalog.gd')
const CAP=preload('res://tests/fixtures/capacity_fixture_v111.gd')
const TREE=preload('res://scripts/crafting/recipe_tree.gd')
const SPEC=preload('res://scripts/data/family_catalog_v127.gd')
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
func click(action):
 var buttons=g.buttons.filter(func(b):return b.action==action and b.enabled)
 ck(not buttons.is_empty(),'registered enabled control '+action)
 if buttons.is_empty():return
 button(buttons[0].rect.get_center(),true);button(buttons[0].rect.get_center(),false)
func empty_board():
 g.reset_slice();g.run.items=[];g.run.stash=[];g.run.primary='';g.run.bags=CAP.full_bags(g.inventory);g.run.gold=30;g.run.serial=200;g.run.round=7
 g.run.shop=[{'kind':'relic_cutlery','locked':false},{'kind':'relic_diaphragm','locked':false},{'kind':'relic_guard_plate','locked':false},{'kind':'relic_tea_strainer','locked':false},{'kind':'relic_clockwork','locked':false},{'kind':'pouch','locked':false}]
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
 for page in 3:
  empty_board()
  for index in range(page*8,page*8+8):fit(kinds[index],'part'+str(index))
  fit('w_sword','weapon');fit('whiff','echo');g.run.primary='weapon'
  ck(g.inventory.validate_run(g.run),'legal current family board '+str(page))
  var before=g.run.duplicate(true)
  await shot('01-items-page-'+str(page+1))
  ck(g.run==before,'render read-only')
  for uid in ['part'+str(page*8+1),'part'+str(page*8+6)]:
   g._open_item_details(g.inventory.find_piece(g.run,uid),'board');await shot('02-detail-'+uid);g._close_item_details()
 # Exact shared inputs offer two mutually exclusive branches.
 empty_board();var source=fit('relic_diverter','gear');fit('mat_43020021','fuel');fit('w_sword','weapon');g.run.primary='weapon'
 g._open_item_details(source,'board');g.ITEM_PANEL.action(g,'detail_recipes')
 await shot('03-gear-branches')
 var rows=TREE.outgoing('relic_diverter');var row=rows.filter(func(r):return r.id=='F127-15')[0]
 TREE.option_page=rows.find(row)/3;await shot('04-branch-alternative')
 click('atlas_recipe:F127-15');await shot('05-exact-ingredients')
 ck(TREE.current_recipe().id=='F127-15','selected exact same-input alternative')
 click('atlas_close');await shot('06-preparation')
 # Press, free drag, right-click rotation and release of a newly purchased part.
 empty_board();fit('w_sword','weapon');g.run.primary='weapon'
 var before=g.run.duplicate(true);var start=g._offer_rect(0).position+Vector2(50,44)
 var at=g._board_to_screen(g.BOARD+Vector2(4.5,3.5)*g.CELL)
 button(start,true);move(at);button(at,true,MOUSE_BUTTON_RIGHT);button(at,false,MOUSE_BUTTON_RIGHT)
 ck(g.run==before,'held shop item not purchased before release')
 await shot('07-held-rotated-cutlery');button(at,false)
 ck(g.run.items.any(func(p):return p.kind=='relic_cutlery' and p.rotation==1) and g.run.gold==before.gold-1,'rotated base purchased on release')
 await shot('08-bought-cutlery')
 # Click two successive actual on-board craft controls, not a forced output.
 empty_board();fit('soup','meal');fit('relic_cutlery','tools');fit('rations','food')
 await shot('08a-ready-first-craft')
 for recipe_id in ['F127-01','F127-02']:
  if g.fusion_view.active():g.fusion_view.finish()
  var entry=g.inline_craft.entries.filter(func(e):return e.recipe_id==recipe_id)
  if entry.is_empty():
   # A newly produced box may need a normal placement beside the next material.
   var box=g.run.items.filter(func(p):return p.kind=='relic_lunchbox')
   if not box.is_empty():g.FORGE.place_material(g.run,'relic_march_lunchbox',box[0].uid,'rations',g.inventory,Callable(),recipe_id)
   await shot('08b-repositioned-'+recipe_id)
   entry=g.inline_craft.entries.filter(func(e):return e.recipe_id==recipe_id)
  ck(not entry.is_empty(),'successive native craft button '+recipe_id)
  if entry.is_empty():continue
  var target=entry[0].target;var center=entry[0].rect.get_center();button(center,true);button(center,false)
  ck((g.run.items+g.run.stash).any(func(p):return p.kind==target),'actual click creates '+target)
  for frame in 18:g._process(1.0/60)
  await shot('08c-fusing-'+recipe_id)
  g.fusion_view.finish();await shot('08d-crafted-'+recipe_id)
 ck((g.run.items+g.run.stash).any(func(p):return p.kind=='relic_march_lunchbox') and not (g.run.items+g.run.stash).any(func(p):return p.kind in ['soup','relic_cutlery','rations','relic_lunchbox']),'two stages consume exact inputs and leave final branch')
 # All new families coexist in actual native combat without independent fake timers.
 empty_board()
 for kind in ['w_sword','w_broadblade','whiff','zig','relic_capacitor','relic_echo_relay','relic_recoil_guard','relic_breach_scope','relic_noise_chamber','relic_shatter_prism','provision_strong_tea','relic_march_lunchbox']:fit(kind,kind)
 g.run.primary='w_sword';ck(g.inventory.validate_run(g.run),'legal mixed-family combat')
 g.opponent=g.inventory.snapshot(g.run,'v127-native','组合验收');g.opponent.leader='hsin'
 g._start_battle();ck(g.run.phase=='battle','normal battle application starts')
 g.battle_entry_age=1;g.motion.transition_left=0;g.transition_image=null
 for frame in 720:g._process(1.0/60)
 await shot('09-real-combat')
 ck(not g.combat.events.is_empty(),'real events recorded')
 g.paused=true;var frozen=g.combat_vfx.impacts.duplicate(true);g._process(.5)
 ck(g.combat_vfx.impacts==frozen,'pause freezes actual visuals')
 FileAccess.open(OUT+'capture.txt',FileAccess.WRITE).store_string('Hidden unfocusable native viewport; isolated QA Storage; 24 icons, branch identity, real purchase/rotation and 720 battle ticks. '+str(checks)+' checks, '+str(failures)+' failures.\n')
 g.queue_free();await process_frame;print('NATIVE_FAMILIES_V127 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
