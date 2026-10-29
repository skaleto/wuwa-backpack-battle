extends SceneTree
const OUT="res://build/qa/ecosystem-v125/native/"
const C=preload("res://scripts/data/catalog.gd")
const CAP=preload("res://tests/fixtures/capacity_fixture_v111.gd")
const TREE=preload("res://scripts/crafting/recipe_tree.gd")
var g
var viewport
var failures=0
func ck(ok,label):
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
 root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true);call_deferred("capture")
func shot(name):
 g.motion.modal_value=0 if g.overlay.is_empty() else 1;g.motion.modal_target=g.motion.modal_value;g.queue_redraw()
 await process_frame;RenderingServer.force_draw(true);await process_frame
 ck(viewport.get_texture().get_image().save_png(OUT+name+".png")==OK,"capture "+name)
func capture():
 if DisplayServer.get_name()=="headless":quit(2);return
 DirAccess.make_dir_recursive_absolute(OUT)
 viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 g=preload("res://tests/fixtures/travel_fixture_v64.gd").new();viewport.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
 g.run.items=[];g.run.stash=[];g.run.primary="";g.run.bags=CAP.full_bags(g.inventory);g.run.round=7;g.run.gold=18
 var pieces=[
 ["echo_anger","anger",1,0,0],["w_sword","sword",2,0,0],
 ["relic_diverter","gear",6,0,0],["w_sword","sword2",8,0,1],
 ["echo_porcelain","porcelain",0,2,0],["turtle","turtle",1,2,0],
 ["echo_gliding_sentry","sentry",2,2,0],["rocksteady","rock",4,2,0],["echo_sorrow","sorrow",6,2,0],
 ["echo_singilum","singilum",0,4,0],["soup","soup",3,4,0],["cool_tea","tea",4,4,0],
 ["relic_lunchbox","lunch",3,5,0],["echo_moth","moth",6,4,0]]
 for row in pieces:
  var piece=g.piece(row[0],row[1],row[2],row[3]);piece.rotation=row[4];g.run.items.append(piece)
 g.run.shop=[{"kind":"echo_porcelain","locked":false},{"kind":"echo_sorrow","locked":false},{"kind":"relic_lunchbox","locked":false},{"kind":"echo_moth","locked":false},{"kind":"mat_42500010","locked":false},{"kind":"pouch","locked":false}]
 g.run.stash=[g.piece("spicy_meat","stored",0,0)]
 ck(g.inventory.validate_run(g.run),"legal full ecosystem board")
 var before=g.run.duplicate(true);var disk=FileAccess.get_file_as_bytes(g.storage.root_path+"run.json")
 await shot("01-new-combinations")
 for uid in ["sentry","lunch","moth","singilum"]:
  g._open_item_details(g.inventory.find_piece(g.run,uid),"board");await shot("02-detail-"+uid);g.overlay=""
 g._open_item_details(g.inventory.find_piece(g.run,"soup"),"board");g.ITEM_PANEL.action(g,"detail_recipes")
 var recipes=TREE.outgoing("soup")
 var index=recipes.find(recipes.filter(func(r):return r.id=="E125-01")[0]);TREE.option_page=index/3
 await shot("03-food-branches")
 ck(g.buttons.any(func(b):return b.action=="atlas_recipe:E125-01"),"new lunchbox branch visible and clickable")
 g.ITEM_PANEL.action(g,"atlas_recipe:E125-01");await shot("04-food-recipe")
 ck(TREE.current_recipe().id=="E125-01","new recipe selection preserves branch identity")
 g._close_item_details();g.overlay="";g.motion.modal_value=0;g.motion.modal_target=0
 ck(g.run==before and FileAccess.get_file_as_bytes(g.storage.root_path+"run.json")==disk,"read-only capture never mutates save")
 g.opponent=g.inventory.snapshot(g.run,"eco-native-opponent","组合验收");g.opponent.leader="hsin"
 g._start_battle();ck(g.run.phase=="battle","native battle starts through normal application")
 g.battle_entry_age=1;g.motion.transition_left=0;g.transition_image=null
 for frame in 420:
  g._process(1.0/60)
  if frame==419:await shot("05-live-combat")
 ck(g.combat.events.any(func(e):return e.kind=="guard"),"real parry events in native battle")
 ck(g.combat.events.any(func(e):return e.kind=="cooldown_advance" and e.get("source_uid","")=="porcelain"),"real echo relay events in native battle")
 g.paused=true;var frozen=g.combat_vfx.impacts.duplicate(true);g._process(.5)
 ck(g.combat_vfx.impacts==frozen,"paused combat freezes visuals")
 FileAccess.open(OUT+"capture.txt",FileAccess.WRITE).store_string("Hidden unfocusable native SubViewport, independent QA Storage. 8 icons, current detail values, recipe branch selection and 420 real combat presentation ticks. Failures: "+str(failures))
 g.queue_free();await process_frame
 print("NATIVE_ECOSYSTEM_V125 ",failures," failures");quit(1 if failures else 0)
