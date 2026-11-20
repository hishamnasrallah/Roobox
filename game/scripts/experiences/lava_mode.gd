extends GameMode
## Lava Rising rounds: waiting -> running (lava climbs faster and faster) -> ended.

const WAIT_TIME := 8.0
const END_TIME := 4.0
const MAX_TIME := 150.0
const TOP := 92.0
const START_H := -1.0

var state: String = "waiting"
var timer: float = WAIT_TIME
var lava_h: float = START_H
var elapsed: float = 0.0
var round_no: int = 0
var _tick: float = 0.0


func _ready() -> void:
	_to_waiting()


func _process(delta: float) -> void:
	match state:
		"waiting":
			timer -= delta
			if timer <= 0.0:
				state = "running"
				elapsed = 0.0
				lava_h = START_H
				round_no += 1
				emit_event({"t": "state", "s": "running", "round": round_no, "h": lava_h, "e": 0.0})
		"running":
			elapsed += delta
			lava_h += (0.55 + 0.012 * elapsed) * delta
			_tick += delta
			if _tick >= 0.2:
				_tick = 0.0
				emit_event({"t": "lava", "h": lava_h, "e": elapsed}, false)
			if lava_h >= TOP or elapsed >= MAX_TIME:
				state = "ended"
				timer = END_TIME
				emit_event({"t": "state", "s": "ended", "time": END_TIME, "h": lava_h, "e": elapsed})
		"ended":
			timer -= delta
			if timer <= 0.0:
				_to_waiting()


func _to_waiting() -> void:
	state = "waiting"
	timer = WAIT_TIME
	lava_h = START_H
	emit_event({"t": "state", "s": "waiting", "time": WAIT_TIME, "h": START_H})


func snapshot() -> Dictionary:
	return {"t": "state", "s": state, "time": timer, "h": lava_h, "e": elapsed, "round": round_no, "late": true}
