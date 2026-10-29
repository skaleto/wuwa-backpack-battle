extends "res://tests/regression/test_process_equivalence_v78.gd"
# Numerical and procurement changes intentionally invalidate historical event hashes.
# Same 18 full sequences now test legality, exact repeatability and settlement income.
var failures=0
var checks=0
var before_gold=0
func step(label:String,run:Dictionary,value:Variant=null):
 checks+=1
 if not inventory.validate_run(run):failures+=1;printerr("FAIL state after ",label)
 if label=="battle":before_gold=run.gold
 if label=="finish" and run.phase!="ending" and run.gold!=before_gold+I.ECONOMY.income(1,run.round):failures+=1;printerr("FAIL round income")
 super.step(label,run,value)
func _initialize():
 scenarios()
 var first=traces.duplicate(true);traces=[]
 scenarios()
 if traces!=first:failures+=1;printerr("FAIL deterministic end-to-end replay")
 print("PROCESS_V83: ",traces.size()," snapshots repeated, ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
