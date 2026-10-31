extends RefCounted
## Shared run boundaries. Shop availability is separate from crafting eligibility.
const WIN_TARGET=8
const LOSS_LIMIT=4
const MAX_ROUNDS=WIN_TARGET+LOSS_LIMIT-1
const HISTORICAL_VERSIONS=["resonance-v60","resonance-v75","resonance-v83","resonance-v86","resonance-v87","resonance-v88","resonance-v92"]
static func cleared(run:Dictionary)->bool:
 # This is a completed-result projection, never the live settlement rule.
 return run.get("phase","")=="ending" and int(run.get("wins",0))>=int(display_limits(run).wins)
static func display_limits(run:Dictionary)->Dictionary:
 var historical=run.get("phase","")=="ending" and run.get("simulation_version","") in HISTORICAL_VERSIONS
 return {"wins":6 if historical else WIN_TARGET,"losses":3 if historical else LOSS_LIMIT}
static func result_delta(winner:int)->Dictionary:
 return {"wins":1 if winner==1 else 0,"losses":0 if winner==1 else 1}
