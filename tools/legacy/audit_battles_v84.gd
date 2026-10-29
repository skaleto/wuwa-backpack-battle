extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const C=preload("res://scripts/data/catalog.gd")
const B=preload("res://scripts/battle/battle.gd")
const P=preload("res://scripts/shop/practice_budget.gd")
var inv=I.new()
func _initialize():call_deferred("audit")
func slim(result):
 return {"winner":result.winner,"duration":result.duration,"totals":result.totals,"final":result.frames[-1].sides,"used":result.used}
func audit():
 var history=JSON.parse_string(FileAccess.get_file_as_string("res://build/qa/ui-v84/later-history.json"));var report=[]
 for h in history:
  if h.round>2:continue
  var matches=[]
  for seed_value in range(31):
   var enemy=P.build(inv,int(h.round),seed_value)
   var result=B.new().simulate(h.build,enemy,31,false)
   if result.winner!=h.winner or not is_equal_approx(result.duration,h.duration):continue
   if not is_equal_approx(result.totals[0].damage,h.totals[0].damage) or not is_equal_approx(result.totals[1].damage,h.totals[1].damage):continue
   matches.append({"seed":seed_value,"enemy":enemy,"result":slim(result)})
  var row={"round":h.round,"matches":matches,"counterfactuals":[]}
  if not matches.is_empty():
   var enemy=matches[0].enemy
   for piece in h.build.items:
    if not C.is_tag(piece.kind,"weapon"):continue
    var build=h.build.duplicate(true);build.primary=piece.uid
    var ctx=B.new().begin(build,enemy,31)
    var weights={}
    for item in build.items:
     if C.is_tag(item.kind,"weapon"):weights[item.uid]=B.new().weapon_damage_weight(ctx,0,item)
    row.counterfactuals.append({"primary":C.items[piece.kind].name,"weights":weights,"result":slim(B.new().simulate(build,enemy,31,false))})
   var ctx=B.new().begin(h.build,enemy,31);row.opening=ctx.states
   row.opening_buffs=ctx.local[0]
   row.star_links={}
   for item in h.build.items:
    var partners=B.new().linked(ctx,0,item)
    if not partners.is_empty():row.star_links[item.uid]=partners.map(func(p):return p.uid)
  report.append(row)
  print("ROUND ",h.round," MATCHES ",matches.map(func(m):return m.seed))
  for x in row.counterfactuals:print(x.primary," => ",x.result.winner," hp ",x.result.final[0].hp," damage ",x.result.totals[0].damage," duration ",x.result.duration)
 FileAccess.open("res://build/qa/ui-v84/battle-audit.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 quit()
