extends RefCounted
## UI-only pulses from committed relationship changes. Receives rule projections,
## never inventory or run objects. Refreshing a preview cannot light a star.
const DURATION=.42
const FADE_START=.24
var pulses:Array=[]
static func key(marker:Dictionary)->String:
	return str(marker.source_uid)+":"+str(marker.target_uid)+":"+str(marker.cell)
func record(before:Array,after:Array)->void:
	var old={}
	for marker in before:old[key(marker)]=true
	retain(after)
	for marker in after:
		if old.has(key(marker)):continue
		pulses=pulses.filter(func(p):return key(p)!=key(marker))
		var pulse=marker.duplicate(true);pulse.age=0.0;pulses.append(pulse)
func retain(current:Array)->void:
	var keys={}
	for marker in current:keys[key(marker)]=true
	pulses=pulses.filter(func(p):return keys.has(key(p)))
func update(delta:float)->void:
	for pulse in pulses:pulse.age+=maxf(0,delta)
	pulses=pulses.filter(func(p):return p.age<DURATION)
func markers()->Array:
	# Several sources may point to this same cell; one visible flash suffices.
	var cells={};var result=[]
	for pulse in pulses:
		if cells.has(pulse.cell):continue
		cells[pulse.cell]=true;result.append(pulse.duplicate(true))
	return result
func clear()->void:pulses.clear()
