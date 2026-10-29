extends RefCounted

const RULESET = "wuwa-pack-v5"
const SIMULATION_VERSION = "resonance-v128"
static var v115_space: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/compat/design/v115-space-baseline.json"))
static var v115_hash: String = v115_space.catalogue_hash
static var release_hashes:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/release-hashes.json"))
static var common_hash: String = release_hashes["common_hash"]
static var v114_hash: String = release_hashes["v114_hash"]
static var v116_hash: String = release_hashes["v116_hash"]
static var v124_hash: String = release_hashes["v124_hash"]
static var v125_hash: String = release_hashes["v125_hash"]
static var v127_hash: String = release_hashes["v127_hash"]
static var v128_hash: String = release_hashes["v128_hash"]
static var catalogue_hash: String = release_hashes["catalogue_hash"]
static var v125_combinations:Array=[]
static var v125_item_ids:Array=[]
static var v127_combinations:Array=[]
static var v127_items:Dictionary={}
static var v127_item_ids:Array=[]
static var v128_combinations:Array=[]
static var v128_items:Dictionary={}
static var v128_item_ids:Array=[]
static var data: Dictionary = preload("res://scripts/data/specialty_catalog_v114.gd").apply(JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json")))
static var _leaders_applied: bool = _apply_leaders()
static func _apply_leaders()->bool:
	data=preload("res://scripts/data/leader_catalog_v115.gd").apply(data)
	data=preload("res://scripts/data/space_catalog_v116.gd").apply(data)
	data=preload("res://scripts/data/strategy_catalog_v124.gd").apply(data)
	data=preload("res://scripts/data/ecosystem_catalog_v125.gd").apply(data)
	v125_combinations=data.recipes.duplicate(true)
	v125_item_ids=data.items.keys()
	data=preload("res://scripts/data/family_catalog_v127.gd").apply(data)
	v127_combinations=data.recipes.duplicate(true)
	v127_items=data.items.duplicate(true)
	v127_item_ids=data.items.keys()
	data=preload("res://scripts/data/original_catalog_v128.gd").apply(data)
	v128_combinations=data.recipes.duplicate(true)
	v128_items=data.items.duplicate(true)
	v128_item_ids=data.items.keys()
	data=preload("res://scripts/data/pocket_catalog_v129.gd").apply(data)
	return true
static var items: Dictionary = data.items
static var characters: Dictionary = data.characters
static var roster: Dictionary = data.roster
static var combinations: Array = data.recipes
static func profile(kind:String)->Dictionary:
	var item=items.get(kind,{})
	return item.get("v128",item.get("v127",item.get("v125",item.get("v124",item.get("v75",{})))))

static func supply_profile(kind:String,version:int)->Dictionary:
	if version>=128:return profile(kind)
	var item=items.get(kind,{})
	if version>=127:return item.get("v127",item.get("v125",item.get("v124",item.get("v75",{}))))
	return item.get("v125",item.get("v124",item.get("v75",{})))

static func supply_recipes(version:int)->Array:
	return combinations if version>=128 else v127_combinations if version>=127 else v125_combinations
const ELEMENTS = {"aero":Color("8abc9a"), "electro":Color("a991c9"), "spectro":Color("d2bb64"), "fusion":Color("d99169"), "glacio":Color("8fbfc4"), "havoc":Color("b993ae"), "neutral":Color("b6b69e")}

static func tint(kind: String) -> Color:
	return ELEMENTS.get(items.get(kind,{}).get("element","neutral"),Color("b6b69e"))

static func is_tag(kind: String, tag: String) -> bool:
	return items.has(kind) and tag in items[kind].get("tags",[])

static func selectable_leaders() -> Array:
	return data.get("selectable_leaders",characters.keys())
