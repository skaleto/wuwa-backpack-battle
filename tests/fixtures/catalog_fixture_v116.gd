extends RefCounted
## Frozen pre-V124 catalogue for historical rule and probability regressions.
## Current V124 behavior is covered separately; never rewrite frozen snapshots.
const C=preload("res://scripts/data/catalog.gd")

static func data()->Dictionary:
	var frozen=JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	frozen=preload("res://scripts/data/specialty_catalog_v114.gd").apply(frozen)
	frozen=preload("res://scripts/data/leader_catalog_v115.gd").apply(frozen)
	return preload("res://scripts/data/space_catalog_v116.gd").apply(frozen)

static func apply()->Dictionary:
	var saved={"items":C.items.duplicate(true),"recipes":C.combinations.duplicate(true),"supply_recipes":C.v125_combinations.duplicate(true),"supply_recipes127":C.v127_combinations.duplicate(true)}
	replace(data())
	return saved

static func restore(saved:Dictionary)->void:
	replace(saved)
	C.v125_combinations=saved.get('supply_recipes',saved.recipes).duplicate(true)
	C.v127_combinations=saved.get('supply_recipes127',saved.recipes).duplicate(true)

static func replace(value:Dictionary)->void:
	# Keep every consumer's shared Dictionary/Array reference intact.
	C.items.clear();C.items.merge(value.items.duplicate(true))
	C.combinations.clear();C.combinations.append_array(value.recipes.duplicate(true))
	C.v125_combinations=value.recipes.duplicate(true)
	C.v127_combinations=value.recipes.duplicate(true)
