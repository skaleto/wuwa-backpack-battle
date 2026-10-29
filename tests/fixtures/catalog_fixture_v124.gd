extends RefCounted
## Freeze explicitly superseded V124 semantics for legacy regression evidence.
const C=preload("res://scripts/data/catalog.gd")
static func apply()->Dictionary:
 var saved={"items":C.items.duplicate(true),"recipes":C.combinations.duplicate(true),"supply_recipes":C.v125_combinations.duplicate(true),"supply_recipes127":C.v127_combinations.duplicate(true)}
 var data=preload("res://scripts/data/strategy_catalog_v124.gd").apply(preload("res://tests/fixtures/catalog_fixture_v116.gd").data())
 preload("res://tests/fixtures/catalog_fixture_v116.gd").replace(data)
 return saved
