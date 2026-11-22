class_name NakamaClient
extends RefCounted
## Minimal REST client for a Nakama server (https://heroiclabs.com/nakama).
## Covers what Roobox needs: device auth, account, storage, friends,
## leaderboards and RPCs. Every call is a coroutine: `await client.x()`.
## Results are dictionaries: {ok: bool, code: int, data: Dictionary, error: String}

enum FriendState { FRIEND = 0, INVITE_SENT = 1, INVITE_RECEIVED = 2, BLOCKED = 3 }

var base_url: String
var server_key: String
var token: String = ""
var user_id: String = ""
var username: String = ""
var display_name: String = ""
var timeout: float = 8.0

var _host: Node


func _init(host: Node, url: String, key: String = "defaultkey") -> void:
	_host = host
	base_url = url.strip_edges().trim_suffix("/")
	server_key = key


func is_authenticated() -> bool:
	return token != ""


# ---------------------------------------------------------------- core ---

func request(method: HTTPClient.Method, path: String, body: Variant = null, basic: bool = false) -> Dictionary:
	if _host == null or not _host.is_inside_tree():
		return _fail(0, "client host is not in the scene tree")
	var http := HTTPRequest.new()
	http.timeout = timeout
	_host.add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	if basic:
		headers.append("Authorization: Basic " + Marshalls.utf8_to_base64(server_key + ":"))
	elif token != "":
		headers.append("Authorization: Bearer " + token)
	var payload := "" if body == null else JSON.stringify(body)
	var err := http.request(base_url + path, headers, method, payload)
	if err != OK:
		http.queue_free()
		return _fail(0, "could not start request (%d)" % err)
	var res: Array = await http.request_completed
	http.queue_free()
	var result: int = res[0]
	var code: int = res[1]
	var raw: PackedByteArray = res[3]
	if result != HTTPRequest.RESULT_SUCCESS:
		return _fail(0, "network error (%d) - is the server reachable?" % result)
	var text := raw.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text) if text != "" else {}
	var data: Dictionary = parsed if parsed is Dictionary else {}
	var ok := code >= 200 and code < 300
	var msg := ""
	if not ok:
		msg = str(data.get("message", text))
	return {"ok": ok, "code": code, "data": data, "error": msg}


func _fail(code: int, msg: String) -> Dictionary:
	return {"ok": false, "code": code, "data": {}, "error": msg}


static func q(value: String) -> String:
	return value.uri_encode()


# ------------------------------------------------------------ account ---

## Logs in with a device id (creates the account the first time).
## `wanted_username` is only used on creation; must be unique server-wide.
func authenticate_device(device_id: String, wanted_username: String) -> Dictionary:
	var base := sanitize_username(wanted_username)
	var r: Dictionary = {}
	for attempt in 4:
		var uname := base if attempt == 0 else "%s%d" % [base.substr(0, 12), randi() % 9000 + 1000]
		r = await request(HTTPClient.METHOD_POST,
			"/v2/account/authenticate/device?create=true&username=%s" % q(uname), {"id": device_id}, true)
		if r["ok"] or int(r["code"]) != 409:
			break
	if not r["ok"]:
		return r
	token = str((r["data"] as Dictionary).get("token", ""))
	var acc := await get_account()
	return acc


func get_account() -> Dictionary:
	var r := await request(HTTPClient.METHOD_GET, "/v2/account")
	if r["ok"]:
		var user: Dictionary = (r["data"] as Dictionary).get("user", {})
		user_id = str(user.get("id", ""))
		username = str(user.get("username", ""))
		display_name = str(user.get("display_name", ""))
	return r


func update_display_name(name_text: String) -> Dictionary:
	var r := await request(HTTPClient.METHOD_PUT, "/v2/account", {"display_name": name_text.substr(0, 32)})
	if r["ok"]:
		display_name = name_text
	return r


static func sanitize_username(text: String) -> String:
	var out := ""
	for ch in text.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_":
			out += ch
	if out.length() < 3:
		out = "player" + out
	return out.substr(0, 16)


# ------------------------------------------------------------ storage ---

## Saves a JSON object. public = readable by other players.
func write_object(collection: String, key: String, value: Dictionary, public: bool = false) -> Dictionary:
	return await request(HTTPClient.METHOD_PUT, "/v2/storage", {"objects": [{
		"collection": collection,
		"key": key,
		"value": JSON.stringify(value),
		"permission_read": 2 if public else 1,
		"permission_write": 1,
	}]})


## Reads a JSON object (own by default). Returns {} when missing.
func read_object(collection: String, key: String, owner_id: String = "") -> Dictionary:
	var uid := owner_id if owner_id != "" else user_id
	var r := await request(HTTPClient.METHOD_POST, "/v2/storage", {"object_ids": [{
		"collection": collection, "key": key, "user_id": uid,
	}]})
	if not r["ok"]:
		return {}
	var objects: Array = (r["data"] as Dictionary).get("objects", [])
	if objects.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(str((objects[0] as Dictionary).get("value", "{}")))
	return parsed if parsed is Dictionary else {}


## Reads several objects at once: ids = [{collection, key, user_id}].
## Returns [{user_id, key, value: Dictionary}] for the ones that exist.
func read_objects(ids: Array) -> Array:
	if ids.is_empty():
		return []
	var r := await request(HTTPClient.METHOD_POST, "/v2/storage", {"object_ids": ids})
	if not r["ok"]:
		return []
	var out: Array = []
	for o: Dictionary in (r["data"] as Dictionary).get("objects", []):
		var v: Variant = JSON.parse_string(str(o.get("value", "{}")))
		out.append({"user_id": str(o.get("user_id", "")), "key": str(o.get("key", "")),
			"value": v if v is Dictionary else {}})
	return out


## Lists publicly readable objects of a collection (all users).
## Returns [{key, user_id, value: Dictionary}] (empty on error).
func list_public(collection: String, limit: int = 50) -> Array:
	var r := await request(HTTPClient.METHOD_GET, "/v2/storage/%s?limit=%d" % [q(collection), limit])
	if not r["ok"]:
		return []
	var out: Array = []
	for o: Dictionary in (r["data"] as Dictionary).get("objects", []):
		var v: Variant = JSON.parse_string(str(o.get("value", "{}")))
		out.append({"key": str(o.get("key", "")), "user_id": str(o.get("user_id", "")),
			"value": v if v is Dictionary else {}})
	return out


# ------------------------------------------------------------ friends ---

## Returns [{user: {...}, state: FriendState}] (empty on error).
func list_friends() -> Array:
	var r := await request(HTTPClient.METHOD_GET, "/v2/friend?limit=100")
	if not r["ok"]:
		return []
	return (r["data"] as Dictionary).get("friends", [])


func add_friend_by_username(uname: String) -> Dictionary:
	return await request(HTTPClient.METHOD_POST, "/v2/friend?usernames=%s" % q(uname.strip_edges()))


## Adding someone who invited you accepts their request.
func add_friend_by_id(id: String) -> Dictionary:
	return await request(HTTPClient.METHOD_POST, "/v2/friend?ids=%s" % q(id))


func remove_friend(id: String) -> Dictionary:
	return await request(HTTPClient.METHOD_DELETE, "/v2/friend?ids=%s" % q(id))


# -------------------------------------------------------- leaderboards ---

func submit_score(board: String, score: int) -> Dictionary:
	return await request(HTTPClient.METHOD_POST, "/v2/leaderboard/%s" % q(board), {"score": str(score)})


## Returns {records: [...], owner_records: [...]} ({} on error).
func list_records(board: String, limit: int = 10) -> Dictionary:
	var path := "/v2/leaderboard/%s?limit=%d" % [q(board), limit]
	if user_id != "":
		path += "&owner_ids=%s" % q(user_id)
	var r := await request(HTTPClient.METHOD_GET, path)
	return r["data"] if r["ok"] else {}


# ---------------------------------------------------------------- rpc ---

## Calls a server RPC. Returns the decoded JSON payload ({} on error).
func rpc(id: String, payload: Dictionary = {}) -> Dictionary:
	# Over HTTP the RPC body is the payload encoded as a JSON *string*.
	var r := await request(HTTPClient.METHOD_POST, "/v2/rpc/%s" % q(id), JSON.stringify(payload))
	if not r["ok"]:
		return {}
	var parsed: Variant = JSON.parse_string(str((r["data"] as Dictionary).get("payload", "{}")))
	return parsed if parsed is Dictionary else {}
