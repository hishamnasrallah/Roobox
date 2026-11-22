class_name GameData
extends RefCounted
## Per-game save data for scripts (player:set_data / get_data), kept on
## each player's own device: user://gamedata.json = {game: {key: value}}.

const PATH := "user://gamedata.json"
const MAX_KEYS := 50


static func _all() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return d if d is Dictionary else {}


static func all_games() -> Dictionary:
	return _all()


## Cloud -> device: adds values this device doesn't have yet.
static func merge(cloud: Dictionary) -> void:
	var all := _all()
	for game in cloud:
		if not (cloud[game] is Dictionary):
			continue
		var g: Dictionary = all.get(game, {}) if all.get(game) is Dictionary else {}
		var incoming := clean(cloud[game])
		for k in incoming:
			if not g.has(k) and g.size() < MAX_KEYS:
				g[k] = incoming[k]
		all[str(game).substr(0, 40)] = g
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(all))


static func load_game(game: String) -> Dictionary:
	var g: Variant = _all().get(game, {})
	return g if g is Dictionary else {}


static func save_value(game: String, key: String, value: Variant) -> void:
	var all := _all()
	var g: Dictionary = all.get(game, {}) if all.get(game) is Dictionary else {}
	if not g.has(key) and g.size() >= MAX_KEYS:
		return
	g[key] = value
	all[game] = g
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(all))


## Keeps only small, JSON-safe values (numbers, bools, short strings).
static func clean(data: Variant) -> Dictionary:
	var out := {}
	if not (data is Dictionary):
		return out
	for k in (data as Dictionary):
		if out.size() >= MAX_KEYS:
			break
		var v: Variant = data[k]
		if v is float or v is int or v is bool:
			out[str(k).substr(0, 32)] = v
		elif v is String:
			out[str(k).substr(0, 32)] = (v as String).substr(0, 200)
	return out


static func game_key(level: Dictionary) -> String:
	return str(level.get("name", "Game")).strip_edges().substr(0, 40)
