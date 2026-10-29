extends SceneTree
## Visual replay of a real procurement log, in isolated QA Storage and hidden GPU viewport.
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const P=preload("res://scripts/shop/practice_budget.gd")
var game
var viewport
func _initialize():
 root.hide();root.unfocusable=true
 call_deferred("run")
func shot(label:String):
 game.paint_alpha=1;game.paint_offset=Vector2.ZERO;game.queue_redraw()
 await process_frame;RenderingServer.force_draw(true);await process_frame
 RenderingServer.force_draw(true);await process_frame
 assert(viewport.get_texture().get_image().save_png("res://build/qa/gameplay-v93/native/"+label+".png")==OK)
func run():
 assert(DisplayServer.get_name()!="headless")
 var report=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/data/gameplay-v93/reports/focused-ui-match-playthrough.json"))
 var samples=report.samples.filter(func(s):return s.max_lineage_depth>=3)
 assert(not samples.is_empty())
 var sample=samples[0];var last=sample.rounds[-1]
 viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport);game=G.new();viewport.add_child(game);await process_frame
 game.set_process(false);game.set_process_input(false)
 game.run=game.inventory.new_run(sample.leader,int(sample.seed),"focused");game.run.merge(sample.final_snapshot,true)
 game.run.items=last.items.duplicate(true);game.run.bags=last.bags.duplicate(true);game.run.stash=last.stash.duplicate(true)
 game.run.gold=int(last.gold);game.run.round=int(last.round);game.run.seed=int(sample.seed)*100+int(last.round)
 game.run.wins=int(sample.wins)-(1 if int(last.winner)==1 else 0);game.run.losses=int(sample.losses)-(0 if int(last.winner)==1 else 1)
 game.run.recruited_round=0
 for entry in sample.ledger:
  if entry.purpose=="recruit" and int(entry.round)<=int(last.round):game.run.recruited_round=maxi(game.run.recruited_round,int(entry.round))
 game.run.serial=1
 for p in game.run.items+game.run.stash+game.run.bags:
  if p.uid.begins_with("i"):game.run.serial=maxi(game.run.serial,int(p.uid.substr(1))+1)
 game.run.phase="shop";game.run.shop=[{},{},{},{},{},{}];game.run.combat={};game.run.history=[]
 game.opponent=P.build(game.inventory,int(last.round),int(last.opponent.seed),"focused");game.screen="game";game.selected_leader=sample.leader
 game.overlay="";game.hovered={};game.dragging={};game.mouse=Vector2(1360,900)
 assert(game.inventory.validate_run(game.run),"acquired replay run must be legal")
 game._start_battle();assert(int(game.combat.winner)==int(last.winner))
 game.battle_entry_age=1.0;game.motion.modal_value=0;game.motion.modal_target=0
 for frame in mini(120,int(game.combat.duration*5)):game._process(.1)
 await shot("10-acquired-chain-replay")
 var support=game.run.items.filter(func(p):return p.kind=="weapon_21050036" or p.kind=="echo_tianqui" or p.kind=="bellborne")
 if support.is_empty():support=[game.run.items[-1]]
 game._open_item_details(support[0],"board");game.item_selection_age=game.ITEM_SELECTION_DURATION;game.motion.modal_value=1;game.motion.modal_target=1
 await shot("11-acquired-item-detail")
 game._close_item_details();game.combat_time=game.combat.duration+1;game.run.phase="result";game.overlay="";game.motion.modal_value=0;game.motion.modal_target=0;game._clear_feedback()
 await shot("12-acquired-contributions")
 print(JSON.stringify({"scope":"GPU replay of actually acquired last-round build, not a new playthrough","leader":sample.leader,"seed":sample.seed,"round":last.round,"lineage":sample.max_lineage_depth,"winner":game.combat.winner,"display_time":game.combat_time,"acquisition_hash":sample.acquisition_hash}))
 game.queue_free();await process_frame;quit()
