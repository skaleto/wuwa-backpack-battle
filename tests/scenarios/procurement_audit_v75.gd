extends "res://tests/fixtures/recruitment_fixture_v113.gd"
## Every public mutation, including candidate-copy moves, is checked independently.
var audits=0
var audit_failures=[]
func audit(run:Dictionary,label:String)->void:
 audits+=1
 if not validate_run(run):audit_failures.append(label);printerr("FAIL illegal state after ",label)
func purchase_at(run:Dictionary,index:int,preview:Dictionary,destination:String)->Dictionary:
 var before=run.duplicate(true);var result=super.purchase_at(run,index,preview,destination)
 audit(run,"purchase")
 if result.is_empty() and run!=before:audit_failures.append("purchase atomicity")
 return result
func refresh(run:Dictionary,charge:bool=false)->bool:
 var result=super.refresh(run,charge)
 audit(run,"refresh");return result
func place(run:Dictionary,item:Dictionary)->bool:
 var before=run.duplicate(true);var result=super.place(run,item)
 audit(run,"place")
 if not result and run!=before:audit_failures.append("place atomicity")
 return result
func recruit(run:Dictionary,role_id:String)->bool:
 var result=super.recruit(run,role_id);audit(run,"recruit");return result
func sell(run:Dictionary,item:Dictionary)->bool:
 var result=super.sell(run,item);audit(run,"sale");return result
func finish(run:Dictionary,winner:int)->Dictionary:
 var result=super.finish(run,winner);audit(run,"finish");return result
