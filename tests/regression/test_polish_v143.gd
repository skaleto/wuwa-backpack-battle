extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const P=preload("res://scripts/inventory/pocket_rules_current.gd")
const LIFE=preload("res://scripts/run/run_lifecycle.gd")
const NET=preload("res://scripts/online/async_pvp.gd")
const B=preload("res://scripts/battle/battle.gd")
const STATUS=preload("res://scripts/ui/battle/battle_status_view.gd")
const RECYCLE=preload("res://scripts/ui/shop_recycle_view.gd")
const QL=preload("res://scripts/ui/chibi_layout.gd")
const D=preload("res://scripts/ui/items/item_description.gd")
const S=preload("res://scripts/storage/storage.gd")
class Probe:
 extends "res://tests/fixtures/travel_fixture_v64.gd"
 var drawn_kind=""
 var drawn_rect=Rect2()
 func _draw_shop_item(kind:String,rect:Rect2,_alpha:float)->void:
  drawn_kind=kind;drawn_rect=rect
var inv=I.new()
var failures=0
func ck(ok:bool,label:String):
 if not ok:failures+=1;printerr("FAIL ",label)
func piece(kind:String,uid:String,x:int=0,y:int=0,rotation:int=0)->Dictionary:
 var p=inv.make_piece(kind,uid);p.x=x;p.y=y;p.rotation=rotation;return p
func _initialize():call_deferred("test")
func test():
 var old=inv.new_run("lynae",143);var run=LIFE.start("lynae",143,inv).run
 ck(not old.has("pocket_version") and run.pocket_version==143,"new gameplay explicitly opts into pocket rules; old snapshots unchanged")
 var blade=piece("w_sword","i1")
 run.items=[blade];run.bags=[piece("pocket_single","b1")]
 ck(P.shields(run,inv)==[{"uid":"b1","amount":3.0}],"one occupied single cell provides opening shield")
 var legacy=run.duplicate(true);legacy.erase("pocket_version")
 ck(P.shields(legacy,inv).is_empty(),"old single pocket retains capacity only")
 var engine=B.new();var ctx=engine.begin(run,run,143);var old_ctx=engine.begin(legacy,legacy,143)
 ck(is_equal_approx(ctx.states[0].shield-old_ctx.states[0].shield,3),"actual battle receives small-pocket opening shield")
 run.items=[];ck(P.shields(run,inv).is_empty(),"empty single pocket does not grant free shield")
 run.items=[blade]
 run.bags=[piece("pocket_double","b1")]
 ck(is_equal_approx(P.bonus(blade,run,inv).speed,.06),"double pocket reduces cooldown by six percent")
 for turn in 4:
  run.bags=[piece("pocket_long_l","b1",0,0,turn)]
  var cell=inv.occupied(run.bags[0])[0];blade.x=cell.x;blade.y=cell.y
  ck(is_equal_approx(P.bonus(blade,run,inv).power,.06),"long L weapon bonus works on contact after rotation "+str(turn))
 blade.x=0;blade.y=0
 run.bags=[piece("pocket_long_j","b1",0,0)]
 ck(is_equal_approx(P.bonus(blade,run,inv).power,0),"echo pocket does not strengthen a weapon")
 var echo=piece("whiff","i2",1,0)
 ck(is_equal_approx(P.bonus(echo,run,inv).power,.10),"mirrored long L strengthens touching echo")
 run.bags=[piece("pocket_double","b1"),piece("strip","b2",1,0)]
 var first=P.bonus(blade,run,inv).speed;run.bags.reverse()
 ck(is_equal_approx(first,.10) and is_equal_approx(P.bonus(blade,run,inv).speed,first),"strongest same-type effect wins independently of bag ordering")
 run=LIFE.start("lynae",143,inv).run
 var ghost=inv.snapshot(run,"qa");var copy=JSON.parse_string(JSON.stringify(ghost))
 ck(inv.validate_ghost(copy) and copy.pocket_version==143,"snapshot survives JSON with explicit pocket version")
 var older=ghost.duplicate(true);older.erase("pocket_version")
 for sample in [run,old]:
  var frozen=NET.freeze(inv,sample,"alice","qa-polish")
  var pool=NET.pool_id(sample)
  var key=NET.object_key(pool,1,0,"alice","qa-polish",frozen.sha256)
  ck(NET.decode(inv,frozen.bytes,key,pool,1).ok,"wire roundtrip works for current and legacy optional versions")
 ck(NET.pool_id(older)!=NET.pool_id(ghost),"new pocket abilities never enter legacy online pool")
 copy.pocket_version=144;ck(not inv.validate_ghost(copy),"unknown pocket rules rejected")
 ck("3" in D.effects("pocket_single",run)[0] and "扩展" in D.effects("pocket_single",old)[0],"item details follow the actual run version")
 var files=S.new("user://qa-polish143-"+str(OS.get_process_id())+"/")
 ck(files.save(run) and files.resume().pocket_version==143,"save reload retains rule version")
 ck(NET.pool_id(files.opponent(run))==NET.pool_id(run),"practice opponent shares new rule identity")
 ck(NET.pool_id(files.practice_opponent(run))==NET.pool_id(run),"async fallback shares new rules")
 var statuses=[]
 for key in ["charge","haste","noise","frost","freeze"]:statuses.append({"id":key,"stacks":3,"remaining":4.5})
 for side in 2:
  var chips=STATUS.chips(side,statuses)
  ck(not STATUS.health(side).intersects(STATUS.stamina(side)),"vital bars separate")
  for n in chips.size():
   ck(not chips[n].rect.intersects(STATUS.stamina(side)) and chips[n].rect.end.y<460,"status cannot overlap stamina or board")
   ck(not chips[n].label.is_empty() and not chips[n].detail.is_empty(),"all combat statuses have readable meanings")
   if n>0:ck(not chips[n].rect.intersects(chips[n-1].rect),"status chips do not overlap")
 ck(RECYCLE.accepts(blade,"board") and RECYCLE.accepts(blade,"stash") and not RECYCLE.accepts(blade,"shop"),"unbought goods cannot open sell box")
 ck(RECYCLE.pose(QL.SELL,1).lid.position.y<RECYCLE.pose(QL.SELL,0).lid.position.y,"lid opens independently of box")
 ck(QL.SHOP.encloses(QL.SELL) and not QL.SELL.intersects(QL.REFRESH) and not QL.SELL.intersects(QL.CATALOGUE),"recycle box occupies a clear part of shop")
 var g=Probe.new();root.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
 g.dragging=piece("pocket_single","preview");g.drag_origin="shop";g.drag_offer_index=0;g.drag_pressed=true;g.drag_rotated=false;g.drag_distance=0
 g.mouse=g._shop_icon_rect(0).get_center();g.drag_press_at=g.mouse
 g._draw_drag()
 ck(g.drawn_kind=="pocket_single" and g.drawn_rect.size==g._shop_icon_rect(0).size,"shop press uses fixed-pitch shelf rendering, not generic full-size bag rendering")
 # Exercise real drag release: refund exactly once, and remove only the sold item.
 g.dragging=g.run.items[0].duplicate(true);g.drag_origin="board";g.drag_pressed=false
 var uid=g.dragging.uid;var gold=g.run.gold;var refund=inv.resale_value(g.dragging)
 g.mouse=QL.SELL.get_center();g._mouse_up()
 ck(g.run.gold==gold+refund and inv.find_piece(g.run,uid).is_empty(),"drop in recycle box performs original atomic sell transaction")
 var sold=g.run.duplicate(true);g._mouse_up();ck(g.run==sold,"empty second release cannot sell twice")
 g.queue_free();await process_frame
 print("POLISH143 failures=",failures);quit(1 if failures else 0)
