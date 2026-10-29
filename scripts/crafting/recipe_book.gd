extends RefCounted
## Catalogue facts only. No run, eligibility, geometry or ownership.
static func accepts_base(recipe:Dictionary,kind:String)->bool:return recipe.get("base","")==kind
static func for_target(recipes:Array,target:String,recipe_id:String="")->Array:
	return recipes.filter(func(v):return v.target==target and (recipe_id.is_empty() or v.id==recipe_id))
static func for_base(recipes:Array,kind:String)->Array:return recipes.filter(func(v):return accepts_base(v,kind))
static func pairs(recipes:Array,a:String,b:String)->Array:
	return recipes.filter(func(r):return r.materials.size()==1 and ((r.base==a and r.materials[0]==b) or (r.base==b and r.materials[0]==a)))
