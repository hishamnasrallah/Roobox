extends Node
## Global game state, player profile and unified input (keyboard, mouse, touch).
## Registered as the `Game` autoload.

signal coins_changed(total: int)
signal checkpoint_reached
signal player_died
signal player_respawned
signal course_started(course_name: String)
signal course_completed(course_name: String, time_sec: float)

const LOOK_SENSITIVITY_MOUSE := 0.0045
const LOOK_SENSITIVITY_TOUCH := 0.0065
const PROFILE_PATH := "user://profile.cfg"

const SHIRT_COLORS: Array[Color] = [
	Color(1.0, 0.55, 0.2), Color(0.95, 0.25, 0.3), Color(0.25, 0.55, 1.0),
	Color(0.3, 0.8, 0.4), Color(0.65, 0.4, 1.0), Color(1.0, 0.8, 0.2),
	Color(0.15, 0.17, 0.22), Color(0.95, 0.95, 0.97),
]
const PANTS_COLORS: Array[Color] = [
	Color(0.2, 0.27, 0.55), Color(0.15, 0.15, 0.18), Color(0.45, 0.3, 0.2),
	Color(0.3, 0.5, 0.3), Color(0.75, 0.75, 0.8), Color(0.55, 0.15, 0.2),
]
const SKIN_COLORS: Array[Color] = [
	Color(1.0, 0.84, 0.7), Color(0.95, 0.75, 0.58), Color(0.8, 0.58, 0.4),
	Color(0.55, 0.38, 0.25), Color(0.38, 0.26, 0.18),
]

var coins: int = 0
var total_coins: int = 0
var spawn_point: Vector3 = Vector3(0, 1, 0)
var checkpoint_position: Vector3 = Vector3(0, 1, 0)
var current_course: String = ""
var course_time: float = 0.0
var best_times: Dictionary = {}

## Local player profile (also sent to other players online).
var player_name: String = ""
var shirt_index: int = 0
var pants_index: int = 0
var skin_index: int = 0
var server_address: String = "127.0.0.1"
## Coins collected across all sessions (saved locally + in the cloud).
var lifetime_coins: int = 0
## Account server (Nakama), e.g. "http://203.0.113.5:7350". Empty = guest.
var backend_url: String = ""
var backend_key: String = "defaultkey"
## Stable random id for device login (generated once per install).
var device_id: String = ""

## Set by the player on _ready.
var player: CharacterBody3D = null

# --- Input state (filled by keyboard/mouse here and by TouchControls) ---
var touch_move: Vector2 = Vector2.ZERO
var touch_jump_held: bool = false
var input_blocked: bool = false
var _look_delta: Vector2 = Vector2.ZERO
var _zoom_delta: float = 0.0
var _jump_buffer: float = 0.0
var _mouse_looking: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_actions()
	load_profile()


func _process(delta: float) -> void:
	if current_course != "":
		course_time += delta
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)


# -------------------------------------------------------------- profile ---

func load_profile() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PROFILE_PATH) == OK:
		player_name = str(cfg.get_value("profile", "name", ""))
		shirt_index = int(cfg.get_value("profile", "shirt", 0))
		pants_index = int(cfg.get_value("profile", "pants", 0))
		skin_index = int(cfg.get_value("profile", "skin", 0))
		server_address = str(cfg.get_value("net", "address", "127.0.0.1"))
		best_times = cfg.get_value("stats", "best_times", {}) as Dictionary
		lifetime_coins = int(cfg.get_value("stats", "coins", 0))
		backend_url = str(cfg.get_value("online", "backend_url", ""))
		backend_key = str(cfg.get_value("online", "backend_key", "defaultkey"))
		device_id = str(cfg.get_value("online", "device_id", ""))
	if device_id.length() < 16:
		device_id = _new_device_id()
		save_profile()
	if player_name.strip_edges() == "":
		player_name = "Player%d" % (randi() % 9000 + 1000)
	shirt_index = clampi(shirt_index, 0, SHIRT_COLORS.size() - 1)
	pants_index = clampi(pants_index, 0, PANTS_COLORS.size() - 1)
	skin_index = clampi(skin_index, 0, SKIN_COLORS.size() - 1)


func save_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "name", player_name)
	cfg.set_value("profile", "shirt", shirt_index)
	cfg.set_value("profile", "pants", pants_index)
	cfg.set_value("profile", "skin", skin_index)
	cfg.set_value("net", "address", server_address)
	cfg.set_value("stats", "best_times", best_times)
	cfg.set_value("stats", "coins", lifetime_coins)
	cfg.set_value("online", "backend_url", backend_url)
	cfg.set_value("online", "backend_key", backend_key)
	cfg.set_value("online", "device_id", device_id)
	cfg.save(PROFILE_PATH)


func _new_device_id() -> String:
	var crypto := Crypto.new()
	return "roobox-" + crypto.generate_random_bytes(16).hex_encode()


## Profile as a plain dictionary (safe to send over the network).
func profile() -> Dictionary:
	return {
		"name": player_name,
		"shirt": SHIRT_COLORS[shirt_index],
		"pants": PANTS_COLORS[pants_index],
		"skin": SKIN_COLORS[skin_index],
	}


# ---------------------------------------------------------------- state ---

func reset_run() -> void:
	coins = 0
	total_coins = 0
	checkpoint_position = spawn_point
	current_course = ""
	course_time = 0.0
	touch_move = Vector2.ZERO
	touch_jump_held = false
	input_blocked = false
	_look_delta = Vector2.ZERO
	_zoom_delta = 0.0
	_jump_buffer = 0.0


func register_coin() -> void:
	total_coins += 1


func add_coin() -> void:
	coins += 1
	lifetime_coins += 1
	coins_changed.emit(coins)
	Sfx.play("coin")


func set_checkpoint(pos: Vector3) -> void:
	if pos.distance_to(checkpoint_position) < 0.5:
		return
	checkpoint_position = pos
	checkpoint_reached.emit()
	Sfx.play("checkpoint")


func reset_checkpoint_to_spawn() -> void:
	checkpoint_position = spawn_point
	current_course = ""


func start_course(course_name: String) -> void:
	if current_course == course_name:
		return
	current_course = course_name
	course_time = 0.0
	course_started.emit(course_name)


func complete_course(course_name: String) -> void:
	if current_course != course_name:
		return
	var t := course_time
	current_course = ""
	var prev: float = best_times.get(course_name, 0.0)
	if prev <= 0.0 or t < prev:
		best_times[course_name] = t
		save_profile()
	course_completed.emit(course_name, t)
	Sfx.play("win")


func kill_player() -> void:
	player_died.emit()


func notify_respawned() -> void:
	player_respawned.emit()


func restart() -> void:
	reset_run()
	get_tree().reload_current_scene()


# ---------------------------------------------------------------- input ---

## Movement input on the XZ plane: x = right, y = forward. Length <= 1.
func get_move_input() -> Vector2:
	if input_blocked:
		return Vector2.ZERO
	var keys := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var v := keys if keys.length_squared() > touch_move.length_squared() else touch_move
	return v.limit_length(1.0)


func is_jump_held() -> bool:
	return touch_jump_held or Input.is_action_pressed("jump")


func press_jump() -> void:
	_jump_buffer = 0.15


func consume_jump() -> bool:
	if _jump_buffer > 0.0 and not input_blocked:
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
