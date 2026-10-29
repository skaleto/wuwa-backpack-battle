extends SceneTree
const G=preload("res://scripts/game.gd")
const F=preload("res://scripts/crafting/craft.gd")
var checks=0;var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
 var game=G.new();var inv=game.inventory;var r=inv.new_run("aemeath",19)
 var cover=inv.make_piece("satchel","cover");cover.x=2;cover.y=2;r.bags.append(cover)
 var source=inv.make_piece("weapon_21020024","sword");source.x=1;source.y=3;source.rotation=2
 var echo=inv.make_piece("heron","echo");echo.x=3;echo.y=1
 var stars=inv.stars(source);var items=[source,echo];var before=r.duplicate(true)
 ck(inv.star_links(source,items,r).size()==1,"screenshot two cells have one real linked item")
 var lit=stars.filter(func(p):return game._effect_star_state(source,items,p,r)=="lit")
 ck(lit.size()==1,"two-cell echo lights only one representative star")
 ck(stars.filter(func(p):return game._effect_star_state(source,[source],p,r)!="unlit").is_empty(),"all empty stars are grey")
 var states=stars.map(func(p):return game._effect_star_state(source,items,p,r))
 ck(states==stars.map(func(p):return game._effect_star_state(source,[echo,source],p,r)),"representative does not flicker with inventory order")
 var second=inv.make_piece("zig","echo2");second.x=1;second.y=2;items.append(second)
 ck(inv.star_links(source,items,r).size()==2 and stars.filter(func(p):return game._effect_star_state(source,items,p,r)=="lit").size()==2,"two unique echoes light two stars")
 var wrong=inv.make_piece("mat_43020031","wrong");wrong.x=1;wrong.y=2
 ck(game._effect_star_state(source,[source,wrong],Vector2i(1,2),r)=="unlit","wrong category stays grey")
 ck(r==before,"feedback does not mutate state")
 for turn in 4:
  var rotated=source.duplicate(true);rotated.rotation=turn;rotated.x=2;rotated.y=2
  var positions=inv.stars(rotated);var a=inv.make_piece("zig","a");var b=inv.make_piece("zig","b")
  a.x=positions[0].x;a.y=positions[0].y;b.x=positions[1].x;b.y=positions[1].y
  ck(positions.filter(func(p):return game._effect_star_state(rotated,[rotated,a,b],p,r)=="lit").size()==2,"distinct same-kind targets count through rotation "+str(turn))
 ck(game.has_method("_effect_star_markers"),"draw uses shared marker projection")
 if game.has_method("_effect_star_markers"):
  var rows=game._effect_star_markers(source,items,r)
  ck(rows.filter(func(v):return v.state=="lit").size()==2,"shared markers count unique matches")
  for row in rows:ck(row.center==(Vector2(row.cell)+Vector2.ONE*.5)*game.CELL,"every marker is cell-centered")
 # Exact pair from screenshots: direction does not prevent adjacency.
 r=inv.new_run("aemeath",19);r.shop=[{},{},{},{},{},{}];r.serial=20
 source=inv.make_piece("weapon_21020024","i1");source.x=1;source.y=1;source.rotation=2
 echo=inv.make_piece("zig","i2");echo.x=2;echo.y=0
 var corner=inv.make_piece("corner","b2");corner.x=3;r.bags.append(corner)
 r.items=[source,echo];r.stash=[];r.primary="i1"
 ck(inv.validate_run(r) and inv.adjacent(source,echo),"screenshot pair is legal and adjacent")
 for turn in [1,2,3]:
  r.round=turn;before=r.duplicate(true);var p=F.preview(r,"weapon_21020015","i1",inv)
  ck(p.ok and r==before,"owned screenshot pair can craft at round "+str(turn))
 r.round=4;var ready=F.ready_options(r,inv).filter(func(v):return v.target=="weapon_21020015")
 ck(ready.size()==1,"same layout remains ready at round four")
 if not ready.is_empty():ck(F.commit_ready(r,ready[0],inv).ok and inv.validate_run(r),"round four exact recipe commits")
 print("STARS_V80 ",checks," checks, ",failures," failures")
 game.free();quit(1 if failures else 0)
