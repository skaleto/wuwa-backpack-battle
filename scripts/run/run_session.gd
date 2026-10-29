extends RefCounted
## Single operation commit boundary. Planning never writes the live run.
## Content stamp detects legacy writers too; no second mutable state or event bus.
static func stamp(run:Dictionary)->String:return JSON.stringify(run).sha256_text()
static func commit(run:Dictionary,plan:Dictionary,validate:Callable,persist:Callable=Callable())->Dictionary:
	if not plan.get("ok",false):return plan
	if plan.get("source","")!=stamp(run):
		return {"ok":false,"target":plan.get("target",""),"reason":"配方状态已变化" if plan.has("target") else "操作状态已变化","materials":[],"consumed":[]}
	if not plan.has("run") or not validate.call(plan.run):
		return {"ok":false,"target":plan.get("target",""),"reason":"成品无法合法入匣" if plan.has("target") else "操作结果无效","materials":[],"consumed":[]}
	# Isolate committed data from previews, result events and persistence callbacks.
	var result=plan.duplicate(true);result.erase("run");result.erase("source")
	# Successful no-ops retain their old return contract without redundant writes.
	if run==plan.run:return result
	var next:Dictionary=plan.run.duplicate(true)
	if persist.is_valid() and persist.call(next.duplicate(true))==false:
		return {"ok":false,"error":"save_failed","reason":"进度保存失败，请重试"}
	run.clear();run.merge(next,true)
	return result
