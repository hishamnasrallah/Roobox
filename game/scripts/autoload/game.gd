extends Node
## Global game state, player profile and unified input (keyboard, mouse, touch).
## Registered as the `Game` autoload.

signal coins_changed(total: int)
signal checkpoint_reached
signal player_died
signal player_respawned
signal course_started(course_name: String)
signal course_completed(course_name: String, time_sec: float)
signal settings_changed
## Ask the local player to play an emote ("" stops it).
signal emote_requested(id: String)
## Backpack (hotbar) changed or a different tool is held.
signal backpack_changed
## The local player's health changed.
signal health_changed(health: float, max_health: float)
## The USE button was pressed (swing the sword...).
signal tool_used
## Short message for the HUD (e.g. "SPEED COIL!").
signal notice(text: String)
## A badge was earned (shown as a toast by the HUD).
signal badge_awarded(badge_name: String, desc: String)

const LOOK_SENSITIVITY_MOUSE := 0.0045
const LOOK_SENSITIVITY_TOUCH := 0.0065
const PROFILE_PATH := "user://profile.cfg"

const SHIRT_COLORS: Array[Color] = [
	Color(1.0, 0.55, 0.2), Color(0.95, 0.25, 0.3), Color(0.25, 0.55, 1.0),
	Color(0.3, 0.8, 0.4), Color(0.65, 0.4, 1.0), Color(1.0, 0.8, 0.2),
	Color(0.15, 0.17, 0.22), Color(0.95, 0.95, 0.97),
]
const FACES: Array[String] = ["SMILE", "GRIN", "COOL", "WOW", "WINK", "HAPPY"]
const HAIRS: Array[String] = ["CAP", "SPIKY", "LONG", "BALD", "BUN", "MOHAWK"]
const HAIR_COLORS: Array[Color] = [
	Color(0.25, 0.16, 0.1), Color(0.08, 0.07, 0.07), Color(0.85, 0.65, 0.3), Color(0.75, 0.3, 0.15),
	Color(0.85, 0.85, 0.9), Color(0.35, 0.55, 1.0), Color(1.0, 0.45, 0.7),
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
## Best scores of round-based experiences: board id -> int.
var best_scores: Dictionary = {}

## Local player profile (also sent to other players online).
var player_name: String = ""
var shirt_index: int = 0
var pants_index: int = 0
var skin_index: int = 0
var face_index: int = 0
var hair_index: int = 0
var hair_color_index: int = 0
var server_address: String = "127.0.0.1"
## Coins collected across all sessions (saved locally + in the cloud).
var lifetime_coins: int = 0
## Coins spent in the avatar shop. Wallet = lifetime_coins - spent_coins.
var spent_coins: int = 0
var owned_items: Array = []
## slot -> item id
var equipped: Dictionary = {}
var last_daily: String = ""

# --- Settings ---
var language: String = ""
var sensitivity: float = 1.0
var graphics: String = "medium"
var volume: float = 0.8
var show_fps: bool = true
var chat_enabled: bool = true
var tutorial_done: bool = false
## Player names muted this session (their chat is hidden).
var muted: Array = []

const DAILY_REWARD := 100

## Emotes: index is sent over the network (0 = none).
const EMOTES: Array[String] = ["", "wave", "dance", "cheer", "point", "clap", "sit", "laugh"]

## Built-in badges (games made in Studio can award their own with scripts).
const BADGES: Array[Dictionary] = [
	{"id": "welcome", "name": "Welcome!", "desc": "Play your first game."},
	{"id": "first_win", "name": "Winner", "desc": "Finish a course or win a round."},
	{"id": "coins_100", "name": "Coin Collector", "desc": "Collect 100 coins in total."},
	{"id": "coins_1000", "name": "Treasure Hunter", "desc": "Collect 1000 coins in total."},
	{"id": "explorer", "name": "Explorer", "desc": "Play 10 different games."},
	{"id": "globetrotter", "name": "Globetrotter", "desc": "Play 50 different games."},
	{"id": "creator", "name": "Creator", "desc": "Save a game you made in Studio."},
	{"id": "publisher", "name": "Publisher", "desc": "Publish a game for everyone."},
	{"id": "fashion", "name": "Fashionista", "desc": "Buy an avatar item."},
	{"id": "friend", "name": "Friendly", "desc": "Add a friend."},
	{"id": "dancer", "name": "Dancer", "desc": "Use an emote."},
]

## Parental controls. When a PIN is set, only someone with the PIN can
## change them. Keys: no_chat, no_online, no_publish, no_friends.
var parental: Dictionary = {"pin": "", "no_chat": false, "no_online": false, "no_publish": false, "no_friends": false}

## Tools you picked up in this game (ids from Tools.LIST) and the held one.
var backpack: Array = []
var held_tool: int = -1

## Chat mute from a moderator (unix time; 0 = not muted).
var chat_muted_until: int = 0
## Players you blocked: [{name, uid}] (their chat and bubbles are hidden).
var blocked: Array = []

## "" = not asked yet, "under13", "13plus" (asked on first launch).
var age_group: String = ""

## Badges earned: id -> unix time. Custom game badges use "game:<game>:<name>".
var badges: Dictionary = {}
## Favorite game ids (library "g:..." ids or featured experience ids).
var favorites: Array = []
## Recently played ids, newest first.
var recent: Array = []
## Times each game was started: id -> count.
var visits: Dictionary = {}
## Account server (Nakama), e.g. "http://203.0.113.5:7350". Empty = guest.
var backend_url: String = ""
var backend_key: String = "defaultkey"
## Stable random id for device login (generated once per install).
var device_id: String = ""

## Level to play in the "ugc" experience (Studio test / creations / community).
var pending_level: Dictionary = {}
## Studio: slot being edited, test-play flag, and slot to reopen after a test.
var studio_slot: String = ""
var testing: bool = false
var resume_studio: String = ""

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
		face_index = clampi(int(cfg.get_value("profile", "face", 0)), 0, FACES.size() - 1)
		hair_index = clampi(int(cfg.get_value("profile", "hair", 0)), 0, HAIRS.size() - 1)
		hair_color_index = clampi(int(cfg.get_value("profile", "hair_color", 0)), 0, HAIR_COLORS.size() - 1)
		server_address = str(cfg.get_value("net", "address", "127.0.0.1"))
		best_times = cfg.get_value("stats", "best_times", {}) as Dictionary
		lifetime_coins = int(cfg.get_value("stats", "coins", 0))
		best_scores = cfg.get_value("stats", "best_scores", {}) as Dictionary
		spent_coins = int(cfg.get_value("shop", "spent", 0))
		owned_items = cfg.get_value("shop", "owned", []) as Array
		equipped = cfg.get_value("shop", "equipped", {}) as Dictionary
		last_daily = str(cfg.get_value("shop", "last_daily", ""))
		language = str(cfg.get_value("settings", "language", ""))
		sensitivity = clampf(float(cfg.get_value("settings", "sensitivity", 1.0)), 0.3, 2.5)
		graphics = str(cfg.get_value("settings", "graphics", "medium"))
		volume = clampf(float(cfg.get_value("settings", "volume", 0.8)), 0.0, 1.0)
		show_fps = bool(cfg.get_value("settings", "show_fps", true))
		chat_enabled = bool(cfg.get_value("settings", "chat", true))
		tutorial_done = bool(cfg.get_value("settings", "tutorial_done", false))
		backend_url = str(cfg.get_value("online", "backend_url", ""))
		backend_key = str(cfg.get_value("online", "backend_key", "defaultkey"))
		device_id = str(cfg.get_value("online", "device_id", ""))
		badges = cfg.get_value("social", "badges", {}) as Dictionary
		favorites = cfg.get_value("social", "favorites", []) as Array
		recent = cfg.get_value("social", "recent", []) as Array
		visits = cfg.get_value("social", "visits", {}) as Dictionary
		age_group = str(cfg.get_value("settings", "age_group", ""))
		blocked = cfg.get_value("social", "blocked", []) as Array
		var pc: Variant = cfg.get_value("settings", "parental", {})
		if pc is Dictionary:
			parental.merge(pc as Dictionary, true)
	if language == "":
		language = "ar" if OS.get_locale_language() == "ar" else "en"
	if not (graphics in ["low", "medium", "high"]):
		graphics = "medium"
	apply_settings()
	if device_id.length() < 16:
		device_id = _new_device_id()
		save_profile()
	if player_name.strip_edges() == "":
		player_name = "Player%d" % (randi() % 9000 + 1000)
	shirt_index = clampi(shirt_index, 0, SHIRT_COLORS.size() - 1)
	pants_index = clampi(pants_index, 0, PANTS_COLORS.size() - 1)
	skin_index = clampi(skin_index, 0, SKIN_COLORS.size() - 1)


## Applies language, volume (and notifies graphics listeners).
func apply_settings() -> void:
	I18n.set_language(language)
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(bus, volume <= 0.001)
	settings_changed.emit()


func save_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "name", player_name)
	cfg.set_value("profile", "shirt", shirt_index)
	cfg.set_value("profile", "pants", pants_index)
	cfg.set_value("profile", "skin", skin_index)
	cfg.set_value("profile", "face", face_index)
	cfg.set_value("profile", "hair", hair_index)
	cfg.set_value("profile", "hair_color", hair_color_index)
	cfg.set_value("net", "address", server_address)
	cfg.set_value("stats", "best_times", best_times)
	cfg.set_value("stats", "coins", lifetime_coins)
	cfg.set_value("stats", "best_scores", best_scores)
	cfg.set_value("shop", "spent", spent_coins)
	cfg.set_value("shop", "owned", owned_items)
	cfg.set_value("shop", "equipped", equipped)
	cfg.set_value("shop", "last_daily", last_daily)
	cfg.set_value("settings", "language", language)
	cfg.set_value("settings", "sensitivity", sensitivity)
	cfg.set_value("settings", "graphics", graphics)
	cfg.set_value("settings", "volume", volume)
	cfg.set_value("settings", "show_fps", show_fps)
	cfg.set_value("settings", "chat", chat_enabled)
	cfg.set_value("settings", "tutorial_done", tutorial_done)
	cfg.set_value("online", "backend_url", backend_url)
	cfg.set_value("online", "backend_key", backend_key)
	cfg.set_value("online", "device_id", device_id)
	cfg.set_value("social", "badges", badges)
	cfg.set_value("social", "favorites", favorites)
	cfg.set_value("social", "recent", recent)
	cfg.set_value("social", "visits", visits)
	cfg.set_value("settings", "parental", parental)
	cfg.set_value("settings", "age_group", age_group)
	cfg.set_value("social", "blocked", blocked)
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
		"items": equipped_ids(),
		"face": face_index,
		"hair": hair_index,
		"hair_color": HAIR_COLORS[hair_color_index],
	}


# ----------------------------------------------------------------- shop ---

func wallet() -> int:
	return maxi(lifetime_coins - spent_coins, 0)


func owns(id: String) -> bool:
	return id in owned_items


func equipped_ids() -> Array:
	var out: Array = []
	for slot in AvatarItems.SLOTS:
		var id := str(equipped.get(slot, ""))
		if id != "" and owns(id):
			out.append(id)
	return out


## Buys an item with coins. Returns "" on success or an error message.
func buy(id: String) -> String:
	var it := AvatarItems.get_item(id)
	if it.is_empty():
		return "Unknown item"
	if owns(id):
		return "You already own it"
	var price: int = it["price"]
	if wallet() < price:
		return "Not enough coins (%d more needed)" % (price - wallet())
	spent_coins += price
	owned_items.append(id)
	equipped[it["slot"]] = id
	save_profile()
	award_badge("fashion")
	return ""


## Equips an owned item, or takes it off if it is already worn.
func toggle_equip(id: String) -> void:
	var it := AvatarItems.get_item(id)
	if it.is_empty() or not owns(id):
		return
	var slot: String = it["slot"]
	if equipped.get(slot, "") == id:
		equipped.erase(slot)
	else:
		equipped[slot] = id
	save_profile()


func daily_available() -> bool:
	return last_daily != Time.get_date_string_from_system()


func claim_daily() -> int:
	if not daily_available():
		return 0
	last_daily = Time.get_date_string_from_system()
	lifetime_coins += DAILY_REWARD
	save_profile()
	return DAILY_REWARD


# ---------------------------------------------------------------- state ---

func reset_run() -> void:
	backpack = []
	held_tool = -1
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
	check_coin_badges()


func check_coin_badges() -> void:
	if lifetime_coins >= 100:
		award_badge("coins_100")
	if lifetime_coins >= 1000:
		award_badge("coins_1000")


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
	award_badge("first_win")


# --------------------------------------------------------------- tools ---

## Puts a tool in the backpack (max 6, no duplicates) and holds it if your
## hands are empty. Returns true if it was added.
func give_tool(id: String) -> bool:
	if not Tools.exists(id) or backpack.has(id) or backpack.size() >= 6:
		return false
	backpack.append(id)
	if held_tool < 0:
		held_tool = backpack.size() - 1
	backpack_changed.emit()
	notice.emit(Tools.label(id) + "!")
	Sfx.play("checkpoint")
	return true


## Holds backpack slot i (or puts the tool away if it is already held).
func equip_tool(i: int) -> void:
	held_tool = -1 if i == held_tool or i < 0 or i >= backpack.size() else i
	backpack_changed.emit()


func held_tool_id() -> String:
	return str(backpack[held_tool]) if held_tool >= 0 and held_tool < backpack.size() else ""


# ---------------------------------------------------- parental controls ---

## True when a parental restriction is switched on.
func parental_on(key: String) -> bool:
	return bool(parental.get(key, false))


## First-launch age answer. Younger players start with chat off
## (a parent can change it in SETTINGS > Parental controls).
func set_age_group(group: String) -> void:
	age_group = group
	if group == "under13":
		parental["no_chat"] = true
	save_profile()


func parental_locked() -> bool:
	return str(parental.get("pin", "")) != ""


## Chat is shown/sent only if the player wants it and parents allow it.
func chat_allowed() -> bool:
	return chat_enabled and not parental_on("no_chat") and chat_muted_until <= int(Time.get_unix_time_from_system())


## True when a player (by Nakama user id or name) is blocked.
func is_blocked(uid: String, pname: String) -> bool:
	for b in blocked:
		if (uid != "" and str(b.get("uid", "")) == uid) or str(b.get("name", "")) == pname:
			return true
	return false


func block_player(uid: String, pname: String) -> void:
	if not is_blocked(uid, pname):
		blocked.append({"uid": uid, "name": pname})
		save_profile()


func unblock_player(pname: String) -> void:
	for b in blocked.duplicate():
		if str(b.get("name", "")) == pname:
			blocked.erase(b)
	save_profile()


# ---------------------------------------------------- badges & favorites ---

func badge_info(id: String) -> Dictionary:
	for b in BADGES:
		if b["id"] == id:
			return b
	if id.begins_with("game:"):
		var parts := id.split(":", true, 2)
		return {"id": id, "name": parts[2] if parts.size() > 2 else id, "desc": "Earned in %s" % (parts[1] if parts.size() > 1 else "a game")}
	return {}


func has_badge(id: String) -> bool:
	return badges.has(id)


## Awards a badge once. Built-in ids from BADGES, or a game badge:
## award_badge("game:My Obby:Speedrunner"). Returns true if it is new.
func award_badge(id: String) -> bool:
	if badges.has(id) or badge_info(id).is_empty():
		return false
	badges[id] = int(Time.get_unix_time_from_system())
	save_profile()
	var b := badge_info(id)
	badge_awarded.emit(str(b["name"]), str(b["desc"]))
	return true


## Remembers that a game was started (recent list, visits, badges).
func note_played(id: String) -> void:
	if id == "" or id == "ugc":
		return
	recent.erase(id)
	recent.push_front(id)
	while recent.size() > 12:
		recent.pop_back()
	visits[id] = int(visits.get(id, 0)) + 1
	save_profile()
	award_badge("welcome")
	if visits.size() >= 10:
		award_badge("explorer")
	if visits.size() >= 50:
		award_badge("globetrotter")


func is_favorite(id: String) -> bool:
	return favorites.has(id)


func toggle_favorite(id: String) -> bool:
	if favorites.has(id):
		favorites.erase(id)
	else:
		favorites.push_front(id)
	save_profile()
	return favorites.has(id)


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
	_look_delta += relative * LOOK_SENSITIVITY_TOUCH * sensitivity


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
		_look_delta += mm.relative * LOOK_SENSITIVITY_MOUSE * sensitivity


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
