extends "res://tests/regression/test_chains_v124.gd"
const SKIN=preload("res://scripts/ui/visual_skin.gd")
const GEO=preload("res://scripts/ui/items/art_geometry.gd")
const INFO=preload("res://scripts/ui/items/item_info.gd")
const TREE=preload("res://scripts/crafting/recipe_tree.gd")
const NEW=["echo_porcelain","echo_anger","echo_sorrow","echo_gliding_sentry","echo_moth","echo_singilum","relic_diverter","relic_lunchbox"]
func _initialize():
 preload('res://tests/fixtures/catalog_fixture_v125.gd').apply()
 var active=C.items.keys().filter(func(k):return C.profile(k).get("active",false) or C.is_tag(k,"bag"))
 ck(active.size()==223,"223 active items including five bags")
 ck(TREE.branch_summary(TREE.recipe_by_id("P037"))=="每10秒附加1光噪。","answer branch describes current noise supply, not obsolete no-debuff trade")
 ck(TREE.branch_summary(TREE.recipe_by_id("P041"))=="开战获得1迅捷；常驻，不消耗。","tea branch describes current opening rather than obsolete delayed haste")
 ck(preload("res://scripts/ui/items/item_presentation_v75.gd").chips("answer").has(["break_shield","穿盾"]),"piercing helper is not labeled shield destruction")
 ck(C.v124_hash=="1c0433da9432a80386a30c74592f2549f95bef7c3b78b63bdb37ba1250e24b4c","precise prior hash remains frozen")
 var expected_counts={"weapon":124,"echo":33,"relic":30,"provision":11,"craft_material":20,"bag":5}
 for category in expected_counts:
  ck(active.filter(func(k):return C.is_tag(k,category)).size()==expected_counts[category],"current category count "+category)
 for kind in NEW:
  var item=C.items[kind];var p=C.profile(kind)
  ck(p.stamina==0 and p.hp==0 and p.shieldAmount==0 and p.healAmount==0,"new specialist has no free defensive bundle "+kind)
  ck(not INFO.live_effects(kind).is_empty(),"live card effects "+kind)
  ck(item.craft_tier==p.tier and item.price==p.cost,"quality and cost agree "+kind)
  ck(FileAccess.file_exists(SKIN.item_path(kind)) and FileAccess.file_exists(GEO.path(kind)),"original art and offline geometry "+kind)
  var image=Image.load_from_file(SKIN.item_path(kind))
  for turn in 4:
   var descriptor=GEO.descriptor(kind,turn,image)
   ck(not descriptor.get("empty",true) and descriptor.image_size==Vector2(image.get_size()),"complete visible geometry "+kind+str(turn))
  ck(item.stars.size()==(1 if kind in NEW.slice(0,3) else 4 if kind=="echo_singilum" else 2 if kind=="relic_diverter" else 3),"quality star count "+kind)
  for star in item.stars:ck(star not in item.shape,"star not inside source "+kind)
 for recipe in C.combinations:
  by_id[recipe.id]=recipe
  if not incoming.has(recipe.target):incoming[recipe.target]=[]
  incoming[recipe.target].append(recipe)
 ck(C.combinations.size()==174 and by_id.size()==174,"174 distinct recipes")
 # Every branch through public acquired-instance placement and atomic crafting.
 for recipe in C.combinations:
  var run=fixture();run.round=1
  var result=make_kind(run,recipe.target,str(recipe.id))
  ck(not result.is_empty() and result.kind==recipe.target,"all acquired chains work at round1 "+recipe.id)
 ck(seen.size()==174,"all branch identities exercised")
 print("ECOSYSTEM_CONTENT_V125 ",checks," checks, ",failures," failures; ",transactions," transactions")
 quit(1 if failures else 0)
