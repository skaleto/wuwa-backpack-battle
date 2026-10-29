extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const C=preload("res://scripts/data/catalog.gd")
const V=preload("res://scripts/ui/items/star_feedback.gd")
const B=preload("res://scripts/battle/battle.gd")
const FILTERS=preload("res://scripts/battle/star_filters.gd")
var inv=I.new();var battle=B.new();var checks=0;var failures=0;var layouts=0
func ck(ok,label):
 checks+=1
 if not ok:
  failures+=1
  if failures<16:printerr("FAIL ",label)
func _initialize():
 var r=inv.new_run("aemeath",19);r.bags=[]
 for y in range(0,6,2):
  for x in range(0,8,2):
   var bag=inv.make_piece("pouch","b%d%d"%[x,y]);bag.x=x;bag.y=y;r.bags.append(bag)
 for kind in C.items:
  if C.items[kind].get("stars",[]).is_empty() or not C.items[kind].has("v75"):continue
  var source=inv.make_piece(kind,"source")
  for other in C.items:
   if not C.items[other].has("v75"):continue
   var target=inv.make_piece(other,"target")
   var matches=FILTERS.for_kind(kind).any(func(f):return battle.capability(target,f))
   # V124 echo stars require a real natural attack, so healing-only echoes
   # remain gray even though their broad capability category is still echo.
   if C.profile(kind).get("star_requires_attack",false) and (float(C.profile(other).get("damage",0))<=0 or float(C.profile(other).get("cd",0))<=0):matches=false
   if C.profile(kind).get("material_effect",{}).get("trigger","")=="star_attack" and float(C.profile(other).damage)<=0:matches=false
   ck(inv.star_eligible(source,target)==matches,"preparation and combat capability "+kind+" / "+other)
  for turn in 4:
   source.rotation=turn;source.x=2;source.y=2
   if not inv.can_place(source,[],r.bags):continue
   var stars=inv.stars(source)
   for other in C.items:
    if C.is_tag(other,"bag"):continue
    var target=inv.make_piece(other,"target");target.rotation=turn
    var placed=false
    for point in stars:
     target.x=point.x;target.y=point.y
     if inv.can_place(target,[source],r.bags):placed=true;break
    if not placed:continue
    layouts+=1
    var actual=inv.star_links(source,[source,target],r)
    var targets=actual.map(func(v):return {"uid":v.uid,"cells":inv.occupied(v)})
    var before=targets.duplicate(true);var markers=V.markers(stars,targets,56)
    var lit=markers.filter(func(m):return m.state=="lit")
    ck(lit.size()==actual.size(),"one real instance one visible star "+kind+" / "+other+" r"+str(turn))
    ck(lit.all(func(m):return m.cell in inv.occupied(target) and m.target_uid==target.uid),"no bright empty cell")
    ck(markers.all(func(m):return m.center==(Vector2(m.cell)+Vector2.ONE*.5)*56),"centered every rotation")
    ck(targets==before,"read-only geometry projection")
 print("CATALOG_FEEDBACK_V81 ",layouts," legal layouts, ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
