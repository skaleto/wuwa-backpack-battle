extends SceneTree
const C=preload("res://scripts/data/catalog.gd")
const B=preload("res://scripts/battle/battle.gd")
var battle=B.new()
var checks=0
var failures=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL V75: ",label)
func near(a:float,b:float,label:String)->void:check(absf(a-b)<.001,label+" got %s expected %s"%[a,b])
func piece(kind:String,uid:String="",x:int=0,y:int=0)->Dictionary:return {"kind":kind,"uid":kind if uid=="" else uid,"x":x,"y":y,"rotation":0,"level":0,"tuning":""}
func build(items:Array=[],primary:String="")->Dictionary:return {"leader":"jiyan","round":1,"items":items,"primary":primary,"supports":[],"bags":[],"roster":[]}
func advance(ctx:Dictionary,t:float)->void:
	while ctx.time+.00001<t:battle.step(ctx,minf(t,ctx.time+.1))
func events(ctx:Dictionary,k:String,uid:String="")->Array:return ctx.events.filter(func(e):return e.kind==k and (uid=="" or e.uid==uid))
func _initialize()->void:
	check(C.SIMULATION_VERSION=="resonance-v128","version changes")
	var p=piece("w_broadblade","main")
	var ctx=battle.begin(build([p],"main"),build())
	ctx.states[0].charge=6
	advance(ctx,2.8)
	near(ctx.totals[0].damage,8*1.8,"V75 base plus charged bonus")
	var healer=piece("medical")
	ctx=battle.begin(build([healer]),build());ctx.states[0].hp=50
	advance(ctx,5.9);near(ctx.states[0].hp,50,"full independent medical period")
	advance(ctx,6);near(ctx.states[0].hp,53,"medical 3 per six seconds")
	ctx=battle.begin(build([piece("tea"),piece("tea","t2")]),build())
	near(ctx.states[0].max_hp,117,"same-origin HP highest")
	ctx=battle.begin(build([piece("echo_glacio")]),build())
	battle.apply_frost(ctx,0,p,1,0);near(ctx.totals[0].damage,0,"frost has no invented hit damage")
	print("BATTLE_V75: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
