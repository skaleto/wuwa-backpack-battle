extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const CF=preload("res://tests/fixtures/craft_fixture_v75.gd")
const CAP=preload("res://tests/fixtures/capacity_fixture_v111.gd")
const OUT="res://build/qa/feedback-v112/native/"
var viewport:SubViewport
var images=[]
func _initialize()->void:
 root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true)
 DirAccess.make_dir_recursive_absolute(OUT);call_deferred("capture")
func shot(g,name:String)->void:
 g.queue_redraw();await process_frame;RenderingServer.force_draw(true);await process_frame
 assert(viewport.get_texture().get_image().save_png(OUT+name+".png")==OK);images.append(name);print("CAPTURE ",name)
func click(g,point:Vector2)->void:
 var move=InputEventMouseMotion.new();move.position=point;g._input(move)
 for down in [true,false]:
  var event=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;g._input(event)
func capture()->void:
 viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var g=G.new();viewport.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
 g.run.round=3;g.run.gold=20;g.run.bags=[g.piece("satchel","b1",1,1),g.piece("pouch","b2",4,1),g.piece("strip","b3",1,3),g.piece("corner","b4",2,3)]
 g.run.items=[g.piece("w_sword","i1",1,2),g.piece("whiff","i2",2,3),g.piece("rations","i3",1,4)];g.run.serial=50
 g.run.shop=[{"kind":"whiff","locked":false},{"kind":"w_sword","locked":false},{"kind":"daily_tea","locked":false},{"kind":"soup","locked":false},{"kind":"turtle","locked":false},{"kind":"corner","locked":false}]
 g.mouse=Vector2(20,100);g.hovered={};g.dragging={};g.overlay="";g.motion.modal_value=0;g.motion.transition_left=0;g.transition_image=null
 assert(g.inventory.validate_run(g.run),"native fixture must permit real UI commits")
 await shot(g,"01-shop-benefits")
 click(g,g.QL.offer_control(0).get_center());assert(g.run.shop[0].locked)
 g.motion.elapsed+=.12;await shot(g,"02-lock-arriving")
 g.motion.elapsed+=.4;await shot(g,"03-lock-settled")
 click(g,g._offer_rect(0).get_center());assert(g.overlay=="item_details" and g.detail_origin=="shop")
 await shot(g,"04-shop-partner-detail")
 g._close_item_details();g.motion.modal_value=0
 # Same board view sampled at rest and at the midpoint of the selected-item lift.
 var item=g.run.items[0];g.detail_item=item;g.detail_origin="board";g.hovered={"origin":"board","item":item}
 g.item_selection_age=g.ITEM_SELECTION_DURATION;await shot(g,"05-stars-rest")
 g.item_selection_age=g.ITEM_SELECTION_DURATION*.5;await shot(g,"06-stars-lift")
 g._open_item_details(g.run.bags[1],"bag");await shot(g,"07-pocket-details")
 g._open_item_details(g.piece("weapon_21020086","atlas",0,0),"catalogue");await shot(g,"08-feixue-party-requirement")
 g.run=CF.make(g.inventory,"weapon_21020076");g.run.bags=CAP.full_bags(g.inventory);g.run.items=[];g.run.stash=[];g.run.shop=[{},{},{},{},{},{}]
 for kind in ["weapon_21020076","heron","weapon_21020015"]:
  var p=g.inventory.make_piece(kind,"rare%d"%g.run.items.size());var placed=g.inventory.first_fit(p,g.run.items,g.run.bags)
  assert(not placed.is_empty());g.run.items.append(placed)
 g.run.primary=g.run.items[0].uid;g.overlay="";g.hovered={};g.motion.modal_value=0;g.mouse=Vector2(20,100);g.item_selection_age=2
 for n in 3:g.motion.elapsed=1+n*.7;await shot(g,"09-rare-effects-%d"%n)
 g.opponent=g.inventory.practice(8,19);g.run.round=8;g.run.phase="shop";g._start_battle();g.battle_entry_age=1
 g.combat_time=8;await shot(g,"10-battle-stamina")
 FileAccess.open(OUT+"result.json",FileAccess.WRITE).store_string(JSON.stringify({"images":images,"isolated_storage":true,"hidden_unfocusable":true,"synthetic_input":true,"real_pointer_untouched":true},"\t"))
 g.queue_free();await process_frame;print("V112 NATIVE COMPLETE");quit()
