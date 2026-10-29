extends 'res://scripts/inventory/inventory.gd'
## Explicit historical recruitment fixture only. Current operations still execute
## through the same planners, geometry and commit boundary; no copied engine.
func new_run(leader:String,seed_value:int,pool_mode:String='full')->Dictionary:
 var run=super.new_run_supply(leader,seed_value,pool_mode,0)
 run.erase('recruitment')
 return run
