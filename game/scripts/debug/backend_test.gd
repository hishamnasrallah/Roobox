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
	var bob_dev := _uid()
	var rb := await b.authenticate_device(bob_dev, "bob" + tag)
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

	# --- Presence (what a friend is playing, so you can join them) ---
	var pw := await a.write_object("presence", "now", {"exp": "ugc", "title": "Meadow Obby",
		"server": "10.0.0.5:7777", "t": int(Time.get_unix_time_from_system())}, true)
	_check(pw["ok"], "alice publishes presence", pw)
	var seen := await b.read_objects([{"collection": "presence", "key": "now", "user_id": a.user_id}])
	_check(seen.size() == 1 and str((seen[0]["value"] as Dictionary).get("server", "")) == "10.0.0.5:7777",
		"bob sees what alice is playing", seen)

	# --- Reports + moderation (ADMIN_USERS=roomodci in CI) ---
	var rep := await b.rpc("report", {"target": "Alice A", "reason": "ci report", "context": ["hi"], "reporter": "bob"})
	_check(bool(rep.get("ok", false)), "report via RPC", rep)
	var notmod := await b.rpc("mod_check")
	_check(not bool(notmod.get("admin", true)), "normal player is not a moderator", notmod)
	var denied := await b.rpc("mod_reports")
	_check(not denied.has("reports"), "normal player can't read reports", denied)
	var m := NakamaClient.new(self, url)
	var rm := await m.authenticate_device(_uid(), "roomodci")
	_check(rm["ok"] and m.username == "roomodci", "moderator signs in", rm)
	var ismod := await m.rpc("mod_check")
	_check(bool(ismod.get("admin", false)), "moderator is recognised", ismod)
	var reps := await m.rpc("mod_reports")
	var found_rep := ""
	for r0 in reps.get("reports", []):
		if str((r0 as Dictionary).get("reason", "")) == "ci report":
			found_rep = str((r0 as Dictionary).get("key", ""))
	_check(found_rep != "", "moderator sees the report", reps)
	var dis := await m.rpc("mod_dismiss", {"key": found_rep})
	_check(bool(dis.get("ok", false)), "moderator dismisses the report", dis)
	await a.write_object("games_index", "badgame", {"name": "Bad", "author": "a", "parts": 1, "updated": 1}, true)
	var rmg := await m.rpc("mod_remove_game", {"owner": a.user_id, "key": "badgame"})
	var gone := await b.read_objects([{"collection": "games_index", "key": "badgame", "user_id": a.user_id}])
	_check(bool(rmg.get("ok", false)) and gone.is_empty(), "moderator removes a community game", [rmg, gone])

	# --- Likes / plays ---
	var v1 := await a.rpc("game_vote", {"id": "g:obby:meadow", "v": 1})
	var v2 := await b.rpc("game_vote", {"id": "g:obby:meadow", "v": 1})
	var v3 := await b.rpc("game_vote", {"id": "g:obby:meadow", "v": -1})
	await a.rpc("game_play", {"id": "g:obby:meadow"})
	var gs := await a.rpc("game_stats", {"ids": ["g:obby:meadow", "g:none:none"]})
	var row: Dictionary = (gs.get("stats", {}) as Dictionary).get("g:obby:meadow", {})
	_check(int(v1.get("likes", 0)) == 1 and int(v2.get("likes", 0)) == 2 and int(v3.get("likes", 0)) == 1,
		"likes count once per player (changing a vote moves it)", [v1, v2, v3])
	_check(int(row.get("likes", 0)) == 1 and int(row.get("dislikes", 0)) == 1 and int(row.get("plays", 0)) == 1
		and int(row.get("my", 0)) == 1, "game stats (likes, dislikes, plays, my vote)", gs)

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
	Game.badges = {"welcome": 1700000000}
	Game.favorites = ["g:obby:meadow"]
	await Backend.push_progress()
	Game.lifetime_coins = 0
	Game.best_times = {}
	Game.badges = {}
	Game.favorites = []
	await Backend.pull_progress()
	_check(Game.lifetime_coins == 7 and float(Game.best_times.get("Sky Tower", 0.0)) == 99.0,
		"progress round-trips through the cloud", [Game.lifetime_coins, Game.best_times])
	_check(Game.has_badge("welcome") and Game.is_favorite("g:obby:meadow"),
		"badges and favorites round-trip through the cloud", [Game.badges, Game.favorites])
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

	await _admin_tests(a, b, bob_dev, m)
	_finish()


func _http_kick_list() -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	http.request(url + "/v2/rpc/kick_list?http_key=defaulthttpkey&unwrap",
		PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, "{}")
	var res: Array = await http.request_completed
	http.queue_free()
	var d: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	return d if d is Dictionary else {}


## Admin tools (CI runs Nakama with ADMIN_USERS=roomodci, JOIN_SECRET=ci-join-secret).
func _admin_tests(a: NakamaClient, b: NakamaClient, bob_dev: String, mod: NakamaClient) -> void:
	var found := await mod.rpc("admin_user", {"query": b.username})
	_check(bool(found.get("found", false)) and str((found.get("user", {}) as Dictionary).get("id", "")) == b.user_id,
		"admin finds a player by username", found)
	var nb := await b.rpc("admin_user", {"query": a.username})
	_check(not bool(nb.get("found", false)), "normal players can't use admin tools", nb)
	# Join pass for protected game servers.
	var tk := await b.rpc("join_ticket")
	var ticket := str(tk.get("ticket", ""))
	var ok_pass := ServerGuard.verify(ticket, "ci-join-secret")
	_check(ok_pass["ok"] and str(ok_pass["uid"]) == b.user_id, "join pass is signed and checks out", [ticket, ok_pass])
	var bad_pass := ServerGuard.verify(ticket.replace(b.user_id, a.user_id), "ci-join-secret")
	_check(not bad_pass["ok"], "a changed join pass is rejected", bad_pass)
	# Mute + kick.
	var mu := await mod.rpc("admin_mute", {"user_id": b.user_id, "name": b.username, "hours": 1})
	var my := await b.rpc("my_status")
	_check(bool(mu.get("ok", false)) and int(my.get("chat_ends", 0)) > int(my.get("now", 0)), "chat mute", [mu, my])
	await mod.rpc("admin_kick", {"user_id": b.user_id, "name": b.username})
	var kl := await _http_kick_list()
	_check(b.user_id in (kl.get("kick", []) as Array) and (kl.get("mute", {}) as Dictionary).has(b.user_id),
		"game servers get the kick and mute list (http key)", kl)
	# Temporary ban: 2 seconds.
	var bn := await mod.rpc("admin_ban", {"user_id": b.user_id, "name": b.username, "hours": 2.0 / 3600.0, "reason": "ci"})
	_check(bool(bn.get("ok", false)), "ban a player", bn)
	var again := NakamaClient.new(self, url)
	var blocked_login := await again.authenticate_device(bob_dev, b.username)
	_check(not blocked_login["ok"], "a banned player can't sign in", blocked_login)
	await get_tree().create_timer(3.0).timeout
	var later := NakamaClient.new(self, url)
	var back := await later.authenticate_device(bob_dev, b.username)
	_check(back["ok"] and later.user_id == b.user_id, "a temporary ban ends by itself", back)
	# Permanent ban + unban.
	await mod.rpc("admin_ban", {"user_id": b.user_id, "name": b.username, "hours": 0, "reason": "ci forever"})
	var st := await mod.rpc("admin_user", {"query": b.username})
	_check(bool((st.get("state", {}) as Dictionary).get("banned", false)), "ban shows in the admin panel", st)
	var ub := await mod.rpc("admin_unban", {"user_id": b.user_id, "name": b.username})
	var after := NakamaClient.new(self, url)
	var ok_login := await after.authenticate_device(bob_dev, b.username)
	_check(bool(ub.get("ok", false)) and ok_login["ok"], "unban lets the player back in", ok_login)
	await mod.rpc("admin_mute", {"user_id": b.user_id, "name": b.username, "hours": 0})
	# Delete a player's published games.
	await a.write_object("games_index", "del1", {"name": "Del", "author": "a", "parts": 1, "updated": 1}, true)
	var dg := await mod.rpc("admin_delete_games", {"user_id": a.user_id, "name": a.username})
	_check(int(dg.get("deleted", 0)) >= 1, "delete all games of a player", dg)
	var lg := await mod.rpc("admin_log")
	_check((lg.get("log", []) as Array).size() >= 5, "every admin action is logged", (lg.get("log", []) as Array).size())
	var bl := await a.block_user(after.user_id)
	_check(bl["ok"], "block a player", bl)
	# Account deletion (required by Google Play).
	var dev := _uid()
	var tmp := NakamaClient.new(self, url)
	await tmp.authenticate_device(dev, "deleteme")
	var old_id := tmp.user_id
	var del := await tmp.rpc("delete_my_account")
	var fresh := NakamaClient.new(self, url)
	await fresh.authenticate_device(dev, "deleteme")
	_check(bool(del.get("ok", false)) and fresh.user_id != "" and fresh.user_id != old_id,
		"players can delete their account", [del, old_id, fresh.user_id])


func _finish() -> void:
	if _fails.is_empty():
		print("BACKENDTEST PASS")
	else:
		print("BACKENDTEST FAIL: " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)
