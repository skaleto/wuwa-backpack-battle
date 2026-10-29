extends SceneTree
const C=preload('res://scripts/data/catalog.gd')
func _initialize():
 var out={'simulation_version':C.SIMULATION_VERSION,'catalogue_hash':C.catalogue_hash,'items':C.items,'recipes':C.combinations}
 FileAccess.open('res://tests/fixtures/data/families-v127/runtime-catalogue.json',FileAccess.WRITE).store_string(JSON.stringify(out,'\t'))
 print('V127 exported ',C.items.size(),' records / ',C.combinations.size(),' recipes');quit()
