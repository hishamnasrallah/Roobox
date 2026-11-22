class_name ServerGuard
extends Node
## Protects dedicated game servers (configured with environment variables):
##   ROOBOX_JOIN_SECRET  - when set, players need a signed join pass from the
##                         account server (so banned players can't join)
##   ROOBOX_BACKEND_URL  - account server, e.g. http://nakama:7350
##   ROOBOX_HTTP_KEY     - its http key, to ask who to kick / who is muted
## Without these the server is open (fine for LAN / testing).

const POLL := 15.0

var _t: float = 0.0
var _busy: bool = false


static func secret() -> String:
	return OS.get_environment("ROOBOX_JOIN_SECRET")


static func enabled() -> bool:
	return secret() != ""


## Checks a pass "user_id|username|expires|chat_ends|signature".
## Returns {ok, uid, username, chat_ends, error}.
static func verify(ticket: String, key: String = "") -> Dictionary:
	var k := key if key != "" else secret()
	var parts := ticket.split("|")
	if parts.size() != 5:
		return {"ok": false, "error": "Please sign in (SETTINGS) to play on this server."}
	var msg := "|".join(parts.slice(0, 4))
	var sig := Crypto.new().hmac_digest(HashingContext.HASH_SHA256, k.to_utf8_buffer(), msg.to_utf8_buffer()).hex_encode()
	if sig != parts[4].to_lower():
		return {"ok": false, "error": "Your sign-in could not be checked. Try again."}
	if int(parts[2]) < int(Time.get_unix_time_from_system()):
		return {"ok": false, "error": "Your sign-in pass expired. Try again."}
	return {"ok": true, "uid": parts[0], "username": parts[1], "chat_ends": int(parts[3]), "error": ""}


func _process(delta: float) -> void:
	if Network.mode != "server" or _busy:
		return
	var url := OS.get_environment("ROOBOX_BACKEND_URL")
	var key := OS.get_environment("ROOBOX_HTTP_KEY")
	if url == "" or key == "":
		return
	_t += delta
	if _t < POLL:
		return
	_t = 0.0
	_poll(url, key)


func _poll(url: String, key: String) -> void:
	_busy = true
	var http := HTTPRequest.new()
	http.timeout = 8.0
	add_child(http)
	var err := http.request("%s/v2/rpc/kick_list?http_key=%s&unwrap" % [url, key.uri_encode()],
		PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, "{}")
	if err == OK:
		var res: Array = await http.request_completed
		if int(res[1]) == 200:
			var data: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
			if data is Dictionary:
				apply_list(data)
	http.queue_free()
	_busy = false


## {kick: [user ids], mute: {user id: unix time}}
func apply_list(data: Dictionary) -> void:
	var kick: Array = data.get("kick", []) if data.get("kick") is Array else []
	var mute: Dictionary = data.get("mute", {}) if data.get("mute") is Dictionary else {}
	for pid: int in Network.players.keys():
		var info: Dictionary = Network.players[pid]
		var uid := str(info.get("uid", ""))
		if uid == "":
			continue
		info["chat_ends"] = int(mute.get(uid, 0))
		if uid in kick:
			Network.kick(pid, "A moderator removed you from this server.")
