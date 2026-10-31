extends SceneTree
class Fixture:
 extends "res://tests/fixtures/travel_fixture_v64.gd"
 var forced_frame={}
 func _vitals_frame()->Dictionary:
  return forced_frame if not forced_frame.is_empty() else super._vitals_frame()
var game
var view
var output="res://build/qa/polish143"
func _initialize():
 root.unfocusable=true;root.mode=Window.MODE_MINIMIZED;AudioServer.set_bus_mute(0,true)
 DirAccess.make_dir_recursive_absolute(output)
 call_deferred("render")
func capture(name:String):
 game.queue_redraw();await process_frame;await process_frame
 RenderingServer.force_draw(true)
 view.get_texture().get_image().save_png(output.path_join(name+".png"))
func render():
 view=SubViewport.new();view.size=Vector2i(1440,960);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 game=Fixture.new();view.add_child(game);await process_frame;game.set_process(false);game.set_process_input(false)
 game.run=preload("res://scripts/run/run_lifecycle.gd").start("aemeath",143,game.inventory).run
 game.opponent=game.storage.opponent(game.run)
 game.run.shop=[{"kind":"pocket_single","price":1},{"kind":"pocket_double","price":2},{"kind":"pocket_long_l","price":3},{"kind":"pocket_long_j","price":3},{"kind":"tea","price":3},{"kind":"w_sword","price":4}]
 game.mouse=Vector2.ZERO
 await capture("shop")
 game.dragging=game.run.items[0].duplicate(true);game.drag_origin="board";game.drag_pressed=false
 game.mouse=game.QL.SELL.get_center();game.motion.hover_values["recycle:open"]=1
 await capture("recycle-open")
 game.dragging={};game.motion.hover_values["recycle:open"]=0
 await game._start_battle();game.battle_entry_age=1;game.combat_time=4
 game.motion.transition_left=0;game.transition_image=null
 await capture("battle")
 game.forced_frame=game._vitals_frame().duplicate(true)
 var statuses=[]
 for key in ["charge","haste","noise","frost","freeze"]:statuses.append({"id":key,"stacks":4,"remaining":3.5})
 for side in game.forced_frame.sides:side.statuses=statuses.duplicate(true)
 await capture("status-stress")
 game.mouse=Vector2(365,444);await capture("status-detail")
 game.mouse=Vector2.ZERO;game.run.phase="result";game.combat.winner=1;game.phase_age=.35
 await capture("victory-pop")
 game.phase_age=2;await capture("victory-rest")
 game.combat.winner=-1;game.phase_age=.58;await capture("heart-break")
 game.queue_free();await process_frame;print("POLISH143 hidden native previews captured");quit()
