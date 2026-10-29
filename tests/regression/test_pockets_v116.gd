extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const B=preload("res://scripts/battle/battle.gd")
const P=preload("res://scripts/inventory/pocket_rules.gd")
const C=preload("res://scripts/data/catalog.gd")
var inv=I.new()
var checks=0
var failures=0

func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)

func piece(kind:String,uid:String,x:int,y:int,rotation:int=0)->Dictionary:
	var result=inv.make_piece(kind,uid)
	result.merge({"x":x,"y":y,"rotation":rotation},true)
	return result

func build(item:Dictionary,bags:Array)->Dictionary:
	# Lynae's opening HP has no attack, haste or shield contribution to these probes.
	var result=inv.new_run("lynae",116)
	result.items=[] if item.is_empty() else [item]
	result.bags=bags;result.stash=[];result.primary=item.get("uid","") if C.is_tag(item.get("kind",""),"weapon") else ""
	result.shop=[{},{},{},{},{},{}];result.serial=200
	return result

# Rotate the complete arrangement, retaining real catalogue footprints and UIDs.
func rotated(run:Dictionary,turn:int)->Dictionary:
	var result=run.duplicate(true)
	var low=Vector2i(100,100)
	for bag in run.bags:
		for cell in inv.occupied(bag):
			var point=inv.rotated(cell,turn)
			low.x=mini(low.x,point.x);low.y=mini(low.y,point.y)
	for item in result.bags+result.items:
		var origin=Vector2i(100,100)
		for cell in inv.occupied(item):
			var point=inv.rotated(cell,turn)-low
			origin.x=mini(origin.x,point.x);origin.y=mini(origin.y,point.y)
		item.x=origin.x;item.y=origin.y;item.rotation=posmod(int(item.rotation)+turn,4)
	return result

func source_check(run:Dictionary,expected:int,label:String)->void:
	var before=run.duplicate(true)
	var item=run.items[0]
	var bonus=inv.pocket_bonus(item,run)
	ck(bonus.sources.size()==expected,label+" has one source per applied type")
	var stats=[]
	for source in bonus.sources:
		var bags=run.bags.filter(func(bag):return bag.uid==source.uid)
		ck(bags.size()==1 and source.kind==bags[0].kind,label+" identifies an actual bag")
		ck(not source.cells.is_empty() and source.cells.all(func(cell):return cell in inv.occupied(item) and cell in inv.occupied(bags[0])),label+" highlights only actual occupied contact cells")
		if source.stat!="shield":
			ck(source.stat not in stats and is_equal_approx(source.value,P.profile(source.kind).amount),label+" lists full unique-type value")
		stats.append(source.stat)
	ck(run==before and inv.pocket_bonus(item,run)==bonus,label+" preview is read-only and repeatable")

func contact_cases()->void:
	var cases=[
		{"kind":"strip","stat":"speed","full":piece("w_sword","i1",0,0),"partial":piece("w_sword","i1",2,0),"bags":[piece("strip","b1",0,0,1),piece("satchel","b2",3,0)]},
		{"kind":"travel","stat":"power","full":piece("w_sword","i1",0,0),"partial":piece("w_sword","i1",2,0),"bags":[piece("travel","b1",0,0),piece("satchel","b2",3,0)]},
		{"kind":"corner","stat":"power","full":piece("echo_bloom","i1",0,0),"partial":piece("echo_bloom","i1",1,1),"bags":[piece("corner","b1",0,0),piece("satchel","b2",0,2)]}
	]
	for spec in cases:
		for turn in 4:
			var full=rotated(build(spec.full,spec.bags),turn)
			var partial=rotated(build(spec.partial,spec.bags),turn)
			var label=spec.kind+" rotation "+str(turn)
			ck(inv.validate_run(full) and inv.validate_run(partial),label+" full and crossing placements are legal")
			var all_bonus=inv.pocket_bonus(full.items[0],full)
			var touch_bonus=inv.pocket_bonus(partial.items[0],partial)
			ck(is_equal_approx(all_bonus[spec.stat],P.profile(spec.kind).amount) and is_equal_approx(touch_bonus[spec.stat],all_bonus[spec.stat]),label+" partial and full contact grant the same complete bonus")
			ck(touch_bonus.sources[0].cells.size()<inv.occupied(partial.items[0]).size(),label+" case truly crosses bags")
			source_check(partial,1,label)
			var off=partial.duplicate(true)
			off.bags=off.bags.filter(func(bag):return bag.uid!="b1")
			ck(is_zero_approx(inv.pocket_bonus(off.items[0],off)[spec.stat]),label+" removing contact removes the bonus")
	ck(is_zero_approx(P.covered_value("strip",0,3)),"zero contact grants no speed")
	ck(is_equal_approx(P.covered_value("travel",1,6),.08),"one occupied contact grants complete weapon bonus")
	ck(is_equal_approx(P.covered_value("corner",1,6),.15),"one occupied contact grants complete echo bonus")

func type_cases()->void:
	var same=[
		build(piece("w_sword","i1",0,0),[piece("strip","b1",0,0),piece("strip","b2",1,0),piece("strip","b3",2,0)]),
		build(piece("w_sword","i1",2,0),[piece("travel","b1",0,0),piece("travel","b2",3,0)]),
		build(piece("echo_bloom","i1",1,1),[piece("corner","b1",0,0),piece("corner","b2",1,2)])
	]
	for run in same:
		ck(inv.validate_run(run),"same-type crossing fixture is legal")
		var bonus=inv.pocket_bonus(run.items[0],run)
		var profile=P.profile(run.bags[0].kind)
		ck(is_equal_approx(bonus.speed if profile.stat=="speed" else bonus.power,profile.amount),"multiple "+run.bags[0].kind+" pockets grant only one bonus")
		source_check(run,1,"same-type "+run.bags[0].kind)
		var reverse=run.duplicate(true);reverse.bags.reverse()
		var reversed_bonus=inv.pocket_bonus(reverse.items[0],reverse)
		ck(is_equal_approx(reversed_bonus.speed,bonus.speed) and is_equal_approx(reversed_bonus.power,bonus.power),"reordering same-type bags cannot change totals")
	var mixed=[
		build(piece("w_sword","i1",1,0),[piece("strip","b1",1,0),piece("travel","b2",2,0)]),
		build(piece("echo_bloom","i1",0,0),[piece("strip","b1",0,0,1),piece("corner","b2",0,1)])
	]
	for base in mixed:
		for turn in 4:
			var run=rotated(base,turn)
			ck(inv.validate_run(run),"mixed-type rotated crossing is legal")
			var bonus=inv.pocket_bonus(run.items[0],run)
			ck(is_equal_approx(bonus.speed,.1) and is_equal_approx(bonus.power,.08 if C.is_tag(run.items[0].kind,"weapon") else .15),"different types grant both complete bonuses")
			source_check(run,2,"mixed-type rotation "+str(turn))
	for spec in [["corner","w_sword"],["travel","echo_bloom"],["strip","nutrition"],["strip","mat_43020011"]]:
		var run=build(piece(spec[1],"i1",0,0),[piece(spec[0],"b1",0,0)])
		var bonus=inv.pocket_bonus(run.items[0],run)
		ck(is_zero_approx(bonus.speed) and is_zero_approx(bonus.power) and bonus.sources.is_empty(),"contact does not bypass applicability: "+spec[0]+"/"+spec[1])

func shield_cases()->void:
	var bags=[piece("pouch","b1",0,0),piece("satchel","b2",2,0),piece("satchel","b3",0,2),piece("pouch","b4",5,0)]
	for spec in [[0,0,8.0],[1,0,4.0],[1,1,2.0]]:
		var run=build(piece("heron","i1",spec[0],spec[1]),bags)
		ck(inv.validate_run(run),"shield occupied-cell fixture is legal")
		var bonus=inv.pocket_bonus(run.items[0],run)
		var shields=P.shields(run,inv)
		ck(bonus.sources.size()==1 and is_equal_approx(bonus.sources[0].value,spec[2]),"shield item preview still counts occupied cells")
		ck(shields.size()==1 and shields[0].uid=="b1" and is_equal_approx(shields[0].amount,spec[2]),"empty shield pocket contributes nothing")
		var battle=B.new();var ctx=battle.begin(run,build({},bags),116)
		ck(is_equal_approx(ctx.states[0].shield,spec[2]),"opening combat shield equals actual occupied cells")
	var split=build(piece("heron","i1",1,0),[piece("pouch","b1",0,0),piece("pouch","b2",2,0)])
	var shields=P.shields(split,inv)
	ck(inv.validate_run(split) and shields.size()==2 and is_equal_approx(shields[0].amount+shields[1].amount,8),"different shield pockets retain their own used-cell amounts")
	ck(inv.pocket_bonus(split.items[0],split).sources.size()==2,"shield preview preserves both real per-cell sources")
	var empty=build({},bags);empty.stash=[piece("heron","i1",0,0)]
	ck(P.shields(empty,inv).is_empty(),"stash contents and empty bag cells grant no shield")

func combat_sample(run:Dictionary)->Dictionary:
	var before=run.duplicate(true)
	var battle=B.new();var foe=build({},[piece("satchel","b9",0,0)])
	var ctx=battle.begin(run,foe,116)
	var item=run.items[0]
	var duration=float(ctx.timers[0][item.uid])
	for tick in range(1,int(ceil(duration*10))+1):battle.step(ctx,float(tick)*.1)
	ck(run==before,"actual combat keeps the preparation build unchanged")
	return {"cooldown":duration,"damage":float(ctx.totals[0].damage),"bonus":ctx.bonuses[0][item.uid],"events":ctx.events}

func combat_cases()->void:
	var single=build(piece("w_sword","i1",0,0),[piece("strip","b1",0,0,1),piece("satchel","b2",3,0)])
	var cross=single.duplicate(true);cross.items[0].x=2
	var a=combat_sample(single);var b=combat_sample(cross)
	ck(is_equal_approx(a.cooldown,1.62) and is_equal_approx(a.cooldown,b.cooldown) and is_equal_approx(a.damage,b.damage),"partial and full acceleration give the same actual first cooldown and damage")
	var many=build(piece("w_sword","i1",0,0),[piece("strip","b1",0,0),piece("strip","b2",1,0),piece("strip","b3",2,0)])
	var repeated=combat_sample(many)
	ck(is_equal_approx(repeated.cooldown,a.cooldown),"three speed pockets cannot shorten combat cooldown again")
	var full=build(piece("w_sword","i1",0,0),[piece("travel","b1",0,0),piece("satchel","b2",3,0)])
	var partial=full.duplicate(true);partial.items[0].x=2
	a=combat_sample(full);b=combat_sample(partial)
	ck(is_equal_approx(a.damage,4.32) and is_equal_approx(a.damage,b.damage),"partial and full weapon contact both deal exact complete-bonus damage")
	partial.bags[1].kind="travel";b=combat_sample(partial)
	ck(is_equal_approx(a.damage,b.damage),"two weapon pockets cannot increase actual attack damage again")
	full=build(piece("echo_bloom","i1",0,0),[piece("corner","b1",0,0),piece("satchel","b2",0,2)])
	partial=full.duplicate(true);partial.items[0].x=1;partial.items[0].y=1
	a=combat_sample(full);b=combat_sample(partial)
	ck(is_equal_approx(a.damage,4.6) and is_equal_approx(a.damage,b.damage),"partial and full echo contact both deal exact complete-bonus damage")
	var mixed=build(piece("w_rectifier","i1",2,1),[piece("travel","b1",0,0),piece("strip","b2",3,0),piece("pouch","b3",1,2)])
	ck(inv.validate_run(mixed),"three-effect combat fixture is legal")
	var before=mixed.duplicate(true);var battle=B.new();var ctx=battle.begin(mixed,build({},mixed.bags),116)
	ck(is_equal_approx(ctx.timers[0].i1,2.16) and is_equal_approx(ctx.bonuses[0].i1.multiplier,1.08) and is_equal_approx(ctx.states[0].shield,2),"speed, weapon and one real shield cell combine in actual battle")
	for tick in range(1,23):battle.step(ctx,float(tick)*.1)
	ck(is_equal_approx(ctx.totals[0].damage,5.4) and mixed==before,"combined contact grants exact attack damage without changing source build")

func _initialize()->void:
	contact_cases();type_cases();shield_cases();combat_cases()
	print("POCKETS_V116 ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
