extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const C=preload("res://scripts/data/catalog.gd")
const SUPPORTS=preload("res://scripts/party/supports.gd")
var checks=0
var failures=0
func ck(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:
 AudioServer.set_bus_mute(0,true);call_deferred("test")
func test()->void:
 var g=G.new();root.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
 g.run.gold=100;g.run.round=3;g.run.shop[5]={"kind":"pouch","locked":false}
 var before=g.run.duplicate(true);g._action("bag_choice")
 ck(g.run==before,"stale bag-cycle input cannot replace the rolled bag")
 var retired=g.inventory.plan_set_bag_offer(g.run,"corner")
 ck(not retired.ok and g.run==before,"retired bag-selection API cannot bypass the shop roll")
 g.run.shop[5]={"kind":"pouch","locked":false};g._action("lock:5");ck(g.run.shop[5].get("locked",false),"bag offer can be locked normally")
 g._action("reroll");ck(g.run.shop[5].kind=="pouch","locked bag survives ordinary refresh")
 g._action("lock:5")
 var shapes={}
 for n in 80:
  g._commit_preparation(g.inventory.plan_refresh(g.run,false))
  shapes[g.run.shop[5].kind]=true
 ck(shapes.size()>=4,"natural rerolls still supply distinct pocket shapes")
 g.reset_slice();g.audio.requested.clear()
 var item=g.run.items[0];g.dragging=item.duplicate(true);g.drag_origin="board";g.drag_pressed=false;g.drag_distance=40
 g.mouse=g._sell_rect().get_center();g._mouse_up()
 ck(not g.run.items.any(func(p):return p.uid==item.uid),"sale fixture commits")
 ck(g.audio.requested.get("sell",0)==1 and g.audio.requested.get("drop",0)==0,"selling has one coin-return sound, not a placement sound")
 ck(g.audio.streams.has("sell"),"sale has a dedicated sampled sound")
 g.reset_slice();item=g.run.items[0];g.detail_item=item;g.detail_origin="board";g.item_selection_age=g.ITEM_SELECTION_DURATION*.5
 ck(g.has_method("_star_pose"),"stars share the selected item's display transform")
 if g.has_method("_star_pose"):
  var pose=g._star_pose(item,g.BOARD)
  var at=g._piece_position(item,g.BOARD,0)
  var actual=g._piece_pose(item,at,g._projection_for(item.kind,int(item.rotation),g.CELL),0)
  ck(pose.is_equal_approx(actual*Transform2D(0,at-g.BOARD-Vector2(item.x,item.y)*g.CELL)),"selected star positions use the identical item pose")
  ck(pose!=Transform2D.IDENTITY,"click actually lifts stars")
  var original=g.run.duplicate(true)
  for rotation in 4:
   var probe=item.duplicate(true);probe.rotation=rotation
   g._star_pose(probe,g.BOARD)
  ck(original==g.run,"display transforms never alter slots or inventory")
 var rules=preload("res://scripts/crafting/craft_rules.gd").new()
 ck(rules.has_method("recruitment_hint"),"signature requirements distinguish incompatible parties")
 if rules.has_method("recruitment_hint"):
  var def=C.items.weapon_21020086
  var hint=rules.recruitment_hint(def,C.roster,"fusion",[])
  ck(hint.compatible and hint.text=="已解锁","V113 signature accessible regardless of party element")
  hint=rules.recruitment_hint(def,C.roster,"glacio",[])
  ck(hint.compatible and hint.text=="已解锁","V113 matching owner is association, not a prerequisite")
 # Historical V113 paid-roster coverage: each signature owner was reachable.
 var old_inventory=preload("res://tests/fixtures/recruitment_fixture_v113.gd").new()
 for kind in C.items:
  var d=C.items[kind]
  if not d.get("strict_signature",false):continue
  var reachable=false
  for leader in C.selectable_leaders():
   var r=old_inventory.new_run(leader,32);r.round=2
   var candidates=SUPPORTS.candidates(r)
   for owner in d.get("signature_owner_ids",[]):
    if owner in candidates or owner==C.characters[leader].roster_id:reachable=true
  ck(reachable,"signature has a playable owner path: "+kind)
 ck(ResourceLoader.exists("res://scripts/ui/shop_presentation.gd"),"shop has a read-only benefit view")
 if ResourceLoader.exists("res://scripts/ui/shop_presentation.gd"):
  var view=load("res://scripts/ui/shop_presentation.gd")
  ck(view.benefits("whiff").any(func(v):return v[0]=="haste"),"迅捷 echo identifies haste at purchase time")
  ck(view.benefits("daily_tea").any(func(v):return v[0]=="haste"),"opening tea is not mislabelled as only generic material")
  ck(view.benefits("pouch")==[["shield","护盾"]],"bag explains regional bonus, not a star")
  for kind in C.items:
   ck(not view.benefits(kind).is_empty() and view.benefits(kind).size()<=2,"compact nonempty shop role: "+kind)
 var handler=preload("res://scripts/crafting/craft_handler.gd").new()
 ck(handler.has_method("shop_partners"),"shop detail exposes actual owned recipe partners")
 if handler.has_method("shop_partners"):
  g.reset_slice();g.run.shop=[{"kind":"whiff","locked":false},{},{},{},{},{}]
  var original=g.run.duplicate(true)
  var partners=handler.shop_partners(g.run,0,g.inventory)
  ck(partners.any(func(p):return p.kind=="w_sword"),"purchased echo points to the owned sword recipe")
  g.run.stash=g.run.items;g.run.items=[];g.run.primary=""
  for n in 20:g.run.stash.push_front(g.piece("tea","extra%d"%n,0,0))
  partners=handler.shop_partners(g.run,0,g.inventory)
  ck(partners.any(func(p):return p.kind=="w_sword"),"partner query includes nonvisible stash pages")
  g.run.stash=[];g.run.shop[1]={"kind":"w_sword","locked":false}
  ck(handler.shop_partners(g.run,0,g.inventory).is_empty(),"another unsold offer is not an owned partner")
 g.music.stop_all();g.audio.stop_all()
 g.queue_free();await process_frame
 await create_timer(.12).timeout
 print("FEEDBACK_V112 ",checks," checks, ",failures," failures");quit(1 if failures else 0)
