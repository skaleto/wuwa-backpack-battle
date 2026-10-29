extends RefCounted

const RULESET = "wuwa-pack-v4"
static var catalogue_hash: String = preload("res://scripts/compat/catalogue_fingerprints.gd").text(FileAccess.get_file_as_string("res://data/compat/catalog-v4-crafting-base.json"))
static var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/compat/catalog-v4-crafting-base.json"))
static var items: Dictionary = data.items
static var characters: Dictionary = data.characters
static var roster: Dictionary = data.roster
static var combinations: Array = []
const ELEMENTS = {"aero":Color("8abc9a"), "electro":Color("a991c9"), "spectro":Color("d2bb64"), "fusion":Color("d99169"), "glacio":Color("8fbfc4"), "havoc":Color("b993ae"), "neutral":Color("b6b69e")}

static func tint(kind: String) -> Color:
	return ELEMENTS.get(items.get(kind,{}).get("element","neutral"),Color("b6b69e"))

static func is_tag(kind: String, tag: String) -> bool:
	return items.has(kind) and tag in items[kind].get("tags",[])
