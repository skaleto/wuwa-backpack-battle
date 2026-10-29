extends SceneTree
const F=preload("res://scripts/ui/pockets/bag_fine_seams.gd")
const T=preload("res://scripts/ui/pockets/terminal_grid.gd")
const FIX=preload("res://tests/fixtures/bag_trial_fixture_v109.gd")
var checks=0
var failures=0
func ck(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:
 for turn in 4:
  for kind in ["pouch","pocket_long_l","pocket_long_j"]:
   var pieces=T.form_bags(FIX.touching(FIX.bag(kind,"a",turn),FIX.bag("pouch","b",turn),Vector2i.RIGHT,true))
   var before=pieces.duplicate(true);var together=F.layout(pieces,80)
   for piece in pieces:
    var separate=F.layout([piece],80)
    for face in separate.faces:
     var matching=together.faces.filter(func(p):return p.cell==face.cell)[0]
     ck(matching.corners==face.corners,"contact must retain each bag's own rounded ends "+kind+" / "+str(turn))
   ck(pieces==before,"display remains read-only")
   ck(together.faces.size()==T.inventory.coverage(FIX.touching(FIX.bag(kind,"a",turn),FIX.bag("pouch","b",turn),Vector2i.RIGHT,true)).size(),"no fake extra cells")
 # Cross-pocket placement is a logical rule, independent of the narrow visual crease.
 var inv=T.inventory;var run=inv.new_run("aemeath",19)
 run.bags=[{"kind":"satchel","uid":"a","x":0,"y":0,"rotation":0},{"kind":"pouch","uid":"b","x":3,"y":0,"rotation":0}]
 var sword=inv.make_piece("w_sword","s");sword.x=2;sword.y=0
 ck(inv.can_place(sword,[],run.bags),"weapon still crosses the join")
 print("JOINED_POCKETS_V132 ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
