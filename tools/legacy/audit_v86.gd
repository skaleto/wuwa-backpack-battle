extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const C=preload("res://scripts/data/catalog.gd")
const B=preload("res://scripts/battle/battle.gd")
const P=preload("res://scripts/shop/practice_budget.gd")
var inv=I.new();var report={"reported":[],"components":[],"early":[]}
func summary(r):return {"winner":r.winner,"duration":r.duration,"hp":r.frames[-1].sides.map(func(s):return s.hp),"damage":r.totals.map(func(t):return t.damage),"wait":r.totals.map(func(t):return t.stamina_wait_seconds)}
func _initialize():call_deferred("audit")
func audit():
 var history=JSON.parse_string(FileAccess.get_file_as_string("res://build/qa/ui-v84/later-history.json"))
 var old_audit=JSON.parse_string(FileAccess.get_file_as_string("res://build/qa/ui-v84/battle-audit.json"))
 for h in history:
  if h.round>2:continue
  var enemy=old_audit[int(h.round)-1].matches[0].enemy
  var result=B.new().simulate(h.build,enemy,31,false)
  report.reported.append({"round":h.round,"fixed_original_enemy":true,"result":summary(result)})
 var specs=JSON.parse_string(FileAccess.get_file_as_string("res://data/compat/design/v86.json")).materials
 for k in specs:
  var material=inv.make_piece(k,"m");var weapon=inv.make_piece("w_sword","w");var echo=inv.make_piece("zig","e")
  weapon.y=1;echo.x=1
  var base={"leader":"aemeath","round":1,"items":[weapon,echo],"bags":[],"roster":[],"supports":[]}
  var single=base.duplicate(true);single.items.append(material)
  var duplicate=single.duplicate(true);var copy=material.duplicate(true);copy.uid="z-copy";duplicate.items.append(copy)
  var a=B.new().simulate(single,base,31,false);var b=B.new().simulate(duplicate,base,31,false)
  report.components.append({"kind":k,"single":summary(a),"duplicate":summary(b),"note":"controlled effects probe; no bag occupancy or acquisition claim"})
 for round_number in [1,2,3]:
  var outcomes={"wins":0,"losses":0,"draws":0};var count=0
  for seed_value in range(12):
   var a=P.build(inv,round_number,seed_value);var b=P.build(inv,round_number,seed_value+12)
   var result=B.new().simulate(a,b,31,false);var swapped=B.new().simulate(b,a,31,false)
   assert(result.winner==-swapped.winner)
   outcomes["wins" if result.winner==1 else "losses" if result.winner==-1 else "draws"]+=1;count+=1
  report.early.append({"round":round_number,"pairs":count,"outcomes":outcomes,"note":"public-budget synthetic builds; outcomes are diagnostic, not optimal-play win rates"})
 FileAccess.open("res://build/qa/gameplay-v86/balance-audit.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 print("V86 AUDIT ",JSON.stringify(report.reported)," early ",JSON.stringify(report.early))
 quit()
