extends RefCounted
## Supply policy only. Does not lock ownership, recipes, combat or UI placement.
static var design:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/compat/design/v93.json"))
static func includes(run:Dictionary,kind:String)->bool:
 var introduced=int(preload("res://scripts/data/catalog.gd").profile(kind).get("introduced_version",0))
 if introduced>=125 and int(run.get("supply_version",0))>=introduced:return true
 return run.get("pool_mode","full")!="focused" or (kind in design.focused_pool and int(run.get("round",1))>=int(design.offer_rounds[kind]))
