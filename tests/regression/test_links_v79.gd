extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const LINK=preload("res://scripts/ui/crafting/craft_link_view.gd")
var game;var checks=0;var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():call_deferred("test")
func test():
 var distant=LINK.spans(Vector2.ZERO,Vector2(800,0),false)
 ck(distant.size()==2 and distant[0].y<.5 and distant[1].x>.5,"distant links leave a real empty center")
 ck(LINK.spans(Vector2.ZERO,Vector2(80,0),true)==[Vector2(0,1)],"adjacency joins the complete line")
 game=G.new();root.add_child(game);await process_frame;game.set_process(false);game.set_process_input(false)
 game.reset_slice();game.run.shop=[{"kind":"mat_43020011","locked":false},{},{},{},{},{}]
 game.run.items=[game.piece("w_sword","i1",0,0)];game.run.stash=[];game.run.primary="i1";game.mouse=Vector2(40,920)
 game.motion.modal_value=0;game.hovered={}
 var before=game.run.duplicate(true)
 var links=game.inline_craft.links(game._craft_view_model())
 ck(links.size()==1,"shop-board link is visible with no hover")
 game.inventory.stash(game.run,game.run.items[0]);links=game.inline_craft.links(game._craft_view_model())
 ck(links.size()==1 and not links[0].ready,"shop-storage relationship is always visible")
 game.run.items=[];game.run.stash=[];game.run.primary=""
 game.run.shop=[{"kind":"mat_43020011","locked":false},{"kind":"w_sword","locked":false},{},{},{},{}]
 links=game.inline_craft.links(game._craft_view_model())
 ck(links.size()==1 and not links[0].ready,"two shop ingredients show potential without ownership")
 game.run.shop=[{},{},{},{},{},{}];game.run.items=[game.piece("w_sword","i1",0,0),game.piece("whiff","i2",2,1)];game.run.primary="i1"
 game.inline_craft.refresh(game._craft_view_model())
 ck(game.inline_craft.entries.size()==1,"screenshot arrangement has immediate button without expansion")
 if not game.inline_craft.entries.is_empty():
  var entry=game.inline_craft.entries[0];game.mouse=entry.rect.get_center()
  var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=game.mouse;e.pressed=true;game._input(e)
  e.pressed=false;game._input(e)
  ck(game.run.stash.size()==1 and game.fusion_view.active(),"button actually creates stored item and fusion")
  if not game.run.stash.is_empty():ck(game.fusion_view.destination==game._stash_rect(0).get_center(),"fusion converges on actual storage slot")
  game.fusion_view.finish();ck(game.inventory.validate_run(game.run),"skipping fusion does not change valid result")
 game.reset_slice();game.run.shop=[{},{},{},{},{},{}];game.run.items=[game.piece("w_sword","i1",0,0),game.piece("whiff","i2",2,1)];game.run.primary="i1";game.run.serial=20
 for n in 6:game.run.stash.append(game.piece("nutrition","s"+str(n),0,0))
 game.inline_craft.refresh(game._craft_view_model())
 ck(game.inline_craft.entries.size()==1 and game.inline_craft.entries[0].ok,"V103 six stored items retain an actionable recipe")
 if not game.inline_craft.entries.is_empty():
  game.mouse=game.inline_craft.entries[0].rect.get_center();before=game.run.duplicate(true)
  var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=game.mouse;e.pressed=true;game._input(e);e.pressed=false;game._input(e)
  ck(game.run.stash.size()==7 and game.run.items.is_empty() and game.fusion_view.active() and game._stash_current_page()==1,"V103 click consumes inputs once and reveals seventh output")
 print("LINKS_V79 ",checks," checks, ",failures," failures")
 game.queue_free();await process_frame;quit(1 if failures else 0)
