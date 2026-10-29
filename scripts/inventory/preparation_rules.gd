extends RefCounted
## Small preparation edits that used to live in mouse/UI branches.
const C=preload("res://scripts/data/catalog.gd")
const FEATURES=preload("res://scripts/run/demo_features.gd")
const SESSION=preload("res://scripts/run/run_session.gd")
static func plan(run:Dictionary,next:Dictionary,ok:bool,value:Variant=true)->Dictionary:
	return {"ok":ok,"source":SESSION.stamp(run),"run":next,"value":value}
static func primary(run:Dictionary,uid:String)->Dictionary:
	var next=run.duplicate(true)
	var valid=run.get("phase","")=="shop" and run.get("items",[]).any(func(v):return v.uid==uid and C.is_tag(v.kind,"weapon"))
	if valid:next.primary=uid
	return plan(run,next,valid)
static func rotate_stored(run:Dictionary,uid:String,rotation:int)->Dictionary:
	var next=run.duplicate(true)
	if run.get("phase","")!="shop" or rotation<0 or rotation>3:return plan(run,next,false)
	for item in next.get("stash",[]):
		if item.uid==uid:
			item.rotation=rotation;return plan(run,next,true)
	return plan(run,next,false)
static func relay(run:Dictionary,uids:Array,validate:Callable,complete_guide:bool=false)->Dictionary:
	var next=run.duplicate(true)
	var valid=run.get("phase","")=="shop" and validate.call(run,uids)
	if valid:
		next.relay=uids.duplicate()
		if complete_guide:next.relay_guide_complete=true
	return plan(run,next,valid)
static func guide(run:Dictionary,primary_item:Dictionary,links:Array)->Dictionary:
	var next=run.duplicate(true)
	var valid=FEATURES.CONCERTO_ENABLED and not run.get("relay_guide_complete",false) and not primary_item.is_empty() and not links.is_empty()
	if valid:next.relay_guide_complete=true
	return plan(run,next,valid)
