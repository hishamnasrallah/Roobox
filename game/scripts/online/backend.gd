extends Node
## Game-facing online services (accounts, cloud save, friends, records)
## built on NakamaClient. Registered as the `Backend` autoload.
## Everything degrades gracefully: with no backend configured or
## reachable, the game simply runs offline as a guest.

signal status_changed

const AUTOSAVE_INTERVAL := 45.0
## Presence ("what am I playing") is refreshed this often; friends treat
## anything older than PRESENCE_FRESH seconds as offline.
const PRESENCE_INTERVAL := 60.0
const PRESENCE_FRESH := 300

var client: NakamaClient = null
var online: bool = false
var busy: bool = false
var last_error: String = ""
var _autosave_t: float = 0.0
var _dirty: bool = false
var _presence: Dictionary = {}
var _presence_t: float = 0.0


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
	_presence_t += delta
	if _presence_t >= PRESENCE_INTERVAL and not _presence.is_empty():
		_presence_t = 0.0
		_write_presence()


# ----------------------------------------------------------- presence ---

## Tells friends what you are playing. server = "host:port" they can join
## ("" = not joinable, e.g. solo). exp_id "" = in the menu.
func set_presence(exp_id: String, title: String, server: String) -> void:
	if Game.parental_on("no_online"):
		server = ""
	_presence = {"exp": exp_id, "title": title.substr(0, 40), "server": server}
	_presence_t = 0.0
	if online:
		_write_presence()


func _write_presence() -> void:
	var p := _presence.duplicate()
	p["t"] = int(Time.get_unix_time_from_system())
	await client.write_object("presence", "now", p, true)


## Presence of these user ids: {user_id: {exp, title, server, fresh}}.
func presence_of(user_ids: Array) -> Dictionary:
	var out := {}
	if not online or user_ids.is_empty():
		return out
	var ids: Array = []
	for uid in user_ids:
		ids.append({"collection": "presence", "key": "now", "user_id": str(uid)})
	var now := int(Time.get_unix_time_from_system())
	for o: Dictionary in await client.read_objects(ids):
		var v: Dictionary = o["value"]
		var fresh := absi(now - int(v.get("t", 0))) < PRESENCE_FRESH
		out[o["user_id"]] = {"exp": str(v.get("exp", "")), "title": str(v.get("title", "")),
			"server": str(v.get("server", "")), "fresh": fresh}
	return out


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
	Game.spent_coins = maxi(Game.spent_coins, int(cloud.get("spent", 0)))
	for id in cloud.get("owned", []):
		if not Game.owns(str(id)) and AvatarItems.exists(str(id)):
			Game.owned_items.append(str(id))
	if Game.equipped.is_empty() and cloud.get("equipped") is Dictionary:
		Game.equipped = cloud["equipped"]
	if str(cloud.get("last_daily", "")) > Game.last_daily:
		Game.last_daily = str(cloud["last_daily"])
	var scores: Dictionary = cloud.get("best_scores", {})
	for board: String in scores:
		Game.best_scores[board] = maxi(int(Game.best_scores.get(board, 0)), int(scores[board]))
	var cb: Variant = cloud.get("badges", {})
	if cb is Dictionary:
		for id in cb:
			if not Game.badges.has(str(id)) and not Game.badge_info(str(id)).is_empty():
				Game.badges[str(id)] = int(cb[id])
	var cf: Variant = cloud.get("favorites", [])
	if cf is Array:
		for id in cf:
			if not Game.favorites.has(str(id)) and Game.favorites.size() < 100:
				Game.favorites.append(str(id))
	Game.save_profile()
	var gd := await client.read_object("progress", "gamedata")
	if not gd.is_empty():
		GameData.merge(gd)


func push_progress() -> void:
	if not online:
		return
	_dirty = false
	Game.save_profile()
	await client.write_object("progress", "stats", {
		"coins": Game.lifetime_coins,
		"best_times": Game.best_times,
		"best_scores": Game.best_scores,
		"spent": Game.spent_coins,
		"owned": Game.owned_items,
		"equipped": Game.equipped,
		"last_daily": Game.last_daily,
		"badges": Game.badges,
		"favorites": Game.favorites,
	})
	await client.write_object("progress", "gamedata", GameData.all_games())
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


## Submits a raw score (ms for courses, seconds/rounds/stages for modes).
func submit(board: String, value: int) -> void:
	_dirty = true
	if online:
		await client.submit_score(board, value)


## Returns [{rank, name, score, mine}] for a leaderboard.
func top_scores(board: String, limit: int = 10) -> Array:
	if not online:
		return []
	var data := await client.list_records(board, limit)
	var out: Array = []
	for rec: Dictionary in data.get("records", []):
		out.append({
			"rank": int(rec.get("rank", 0)),
			"name": str(rec.get("username", "?")),
			"score": int(str(rec.get("score", "0"))),
			"mine": str(rec.get("owner_id", "")) == client.user_id,
		})
	return out


## Course leaderboards in seconds: [{rank, name, time, mine}].
func top_times(course_name: String, limit: int = 10) -> Array:
	var rows: Array = await top_scores(board_id(course_name), limit)
	for r: Dictionary in rows:
		r["time"] = float(r["score"]) / 1000.0
	return rows


# ---------------------------------------------------------- community ---

## Publishes a Studio creation: full level + a small public index entry.
func publish_game(slot: String, level: Dictionary) -> bool:
	if not online:
		return false
	var lvl := Level.sanitize(level)
	var r1 := await client.write_object("games", slot, lvl, true)
	if not r1["ok"]:
		last_error = str(r1["error"])
		return false
	var r2 := await client.write_object("games_index", slot, {
		"name": lvl["name"],
		"author": Game.player_name,
		"username": client.username,
		"parts": (lvl["parts"] as Array).size(),
		"updated": int(Time.get_unix_time_from_system()),
	}, true)
	return r2["ok"]


## Community games: [{owner, key, name, author, parts}] (newest first).
func list_community(limit: int = 40) -> Array:
	if not online:
		return []
	var rows: Array = await client.list_public("games_index", limit)
	var out: Array = []
	for r: Dictionary in rows:
		var v: Dictionary = r["value"]
		out.append({
			"owner": r["user_id"], "key": r["key"],
			"name": str(v.get("name", "Untitled")), "author": str(v.get("author", "?")),
			"parts": int(v.get("parts", 0)), "updated": int(v.get("updated", 0)),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["updated"]) > int(b["updated"]))
	return out


func load_community(owner: String, key: String) -> Dictionary:
	if not online:
		return {}
	var data := await client.read_object("games", key, owner)
	return Level.sanitize(data) if not data.is_empty() else {}


# -------------------------------------------------------------- safety ---

## Stores a report for moderators (visible in the Nakama console).
func report_player(target_name: String, reason: String, context: Array) -> bool:
	if not online:
		return false
	var key := "r%d_%d" % [Time.get_unix_time_from_system(), randi() % 100000]
	var r := await client.write_object("reports", key, {
		"target": target_name, "reason": reason, "context": context.slice(-20),
		"reporter": Game.player_name, "time": int(Time.get_unix_time_from_system()),
		"experience": Network.experience_id,
	})
	return r["ok"]


# ------------------------------------------------------------ friends ---

## Returns [{id, username, name, online, state}] (state: 0 friend, 1 sent, 2 received).
func friends() -> Array:
	if not online:
		return []
	var out: Array = []
	var raw: Array = await client.list_friends()
	var mutual: Array = []
	for f: Dictionary in raw:
		var u: Dictionary = f.get("user", {})
		out.append({
			"id": str(u.get("id", "")),
			"username": str(u.get("username", "")),
			"name": str(u.get("display_name", u.get("username", ""))),
			"online": bool(u.get("online", false)),
			"state": int(f.get("state", 0)),
			"playing": "", "exp": "", "server": "",
		})
		if int(f.get("state", 0)) == 0:
			mutual.append(str(u.get("id", "")))
	var pres := await presence_of(mutual)
	for f: Dictionary in out:
		var p: Dictionary = pres.get(f["id"], {})
		if p.get("fresh", false):
			f["online"] = true
			f["playing"] = p["title"]
			f["exp"] = p["exp"]
			f["server"] = p["server"]
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

## Public game servers for an experience ("host:port").
## Server entries look like "island=host:7777" or "lava_rising=:7778"
## (empty host = the account server's host). Plain "host:port" = island.
func game_servers(exp_id: String = "island") -> Array:
	var out: Array = []
	var backend_host := Game.backend_url.replace("https://", "").replace("http://", "").split("/")[0].split(":")[0]
	if online:
		var data := await client.rpc("server_list")
		var list: Variant = data.get("servers", [])
		if list is Array:
			for s in list:
				var entry := str(s).strip_edges()
				var eid := "island"
				if entry.contains("="):
					eid = entry.get_slice("=", 0).strip_edges()
					entry = entry.get_slice("=", 1).strip_edges()
				if eid != exp_id:
					continue
				if entry.begins_with(":"):
					entry = backend_host + entry
				out.append(entry)
	if out.is_empty() and exp_id == "island" and backend_host != "":
		out.append("%s:%d" % [backend_host, Network.DEFAULT_PORT])
	return out
