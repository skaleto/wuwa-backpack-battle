extends RefCounted
## Shared public prices of time and resale. Paid cost remains actual money spent.
const C=preload("res://scripts/data/catalog.gd")
static var rules:Dictionary=C.data.economy
static func starting_gold()->int:return int(rules.starting_gold)
static func income(winner:int=0,round_number:int=2)->int:
 var grants:Array=rules.get("income_by_round",[])
 var base=int(grants[clampi(round_number-1,0,grants.size()-1)]) if not grants.is_empty() else int(rules.round_income)
 return base+(int(rules.win_bonus) if winner==1 else 0)
static func budget(round_number:int)->int:
 var total=starting_gold()
 for rn in range(2,round_number+1):total+=income(0,rn)
 return total
static func resale(piece:Dictionary)->int:
 return maxi(0,int(floor(float(piece.get("paid_cost",0))*float(rules.resale_ratio))))+int(piece.get("salvage_credit",0))
