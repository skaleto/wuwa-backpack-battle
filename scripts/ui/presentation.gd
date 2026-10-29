extends RefCounted
## Visual state only. Inventory and battle results commit immediately.
var events: Array = []
var pulses: Dictionary = {}
var landings: Dictionary = {}
var rejections: Dictionary = {}
var hover_targets: Dictionary = {}
var hover_values: Dictionary = {}
var presses: Dictionary = {}
var bars: Dictionary = {}
var bar_times: Dictionary = {}
var hit = [0.0, 0.0]
var transition_left = 0.0
var modal_value = 0.0
var modal_target = 0.0
var last_overlay = ""
var elapsed = 0.0

func emit(kind: String, pos: Vector2, color: Color, to: Vector2 = Vector2.ZERO, uid: String = "", delay: float = 0.0) -> void:
	var duration = .65 if kind == "coin" else (.56 if kind == "fusion" else (.22 if kind == "forge_feed" else .48))
	events.append({"kind":kind, "pos":pos, "to":to, "color":color, "uid":uid, "age":-delay, "duration":duration})
	if events.size() > 128:
		events.pop_front()

func pulse(uid: String) -> void:
	pulses[uid] = .28

func land(uid: String) -> void:
	landings[uid]=.28

func landing_y(uid: String) -> float:
	if not landings.has(uid):return 0.0
	var t=1.0-float(landings[uid])/.28
	# Brief eased placement; settled objects never drift.
	return -5*pow(1-t,3)-sin(t*TAU)*1.1*(1-t)

func reject(uid: String) -> void:
	rejections[uid] = .3

func hover(key: String, on: bool) -> float:
	hover_targets[key] = 1.0 if on else 0.0
	return float(hover_values.get(key, 0.0))

func press(key: String) -> void:
	presses[key] = .16

func transition() -> void:
	transition_left = .34

func transition_alpha() -> float:
	return pow(transition_left/.34, 2.0)

func set_modal(value: String) -> void:
	modal_target = 0.0 if value.is_empty() else 1.0
	if not value.is_empty():
		last_overlay = value

func smooth(key: String, value: float) -> float:
	if not bars.has(key):
		bars[key] = value
		bar_times[key] = elapsed
	# Redrawing a frame must not advance feedback a second time. Accumulating
	# the presentation clock also preserves easing when rendering skips a frame.
	var step=maxf(0.0,elapsed-float(bar_times.get(key,elapsed)))
	bar_times[key]=elapsed
	bars[key] = lerpf(bars[key], value, 1.0-exp(-step*13.0))
	return bars[key]

func update(delta: float,feedback_delta: float=-1.0) -> void:
	if feedback_delta<0:feedback_delta=delta
	elapsed += feedback_delta
	transition_left = maxf(0.0, transition_left-delta)
	for side in range(2):
		hit[side] = maxf(0.0, hit[side]-feedback_delta)
	for key in presses.keys():
		presses[key]-=delta
		if presses[key]<=0:presses.erase(key)
	for bag in [pulses, rejections, landings]:
		for key in bag.keys():
			bag[key] -= feedback_delta
			if bag[key] <= 0:
				bag.erase(key)
	for event in events:
		event.age += feedback_delta
	events = events.filter(func(e): return e.age < e.duration)
	for key in hover_targets:
		hover_values[key] = lerpf(hover_values.get(key, 0.0), hover_targets[key], 1.0-exp(-delta*18.0))
	modal_value = move_toward(modal_value, modal_target, delta/0.24)
	if modal_value == 0 and modal_target == 0:
		last_overlay = ""
