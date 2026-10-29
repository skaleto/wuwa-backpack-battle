extends SceneTree
const G=preload("res://tests/fixtures/demo_fixture.gd")
var game
var checks=[]
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 checks.append({"ok":ok,"label":label})
 if not ok:printerr("FAIL: ",label)
func tick(n:int=1):
 for i in n:
  game._process(1.0/30);game.queue_redraw();await process_frame;RenderingServer.force_draw(false,1.0/30)
func move(p:Vector2):
 var ev=InputEventMouseMotion.new();ev.position=p;game._input(ev);await tick()
func button(down:bool,id:int=MOUSE_BUTTON_LEFT):
 var ev=InputEventMouseButton.new();ev.position=game.mouse;ev.pressed=down;ev.button_index=id;game._input(ev);await tick()
func action(id:String):
 var matches=game.buttons.filter(func(v):return v.action==id and v.enabled)
 check(not matches.is_empty(),"visible action: "+id)
 if matches.is_empty():return
 await move(matches[0].rect.get_center());await button(true);await button(false);await tick(12)
func shot(name:String):
 await tick(2);root.get_texture().get_image().save_png("res://build/qa/demo-v49/review/"+name+".png")
func point(x:float,y:float)->Vector2:return game._board_to_screen(game.BOARD+Vector2(x,y)*game.CELL)
func close():
 game.overlay="";await tick(12)
func run():
 root.size=Vector2i(1440,960);game=G.new();root.add_child(game);await process_frame;game.set_process(false);game.set_process_input(false)
 await tick(12);await shot("01-ready")
 check(game.C.items.keys().filter(func(kind):return not game.C.is_tag(kind,"bag")).all(func(kind):return game._ensure_icon(kind)),"all 178 selected item images load lazily")
 check(game.SKIN.cache_metrics().resident_bytes<=game.SKIN.IDLE_CACHE_BUDGET_BYTES,"off-frame lazy loading obeys texture byte budget")
 check(game.C.characters.keys().all(func(id):return game._ensure_portrait(id,"body")!=null),"all six selected leader illustrations load lazily")
 check(game.buttons.all(func(v):return v.action!="relay_mode"),"no concerto action in preparation")
 var before=game.run.duplicate(true)
 await move(point(1.5,1.5));await button(true);await button(false);await tick(12)
 check(game.overlay=="item_details" and game.run==before,"click details leaves board and save unchanged")
 await shot("02-details");await action("detail_recipes")
 check(game.overlay=="item_recipes","detail recipe is reachable by pointer")
 await shot("03-recipe");await action("detail_result");await action("details_back")
 check(game.overlay=="item_recipes","result details returns to its recipe")
 await action("detail_forge");check(game.overlay=="forge","recipe opens real forge for selected owned base")
 await close()
 await move(point(1.5,1.5));await button(true);await tick(12)
 check(not game.dragging.is_empty(),"holding lifts item without opening panel")
 await move(point(3.0,2.5)+Vector2(7,9));await shot("04-held")
 var origin=game._drag_visual_origin();await move(game.mouse+Vector2(9,4))
 check(game._drag_visual_origin().is_equal_approx(origin+Vector2(9,4)),"free floating follows fractional grid motion")
 await button(true,MOUSE_BUTTON_RIGHT);await button(false,MOUSE_BUTTON_RIGHT);await tick(8);await shot("05-rotated")
 check(game.dragging.rotation==1,"right button rotates held weapon")
 await move(game._stash_mat_rect().get_center());await button(false)
 check(game.run.stash.any(func(v):return v.uid=="cross" and v.rotation==1),"owned drop stores rotated weapon")
 game.reset_review();await tick(12)
 await move(game._offer_rect(4).get_center());await button(true);await button(false);await tick(12)
 check(game.overlay=="item_details","shop click opens details")
 await shot("06-food");await close()
 before=game.run.duplicate(true)
 await move(game._offer_rect(1).get_center());await button(true);await move(Vector2(1430,928));await button(false)
 check(game.run==before,"shop cancel changes no ownership or money")
 await move(game._offer_rect(1).get_center());await button(true);await move(game._stash_mat_rect().get_center());await button(false)
 check(game.run.stash.size()==1 and game.run.gold==before.gold-game.C.items.whiff.price,"valid stash purchase charges once")
 await shot("07-purchased")
 game.reset_review();await tick(12)
 await move(game._bag_handle(game.run.bags[1]).get_center());await button(true);await tick(12)
 check(game.drag_origin=="bag","region edge grabs bag after cleanup")
 await button(true,MOUSE_BUTTON_RIGHT);await button(false,MOUSE_BUTTON_RIGHT)
 await move(point(6.5+game.drag_offset.x,1.5+game.drag_offset.y));await tick(8);await shot("12-floating-bag")
 await button(false);await tick(12)
 var moved_bag=game.run.bags.filter(func(v):return v.uid=="fast")[0]
 check(moved_bag.x==6 and moved_bag.y==1 and moved_bag.rotation==2,"floating bag reattaches at exact preview cells")
 check(game.run.items.filter(func(v):return v.uid=="fast-w")[0].rotation==1,"bag carries contained sword through rotation")
 game.reset_review();await tick(12)
 # Item data coverage and signature panel; no prose rendering in any item surface.
 for kind in game.C.items:
  check(not game.INFO.rows({"kind":kind}).is_empty(),"attribute coverage: "+kind)
 game._open_item_details({"kind":"bellborne","rotation":0},"catalogue");await tick(12);await shot("08-echo");await close()
 var material=game.C.items.keys().filter(func(k):return game.C.is_tag(k,"craft_material"))[0]
 game._open_item_details({"kind":material,"rotation":0},"catalogue");await tick(12);await action("detail_recipes");await shot("09-material-recipes");await close()
 game._action("forge");await tick(12);await shot("10-forge");await close()
 for leader in ["jiyan","yinlin","verina"]:
  game.run=game.inventory.new_run(leader,49);game.screen="game";game.opponent=game.storage.opponent(game.run);game._action("battle");game.transition_image=null;game.motion.transition_left=0
  check(game.run.phase=="battle" and not game.combat.is_empty(),leader+" starts battle")
  await tick(48)
  check(game.combat.frames.all(func(f):return f.sides.all(func(s):return s.concerto==0)),leader+" no concerto in replay")
  if leader=="jiyan":await shot("11-battle")
  game._action("skip");await tick(8)
  check(game.run.phase in ["result","ending"],leader+" settles battle")
  game._action("next");await tick(8)
  check(game.inventory.validate_run(game.run),leader+" next round remains valid")
 var f=FileAccess.open("res://build/qa/demo-v49/native-verification.json",FileAccess.WRITE);var failures=checks.filter(func(v):return not v.ok).size();f.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"));f.close()
 print("NATIVE DEMO: ",checks.size()," checks, ",failures," failures");game.queue_free();await process_frame;quit(1 if failures else 0)
