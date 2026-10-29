extends SceneTree
## Offline replay inspection only. Never loads Storage or writes player data.
const I=preload("res://scripts/inventory/inventory.gd")
const C=preload("res://scripts/data/catalog.gd")
const B=preload("res://scripts/battle/battle.gd")
const P=preload("res://scripts/shop/practice_budget.gd")
const FEEDBACK=preload("res://scripts/ui/battle/battle_feedback.gd")
const OUT="res://build/qa/battle-review-v100/"
var inv=I.new()
func _initialize():call_deferred("audit")
func write(name:String,value)->void:
	FileAccess.open(OUT+name,FileAccess.WRITE).store_string(JSON.stringify(value,"\t"))
func summary(result:Dictionary)->Dictionary:
	return {"winner":result.winner,"duration":result.duration,"totals":result.totals,"final":result.frames[-1].sides}
func same_recorded(a,b)->bool:
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size():return false
		for key in a:
			if not b.has(key) or not same_recorded(a[key],b[key]):return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size():return false
		for i in a.size():
			if not same_recorded(a[i],b[i]):return false
		return true
	if (a is float or a is int) and (b is float or b is int):return absf(float(a)-float(b))<.000001
	return a==b
func audit():
	var h=JSON.parse_string(FileAccess.get_file_as_string(OUT+"reported-fight.json"))
	var matches=[]
	var candidates=[]
	var engine=B.new()
	for seed_value in range(31):
		if C.selectable_leaders()[seed_value%C.selectable_leaders().size()]!="qingxiao":continue
		var enemy=P.build(inv,int(h.round),seed_value,"focused")
		var result=engine.simulate(h.build,enemy,1,true)
		candidates.append({"seed":seed_value,"leader":enemy.leader,"result":summary(result)})
		if result.winner!=h.winner or not is_equal_approx(result.duration,h.duration):continue
		if not is_equal_approx(result.totals[0].damage,h.totals[0].damage) or not is_equal_approx(result.totals[1].damage,h.totals[1].damage):continue
		if not same_recorded(result.totals,h.totals):continue
		matches.append({"seed":seed_value,"enemy":enemy,"result":result})
	write("candidate-matches.json",candidates)
	if matches.size()!=1:
		printerr("Expected one exact recorded-totals match, got ",matches.size());quit(1);return
	var enemy=matches[0].enemy
	var result=matches[0].result
	write("enemy.json",enemy);write("replay.json",result)
	var ctx=engine.begin(h.build,enemy,1)
	var rows=[]
	for side in 2:
		var build=[h.build,enemy][side]
		for item in build.items:
			var d=C.items[item.kind];var events=result.events.filter(func(e):return e.side==side and e.uid==item.uid)
			rows.append({"side":side,"uid":item.uid,"kind":item.kind,"name":d.name,"tier":d.get("rarity",0),"cells":d.shape.size(),"profile":d.get("v75",{}),"pocket_bonus":inv.pocket_bonus(item,build),"links":engine.linked(ctx,side,item).map(func(p):return {"uid":p.uid,"kind":p.kind,"name":C.items[p.kind].name}),"contribution":FEEDBACK.contribution(result.events,side,item.uid,INF),"triggers":events.filter(func(e):return e.kind=="trigger"),"events":events})
	write("item-analysis.json",rows)
	write("summary.json",{"exact_recorded_totals":true,"practice_seed":matches[0].seed,"opening":ctx.states,"result":summary(result),"absorbed":[FEEDBACK.absorption(result.events,0),FEEDBACK.absorption(result.events,1)],"star_triggers":[FEEDBACK.stars(result.events,0),FEEDBACK.stars(result.events,1)]})
	print("EXACT REPLAY MATCH seed ",matches[0].seed,"; ",result.duration,"s; totals ",result.totals.map(func(t):return t.damage))
	quit()
