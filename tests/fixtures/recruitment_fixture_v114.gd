extends 'res://scripts/inventory/inventory.gd'
## Historical V114 scenarios explicitly keep their published recruitment rules.
func new_run(leader:String,seed_value:int,pool_mode:String='full')->Dictionary:
 var run=super.new_run_supply(leader,seed_value,pool_mode,0)
 if not run.is_empty():run.recruitment=preload('res://scripts/party/recruitment_v114.gd').initial();run.simulation_version='resonance-v114'
 return run
