extends SceneTree
## Counterfactual diagnostics in an isolated process. No production files modified.
const I=preload("res://scripts/inventory/inventory.gd")
const C=preload("res://scripts/data/catalog.gd")
const B=preload("res://scripts/battle/battle.gd")
const OUT="res://build/qa/battle-review-v100/"
var inv=I.new()
func _initialize():call_deferred("probe")
func fight(a:Dictionary,b:Dictionary,remove_enemy_hp:float=0.0,own_echo_speed:float=0.0)->Dictionary:
	var engine=B.new();var ctx=engine.begin(a,b,1)
	ctx.states[1].hp-=remove_enemy_hp;ctx.states[1].max_hp-=remove_enemy_hp
	if own_echo_speed>0:ctx.bonuses[0].i16.speed+=own_echo_speed
	var winner=0;var duration=45.0
	for tick in range(1,451):
		var t=tick*.1;engine.step(ctx,t)
		if ctx.states[0].hp<=0 or ctx.states[1].hp<=0:
			winner=0 if ctx.states[0].hp<=0 and ctx.states[1].hp<=0 else 1 if ctx.states[1].hp<=0 else -1
			duration=t;break
	return {"winner":winner,"duration":snappedf(duration,.1),"hp":ctx.states.map(func(s):return snappedf(s.hp,.001)),"damage":ctx.totals.map(func(t):return t.damage),"attacks":ctx.local.map(func(s):return s),"end_progress":ctx.progress,"events":ctx.events}
func probe():
	var a=JSON.parse_string(FileAccess.get_file_as_string(OUT+"reported-fight.json")).build
	var b=JSON.parse_string(FileAccess.get_file_as_string(OUT+"enemy.json"))
	var report={}
	report.baseline=fight(a,b)
	report.enemy_without_lion_15hp=fight(a,b,15)
	report.enemy_without_both_hp_bonuses_23=fight(a,b,23)
	var changed=a.duplicate(true);changed.primary="i26"
	report.other_primary_same_items=fight(changed,b)
	changed=a.duplicate(true)
	for i in changed.items:
		if i.uid=="i26":i.kind="weapon_21020024"
	assert(inv.validate_ghost(changed))
	report.replace_fivestar_with_tier2_overture=fight(changed,b)
	changed=a.duplicate(true)
	for i in changed.items:
		if i.uid=="i24":i.kind="cyan_heron"
	assert(inv.validate_ghost(changed))
	report.replace_inferno_with_tier2_heron=fight(changed,b)
	var backups={}
	for kind in ["weapon_21020024","weapon_21020015"]:
		backups[kind]=C.items[kind].v75.duplicate(true)
		C.items[kind].v75.hasteEvery=0
	report.enemy_without_weapon_haste_only=fight(a,b)
	for kind in backups:C.items[kind].v75=backups[kind].duplicate(true)
	report.own_wankui_extra_5percent_speed=fight(a,b,0,.05)
	for kind in ["weapon_21020024","weapon_21020015"]:C.items[kind].v75.combo_effects=[]
	report.enemy_without_three_hit_bonus_only=fight(a,b)
	for kind in backups:C.items[kind].v75=backups[kind].duplicate(true)
	if fight(a,b)!=report.baseline:
		printerr("Temporary diagnostic overrides did not restore");quit(1);return
	FileAccess.open(OUT+"counterfactuals.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	for key in report:
		var r=report[key];print(key," winner ",r.winner," time ",r.duration," hp ",r.hp," damage ",r.damage)
	quit()
