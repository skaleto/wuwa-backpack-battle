extends 'res://tests/regression/test_chains_v124.gd'
const SKIN=preload('res://scripts/ui/visual_skin.gd')
const GEO=preload('res://scripts/ui/items/art_geometry.gd')
func _initialize():
 preload("res://tests/fixtures/catalog_fixture_v127.gd").apply()
 var manifest=JSON.parse_string(FileAccess.get_file_as_string('res://tests/fixtures/data/families-v127/art/generation-manifest.json'))
 var spec=preload('res://scripts/data/family_catalog_v127.gd').spec
 ck(C.combinations.size()==174-spec.remove_recipes.size()+spec.recipes.size(),'current total exact recipe count')
 for recipe in C.combinations:
  ck(not by_id.has(recipe.id),'unique recipe '+recipe.id)
  by_id[recipe.id]=recipe
  if not incoming.has(recipe.target):incoming[recipe.target]=[]
  incoming[recipe.target].append(recipe)
 for id in spec.remove_recipes:ck(not by_id.has(id),'obsolete recipe removed '+id)
 for recipe in C.combinations:
  var run=fixture();run.round=1
  var result=make_kind(run,recipe.target,str(recipe.id))
  ck(not result.is_empty() and result.kind==recipe.target,'acquired materials can craft at any round '+recipe.id)
 ck(seen.size()==C.combinations.size(),'every exact edge actually committed')
 for kind in spec.new_items:
  var item=C.items[kind];var path=SKIN.item_path(kind)
  ck(FileAccess.file_exists(path) and FileAccess.file_exists(GEO.path(kind)),'final art and offline geometry '+kind)
  var image=Image.load_from_file(path)
  var art=manifest.entries.filter(func(e):return e.id==kind)[0]
  ck(image!=null and image.get_width()==art.width and image.get_height()==art.height and FileAccess.get_sha256(path)==art.sha256,'unaltered full-resolution generated asset '+kind)
  for turn in 4:
   var descriptor=GEO.descriptor(kind,turn,image)
   ck(not descriptor.get('empty',true) and descriptor.image_size==Vector2(image.get_size()),'four complete rotations '+kind+str(turn))
  for star in item.stars:ck(star not in item.shape,'star outside actual silhouette cells '+kind)
 print('FAMILIES_CHAINS_V127 ',checks,' checks, ',failures,' failures; ',seen.size(),' recipes; ',transactions,' atomic crafts');quit(1 if failures else 0)
