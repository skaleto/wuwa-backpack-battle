extends RefCounted
## V127 content is historical; V128 suites exercise the complete live catalogue.
const C=preload('res://scripts/data/catalog.gd')
static func apply()->Dictionary:
 var saved={'items':C.items.duplicate(true),'recipes':C.combinations.duplicate(true),'supply_recipes':C.v125_combinations.duplicate(true),'supply_recipes127':C.v127_combinations.duplicate(true)}
 preload('res://tests/fixtures/catalog_fixture_v116.gd').replace({'items':C.v127_items,'recipes':C.v127_combinations})
 C.v125_combinations=saved.supply_recipes.duplicate(true)
 return saved
