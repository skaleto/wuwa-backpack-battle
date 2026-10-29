extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const CAP=preload("res://tests/fixtures/capacity_fixture_v111.gd")
const A=preload("res://scripts/party/crew_abilities.gd")
const OUT="res://build/qa/recruitment-v113/native/"
var viewport:SubViewport
var images=[]
func _initialize()->void:
 root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true)
 DirAccess.make_dir_recursive_absolute(OUT);call_deferred("capture")
func shot(g,name:String)->void:
 g.motion.modal_value=1.0 if not g.overlay.is_empty() else 0.0;g.queue_redraw();await process_frame;RenderingServer.force_draw(true);await process_frame
 assert(viewport.get_texture().get_image().save_png(OUT+name+".png")==OK);images.append(name);print("CAPTURE ",name)
func click(g,point:Vector2)->void:
 var move=InputEventMouseMotion.new();move.position=point;g._input(move)
 for down in [true,false]:
  var event=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;g._input(event)
func fill(g,kinds:Array)->void:
 g.run.items=[];g.run.bags=CAP.full_bags(g.inventory);g.run.serial=300
 for kind in kinds:
  var p=g.inventory.make_piece(kind,"i%d"%g.run.items.size());var fit=g.inventory.first_fit(p,g.run.items,g.run.bags)
  assert(not fit.is_empty());g.run.items.append(fit)
 g.run.primary=g.run.items[0].uid
func capture()->void:
 viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var g=G.new();viewport.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
 g.run.round=3;g.run.gold=20;g.run.shop=[{},{},{},{},{},{}]
 fill(g,["w_sword","echo_glacio","whiff"])
 g.mouse=Vector2(20,100);g.motion.modal_value=0;g.motion.transition_left=0;g.transition_image=null
 assert(g.inventory.validate_run(g.run))
 g.overlay="crew";g.crew_tab="recruit";g.crew_filter="frost_hunt";g.crew_focus="role_1108"
 await shot(g,"01-feixue-combo")
 var before=g.run.gold;click(g,Vector2(242,865))
 assert("role_1108" in g.run.roster and "role_1108" in g.run.supports and g.run.gold<before)
 await shot(g,"02-cross-element-recruited")
 click(g,Vector2(242,865));assert("role_1108" not in g.run.supports)
 await shot(g,"03-bench")
 click(g,Vector2(242,865));assert("role_1108" in g.run.supports)
 # Ability filtering is a real click target and stays independent of recruitment.
 g.crew_tab="recruit";g.crew_filter="";g.crew_focus="";await shot(g,"09-all-abilities")
 click(g,Vector2(700,163));assert(g.crew_filter=="weapon_echo")
 await shot(g,"10-echo-cooldown-partner")
 click(g,Vector2(1000,163));assert(g.crew_filter=="heal_charge")
 await shot(g,"11-healing-charge-partner")
 # Recipe panel remains freely available even with no signature owner in roster.
 g.run.roster=[];g.run.supports=[];g.run.recruited_round=0;g.overlay=""
 g._open_item_details(g.piece("weapon_21020086","atlas",0,0),"catalogue")
 await shot(g,"04-signature-without-owner")
 g._close_item_details();g.motion.modal_value=0
 fill(g,["w_sword","w_sword","w_sword","whiff","turtle"])
 g.run.roster=["role_1510","role_1410"];g.run.supports=g.run.roster.duplicate();g.run.recruited_round=3;g.run.round=8
 g.overlay="crew";g.crew_tab="formation";g.crew_focus="role_1510";g.crew_page=0
 await shot(g,"05-stamina-partner")
 g.overlay="";g.opponent=g.run.duplicate(true);g.opponent.leader="qingxiao"
 assert(g.inventory.validate_run(g.run));g._start_battle();assert(g.run.phase=="battle");g.battle_entry_age=1
 var fired=g.combat.events.filter(func(e):return e.kind=="crew_trigger" and e.side==0)
 assert(not fired.is_empty());g.combat_time=fired[0].time+.3;g._play_event(fired[0]);await shot(g,"06-partner-trigger")
 g.run.phase="result";g.combat_time=g.combat.duration;g._open_battle_review();assert(g.review.active)
 g._review_action("metric:stamina");g._review_action("item:crew:role_1510");await shot(g,"07-partner-timeline")
 assert(not g.review_timeline.is_empty());var uid=g.review_timeline[0].id;g._review_action("event:"+str(uid));assert(g.review.time==float(g.review.record.events[uid].time))
 await shot(g,"08-seek-event")
 FileAccess.open(OUT+"result.json",FileAccess.WRITE).store_string(JSON.stringify({"images":images,"isolated_storage":true,"hidden_unfocusable":true,"synthetic_input":true,"real_pointer_untouched":true},"\t"))
 g.queue_free();await process_frame;print("V113 NATIVE COMPLETE");quit()
