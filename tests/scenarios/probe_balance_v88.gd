extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const B=preload("res://scripts/battle/battle.gd")
const C=preload("res://scripts/data/catalog.gd")
var inv=I.new()
func build(specs):
 var r=inv.new_run("aemeath",19);r.items=[];r.bags=[];r.stash=[];r.shop=[{},{},{},{},{},{}];r.primary=""
 for y in [0,2,4]:
  for x in [0,3]:
   var p=inv.make_piece("satchel","bag_%d_%d"%[x,y]);p.x=x;p.y=y;r.bags.append(p)
 var n=0
 for s in specs:
  var p=inv.make_piece(s[0],"piece"+str(n));p.x=s[1];p.y=s[2];r.items.append(p);n+=1
 return r
func _initialize():
 var enemy=build([["w_sword",1,1],["whiff",2,2]])
 var cases={
 "haste_parts":[["w_sword",1,1],["whiff",2,2]],
 "haste_stage1":[["weapon_21020024",1,1]],
 "haste_stage1_plus_stage2_input":[["weapon_21020024",1,1],["zig",1,2]],
 "haste_stage2":[["weapon_21020015",0,1]],
 "heavy_parts":[["w_broadblade",1,1],["spicy_meat",1,2]],
 "heavy_stage1":[["weapon_21010104",1,1]],
 "heavy_stage1_plus_stage2_input":[["weapon_21010104",1,1],["mat_42300050",1,2]],
 "heavy_stage2":[["weapon_21010036",0,1]],
 "guard_parts":[["w_gauntlet",1,1],["maocai",1,2]],
 "guard_stage1":[["weapon_21040064",1,1]],
 "guard_stage1_plus_stage2_input":[["weapon_21040064",1,1],["lamp",3,1]],
 "guard_stage2":[["weapon_21040046",1,1]],
 "heavy_partner_near":[["w_broadblade",1,1],["zig",1,2]],
 "heavy_partner_behind":[["w_broadblade",1,1],["zig",1,0]],
 "haste_partner_near":[["w_sword",1,1],["whiff",2,2]],
 "haste_partner_far":[["w_sword",1,1],["whiff",2,3]],
 "guard_linked":[["w_gauntlet",1,1],["echo_glacio",1,2]],
 "guard_apart":[["w_gauntlet",1,1],["echo_glacio",4,3]],
 }
 var report={"scope":"Fixed 20s with high HP, neutral identical leader/bags. Not win rates. Includes consumed ingredients and lost capabilities.","cases":{}}
 for name in cases:
  var a=build(cases[name]);var b=B.new();var ctx=b.begin(a,enemy,31)
  for s in ctx.states:s.hp=9900;s.max_hp=10000
  for n in range(1,201):b.step(ctx,n*.1)
  var totals=ctx.totals[0]
  report.cases[name]={"items":cases[name],"damage":totals.damage,"heal":totals.heal,"shield":totals.shield,"hp_loss":9900-float(ctx.states[0].hp),"charge_attacks":ctx.events.filter(func(e):return e.side==0 and e.kind=="trigger" and e.get("charged",false)).size(),"star_events":ctx.events.filter(func(e):return e.side==0 and e.kind=="star_trigger").size(),"counter_damage":ctx.events.filter(func(e):return e.side==0 and e.kind=="counter").reduce(func(total,e):return total+float(e.value),0.0),"cells":a.items.reduce(func(total,p):return total+C.items[p.kind].shape.size(),0),"price":a.items.reduce(func(total,p):return total+int(C.items[p.kind].v75.get("cost",0)),0)}
 var duels={}
 var builds={"heavy":build([["weapon_21010036",0,1]]),"haste":build([["weapon_21020015",0,1]]),"guard":build([["weapon_21040064",1,1],["echo_glacio",1,2]])}
 for a in builds:
  duels[a]={}
  for b in builds:
   var result=B.new().simulate(builds[a],builds[b],31,false)
   duels[a][b]={"winner":result.winner,"duration":result.duration,"totals":result.totals}
 report.equal_eight_coin_duels=duels
 var route_sets={
  "six_coin_starters":{"heavy":build([["w_broadblade",1,1],["zig",1,2]]),"haste":build([["w_sword",1,1],["whiff",2,2]]),"guard":build([["w_gauntlet",1,1],["echo_glacio",1,2]])},
  "ten_to_eleven_coin_synergies":{"heavy_break":build([["weapon_21010036",0,1],["wuka",0,2]]),"haste_echo":build([["weapon_21020015",0,1],["whiff",0,2]]),"guard_counter":build([["weapon_21040046",1,1]])}
 }
 report.route_duels={}
 for label in route_sets:
  var set_builds=route_sets[label];var results={}
  for a in set_builds:
   results[a]={}
   for other in set_builds:
    var result=B.new().simulate(set_builds[a],set_builds[other],31,false)
    results[a][other]={"winner":result.winner,"duration":result.duration}
  report.route_duels[label]=results
 FileAccess.open("res://build/qa/gameplay-v88/controlled-combos.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 print(JSON.stringify(report));quit()
