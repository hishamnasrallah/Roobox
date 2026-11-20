extends Node
## Automated input self-test (run with: godot --headless --path game -- --selftest).
## Injects real input events through the engine pipeline and checks that
## the player actually moves. Prints SELFTEST PASS / SELFTEST FAIL.

var main: Node3D
var _fails: Array[String] = []


func _ready() -> void:
	_run()


func _log(msg: String) -> void:
	print("SELFTEST ", msg)


func _check(ok: bool, what: String) -> void:
	_log(("ok   " if ok else "FAIL ") + what)
	if not ok:
		_fails.append(what)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _run() -> void:
	await _wait(1.0)
	var player: Player = main.get("player")
	var hud: Hud = main.get("hud")
	var touch := hud.touch
	var vp := get_viewport()
	_log("viewport=%s window=%s touch_size=%s touch_visible=%s on_floor=%s pos=%s" % [
		vp.get_visible_rect().size, DisplayServer.window_get_size(), touch.size,
		touch.visible, player.is_on_floor(), player.global_position])
	_check(player.is_on_floor(), "player standing on spawn")

	# --- Keyboard path ---
	var start := player.global_position
	Input.action_press("move_forward")
	await _wait(1.0)
	Input.action_release("move_forward")
	var moved := player.global_position - start
	_log("keyboard moved=%s" % moved)
	_check(Vector2(moved.x, moved.z).length() > 2.0, "keyboard moves player")
	await _wait(0.6)

	# --- Touch joystick path (events go through the full engine pipeline) ---
	touch.visible = true
	var vis := vp.get_visible_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	var to_window := win / vis if vis.x > 0.0 and win.x > 0.0 else Vector2.ONE
	var p0 := Vector2(200, vis.y - 190)
	start = player.global_position
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = p0 * to_window
	Input.parse_input_event(down)
	await get_tree().process_frame
	for i in 5:
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = (p0 + Vector2(0, -20.0 * (i + 1))) * to_window
		drag.relative = Vector2(0, -20) * to_window
		Input.parse_input_event(drag)
		await get_tree().process_frame
	_log("touch_move=%s" % Game.touch_move)
	_check(Game.touch_move.y > 0.5, "joystick produces forward input")
	await _wait(1.0)
	moved = player.global_position - start
	_log("touch moved=%s" % moved)
	_check(Vector2(moved.x, moved.z).length() > 2.0, "touch joystick moves player")
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = down.position
	Input.parse_input_event(up)
	await _wait(0.6)

	# --- Touch jump button ---
	var y0 := player.global_position.y
	var jc := Vector2(vis.x - 175.0, vis.y - 175.0)
	var jdown := InputEventScreenTouch.new()
	jdown.index = 1
	jdown.pressed = true
	jdown.position = jc * to_window
	Input.parse_input_event(jdown)
	var peak := y0
	for i in 20:
		await get_tree().physics_frame
		peak = maxf(peak, player.global_position.y)
	var jup := InputEventScreenTouch.new()
	jup.index = 1
	jup.pressed = false
	jup.position = jdown.position
	Input.parse_input_event(jup)
	_log("jump peak gain=%.2f" % (peak - y0))
	_check(peak - y0 > 1.0, "touch jump button jumps")

	if _fails.is_empty():
		_log("PASS")
	else:
		_log("FAIL: " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)
