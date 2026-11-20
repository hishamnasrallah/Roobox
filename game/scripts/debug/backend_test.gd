extends Node
## Integration test against a real Nakama server (CI):
##   godot --headless --path game -- --backendtest --backend http://127.0.0.1:7350
## Two players sign up, save/load cloud data, post course times, become
## friends and call the server_list RPC. Prints BACKENDTEST PASS / FAIL.

var url: String = "http://127.0.0.1:7350"
var _fails: Array[String] = []


func _ready() -> void:
	_run()


func _check(ok: bool, what: String, detail: Variant = "") -> void:
	print("BACKENDTEST %s %s %s" % ["ok  " if ok else "FAIL", what, str(detail) if not ok else ""])
	if not ok:
		_fails.append(what)


func _uid() -> String:
	return "test-" + Crypto.new().generate_random_bytes(12).hex_encode()


func _run() -> void:
	var tag := str(randi() % 100000)
	var a := NakamaClient.new(self, url)
	var b := NakamaClient.new(self, url)

	# --- Sign up / login ---
	var ra := await a.authenticate_device(_uid(), "alice" + tag)
	_check(ra["ok"] and a.username.begins_with("alice"), "alice signs up", ra)
	var rb := await b.authenticate_device(_uid(), "bob" + tag)
	_check(rb["ok"] and b.username.begins_with("bob"), "bob signs up", rb)
	if not _fails.is_empty():
		_finish()
		return

	var rn := await a.update_display_name("Alice A")
	await a.get_account()
	_check(rn["ok"] and a.display_name == "Alice A", "display name update", rn)

	# --- Cloud save ---
	var rw := await a.write_object("progress", "stats", {"coins": 42, "best_times": {"Obby Land": 61.5}})
	_check(rw["ok"], "write cloud save", rw)
	var obj := await a.read_object("progress", "stats")
	_check(int(obj.get("coins", 0)) == 42, "read cloud save back", obj)
	var pub := await a.write_object("profile", "avatar", {"shirt": 3}, true)
	_check(pub["ok"], "write public avatar", pub)
	var other := await b.read_object("profile", "avatar", a.user_id)
	_check(int(other.get("shirt", -1)) == 3, "bob reads alice's public avatar", other)

	# --- Leaderboards (+ anti-cheat hook) ---
	var s1 := await a.submit_score("obby_land", 65000)
	_check(s1["ok"], "alice posts 65.0s", s1)
	var s2 := await b.submit_score("obby_land", 70000)
	_check(s2["ok"], "bob posts 70.0s", s2)
	var cheat := await a.submit_score("obby_land", 1000)
	_check(not cheat["ok"], "server rejects an impossible 1.0s time", cheat)
	var recs := await a.list_records("obby_land", 10)
	var rows: Array = recs.get("records", [])
	var first: Dictionary = rows[0] if rows.size() > 0 else {}
	_check(rows.size() >= 2 and str(first.get("owner_id", "")) == a.user_id
		and str(first.get("score", "")) == "65000", "leaderboard order (alice first)", recs)

	# --- Friends ---
	var fr := await b.add_friend_by_username(a.username)
	_check(fr["ok"], "bob sends friend request", fr)
	var af := await a.list_friends()
	var pending := false
	for f: Dictionary in af:
		if str((f.get("user", {}) as Dictionary).get("id", "")) == b.user_id and int(f.get("state", 0)) == 2:
			pending = true
	_check(pending, "alice sees bob's request", af)
	var acc := await a.add_friend_by_id(b.user_id)
	_check(acc["ok"], "alice accepts", acc)
	var bf := await b.list_friends()
	var mutual := false
	for f: Dictionary in bf:
		if str((f.get("user", {}) as Dictionary).get("id", "")) == a.user_id and int(f.get("state", 0)) == 0:
			mutual = true
	_check(mutual, "bob and alice are friends", bf)

	# --- RPC ---
	var sl := await a.rpc("server_list")
	_check(sl.has("servers"), "server_list RPC", sl)

	# --- High-level Backend autoload (what the game uses) ---
	Game.backend_url = url
	Game.player_name = "Carol" + tag
	var ok := await Backend.connect_backend()
	_check(ok and Backend.online, "Backend autoload signs in", Backend.last_error)
	Game.lifetime_coins = 7
	Game.best_times = {"Sky Tower": 99.0}
	await Backend.push_progress()
	Game.lifetime_coins = 0
	Game.best_times = {}
	await Backend.pull_progress()
	_check(Game.lifetime_coins == 7 and float(Game.best_times.get("Sky Tower", 0.0)) == 99.0,
		"progress round-trips through the cloud", [Game.lifetime_coins, Game.best_times])
	var servers := await Backend.game_servers()
	_check(servers.size() >= 1, "game server list (with fallback)", servers)

	# --- Community games (Studio publishing) ---
	var lvl := Level.new_level("CI Game " + tag)
	var pub_ok: bool = await Backend.publish_game("ci" + tag, lvl)
	_check(pub_ok, "publish a Studio game", Backend.last_error)
	var games: Array = await Backend.list_community(50)
	var found: Dictionary = {}
	for g: Dictionary in games:
		if g["key"] == "ci" + tag:
			found = g
	_check(not found.is_empty() and found["name"] == "CI Game " + tag, "game listed in COMMUNITY", games.size())
	if not found.is_empty():
		var dl: Dictionary = await Backend.load_community(found["owner"], found["key"])
		_check((dl.get("parts", []) as Array).size() == 2, "download the published level", dl)
	var as_bob := await b.list_public("games_index", 50)
	var bob_sees := false
	for o: Dictionary in as_bob:
		if o["key"] == "ci" + tag:
			bob_sees = true
	_check(bob_sees, "another player sees the published game")

	_finish()


func _finish() -> void:
	if _fails.is_empty():
		print("BACKENDTEST PASS")
	else:
		print("BACKENDTEST FAIL: " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)
