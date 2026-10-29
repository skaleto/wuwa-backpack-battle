extends 'res://tests/regression/test_chains_v124.gd'
func _initialize()->void:
 var spec=preload('res://scripts/data/original_catalog_v128.gd').spec
 for recipe in C.combinations:
  ck(not by_id.has(recipe.id),'unique exact recipe ID '+recipe.id)
  by_id[recipe.id]=recipe
  if not incoming.has(recipe.target):incoming[recipe.target]=[]
  incoming[recipe.target].append(recipe)
 for recipe in spec.recipes:
  var run=fixture();run.round=1
  var result=make_kind(run,recipe.target,str(recipe.id))
  ck(not result.is_empty() and result.kind==recipe.target,'full lineage crafts on round1 '+recipe.id)
  var original=run.duplicate(true)
  var again=F.transact(run,recipe.target,'missing-source',inv,{},Callable(),recipe.id)
  ck(not again.ok and run==original,'replayed/invalid recipe is atomic '+recipe.id)
 # A tiny owned three-cell strip holds the exact two ingredients, but the 4-cell
 # output must enter unlimited storage. Carry all paid costs and unrelated items.
 var r=fixture(false);r.bags=[inv.make_piece('strip','b1')]
 for index in 107:r.stash.append(inv.make_piece('nutrition','retained'+str(index)))
 var retained=r.stash.duplicate(true);var recipe=by_id['W128-21']
 var a=leaf(r,recipe.base);var b=leaf(r,recipe.materials[0]);var output=forge(r,recipe,a,b)
 ck(not output.is_empty() and r.stash.size()==108 and r.items.is_empty(),'new exact recipe overflows into slot108')
 ck(retained.all(func(p):return inv.find_piece(r,p.uid)==p),'new overflow preserves every unrelated stored instance')
 for kind in spec.new_items:
  var uses=spec.recipes.filter(func(row):return row.base==kind or kind in row.materials)
  ck(not uses.is_empty(),'every new permanent item continues into a real chain '+kind)
  if kind.begins_with('mat_423'):ck(uses.size()>=2,'botanical supports two recipes '+kind)
 print('ORIGINAL_CHAINS_V128 ',checks,' checks, ',failures,' failures; ',transactions,' atomic crafts');quit(1 if failures else 0)
