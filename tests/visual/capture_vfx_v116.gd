extends SceneTree
const G=preload('res://tests/fixtures/travel_fixture_v64.gd')
const OUT='res://build/qa/feedback-v116/native/'
var viewport
var g
var max_impacts=0
func _initialize():
 root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true);call_deferred('run_capture')
func shot(name):
 g.paint_alpha=1;g.paint_offset=Vector2.ZERO;g.motion.transition_left=0;g.transition_image=null
 g.queue_redraw();await process_frame;RenderingServer.force_draw(true);await process_frame
 assert(viewport.get_texture().get_image().save_png(OUT+name+'.png')==OK)
func run_capture():
 for folder in ['','quality-frames','battle-frames']:DirAccess.make_dir_recursive_absolute(OUT+folder)
 viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 g=G.new();viewport.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
 g.reset_slice();g.run.round=7;g.run.gold=12;g.run.serial=30;g.run.shop=[{},{},{},{},{},{}];g.run.bags=[]
 for y in range(0,6,2):
  for x in range(0,8,2):g.run.bags.append(g.piece('pouch','bag%d%d'%[x,y],x,y))
 g.run.items=[g.piece('crew_pulse_grip','i1',1,1),g.piece('w_sword','i2',2,1),g.piece('weapon_21020086','i3',0,4),g.piece('heron','i4',5,3),g.piece('weapon_21050036','i5',5,0)]
 g.run.primary='i2';g.run.stash=[];g.mouse=Vector2(28,70);g._clear_feedback()
 assert(g.inventory.validate_run(g.run))
 var grip_point=g._board_transform(0)*(g.BOARD+Vector2(1.5,1.5)*g.CELL)
 var press=InputEventMouseButton.new();press.position=grip_point;press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true
 g._input(press);g._process(.08);await shot('00-stars-held')
 var release=InputEventMouseButton.new();release.position=grip_point;release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false;g._input(release)
 # Display real outgoing slots: one weapon target, one empty grey slot.
 g._open_item_details(g.run.items[0],'board');g.motion.modal_value=1;g.item_selection_age=.1
 assert(g._effect_star_markers(g.run.items[0],g.run.items,g.run).filter(func(m):return m.state=='lit').size()==1)
 await shot('01-stars-clicked')
 g.item_selection_age=g.ITEM_SELECTION_DURATION;await shot('02-stars-settled')
 g._close_item_details();g.motion.modal_target=0;g.motion.modal_value=0
 g.run.shop=[{'kind':'weapon_21020086','locked':false},{'kind':'heron','locked':false},{'kind':'weapon_21020076','locked':false},{},{},{}]
 for n in 60:
  g._process(1.0/24);await shot('quality-frames/%03d'%n)
  if n==24:await shot('03-rarity')
 # Actual battle events feed the ordinary flight/arrival pipeline.
 g.reset_slice();g.run.round=7;g.run.serial=20;g.run.bags=[];g.run.items=[];g.run.shop=[{},{},{},{},{},{}]
 for y in range(0,6,2):
  for x in range(0,8,2):g.run.bags.append(g.piece('pouch','bag%d%d'%[x,y],x,y))
 var kinds=['w_sword','w_broadblade','w_gauntlet','w_pistol','w_rectifier','whiff','daily_tea']
 for n in kinds.size():
  var p=g.inventory.make_piece(kinds[n],'i'+str(n+1));var fit=g.inventory.first_fit(p,g.run.items,g.run.bags);assert(not fit.is_empty());g.run.items.append(fit)
 g.run.primary='i1';g.run.stash=[]
 assert(g.inventory.validate_run(g.run))
 g.opponent=g.inventory.snapshot(g.run,'qa-opponent','演出验收');g.opponent.leader='hsin'
 g._start_battle();assert(g.run.phase=='battle');g.battle_entry_age=1;g.motion.transition_left=0;g.transition_image=null
 for n in 150:
  g._process(1.0/24);await shot('battle-frames/%03d'%n)
  if g.combat_vfx.impacts.size()>max_impacts:
   max_impacts=g.combat_vfx.impacts.size();await shot('04-combat-impact')
 assert(max_impacts>0)
 # Pause is a real controller state; presentation time must stay frozen.
 g.paused=true;var frozen=g.combat_vfx.impacts.duplicate(true);g._process(.5);assert(g.combat_vfx.impacts==frozen)
 FileAccess.open(OUT+'capture.txt',FileAccess.WRITE).store_string('Hidden/unfocusable native renderer; isolated QA Storage. 60 preparation frames, 150 real combat frames. Max simultaneous real impacts: '+str(max_impacts)+'. Pausing freezes effects. No system cursor or foreground calls.')
 g.queue_free();await process_frame;quit()
