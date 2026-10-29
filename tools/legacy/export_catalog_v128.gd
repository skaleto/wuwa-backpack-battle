extends SceneTree
const C=preload('res://scripts/data/catalog.gd')
func _initialize():
 var effects={}
 for kind in preload('res://scripts/data/original_catalog_v128.gd').spec.new_items:
  effects[kind]=preload('res://scripts/ui/items/item_presentation_v75.gd').effects(kind)
 var out={'simulation_version':C.SIMULATION_VERSION,'catalogue_hash':C.catalogue_hash,'items':C.items,'recipes':C.combinations,'new_item_effects':effects}
 FileAccess.open('res://tests/fixtures/data/wuwa-items-v128/runtime-catalogue.json',FileAccess.WRITE).store_string(JSON.stringify(out,'\t'))
 print('V128 exported ',C.items.size(),' records / ',C.combinations.size(),' recipes');quit()
