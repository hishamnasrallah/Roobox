extends Node
## Automated multiplayer test client (CI):
##   godot --headless --path game -- --nettest --port 7788 --name Alice
## Walks in circles, chats, and checks that it sees another player move
## and talk. Prints NETTEST PASS / NETTEST FAIL and exits.

const DURATION := 12.0

var main: Node3D
var _t: float = 0.0
var _chat_t: float = 0.0
var _states: int = 0
var _chats_from_others: int = 0
var _max_players: int = 0
var _max_remotes: int = 0


func _ready() -> void:
	Network.state_received.connect(_on_state)
	Network.chat_received.connect(_on_chat)
	print("NETTEST %s connected as peer %d" % [Game.player_name, Network.my_id()])


func _on_state(_id: int, _pos: Vector3, _yaw: float, _vel: Vector3, _flags: int) -> void:
	_states += 1


func _on_chat(_id: int, sender: String, text: String) -> void:
	if sender != Game.player_name:
		_chats_from_others += 1
		print("NETTEST %s got chat from %s: %s" % [Game.player_name, sender, text])


func _process(delta: float) -> void:
	_t += delta
	_chat_t += delta
	Game.touch_move = Vector2(sin(_t * 1.5), cos(_t * 1.5)) * 0.8
	if _chat_t > 1.5:
		_chat_t = 0.0
		Network.send_chat("hello from %s" % Game.player_name)
	var remotes: Dictionary = main.get("_remotes")
	_max_players = maxi(_max_players, Network.players.size())
	_max_remotes = maxi(_max_remotes, remotes.size())
	if _t < DURATION:
		return
	set_process(false)
	var ok := _max_players >= 1 and _states >= 20 and _chats_from_others >= 1 and _max_remotes >= 1
	print("NETTEST %s %s players=%d states=%d chats=%d remotes=%d" % [
		Game.player_name, "PASS" if ok else "FAIL", _max_players, _states,
		_chats_from_others, _max_remotes])
	get_tree().quit(0 if ok else 1)
