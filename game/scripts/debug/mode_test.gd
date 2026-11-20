extends Node
## CI test for round-based experiences:
##   godot --headless --path game --fixed-fps 60 -- --modetest lava_rising
## Runs the experience solo for a while and checks its round loop.

var main: Node3D
var exp_id: String = ""
var _t: float = 0.0
var _events: int = 0
var _seen: Dictionary = {}
var _deaths: int = 0
var _max_lava: float = -99.0
var _done: bool = false
var _teleported: bool = false


func _ready() -> void:
	var gm: GameMode = main.get("game_mode")
	if gm != null:
		gm.event.connect(_on_event)
	Game.player_died.connect(func() -> void: _deaths += 1)
	print("MODETEST %s started" % exp_id)


func _on_event(ev: Dictionary, _reliable: bool) -> void:
	_events += 1
	_seen["%s:%s" % [ev.get("t", ""), ev.get("s", "")]] = true
	if ev.has("h"):
		_max_lava = maxf(_max_lava, float(ev["h"]))


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var ex: Experience = main.get("experience")
	match exp_id:
		"lava_rising":
			if _t > 40.0:
				_finish(_seen.has("state:running") and _max_lava > 5.0 and _deaths >= 1,
					"events=%d lava=%.1f deaths=%d seen=%s" % [_events, _max_lava, _deaths, _seen.keys()])
		"color_drop":
			if _t > 40.0:
				_finish(_seen.has("round:") and _seen.has("drop:") and _events >= 6,
					"events=%d deaths=%d seen=%s" % [_events, _deaths, _seen.keys()])
		"obby_rush":
			var player: Player = main.get("player")
			if _t > 1.0 and not _teleported:
				_teleported = true
				player.teleport(_rush_origin(2) + Vector3(0, 0.6, 0))
			if _t > 4.0:
				var cur: int = ex.get("_current")
				var stages: Dictionary = ex.get("_stages")
				_finish(cur == 2 and stages.has(5) and not stages.has(-1),
					"current=%d stages=%s" % [cur, stages.keys()])
		_:
			if _t > 3.0:
				_finish(ex != null, "experience=%s" % ex)


func _rush_origin(k: int) -> Vector3:
	return Vector3(0, 20.0 + k * 0.6, -k * 34.0)


func _finish(ok: bool, detail: String) -> void:
	_done = true
	print("MODETEST %s %s %s" % [exp_id, "PASS" if ok else "FAIL", detail])
	get_tree().quit(0 if ok else 1)
