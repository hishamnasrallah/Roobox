extends Node
## Game-facing online services (accounts, cloud save, friends, records)
## built on NakamaClient. Registered as the `Backend` autoload.
## Everything degrades gracefully: with no backend configured or
## reachable, the game simply runs offline as a guest.

signal status_changed

const AUTOSAVE_INTERVAL := 45.0

var client: NakamaClient = null
var online: bool = false
var busy: bool = false
var last_error: String = ""
var _autosave_t: float = 0.0
var _dirty: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.coins_changed.connect(func(_t: int) -> void: _dirty = true)
	Game.course_completed.connect(_on_course_completed)


func _process(delta: float) -> void:
	if not online:
		return
	_autosave_t += delta
	if _autosave_t >= AUTOSAVE_INTERVAL and _dirty:
		_autosave_t = 0.0
		push_progress()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		Game.save_profile()
		if online and _dirty:
			push_progress()


func status_text() -> String:
	if busy:
		return "Connecting to account server..."
	if online:
		return "Signed in as %s  (@%s)" % [Game.player_name, client.username]
	if Game.backend_url == "":
		return "Playing as guest (no account server set)"
	return "Offline - %s" % last_error if last_error != "" else "Offline"


func username() -> String:
	return client.username if online else ""


# ------------------------------------------------------------ connect ---

## Signs in with this device's id. Safe to call repeatedly.
func connect_backend() -> bool:
	if busy:
		return online
	if Game.backend_url == "":
		online = false
		status_changed.emit()
		return false
	busy = true
	last_error = ""
	status_changed.emit()
	client = NakamaClient.new(self, Game.backend_url, Game.backend_key)
	var r := await client.authenticate_device(Game.device_id, Game.player_name)
	busy = false
	if not r["ok"]:
		online = false
		last_error = str(r["error"])
		status_changed.emit()
		return false
	online = true
	if client.display_name != Game.player_name:
		await client.update_display_name(Game.player_name)
	await pull_progress()
	await push_progress()
	status_changed.emit()
	return true


func disconnect_backend() -> void:
	online = false
	client = null
	status_changed.emit()


# ----------------------------------------------------------- progress ---

## Cloud -> local merge: keep the most coins and the best times.
func pull_progress() -> void:
	if not online:
		return
	var cloud := await client.read_object("progress", "stats")
	if cloud.is_empty():
		return
	Game.lifetime_coins = maxi(Game.lifetime_coins, int(cloud.get("coins", 0)))
	var times: Dictionary = cloud.get("best_times", {})
	for course: String in times:
		var t := float(times[course])
		var local: float = Game.best_times.get(course, 0.0)
		if t > 0.0 and (local <= 0.0 or t < local):
			Game.best_times[course] = t
	Game.save_profile()


func push_progress() -> void:
	if not online:
		return
	_dirty = false
	Game.save_profile()
	await client.write_object("progress", "stats", {
		"coins": Game.lifetime_coins,
		"best_times": Game.best_times,
	})
	await client.write_object("profile", "avatar", {
		"shirt": Game.shirt_index, "pants": Game.pants_index, "skin": Game.skin_index,
	}, true)


func update_name() -> void:
	if online:
		await client.update_display_name(Game.player_name)


# ------------------------------------------------------------ records ---

static func board_id(course_name: String) -> String:
	return course_name.to_lower().replace(" ", "_")


func _on_course_completed(course_name: String, time_sec: float) -> void:
	_dirty = true
	if not online:
		return
	await client.submit_score(board_id(course_name), int(time_sec * 1000.0))
	await push_progress()


## Returns [{rank, name, time, mine}] for the top players of a course.
func top_times(course_name: String, limit: int = 10) -> Array:
	if not online:
		return []
	var data := await client.list_records(board_id(course_name), limit)
	var out: Array = []
	for rec: Dictionary in data.get("records", []):
		out.append({
			"rank": int(rec.get("rank", 0)),
			"name": str(rec.get("username", "?")),
			"time": float(str(rec.get("score", "0"))) / 1000.0,
			"mine": str(rec.get("owner_id", "")) == client.user_id,
		})
	return out


# ------------------------------------------------------------ friends ---

## Returns [{id, username, name, online, state}] (state: 0 friend, 1 sent, 2 received).
func friends() -> Array:
	if not online:
		return []
	var out: Array = []
	var raw: Array = await client.list_friends()
	for f: Dictionary in raw:
		var u: Dictionary = f.get("user", {})
		out.append({
			"id": str(u.get("id", "")),
			"username": str(u.get("username", "")),
			"name": str(u.get("display_name", u.get("username", ""))),
			"online": bool(u.get("online", false)),
			"state": int(f.get("state", 0)),
		})
	return out


func add_friend(uname: String) -> Dictionary:
	if not online:
		return {"ok": false, "error": "offline"}
	return await client.add_friend_by_username(uname)


func accept_friend(id: String) -> Dictionary:
	return await client.add_friend_by_id(id)


func remove_friend(id: String) -> Dictionary:
	return await client.remove_friend(id)


# ------------------------------------------------------------ servers ---

## Public game servers ("host:port"). Falls back to the backend host:7777.
func game_servers() -> Array:
	var out: Array = []
	if online:
		var data := await client.rpc("server_list")
		var list: Variant = data.get("servers", [])
		if list is Array:
			for s in list:
				out.append(str(s))
	if out.is_empty() and Game.backend_url != "":
		var host := Game.backend_url.replace("https://", "").replace("http://", "").split("/")[0].split(":")[0]
		if host != "":
			out.append("%s:%d" % [host, Network.DEFAULT_PORT])
	return out
