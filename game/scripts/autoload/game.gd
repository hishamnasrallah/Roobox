extends Node
## Global game state + unified input (keyboard, mouse and touch).
## Registered as the `Game` autoload.

signal coins_changed(total: int)
signal checkpoint_reached(index: int)
signal player_died
signal player_respawned
signal level_completed(time_sec: float, coins: int)

const LOOK_SENSITIVITY_MOUSE := 0.0045
const LOOK_SENSITIVITY_TOUCH := 0.0065

var coins: int = 0
var total_coins: int = 0
var checkpoint_index: int = 0
var checkpoint_position: Vector3 = Vector3(0, 2, 0)
var run_time: float = 0.0
var running: bool = true
var finished: bool = false

## Set by the player on _ready.
var player: CharacterBody3D = null

# --- Input state (filled by keyboard/mouse here and by TouchControls) ---
var touch_move: Vector2 = Vector2.ZERO
var touch_jump_held: bool = false
var _look_delta: Vector2 = Vector2.ZERO
var _zoom_delta: float = 0.0
var _jump_buffer: float = 0.0
var _mouse_looking: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_actions()


func _process(delta: float) -> void:
	if running and not finished:
		run_time += delta
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)


# ---------------------------------------------------------------- state ---

func reset_run() -> void:
	coins = 0
	total_coins = 0
	checkpoint_index = 0
	checkpoint_position = Vector3(0, 2, 0)
	run_time = 0.0
	running = true
	finished = false
	touch_move = Vector2.ZERO
	touch_jump_held = false
	_look_delta = Vector2.ZERO
	_zoom_delta = 0.0
	_jump_buffer = 0.0


func register_coin() -> void:
	total_coins += 1


func add_coin() -> void:
	coins += 1
	coins_changed.emit(coins)


func set_checkpoint(index: int, pos: Vector3) -> void:
	if index <= checkpoint_index:
		return
	checkpoint_index = index
	checkpoint_position = pos
	checkpoint_reached.emit(index)


func kill_player() -> void:
	if finished:
		return
	player_died.emit()


func notify_respawned() -> void:
	player_respawned.emit()


func complete_level() -> void:
	if finished:
		return
	finished = true
	running = false
	level_completed.emit(run_time, coins)


func restart() -> void:
	reset_run()
	get_tree().reload_current_scene()


# ---------------------------------------------------------------- input ---

## Movement input on the XZ plane: x = right, y = forward. Length <= 1.
func get_move_input() -> Vector2:
	var keys := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var v := keys if keys.length_squared() > touch_move.length_squared() else touch_move
	return v.limit_length(1.0)


func is_jump_held() -> bool:
	return touch_jump_held or Input.is_action_pressed("jump")


func press_jump() -> void:
	_jump_buffer = 0.15


func consume_jump() -> bool:
	if _jump_buffer > 0.0:
		_jump_buffer = 0.0
		return true
	return false


func add_look_touch(relative: Vector2) -> void:
	_look_delta += relative * LOOK_SENSITIVITY_TOUCH


func add_zoom(amount: float) -> void:
	_zoom_delta += amount


func consume_look() -> Vector2:
	var d := _look_delta
	_look_delta = Vector2.ZERO
	return d


func consume_zoom() -> float:
	var z := _zoom_delta
	_zoom_delta = 0.0
	return z


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		press_jump()
	elif event.is_action_pressed("toggle_fullscreen"):
		var mode := DisplayServer.window_get_mode()
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	# Desktop camera: hold right (or left) mouse button and drag.
	# Mouse events emulated from touch are ignored (touch has its own path).
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_LEFT:
			_mouse_looking = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			add_zoom(-1.0)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			add_zoom(1.0)
	elif event is InputEventMouseMotion and _mouse_looking:
		var mm := event as InputEventMouseMotion
		_look_delta += mm.relative * LOOK_SENSITIVITY_MOUSE


func _register_actions() -> void:
	_add_keys("move_forward", [KEY_W, KEY_UP])
	_add_keys("move_back", [KEY_S, KEY_DOWN])
	_add_keys("move_left", [KEY_A, KEY_LEFT])
	_add_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_keys("jump", [KEY_SPACE])
	_add_keys("toggle_fullscreen", [KEY_F11])
	# Gamepad support comes almost for free.
	_add_joy_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	var jb := InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_A
	InputMap.action_add_event("jump", jb)


func _ensure_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)


func _add_keys(action: StringName, keys: Array) -> void:
	_ensure_action(action)
	for k: int in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k as Key
		InputMap.action_add_event(action, ev)


func _add_joy_axis(action: StringName, axis: JoyAxis, value: float) -> void:
	_ensure_action(action)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)
