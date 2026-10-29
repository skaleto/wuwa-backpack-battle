extends RefCounted
## Shared display-only replacements. Python documentation reads the same JSON.
static var entries: Dictionary = _read_entries()

static func _read_entries() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/item-framing.json"))
	if parsed is Dictionary and parsed.get("items") is Dictionary:
		return parsed.items
	push_error("Item art replacement table is invalid")
	return {}

static func paths() -> Dictionary:
	var result: Dictionary = {}
	for kind in entries:
		result[kind] = str(entries[kind].path)
	return result

static func angles() -> Dictionary:
	var result: Dictionary = {}
	for kind in entries:
		result[kind] = float(entries[kind].get("angle",0.0))
	return result
