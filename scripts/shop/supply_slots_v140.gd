extends RefCounted
## Mix category budgets without fixing a category to any shelf position.
## The caller supplies eligible pools with their original round/quality curves.
const VERSION=140
const CATEGORY_WEIGHTS=[.28,.22,.35,.15] # weapons, echoes, utilities, pockets
static func mix(groups:Array,bags:Array)->Dictionary:
 var pools=groups.duplicate();var pocket={}
 for kind in bags:pocket[kind]=1.0/bags.size()
 pools.append(pocket)
 var total=0.0;var result={}
 for n in 4:
  if not pools[n].is_empty():total+=CATEGORY_WEIGHTS[n]
 if total<=0:return result
 for n in 4:
  for kind in pools[n]:result[kind]=float(pools[n][kind])*CATEGORY_WEIGHTS[n]/total
 return result
