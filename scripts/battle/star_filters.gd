extends RefCounted
## Shared star eligibility data. Battle and preparation read the same immutable table.
const FILTERS = {
  "weapon_21010063": [
    "weapon",
    "echo"
  ],
  "weapon_21010044": [
    "echo"
  ],
  "weapon_21010043": [
    "echo"
  ],
  "weapon_21010015": [
    "echo"
  ],
  "weapon_21010076": [
    "shield"
  ],
  "discord": [
    "weapon",
    "echo"
  ],
  "weapon_21010046": [
    "shield"
  ],
  "weapon_21010034": [
    "heal"
  ],
  "verdant": [
    "echo"
  ],
  "weapon_21010026": [
    "echo"
  ],
  "weapon_21010056": [
    "noise"
  ],
  "weapon_21010066": [
    "weapon"
  ],
  "weapon_21020024": [
    "echo"
  ],
  "weapon_21020043": [
    "echo"
  ],
  "weapon_21020107": [
    "weapon",
    "echo"
  ],
  "weapon_21020074": [
    "weapon"
  ],
  "weapon_21020015": [
    "echo"
  ],
  "weapon_21020064": [
    "provision"
  ],
  "weapon_21020106": [
    "echo"
  ],
  "weapon_21020026": [
    "weapon"
  ],
  "weapon_21020066": [
    "echo"
  ],
  "weapon_21030024": [
    "weapon"
  ],
  "weapon_21030043": [
    "echo"
  ],
  "weapon_21030064": [
    "provision"
  ],
  "weapon_21030044": [
    "weapon"
  ],
  "weapon_21030104": [
    "weapon"
  ],
  "weapon_21030036": [
    "echo"
  ],
  "weapon_21030026": [
    "provision"
  ],
  "weapon_21030015": [
    "weapon",
    "provision"
  ],
  "weapon_21030045": [
    "weapon"
  ],
  "weapon_21030056": [
    "weapon"
  ],
  "weapon_21030046": [
    "weapon",
    "provision"
  ],
  "weapon_21040024": [
    "weapon",
    "echo"
  ],
  "weapon_21040043": [
    "echo"
  ],
  "weapon_21040045": [
    "echo"
  ],
  "weapon_21040046": [
    "shield"
  ],
  "weapon_21040056": [
    "echo"
  ],
  "weapon_21040066": [
    "echo"
  ],
  "weapon_21040016": [
    "echo"
  ],
  "weapon_21050044": [
    "echo"
  ],
  "weapon_21050104": [
    "weapon"
  ],
  "weapon_21050043": [
    "echo"
  ],
  "rectifier25": [
    "heal"
  ],
  "variation": [
    "weapon",
    "echo"
  ],
  "weapon_21050017": [
    "weapon"
  ],
  "stringmaster": [
    "weapon",
    "echo"
  ],
  "weapon_21050086": [
    "weapon"
  ],
  "weapon_21050056": [
    "echo"
  ],
  "weapon_21050026": [
    "echo"
  ],
  "weapon_21050076": [
    "weapon",
    "echo"
  ],
  "weapon_21050064": [
    "heal"
  ],
  "weapon_21050036": [
    "weapon"
  ],
  "weapon_21050066": [
    "echo"
  ],
  "echo_vanguard": [
    "weapon"
  ],
  "feilian": [
    "weapon"
  ],
  "rocksteady": [
    "shield"
  ],
  "echo_soulfrayer": [
    "weapon"
  ],
  "cyan_heron": [
    "weapon"
  ],
  "heron": [
    "weapon"
  ],
  "violet": [
    "shield"
  ],
  "echo_shuxin": [
    "shield"
  ],
  "echo_lionarch": [
    "heal"
  ],
  "echo_tianqui": [
    "weapon",
    "echo"
  ],
  "thundering": [
    "weapon"
  ],
  "echo_hecaton": [
    "weapon",
    "heal"
  ],
  "electro_coin": [
    "weapon"
  ],
  "glasses": [
    "provision"
  ],
  "contract": [
    "echo"
  ],
  "aero_coin": [
    "provision"
  ],
  "spectro_coin": [
    "weapon"
  ],
  "captain_seal": [
    "weapon"
  ],
  "sail": [
    "weapon"
  ],
  "elegance": [
    "echo"
  ],
  "answer": [
    "weapon"
  ],
  "lamp": [
    "weapon",
    "shield"
  ],
  "flower": [
    "heal"
  ],
  "starfall": [
    "weapon"
  ],
  "judgment": [
    "echo"
  ]
}

static func for_kind(kind:String)->Array:
	var current=preload("res://scripts/data/catalog.gd").profile(kind)
	return for_profile(kind,current)

static func for_profile(kind:String,current:Dictionary)->Array:
	if current.has("star_categories"):return current.star_categories
	var material=current.get("material_effect",{})
	return [material.category] if not material.get("category","").is_empty() else FILTERS.get(kind,[])
