extends SceneTree
## Background native render only; the root cannot focus, no desktop input, isolated save.
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
var game;var viewport;var report
func _initialize():
 root.hide();root.unfocusable=true;call_deferred("capture")
func shot(label):
 game.queue_redraw();await process_frame;RenderingServer.force_draw(true);await process_frame
 RenderingServer.force_draw(true);await process_frame
 assert(viewport.get_texture().get_image().save_png("res://build/qa/gameplay-v92/native/"+label+".png")==OK)
 report.store_line(label);report.flush()
func prepare():
 game.reset_slice();game._close_item_details();game.run.shop=[{},{},{},{},{},{}]
 game.run.items=[];game.run.stash=[];game.run.bags=[];game.run.serial=50;game.run.primary=""
 for y in [0,2,4]:
  for x in [0,3]:game.run.bags.append(game.piece("satchel","bag%d_%d"%[x,y],x,y))
 game.mouse=Vector2(30,930);game._clear_feedback();game.motion.modal_value=0;game.motion.modal_target=0
func select(item):game.hovered={"origin":"board","item":item}
func capture():
 report=FileAccess.open("res://build/qa/gameplay-v92/native/capture.log",FileAccess.WRITE)
 viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport);game=G.new();viewport.add_child(game);await process_frame
 game.set_process(false);game.set_process_input(false)
 prepare();game.run.items=[game.piece("turtle","turtle",2,2),game.piece("w_sword","sword",1,1)];game.run.primary="sword"
 select(game.run.items[0]);assert(game.inventory.validate_run(game.run));await shot("01-two-star-support")
 prepare();game.run.items=[game.piece("echo_tianqui","boss",2,1),game.piece("w_sword","sword",1,3),game.piece("whiff","whiff",4,3),game.piece("zig","zig",4,4)];game.run.primary="sword"
 select(game.run.items[0]);assert(game.inventory.validate_run(game.run));await shot("02-four-star-boss")
 prepare();game.run.items=[game.piece("w_sword","sword",1,1),game.piece("daily_tea","tea",1,2),game.piece("whiff","whiff",2,2)];game.run.primary="sword"
 game._open_item_details(game.run.items[1],"board");game.motion.modal_value=1;game.motion.modal_target=1;game.item_selection_age=1
 assert(game.inventory.validate_run(game.run));await shot("03-permanent-provision-details")
 game._close_item_details();game.motion.modal_value=0;game.motion.modal_target=0;game.hovered={}
 game.opponent=game.inventory.practice(1,19);game._start_battle();game.battle_entry_age=1;game.transition_image=null;game.motion.transition_left=0
 assert(game.run.phase=="battle")
 var activations=game.combat.events.filter(func(e):return e.kind=="supply" and e.side==0 and e.uid=="tea")
 assert(activations.size()==1);game.combat_time=2.0;game._play_event(activations[0]);await shot("04-provision-stays-after-activation")
 game.run.phase="result";game.run.combat=game.combat;game.inventory.finish(game.run,game.combat.winner)
 assert(game.run.items.any(func(p):return p.uid=="tea"));await shot("05-same-provision-next-round")
 report.store_line("COMPLETE: native hidden render, isolated QA, no desktop input");report.close()
 game.queue_free();await process_frame;quit()
