extends SceneTree
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/inventory/inventory.gd")
var checks=0;var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
 var limits={1:2,2:3,3:4,4:4,5:5};var inv=I.new()
 for kind in C.items:
  var d=C.items[kind];var points=d.get("stars",[]);var unique={}
  ck(points.size()<=limits.get(int(d.rarity),5),"quality budget "+kind)
  for point in points:
   var key=str(point)
   ck(not unique.has(key) and point not in d.shape,"distinct external star "+kind);unique[key]=true
  if d.has("v75"):ck(C.profile(kind).stars==points,"one layout for UI and battle "+kind)
  var p=inv.make_piece(kind,"piece");var original=inv.stars(p)
  for turn in range(4):
   p.rotation=turn;ck(inv.stars(p).size()==original.size(),"rotation preserves budget "+kind)
 ck(C.items.whiff.stars.map(func(p):return Vector2i(p[0],p[1]))==[Vector2i(0,-1),Vector2i(0,-2)],"starter retains its distant weapon star")
 ck(C.items.echo_vanguard.stars.size()==2 and C.items.rocksteady.stars.size()==3 and C.items.echo_hecaton.stars.size()==4,"shield chain grows 2 to 3 to 4")
 ck(C.items.whiff.stars.size()==2 and C.items.cyan_heron.stars.size()==3 and C.items.echo_tianqui.stars.size()==4,"haste chain grows 2 to 3 to 4")
 for kind in ["tea","daily_tea","echo_spectro"]:ck(C.items[kind].stars.is_empty(),"no decorative stars without a star effect "+kind)
 print("STAR_GROWTH_V92 ",checks," checks, ",failures," failures");quit(1 if failures else 0)
