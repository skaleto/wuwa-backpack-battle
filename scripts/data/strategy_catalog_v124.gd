extends RefCounted
## Current combination design. Historical numeric profiles stay intact.
static var spec:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/items/strategy.json"))
static func apply(data:Dictionary)->Dictionary:
	var out=data.duplicate(true)
	for recipe in out.recipes:
		if spec.redirects.has(recipe.id):recipe.base=spec.redirects[recipe.id]
	out.recipes.append_array(spec.recipes.duplicate(true))
	for kind in spec.cores:
		var item=out.items[kind];var core=spec.cores[kind]
		var n=item.v75.duplicate(true)
		for key in ["healPeriod","healAmount","shieldPeriod","shieldAmount","noisePeriod","frostPeriod","hp","emergency","openingShield","charge","hasteEvery"]:n[key]=0
		n.material_effect={};n.combo_effects=[]
		n.merge(core.duplicate(true),true)
		n.route={"蓄力":"充能重击","连动":"迅捷联动","反击":"护盾反击"}[core.role]
		n.hps=float(n.healAmount)/float(n.healPeriod) if n.healPeriod>0 else 0.0
		n.sps=float(n.shieldAmount)/float(n.shieldPeriod) if n.shieldPeriod>0 else 0.0
		n.frostPS=1.0/float(n.frostPeriod) if n.frostPeriod>0 else 0.0
		n.noisePS=0.0
		item.v124=n;item.stars=core.stars.duplicate(true)
		item.target="";item.route=n.route
		item.damage=n.damage;item.cooldown=n.cd;item.stamina=n.stamina
		item.strategy={"role":core.role,"rule":core.rule}
		item.desc=core.ownExtra;item.adaptation_summary="本作改编 · "+core.ownExtra
	return out
