extends RefCounted
## One switch owns the presentation and simulation seam. Save fields stay intact.
const C=preload("res://scripts/data/catalog.gd")
const CONCERTO_ENABLED=false
const CONCERTO_ONLY_ITEMS=["strategy","sail","judgment"]
static func item_enabled(kind:String)->bool:
	var def=C.items.get(kind,{})
	if def.has("v75"):return bool(def.v75.active)
	return bool(def.get("v60",{}).get("active",false))
