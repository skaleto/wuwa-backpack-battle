extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const B=preload("res://scripts/battle/battle.gd")
var inv=I.new()
var checks=0
var failures=0
func ck(ok,label):
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func build(specs:Array)->Dictionary:
	var r=inv.new_run("aemeath",123);r.items=[];r.bags=[];r.primary=""
	for y in [0,2,4]:
		for x in [0,3,6]:
			var bag=inv.make_piece("satchel","b%d_%d"%[x,y]);bag.x=x;bag.y=y;r.bags.append(bag)
	for a in specs:
		var it=inv.make_piece(a[0],a[1]);it.x=a[2];it.y=a[3];r.items.append(it)
	return r
func _initialize():
	var b=B.new();var enemy=build([["w_sword","enemy",0,0]])
	var r=build([["weapon_21020045","laser",1,1],["w_sword","partner",1,2]])
	var ctx=b.begin(r,enemy,5);var blade=r.items[0];var partner=r.items[1]
	ck(is_equal_approx(b.stamina_cost(ctx,0,blade),1.4),"high relay weapon pays explicit additional stamina")
	ctx.states[0].charge=0
	for n in 3:b.activate(ctx,0,blade,n+1);b.commit_pending(ctx,n+1)
	ctx.progress[0][partner.uid]=0;ctx.events=[]
	b.activate(ctx,0,blade,4);b.commit_pending(ctx,4)
	ck(ctx.events.any(func(e):return e.kind=="cooldown_advance" and e.get("source_uid","")==blade.uid and e.get("target_uid","")==partner.uid and is_equal_approx(e.actual_value,1.2)),"laser strengthened hit advances its actual star partner")
	ck(ctx.events.any(func(e):return e.uid==blade.uid and e.kind=="attack" and e.get("prepared",false)),"strengthened damage is explicit in replay")
	ck(ctx.events.any(func(e):return e.uid==blade.uid and e.kind=="trigger" and e.get("prepared",false)),"strengthened attack drives the existing audiovisual cue")
	var before=b.own(ctx,0,blade).duplicate(true)
	b.activate(ctx,0,blade,4.5,false,"derived");b.commit_pending(ctx,4.5)
	ck(b.own(ctx,0,blade)==before,"derived attack cannot feed its own preparation")
	r=build([["weapon_21010076","counter",1,1],["rocksteady","shield",1,2]])
	ctx=b.begin(r,enemy,5);ctx.states[0].shield=0;ctx.events=[]
	b.deal_v75_damage(ctx,1,enemy.items[0],3,1,true,"attack");b.commit_pending(ctx,1)
	ck(not ctx.events.any(func(e):return e.side==0 and e.kind=="counter"),"unblocked hit gives no counter")
	ctx.states[0].shield=30
	b.deal_v75_damage(ctx,1,enemy.items[0],3,2,true,"attack");b.commit_pending(ctx,2)
	b.deal_v75_damage(ctx,1,enemy.items[0],3,3,true,"attack");b.commit_pending(ctx,3)
	ck(ctx.events.any(func(e):return e.side==0 and e.kind=="counter" and is_equal_approx(e.value,8)),"two real blocks pay one Qianban counter")
	var count=ctx.events.filter(func(e):return e.side==0 and e.kind=="counter").size()
	b.deal_v75_damage(ctx,1,enemy.items[0],3,5,false,"counter");b.deal_v75_damage(ctx,1,enemy.items[0],3,6,false,"derived");b.commit_pending(ctx,6)
	ck(ctx.events.filter(func(e):return e.side==0 and e.kind=="counter").size()==count,"derived damage never bounces defensive counter")
	r=build([["weapon_21020106","yun",1,1],["zig","a",1,2],["whiff","b",3,2]])
	ctx=b.begin(r,enemy,5);ctx.states[0].haste=0;ctx.events=[]
	b.natural(ctx,0,r.items[1],"attack",1);b.natural(ctx,0,r.items[1],"attack",2)
	ck(ctx.states[0].haste==0,"one echo repeated cannot activate alternation")
	b.natural(ctx,0,r.items[2],"attack",3)
	ck(ctx.states[0].haste==1,"different star echo activates alternation once")
	r=build([["weapon_21020086","frost",1,1]])
	ctx=b.begin(r,enemy,5)
	ck(b.profile(r.items[0]).frostPeriod==7 and b.own(ctx,0,r.items[0]).clocks.has("frost"),"craft retains independent frost supply")
	r=build([["verdant","charged",1,1]])
	ctx=b.begin(r,enemy,5);ctx.states[0].shield=10;ctx.states[0].charge=6;ctx.events=[]
	b.activate(ctx,0,r.items[0],1);b.commit_pending(ctx,1)
	ck(is_equal_approx(ctx.states[0].shield,2),"shield conversion spends actual protection")
	ctx=b.begin(r,enemy,5);ctx.states[0].charge=0;ctx.states[1].shield=20;ctx.events=[]
	b.activate(ctx,0,r.items[0],1);b.commit_pending(ctx,1)
	ck(ctx.events.any(func(e):return e.kind=="break_shield" and e.uid=="charged" and is_equal_approx(e.value,8)),"Verdant breaks actual shields without needing a charged attack")
	ck(not inv.star_eligible({"kind":"weapon_21020106","uid":"a"},{"kind":"turtle","uid":"b"}),"nonattacking echo cannot light an attack-based star")
	# One enemy natural attack may contain six damage segments; only one block
	# occurrence is counted. The amount-based Steel counter still sums amounts.
	enemy=build([["dreamless","multi",0,0]])
	r=build([["weapon_21010076","counter",1,1]])
	ctx=b.begin(r,enemy,5);ctx.states[0].shield=100;ctx.events=[]
	b.activate(ctx,1,enemy.items[0],1);b.commit_pending(ctx,1)
	ck(ctx.events.filter(func(e):return e.kind=="attack" and e.side==1).size()==6,"fixture attacks in six real segments")
	ck(b.own(ctx,0,r.items[0]).get("core_blocks",0)==1 and not ctx.events.any(func(e):return e.kind=="counter" and e.side==0),"one multihit natural root counts one block")
	r=build([["verdant","core",1,1],["weapon_21040046","shield",1,2]]);r.leader="hsin"
	ctx=b.begin(r,enemy,5)
	ck(ctx.events.any(func(e):return e.kind=="charge" and e.uid=="core" and e.value>0),"opening shield can activate an eligible star")
	r=build([["weapon_21020086","frost",1,1],["w_sword","partner",1,2]])
	ctx=b.begin(r,enemy,5);ctx.states[1].frost_immune_until=20;ctx.events=[]
	for t in [1,2,3]:b.natural(ctx,0,r.items[1],"attack",t);b.commit_pending(ctx,t)
	ck(not ctx.events.any(func(e):return e.kind=="star_trigger") and b.own(ctx,0,r.items[0]).core_weapon==3,"immune enemy neither glows nor consumes prepared frost count")
	ck(not ctx.icd[0].has(r.items[0].kind+":core_frost"),"zero frost gain does not spend its interval")
	ctx.states[1].frost_immune_until=0;b.natural(ctx,0,r.items[1],"attack",4);b.commit_pending(ctx,4)
	ck(b.own(ctx,0,r.items[0]).core_weapon==0 and ctx.events.any(func(e):return e.kind=="frost"),"pending frost is paid on the next effective input")
	r=build([["weapon_21020104","wing",1,1],["zig","echo",1,2]])
	ctx=b.begin(r,enemy,5);ctx.states[0].charge=6;ctx.events=[]
	b.natural(ctx,0,r.items[1],"attack",1);b.natural(ctx,0,r.items[1],"attack",2)
	ck(b.own(ctx,0,r.items[0]).core_echo==2 and not ctx.events.any(func(e):return e.kind=="star_trigger"),"full charge retains the earned counter without false feedback")
	ctx.states[0].charge=0;b.natural(ctx,0,r.items[1],"attack",3)
	ck(ctx.states[0].charge==1 and b.own(ctx,0,r.items[0]).core_echo==0,"retained charge count pays when capacity exists")
	for side in 2:
		r=build([["weapon_21020086","frost",1,1],["w_sword","partner",1,2]]);r.leader="hsin"
		enemy=build([["w_sword","enemy",0,0]]);enemy.leader="hsin"
		ctx=b.begin(r if side==0 else enemy,enemy if side==0 else r,5)
		b.own(ctx,side,r.items[0]).core_weapon=2
		ctx.states[1-side].frost=4;ctx.states[1-side].frost_until=100
		ctx.states[0].charge=0;ctx.states[1].charge=0
		ctx.progress[side].partner=1;ctx.progress[1-side].enemy=1
		ctx.events=[];b.step(ctx,.01)
		ck(ctx.events.filter(func(e):return e.kind=="trigger" and e.uid=="enemy").size()==1,"same-tick freeze cannot cancel already-ready enemy attack on side "+str(side))
	print("CORE_COMBAT_V124 ",checks," checks, ",failures," failures");quit(1 if failures else 0)
