extends "res://scripts/compat/migration_pre_v113_inventory.gd"
## Frozen V74 catalogue policy; geometry/schema reuse the stable inventory validator.
const HASH="8dd957bb1713f16466b349407f1a5641f47cd19fb3e2519b8454f7c7b3e6c8f8"
static var frozen_text=FileAccess.get_file_as_string("res://data/compat/catalog-v74.json")
static var frozen:Dictionary=JSON.parse_string(frozen_text)
func _init()->void:
	qualification_catalogue=frozen
	accepted_catalogue_hash=preload("res://scripts/compat/catalogue_fingerprints.gd").text(frozen_text)
	footprint_catalogue=frozen.items
func valid_piece(item:Variant)->bool:
	return item is Dictionary and frozen.items.has(item.get("kind","")) and super.valid_piece(item)
func collection_legal(items:Array,leader:String)->bool:
	var cores=[]
	for item in items:
		if not frozen.items.has(item.get("kind","")):return false
		var d=frozen.items[item.kind]
		if "keepsake" in d.tags:
			if d.get("owner","")!=leader or item.kind in cores:return false
			cores.append(item.kind)
	return true
func shop_eligible(run:Dictionary,kind:String)->bool:
	if not frozen.items.has(kind):return false
	var d=frozen.items[kind]
	if not d.get("v60",{}).get("active",false) or kind in ["strategy","sail","judgment"] or d.get("craft_only",false):return false
	if (not d.get("released",true) and not d.get("demo_available",false)) or int(run.round)<(1 if kind in ["pouch","strip","corner"] else int(d.round_min)):return false
	if "golden" in d.tags and run.get("golden_acquired",false):return false
	if "weapon" in d.tags:
		if not craft_unlocked(run,kind):return false
		if d.get("strict_signature",false) and int(run.round)<4:return false
	return true
func validate_ghost(raw:Variant,allow_empty:bool=false)->bool:
	if not raw is Dictionary or raw.get("simulation_version","resonance-v60")!="resonance-v60":return false
	return super.validate_ghost(raw,allow_empty)

func validate_run(raw:Variant)->bool:
	if not raw is Dictionary or not raw.get("shop") is Array:return false
	if not super.validate_run(raw):return false
	var consumables=0
	for index in raw.shop.size():
		var offer=raw.shop[index]
		if not offer is Dictionary:return false
		if offer.is_empty():continue
		var tags=frozen.items.get(offer.get("kind",""),{}).get("tags",[])
		if "keepsake" in tags:return false
		# V74 shelf constraints are frozen here; V75 intentionally permits both.
		if index==5 and offer.get("locked",false):return false
		if "consumable" in tags:
			consumables+=1
			if consumables>1:return false
	return true
