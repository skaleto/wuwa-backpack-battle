extends RefCounted
## Short-lived visual addresses from real battle events; no battle state access.
var pulses:Array=[]
func record(event:Dictionary)->void:
	if event.get("kind","")!="star_trigger":return
	var source=str(event.get("source_uid",""))
	var target=str(event.get("target_uid",event.get("trigger_uid","")))
	if source.is_empty() or target.is_empty() or source==target:return
	var side=int(event.get("side",0))
	for pulse in pulses:
		if pulse.side==side and pulse.source_uid==source and pulse.target_uid==target:
			pulse.life=.28;pulse.beneficiary_uid=str(event.get("beneficiary_uid",source));return
	pulses.append({"side":side,"source_uid":source,"target_uid":target,"life":.28,"beneficiary_uid":str(event.get("beneficiary_uid",source))})
func update(delta:float)->void:
	for pulse in pulses:pulse.life-=maxf(0,delta)
	pulses=pulses.filter(func(v):return v.life>0)
func targets(side:int,source:String)->Array:
	return pulses.filter(func(v):return v.side==side and v.source_uid==source).map(func(v):return v.target_uid)
func clear()->void:pulses.clear()
