extends Node
## Multiplayer networking over ENet (UDP).
## Modes:
##   offline - solo play
##   host    - this device is the server AND plays (LAN / listen server)
##   client  - connected to a host or dedicated server
##   server  - dedicated headless server (no local player)
## Topology: clients send their state to the server (peer 1),
## the server relays it to everyone else. Registered as `Network`.

signal connection_succeeded
signal connection_failed(reason: String)
signal disconnected
signal player_joined(id: int, info: Dictionary)
signal player_left(id: int)
signal state_received(id: int, pos: Vector3, yaw: float, vel: Vector3, flags: int)
signal chat_received(id: int, sender: String, text: String)

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 32
const MAX_NAME := 16
const MAX_CHAT := 120

var mode: String = "offline"
## id -> {name, shirt, pants, skin}
var players: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func is_online() -> bool:
	return mode != "offline"


func is_server() -> bool:
	return mode == "host" or mode == "server"


func my_id() -> int:
	return multiplayer.get_unique_id() if is_online() else 1


## Parses "host", "host:port".
func parse_address(text: String) -> Array:
	var t := text.strip_edges()
	var port := DEFAULT_PORT
	var idx := t.rfind(":")
	if idx > 0 and t.count(":") == 1:
		port = int(t.substr(idx + 1))
		t = t.substr(0, idx)
	if port <= 0 or port > 65535:
		port = DEFAULT_PORT
	return [t, port]


func host(port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = "host"
	players.clear()
	players[1] = _sanitize(Game.profile())
	return OK


func start_dedicated(port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = "server"
	players.clear()
	print("[server] listening on UDP port %d (max %d players)" % [port, MAX_PLAYERS])
	return OK


func join(address: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = "client"
	players.clear()
	return OK


func leave() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	mode = "offline"
	players.clear()


## Private LAN IPv4 addresses of this device (to show when hosting).
func local_addresses() -> PackedStringArray:
	var out := PackedStringArray()
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("172."):
			out.append(a)
	return out


# ------------------------------------------------------------ outgoing ---

## Called by the local player ~20 times per second.
func send_state(pos: Vector3, yaw: float, vel: Vector3, flags: int) -> void:
	if mode == "client":
		_state.rpc_id(1, pos, yaw, vel, flags)
	elif mode == "host":
		_remote_state.rpc(1, pos, yaw, vel, flags)


func send_chat(text: String) -> void:
	var t := _clean_text(text, MAX_CHAT)
	if t == "":
		return
	if mode == "client":
		_chat_up.rpc_id(1, t)
	elif mode == "host":
		_broadcast_chat(1, t)
	else:
		chat_received.emit(1, Game.player_name, t)


# ------------------------------------------------------------- signals ---

func _on_peer_connected(id: int) -> void:
	if is_server():
		print("[net] peer connected: %d" % id)


func _on_peer_disconnected(id: int) -> void:
	if not is_server():
		return
	print("[net] peer disconnected: %d" % id)
	if players.has(id):
		players.erase(id)
		_player_left.rpc(id)
		player_left.emit(id)


func _on_connected_to_server() -> void:
	_register.rpc_id(1, Game.profile())
	connection_succeeded.emit()


func _on_connection_failed() -> void:
	leave()
	connection_failed.emit("Could not connect to server")


func _on_server_disconnected() -> void:
	leave()
	disconnected.emit()


# ---------------------------------------------------------------- RPCs ---

@rpc("any_peer", "call_remote", "reliable")
func _register(info: Dictionary) -> void:
	if not is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	var clean := _sanitize(info)
	players[id] = clean
	# Tell the newcomer about everyone already here.
	for pid: int in players:
		if pid != id:
			_player_joined.rpc_id(id, pid, players[pid])
	# Tell everyone else about the newcomer.
	for pid in multiplayer.get_peers():
		if pid != id:
			_player_joined.rpc_id(pid, id, clean)
	if mode == "host":
		player_joined.emit(id, clean)
	print("[net] %s joined as %d (%d players)" % [clean["name"], id, players.size()])


@rpc("authority", "call_remote", "reliable")
func _player_joined(id: int, info: Dictionary) -> void:
	players[id] = info
	player_joined.emit(id, info)


@rpc("authority", "call_remote", "reliable")
func _player_left(id: int) -> void:
	players.erase(id)
	player_left.emit(id)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _state(pos: Vector3, yaw: float, vel: Vector3, flags: int) -> void:
	if not is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id):
		return
	# Basic sanity limits.
	if not pos.is_finite() or pos.length() > 5000.0:
		return
	vel = vel.limit_length(80.0)
	for pid in multiplayer.get_peers():
		if pid != id:
			_remote_state.rpc_id(pid, id, pos, yaw, vel, flags)
	if mode == "host":
		state_received.emit(id, pos, yaw, vel, flags)


@rpc("authority", "call_remote", "unreliable_ordered")
func _remote_state(id: int, pos: Vector3, yaw: float, vel: Vector3, flags: int) -> void:
	state_received.emit(id, pos, yaw, vel, flags)


@rpc("any_peer", "call_remote", "reliable")
func _chat_up(text: String) -> void:
	if not is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id):
		return
	_broadcast_chat(id, _clean_text(text, MAX_CHAT))


func _broadcast_chat(id: int, text: String) -> void:
	if text == "":
		return
	var sender: String = (players.get(id, {}) as Dictionary).get("name", "?")
	_chat_down.rpc(id, sender, text)
	if mode == "host":
		chat_received.emit(id, sender, text)


@rpc("authority", "call_remote", "reliable")
func _chat_down(id: int, sender: String, text: String) -> void:
	chat_received.emit(id, sender, text)


# ------------------------------------------------------------- helpers ---

func _clean_text(text: String, max_len: int) -> String:
	var t := text.strip_edges().replace("\n", " ").replace("[", "(").replace("]", ")")
	return t.substr(0, max_len)


func _sanitize(info: Dictionary) -> Dictionary:
	var nm := _clean_text(str(info.get("name", "Player")), MAX_NAME)
	if nm == "":
		nm = "Player"
	return {
		"name": nm,
		"shirt": _color(info.get("shirt"), Game.SHIRT_COLORS[0]),
		"pants": _color(info.get("pants"), Game.PANTS_COLORS[0]),
		"skin": _color(info.get("skin"), Game.SKIN_COLORS[0]),
	}


func _color(v: Variant, fallback: Color) -> Color:
	if v is Color:
		var c: Color = v
		return Color(clampf(c.r, 0, 1), clampf(c.g, 0, 1), clampf(c.b, 0, 1), 1.0)
	return fallback
