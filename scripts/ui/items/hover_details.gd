extends RefCounted
## Transient pointer state only. It never owns the pinned selection or gameplay.
const DWELL=0.25
var target:Dictionary={}
var anchor=Rect2()
var elapsed=0.0
var pointer_active=true

func clear()->void:
	target={};anchor=Rect2();elapsed=0.0

func update(candidate:Dictionary,source:Rect2,delta:float)->void:
	if candidate.is_empty():clear();return
	if candidate!=target:
		target=candidate.duplicate(true);elapsed=0.0
	anchor=source;elapsed+=maxf(0.0,delta)

func visible()->bool:
	return not target.is_empty() and elapsed>=DWELL
