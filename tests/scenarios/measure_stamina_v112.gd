extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const B=preload("res://tests/scenarios/stamina_probe_v112.gd")
var inv=I.new()
func _initialize()->void:
 var rows=[]
 var cases={"单迅刀":["w_sword"],"双迅刀":["w_sword","w_sword"],"双长刃":["w_broadblade","w_broadblade"],"双刀加速":["w_sword","w_sword","whiff"],"三刀加速":["w_sword","w_sword","w_sword","whiff"],"四刀加速":["w_sword","w_sword","w_sword","w_sword","whiff"],"三刀加速带回耐减耗":["w_sword","w_sword","w_sword","whiff","rations","soup"]}
 for config in [[10.0,2.0],[6.0,1.0],[8.0,1.0],[6.0,1.2]]:
  var battle=B.new();battle.test_max=config[0];battle.test_regen=config[1]
  for title in cases:
   var r=inv.new_run("aemeath",19);r.items=[];r.bags=[]
   for kind in cases[title]:
    var item=inv.make_piece(kind,"t%d"%r.items.size());item.x=r.items.size()*9;r.items.append(item)
   var dummy=inv.new_run("aemeath",19);dummy.items=[];dummy.bags=[]
   var ctx=battle.begin(r,dummy,19);ctx.states[0].hp=10000;ctx.states[0].max_hp=10000;ctx.states[1].hp=10000;ctx.states[1].max_hp=10000
   var lowest=config[0]
   for tick in 300:
    battle.step(ctx,(tick+1)*.1);lowest=minf(lowest,ctx.states[0].stamina)
   var waits=ctx.events.filter(func(e):return e.side==0 and e.kind=="tired")
   var row={"max":config[0],"regen":config[1],"case":title,"min":snappedf(lowest,.01),"first_wait":waits[0].time if not waits.is_empty() else -1,"wait_seconds":snappedf(ctx.totals[0].stamina_wait_seconds,.01),"damage":snappedf(ctx.totals[0].damage,.1)}
   rows.append(row);print(row)
 FileAccess.open("res://build/qa/feedback-v112/stamina-probe.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"));quit()
