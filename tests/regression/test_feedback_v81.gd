extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const P=preload("res://scripts/inventory/pocket_rules.gd")
var game;var checks=0;var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():call_deferred("test")
func test():
 game=G.new();root.add_child(game);await process_frame;game.set_process(false);game.set_process_input(false)
 var inv=game.inventory;game.reset_slice();var r=game.run
 r.items=[game.piece("heron","echo",0,0)];r.bags=[game.piece("pouch","bag",0,0)];r.primary=""
 var bonus=inv.pocket_bonus(r.items[0],r)
 ck(bonus.sources.size()==1 and bonus.sources[0].value==P.shields(r,inv)[0].amount,"four covered cells preview exact +8 shield")
 var sword=game.piece("weapon_21020024","source",1,3);sword.rotation=2
 var echo=game.piece("heron","target",3,1);var second=game.piece("zig","other",2,2)
 r.items=[sword,echo,second];r.primary="source";r.bags=[];r.shop=[{},{},{},{},{},{}]
 for y in range(0,6,2):
  for x in range(0,8,2):r.bags.append(game.piece("pouch","b%d%d"%[x,y],x,y))
 ck(inv.validate_run(r),"shared source with two partners is legal")
 ck(game.has_method("_drag_star_markers"),"selected-item drag projection exists")
 if game.has_method("_drag_star_markers"):
  var before=r.duplicate(true);var m=game._drag_star_markers({"ok":true,"piece":echo,"run":r})
  ck(m==game._effect_star_markers(echo,r.items,r),"V102 dragging shows the selected item's own slots, not incoming sources")
  var future=r.duplicate(true);future.items=future.items.filter(func(v):return v.uid!=sword.uid)
  ck(game._drag_star_markers({"ok":true,"piece":echo,"run":future}).filter(func(v):return v.state=="lit" and v.target_uid==echo.uid).is_empty(),"displaced source cannot leave a false incoming star")
  ck(game._drag_star_markers({"ok":false}).is_empty() and r==before,"invalid drag has no active star and preview is pure")
 ck(game.has_method("_battle_star_markers"),"battle feedback is addressed by actual source and target")
 if game.has_method("_battle_star_markers"):
  game._clear_feedback();r.phase="battle"
  var before=r.duplicate(true)
  game._play_event({"kind":"trigger","side":0,"uid":sword.uid,"time":1})
  ck(game._battle_star_markers(sword,r,0).is_empty(),"ordinary attack animation lights no effect stars")
  var event={"kind":"star_trigger","side":0,"uid":sword.uid,"source_uid":sword.uid,"trigger_uid":echo.uid,"target_uid":echo.uid,"time":1}
  game._play_event(event)
  var m=game._battle_star_markers(sword,r,0)
  ck(m.size()==1 and m[0].target_uid==echo.uid,"only actual recipient lights even if two partners match")
  game._play_event(event);ck(game._battle_star_markers(sword,r,0).size()==1,"duplicate feedback does not add stars")
  ck(game._battle_star_markers(sword,r,1).is_empty(),"opponent with same UID cannot inherit player flash")
  game.star_activations.update(0);ck(game._battle_star_markers(sword,r,0).size()==1,"paused feedback does not expire")
  game.star_activations.update(.4);ck(game._battle_star_markers(sword,r,0).is_empty(),"feedback expires after its own event")
  game._play_event(event);game._clear_feedback();ck(game._battle_star_markers(sword,r,0).is_empty(),"next battle clears old recipients")
  ck(r==before,"feedback changes no gameplay state")
 print("FEEDBACK_V81 ",checks," checks, ",failures," failures")
 game.queue_free();await process_frame;quit(1 if failures else 0)
