extends GameMode
## Color Drop rounds: a color is called, after `think` seconds every other
## tile disappears, then everything comes back with a new pattern.

const WAIT_TIME := 8.0
const ROUNDS := 25
const DROP_TIME := 2.6
const END_TIME := 5.0

var state: String = "waiting"
var timer: float = WAIT_TIME
var round_no: int = 0
var pattern_seed: int = 0
var color: int = 0
var think: float = 4.0


func _ready() -> void:
	_to_waiting()


func _process(delta: float) -> void:
	timer -= delta
	if timer > 0.0:
		return
	match state:
		"waiting":
			round_no = 0
			_next_round()
		"think":
			state = "drop"
			timer = DROP_TIME
			emit_event({"t": "drop", "round": round_no, "color": color, "seed": pattern_seed})
		"drop":
			if round_no >= ROUNDS:
				state = "ended"
				timer = END_TIME
				emit_event({"t": "ended", "round": round_no})
			else:
				_next_round()
		"ended":
			_to_waiting()


func _next_round() -> void:
	round_no += 1
	pattern_seed = randi()
	color = randi() % 6
	think = maxf(1.3, 4.2 - 0.2 * (round_no - 1))
	state = "think"
	timer = think
	emit_event({"t": "round", "round": round_no, "seed": pattern_seed, "color": color, "think": think})


func _to_waiting() -> void:
	state = "waiting"
	timer = WAIT_TIME
	emit_event({"t": "waiting", "time": WAIT_TIME})


func snapshot() -> Dictionary:
	return {"t": "snapshot", "state": state, "round": round_no, "seed": pattern_seed,
		"color": color, "time": timer}
