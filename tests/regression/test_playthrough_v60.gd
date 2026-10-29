extends SceneTree
## Acquisition tests: never overwrite shelves, gold, round, owned items or capacity.
## No Storage instance is created; normal saves and visual preferences are untouched.
const C = preload("res://scripts/data/catalog.gd")
const I = preload("res://scripts/inventory/inventory.gd")
const F = preload("res://scripts/crafting/craft.gd")
const PB = preload("res://scripts/shop/practice_budget.gd")
const B = preload("res://scripts/battle/battle.gd")
const REPORT = "/tmp/resonance-v60-playthrough-checks.json"
const ROUTES = [
	{"name":"charge", "seed":2, "target":"weapon_21020044", "wants":["mat_43020011","whiff","echo_jade_snake","electro_coin","spectro_coin","echo_vanguard"]},
	{"name":"haste", "seed":4, "target":"whiff_fast", "wants":["tuner","whiff","zig","contract","daily_tea","aero_coin"]},
	{"name":"shield_cleanse", "seed":5, "target":"turtle_clean", "wants":["tuner","turtle","flower","rocksteady","salt_tea","echo_aureate"]}
]
const PAIR_ACQUISITIONS = [
	{"name":"sword_pair", "seed":1, "target":"", "wants":["mat_43020011","mat_42300100","whiff","spectro_coin"]},
	{"name":"counter_pair", "seed":22, "target":"", "wants":["flower","violet","echo_soulfrayer"]},
	{"name":"cleanse_pair", "seed":3, "target":"", "wants":["glasses","contract","whiff","echo_glacio","echo_spectro"]}
]
var inv = I.new()
var checks = 0
var failures: Array = []
var samples: Array = []
var spatial_checks: Array = []
var acquired_builds: Dictionary = {}
var pair_acquisitions: Array = []
var pair_results: Array = []

func _initialize() -> void:
	call_deferred("run_tests")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL ", label)

func owned(run: Dictionary) -> Array:
	return run.items + run.stash

func audit(run: Dictionary, log: Dictionary, label: String) -> void:
	check(inv.validate_run(run), log.route + ": legal state after " + label)
	check(int(run.gold) == 9 + int(log.income) - int(log.spent), log.route + ": cash reconciles after " + label)
	check(run.pending_gifts.is_empty() and run.pending_rearrange.is_empty(), log.route + ": no hidden backlog after " + label)

func record(run: Dictionary, log: Dictionary, entry: Dictionary) -> void:
	entry.round = int(run.round)
	entry.gold_after = int(run.gold)
	log.ledger.append(entry)

func purchase(run: Dictionary, slot: int, log: Dictionary) -> bool:
	if run.shop[slot].is_empty(): return false
	var kind: String = run.shop[slot].kind
	var candidate = inv.make_piece(kind, "preview")
	var before = run.duplicate(true)
	candidate.x = 8
	candidate.y = 5
	check(inv.purchase_at(run, slot, candidate, "board").is_empty() and run == before, log.route + ": invalid shop drop is atomic")
	var price = inv.purchase_price(run, slot)
	var fit = inv.first_fit(inv.make_piece(kind, "preview"), run.items, run.bags)
	var item: Dictionary = {}
	var destination = "board"
	if not fit.is_empty():
		item = inv.purchase_at(run, slot, fit, "board")
	elif C.is_tag(kind, "craft_material"):
		destination = "stash"
		item = inv.purchase_at(run, slot, inv.make_piece(kind, "preview"), "stash")
	if item.is_empty():
		check(run == before, log.route + ": rejected purchase leaves state intact")
		return false
	check(int(before.gold) - int(run.gold) == price and run.shop[slot].is_empty(), log.route + ": shelf purchase charges once")
	check(int(run.serial) == int(before.serial) + 1, log.route + ": purchase allocates one identity")
	log.spent += price
	log.purchases.append(kind)
	record(run, log, {"action":"purchase", "kind":kind, "uid":item.uid, "slot":slot, "price":price, "destination":destination, "placement":[item.x,item.y,item.rotation]})
	audit(run, log, "purchase")
	return true

func refresh(run: Dictionary, log: Dictionary) -> void:
	var before = run.duplicate(true)
	var expected = 0 if int(run.refreshes) == 0 else 1
	if inv.refresh(run, true):
		check(int(before.gold) - int(run.gold) == expected, log.route + ": refresh follows public price")
		log.spent += expected
		record(run, log, {"action":"refresh", "price":expected})
		audit(run, log, "refresh")
	else:
		check(run == before, log.route + ": unaffordable refresh is atomic")

# Forge's material purchase button is a public, round-gated purchase path.
# Prioritize an owned base's exact missing inputs, recording their real price.
func buy_target_materials(run: Dictionary, target: String, log: Dictionary) -> void:
	if target.is_empty() or target in log.fusions: return
	var recipes = C.combinations.filter(func(recipe): return recipe.target == target)
	if recipes.size() != 1: return
	var recipe: Dictionary = recipes[0]
	if int(run.round) < int(recipe.round_min) or not owned(run).any(func(piece): return piece.kind == recipe.base): return
	for kind in recipe.materials:
		var needed = recipe.materials.count(kind) + (1 if recipe.base == kind else 0)
		if owned(run).filter(func(piece): return piece.kind == kind).size() >= needed: continue
		if not C.is_tag(kind,"craft_material") or int(run.round) < int(C.items[kind].round_min): continue
		var price = int(C.items[kind].price)
		if int(run.gold) < price: continue
		var before = run.duplicate(true)
		var bought = F.buy_material(run,kind,inv)
		check(bought,log.route + ": public forge purchase accepts affordable unlocked material")
		if not bought:
			check(run == before,log.route + ": rejected forge purchase is atomic")
			continue
		check(int(before.gold) - int(run.gold) == price and run.shop == before.shop,log.route + ": public material purchase charges full price without overwriting shelves")
		check(int(run.serial) == int(before.serial) + 1 and run.stash.size() == before.stash.size() + 1,log.route + ": public material purchase allocates exactly one stored item")
		log.spent += price
		log.purchases.append(kind)
		record(run,log,{"action":"material_purchase","source":"forge_material_button","kind":kind,"uid":run.stash[-1].uid,"price":price,"destination":"stash"})
		audit(run,log,"public material purchase")

func craft_target(run: Dictionary, target: String, log: Dictionary) -> void:
	if target.is_empty(): return
	var recipes = C.combinations.filter(func(r): return r.target == target)
	check(recipes.size() == 1, "unique exact recipe " + target)
	if recipes.size() != 1: return
	var recipe: Dictionary = recipes[0]
	if int(run.round) < int(recipe.round_min): return
	for base in run.items.duplicate(true):
		if base.kind != recipe.base: continue
		if not recipe.materials.all(func(k): return owned(run).filter(func(p): return p.kind == k and p.uid != base.uid).size() >= recipe.materials.count(k)): continue
		for kind in recipe.materials:
			var placement = F.place_material(run, target, base.uid, kind, inv)
			if placement.ok:
				record(run, log, {"action":"place_material", "uid":placement.item.uid, "base_uid":base.uid})
		var before = run.duplicate(true)
		var preview = F.preview(run, target, base.uid, inv)
		check(run == before, log.route + ": craft preview has no side effects")
		if not preview.ok:
			record(run, log, {"action":"craft_blocked", "target":target, "reason":preview.reason})
			continue
		var consumed_kinds = before.items.filter(func(p): return p.uid in preview.consumed).map(func(p): return p.kind)
		var expected: Array = [recipe.base] + recipe.materials
		consumed_kinds.sort()
		expected.sort()
		check(consumed_kinds == expected and preview.consumed.size() == expected.size(), log.route + ": exact distinct recipe inputs")
		check(not F.transact(run, target, base.uid, inv, {"x":8,"y":5,"rotation":0}).ok and run == before, log.route + ": invalid fusion output is atomic")
		var output: Dictionary = preview.output
		var transaction = F.transact(run, target, base.uid, inv, {"x":output.x,"y":output.y,"rotation":output.rotation})
		check(transaction.ok, log.route + ": explicitly confirmed output placement")
		if not transaction.ok: continue
		check(int(run.gold) == int(before.gold), log.route + ": fusion adds no hidden fee")
		check(owned(run).all(func(p): return p.uid not in preview.consumed), log.route + ": consumed identities removed")
		check(run.items.any(func(p): return p.uid == output.uid and p.kind == target), log.route + ": exact output is on board")
		log.fusions.append(target)
		record(run, log, {"action":"fusion", "recipe":recipe.id, "target":target, "consumed":preview.consumed, "output_uid":output.uid})
		audit(run, log, "fusion")
		return

func bonds(run: Dictionary) -> int:
	var total = 0
	for item in run.items:
		total += inv.star_links(item, run.items, run).size()
	return total

func arrange(run: Dictionary, log: Dictionary) -> void:
	for item in run.stash.duplicate(true):
		var fit = inv.first_fit(item, run.items, run.bags)
		if not fit.is_empty():
			check(inv.place(run, fit), log.route + ": acquired stash item placed legally")
	# Search previews on copies; commit each actual move through Inventory.place.
	for item in run.items.duplicate(true):
		var best: Dictionary = item
		var best_score = bonds(run)
		var before_score = best_score
		for rotation in 4:
			for y in inv.HEIGHT:
				for x in inv.WIDTH:
					var candidate = item.duplicate(true)
					candidate.merge({"x":x,"y":y,"rotation":rotation}, true)
					if not inv.can_place(candidate, run.items, run.bags): continue
					var preview = run.duplicate(true)
					if not inv.place(preview, candidate): continue
					var score = bonds(preview)
					if score > best_score:
						best = candidate
						best_score = score
		if best_score > before_score:
			check(inv.place(run, best), log.route + ": star rearrangement is a legal move")
			record(run, log, {"action":"move", "uid":item.uid, "from":[item.x,item.y,item.rotation], "to":[best.x,best.y,best.rotation], "bonds_before":before_score, "bonds_after":best_score})
	audit(run, log, "arrangement")

func event_summary(result: Dictionary, side: int) -> Dictionary:
	var counts: Dictionary = {}
	var values: Dictionary = {}
	for event in result.events:
		if int(event.side) != side: continue
		counts[event.kind] = int(counts.get(event.kind, 0)) + 1
		values[event.kind] = snappedf(float(values.get(event.kind, 0)) + float(event.value), .01)
	return {"counts":counts, "values":values, "damage":result.totals[side].damage, "heal":result.totals[side].heal, "shield":result.totals[side].shield}

func spatial_counterfactual(run: Dictionary, enemy: Dictionary, baseline: Dictionary, seed_value: int, route: String) -> void:
	if spatial_checks.any(func(row): return row.route == route): return
	for source in run.items:
		var fired = baseline.events.filter(func(e): return e.side == 0 and e.kind == "star_trigger" and e.uid == source.uid)
		if fired.is_empty(): continue
		for rotation in 4:
			for y in inv.HEIGHT:
				for x in inv.WIDTH:
					var alternate = run.duplicate(true)
					var moved = source.duplicate(true)
					moved.merge({"x":x,"y":y,"rotation":rotation}, true)
					if not inv.can_place(moved, alternate.items, alternate.bags): continue
					if not inv.place(alternate, moved) or not inv.star_links(moved, alternate.items, alternate).is_empty(): continue
					var result = B.new().simulate(alternate, enemy, seed_value, false)
					check(inv.validate_run(alternate) and alternate.gold == run.gold and alternate.stash == run.stash and alternate.bags == run.bags, route + ": same acquired set can break a star link at no money cost")
					check(not result.events.any(func(e): return e.side == 0 and e.kind == "star_trigger" and e.uid == source.uid), route + ": unlinked source stops publishing star triggers")
					check(baseline.events != result.events, route + ": legal spatial change alters real events")
					spatial_checks.append({"route":route,"round":run.round,"kind":source.kind,"uid":source.uid,"from":[source.x,source.y,source.rotation],"to":[x,y,rotation],"linked_triggers":fired.size(),"unlinked_triggers":0,"linked":event_summary(baseline,0),"unlinked":event_summary(result,0),"winner_before":baseline.winner,"winner_after":result.winner})
					return

func playthrough(config: Dictionary) -> Dictionary:
	var run = inv.new_run("aemeath", int(config.seed))
	var log = {"route":config.name,"seed":config.seed,"leader":run.leader,"income":0,"spent":0,"purchases":[],"fusions":[],"fusion_limitations":[],"ledger":[],"rounds":[]}
	check(int(run.gold) == 9 and int(run.round) == 1, config.name + ": normal new-run budget")
	audit(run, log, "start")
	for round_index in 3:
		check(int(run.round) == round_index + 1 and run.phase == "shop", config.name + ": real settlement opens next round")
		if run.phase != "shop": break
		for shelf in 3:
			if shelf > 0: refresh(run, log)
			record(run, log, {"action":"shelf", "offers":run.shop.map(func(o): return o.get("kind", ""))})
			buy_target_materials(run,config.target,log)
			if shelf == 0 and inv.coverage(run.bags).size() < 6 + (round_index + 1) * 3:
				purchase(run, 5, log)
			for kind in config.wants:
				if owned(run).any(func(p): return p.kind == kind): continue
				if C.is_tag(kind, "craft_material") and config.target in log.fusions: continue
				for slot in 5:
					if run.shop[slot].get("kind", "") == kind and purchase(run, slot, log): break
			buy_target_materials(run,config.target,log)
			craft_target(run, config.target, log)
		arrange(run, log)
		var enemy = PB.build(inv, int(run.round), 50 + round_index * 17)
		check(enemy.practice_method == PB.METHOD, config.name + ": opponent bought from public shelves")
		check(enemy.practice_spend + enemy.practice_unspent == 9 + round_index * 8, config.name + ": opponent budget reconciles")
		var battle_seed = 100 + round_index
		var before = run.duplicate(true)
		var result = B.new().simulate(run, enemy, battle_seed, false)
		check(run == before, config.name + ": battle does not mutate acquired inventory")
		check(result == B.new().simulate(run, enemy, battle_seed, false), config.name + ": complete replay is deterministic")
		check(float(result.duration) > 0 and float(result.totals[0].damage) > 0, config.name + ": actual battle produces damage")
		spatial_counterfactual(run, enemy, result, battle_seed, config.name)
		log.rounds.append({"round":run.round,"gold":run.gold,"bought_cells":inv.coverage(run.bags).size(),"bags":run.bags.duplicate(true),"items":run.items.duplicate(true),"stash":run.stash.duplicate(true),"bonds":bonds(run),"winner":result.winner,"duration":result.duration,"player":event_summary(result,0),"opponent":event_summary(result,1)})
		if round_index == 2:
			acquired_builds[config.name] = run.duplicate(true)
			acquired_builds[config.name].erase("combat")
		var owned_before_settlement = owned(run).duplicate(true)
		# These are the same phase/result writes made by Game's replay/Next flow.
		run.phase = "result"
		run.combat = result
		run.history.append({"round":run.round,"winner":result.winner,"duration":result.duration,"build":inv.snapshot(run,"qa-v60-headless"),"totals":result.totals})
		var before_gold = int(run.gold)
		var settlement = inv.finish(run, int(result.winner))
		check(not settlement.is_empty(), config.name + ": battle settles via Inventory.finish")
		var income = int(run.gold) - before_gold
		check(income == (0 if run.phase == "ending" else 8 + (1 if result.winner == 1 else 0)), config.name + ": actual outcome determines income")
		log.income += income
		var new_supplies = owned(run).filter(func(p): return not owned_before_settlement.any(func(old): return old.uid == p.uid))
		check(new_supplies.is_empty(), config.name + ": settlement injects no unbought supplies")
		record(run, log, {"action":"settlement", "battle_round":round_index+1, "winner":result.winner, "income":income, "used":result.used[0], "granted_items":new_supplies.map(func(p): return {"kind":p.kind,"uid":p.uid,"catalogue_price":C.items[p.kind].price})})
		check(owned(run).all(func(p): return p.uid not in result.used[0]), config.name + ": only consumed supplies disappear on settlement")
		check(owned_before_settlement.filter(func(p): return p.uid not in result.used[0]).all(func(p): return owned(run).any(func(after): return after.uid == p.uid and after.kind == p.kind)), config.name + ": all unconsumed acquisitions survive settlement")
		audit(run, log, "settlement")
	check(log.rounds.size() == 3, config.name + ": three real battles completed")
	if not config.target.is_empty() and config.target not in log.fusions:
		log.fusion_limitations.append({"target":config.target,"reason":"Three rounds did not provide both affordable inputs and legal adjacent/output space; no inventory or budget was injected."})
	log.final_gold = int(run.gold)
	log.final_phase = run.phase
	return log

func active_price(run: Dictionary) -> int:
	return run.items.reduce(func(total, item): return total + int(C.items[item.kind].price), 0)

func active_cells(run: Dictionary) -> int:
	return run.items.reduce(func(total, item): return total + inv.cells(item).size(), 0)

# Buy both alternatives normally, then branch one acquired state. Unused paid
# alternatives are stashed through the same API as player inventory management.
func choice_variants(name: String, kinds: Array) -> Array:
	var common: Dictionary = acquired_builds[name].duplicate(true)
	for kind in kinds:
		var matches = owned(common).filter(func(p): return p.kind == kind)
		check(matches.size() == 1, name + ": comparison alternative was acquired exactly once: " + kind)
		if matches.size() != 1: return []
		if common.items.any(func(p): return p.uid == matches[0].uid):
			check(inv.stash(common, matches[0]), name + ": unused acquired alternative can be stashed")
	var variants: Array = []
	var footprint: Array = []
	for kind in kinds:
		var variant = common.duplicate(true)
		var piece: Dictionary = variant.stash.filter(func(p): return p.kind == kind)[0]
		var fit: Dictionary = {}
		for rotation in 4:
			for y in inv.HEIGHT:
				for x in inv.WIDTH:
					var moved = piece.duplicate(true)
					moved.merge({"x":x,"y":y,"rotation":rotation}, true)
					var cells = inv.occupied(moved)
					if not footprint.is_empty() and not (cells.size() == footprint.size() and cells.all(func(c): return c in footprint)): continue
					if inv.can_place(moved, variant.items, variant.bags):
						fit = moved
						break
				if not fit.is_empty(): break
			if not fit.is_empty(): break
		check(not fit.is_empty(), name + ": equal occupied cells are feasible for " + kind)
		if fit.is_empty(): return []
		check(inv.place(variant, fit) and inv.validate_run(variant), name + ": selected alternative placed legally")
		footprint = inv.occupied(fit)
		variants.append(variant)
	return variants

func compare_pair(name: String, variants: Array, enemy: Dictionary, effect: String, effect_variant: int) -> void:
	check(variants.size() == 2, name + ": two variants constructed from paid acquisitions")
	if variants.size() != 2: return
	check(variants[0].gold == variants[1].gold and variants[0].bags == variants[1].bags, name + ": equal cash and purchased capacity")
	check(active_price(variants[0]) == active_price(variants[1]) and active_cells(variants[0]) == active_cells(variants[1]), name + ": equal active catalogue cost and occupied cell count")
	var footprint_a: Array = variants[0].items.reduce(func(cells,item): return cells + inv.occupied(item), [])
	var footprint_b: Array = variants[1].items.reduce(func(cells,item): return cells + inv.occupied(item), [])
	check(footprint_a.size() == footprint_b.size() and footprint_a.all(func(cell): return cell in footprint_b), name + ": both variants occupy exactly the same board cells")
	var rows: Array = []
	for build in variants:
		var result = B.new().simulate(build, enemy, 203, false)
		rows.append({"items":build.items,"stash":build.stash,"gold":build.gold,"active_catalogue_cost":active_price(build),"occupied_cells":active_cells(build),"winner":result.winner,"duration":result.duration,"player":event_summary(result,0),"opponent":event_summary(result,1)})
	check(int(rows[effect_variant].player.counts.get(effect, 0)) > 0, name + ": expected counter action actually occurred: " + effect)
	pair_results.append({"name":name,"battle_seed":203,"enemy":inv.snapshot(enemy,"qa-v60-pair"),"variants":rows})

func paired_checks() -> void:
	for config in PAIR_ACQUISITIONS:
		pair_acquisitions.append(playthrough(config))
	var sword_variants: Array = []
	for target in ["weapon_21020044","weapon_21020034"]:
		var run: Dictionary = acquired_builds.sword_pair.duplicate(true)
		for piece in run.items.duplicate(true):
			if C.is_tag(piece.kind,"craft_material"):
				check(inv.stash(run,piece), "sword pair: paid materials moved to storage")
		var log = pair_acquisitions[0].duplicate(true)
		# The snapshot is just before round 3's fight, so exclude its settlement.
		log.income = log.ledger.filter(func(row): return row.action == "settlement" and row.battle_round < 3).reduce(func(total,row): return total + int(row.income),0)
		craft_target(run,target,log)
		check(target in log.fusions, "sword pair: exact alternative fusion succeeds " + target)
		sword_variants.append(run)
	compare_pair("shield_vs_breaker",sword_variants,acquired_builds.shield_cleanse,"break_shield",1)
	compare_pair("haste_vs_shield_counter",choice_variants("counter_pair",["echo_soulfrayer","violet"]),acquired_builds.haste,"counter",1)
	compare_pair("debuff_vs_cleanse",choice_variants("cleanse_pair",["contract","glasses"]),acquired_builds.cleanse_pair,"cleanse",1)

func run_tests() -> void:
	var base_damage = C.items.whiff.v60.actions.filter(func(action): return action.type == "damage").reduce(func(total, action): return total + float(action.value), 0.0)
	var upgraded_damage = C.items.whiff_fast.v60.actions.filter(func(action): return action.type == "damage").reduce(func(total, action): return total + float(action.value), 0.0)
	check(upgraded_damage / float(C.items.whiff_fast.cooldown) > base_damage / float(C.items.whiff.cooldown), "paid whiff fusion improves ordinary damage rate over its base")
	for config in ROUTES:
		samples.append(playthrough(config))
	check(samples.all(func(s): return s.leader == "aemeath"), "routes use the same leader")
	check(samples[0].purchases != samples[1].purchases and samples[1].purchases != samples[2].purchases, "purchase sequences differ")
	check(samples[0].fusions != samples[1].fusions and samples[1].fusions != samples[2].fusions, "acquisition forms different exact recipes")
	check(spatial_checks.size() >= 2, "two acquired builds demonstrate star placement causality")
	paired_checks()
	var file = FileAccess.open(REPORT, FileAccess.WRITE)
	check(file != null, "report is writable outside player storage")
	if file != null:
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"catalogue_hash":C.catalogue_hash,"samples":samples,"spatial_checks":spatial_checks,"pair_acquisitions":pair_acquisitions,"pair_results":pair_results}, "\t"))
		file.close()
	print("PLAYTHROUGH_V60 ", checks, " checks, ", failures.size(), " failures; ", REPORT)
	quit(1 if not failures.is_empty() else 0)
