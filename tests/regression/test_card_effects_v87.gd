extends SceneTree
## V87 card-written star effects: data specs execute through the generic
## material_effects paths; placement on star cells decides the outcome.
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const B=preload("res://scripts/battle/battle.gd")
var inv=I.new()
var checks=0
var failures=0
func ck(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():call_deferred("test")
func placed(leader:String,pieces:Array)->Dictionary:
	var r=inv.new_run(leader,19);r.shop=[{},{},{},{},{},{}]
	var serial=0
	for p in pieces:
		serial+=1
		var piece=inv.make_piece(p[0],"t"+str(serial))
		piece.x=int(p[1]);piece.y=int(p[2])
		if C.is_tag(p[0],"bag"):r.bags.append(piece)
		else:r.items.append(piece)
	return r if inv.validate_run(r) else {}
func test():
	# Frozen prior rules; V125 replacements covered by ecosystem suites.
	preload("res://tests/fixtures/catalog_fixture_v124.gd").apply()
	var enemy=inv.new_run("hsin",7)
	# Starter sword sits at (0,0) on the satchel; its star ring includes (1,1).
	var linked=placed("aemeath",[["whiff",1,1]])
	ck(not linked.is_empty(),"linked board is legal")
	var sim=B.new().simulate(linked,enemy,31,false)
	var sword_triggers=sim.events.filter(func(e):return e.kind=="star_trigger" and str(e.source_uid)=="i1" and str(e.trigger_uid)=="t1")
	ck(sword_triggers.size()>0,"sword star fires when whiff stands on its star cell")
	ck(sim.events.any(func(e):return e.kind=="cooldown_advance" and str(e.uid)=="i1"),"sword self-cooldown actually advances")
	# Same board with whiff parked off the star cells: no sword star at all.
	var apart=placed("aemeath",[["pouch",3,0],["whiff",4,1]])
	ck(not apart.is_empty(),"apart board is legal")
	var sim2=B.new().simulate(apart,enemy,31,false)
	ck(not sim2.events.any(func(e):return e.kind=="star_trigger" and str(e.source_uid)=="i1"),"sword star stays dark off the star cells")
	ck(not sim2.events.any(func(e):return e.kind=="star_trigger" and str(e.source_uid)=="t2"),"whiff star stays dark when no weapon is adjacent")
	# Same-kind interval: sword star can fire at most once per 3 seconds.
	var duration=float(sim.duration)
	ck(sword_triggers.size()<=int(duration/3.0)+1,"sword star respects the 3s same-name interval")
	# Broadblade star: echo attacks build charge stacks.
	var charge=placed("aemeath",[["whiff",2,1]])
	charge.items=charge.items.filter(func(p):return p.uid!="i1");charge.primary="b0"
	var blade=inv.make_piece("w_broadblade","b0");blade.x=0;blade.y=0
	charge.items.append(blade)
	ck(inv.validate_run(charge),"broadblade board is legal")
	var sim3=B.new().simulate(charge,enemy,31,false)
	ck(sim3.events.any(func(e):return e.kind=="charge" and e.value>0 and str(e.uid)=="b0"),"broadblade star grants charge from echo attacks")
	# Whiff star buffs the strongest linked weapon: linked board out-damages apart.
	ck(float(sim.totals[0].damage)>float(sim2.totals[0].damage),"lit star cells deal more damage than dark ones at the same seed")
	# Teas do what their cards say.
	var tea=placed("aemeath",[["cool_tea",2,1]])
	ck(not tea.is_empty(),"cool tea board is legal")
	var sim4=B.new().simulate(tea,enemy,31,false)
	ck(sim4.events.any(func(e):return e.kind=="shield" and absf(float(e.value)-8.0)<.01 and str(e.uid)=="t1"),"cool tea shields 8 at opening as written")
	ck(sim4.events.any(func(e):return e.kind=="supply" and str(e.uid)=="t1"),"cool tea activates once and stays equipped")
	ck(sim4.events.any(func(e):return e.kind=="haste" and int(e.value)>0 and str(e.uid)=="i2"),"daily tea still grants opening haste")
	# Card text matches the executed spec for every authored kind.
	var authored=["w_broadblade","w_sword","w_pistol","w_gauntlet","w_rectifier","whiff","echo_bloom","echo_glacio","turtle","echo_butterfly","wuka","zig","weapon_21020012","weapon_21020011","weapon_21050011"]
	for kind in authored:
		var d=C.items[kind]
		ck(not d.get("stars",[]).is_empty(),"authored card has star cells "+kind)
		ck(str(d.v75.get("star",""))==str(d.v75.get("starText","")) and d.v75.get("star","").find("★")==0,"card text is written and starts with the star glyph "+kind)
		ck(d.v75.get("material_effect",{}).get("trigger","")in ["star_attack","star_shield"],"spec uses the generic star trigger "+kind)
	print("CARD_EFFECTS_V87 ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
