extends Node3D
## CI test for the built-in game library:
##   godot --headless --path game --fixed-fps 60 -- --librarytest
## Generates every game, validates it, compiles its script and builds one
## game of each type into the scene.

var _fails: Array[String] = []


func _check(ok: bool, what: String, detail: Variant = "") -> void:
	if not ok:
		print("LIBRARYTEST FAIL %s %s" % [what, str(detail)])
		_fails.append(what)


func _positions(lvl: Dictionary) -> Dictionary:
	var out := {}
	for p: Dictionary in lvl["parts"]:
		var v := Level.pos(p).snapped(Vector3.ONE)
		out["%d|%d|%d" % [int(v.x), int(v.y), int(v.z)]] = true
	return out


func _ready() -> void:
	var games := GameLibrary.all()
	_check(games.size() == GameLibrary.count() and games.size() >= 300, "at least 300 games", games.size())
	_check(GameLibrary.GENRES.size() >= 19, "at least 19 game types", GameLibrary.GENRES.size())
	# The two layouts of every game type must really be different maps.
	for g: Dictionary in GameLibrary.GENRES:
		var la := GameLibrary.generate("g:%s:%s" % [g["id"], GameLibrary.THEMES[0]["id"]])
		var lb := GameLibrary.generate("g:%s:%s" % [g["id"], GameLibrary.THEMES[1]["id"]])
		var pa := _positions(la)
		var pb := _positions(lb)
		var same := 0
		for k: String in pa:
			if pb.has(k):
				same += 1
		var ratio := float(same) / maxf(1.0, float(mini(pa.size(), pb.size())))
		_check(ratio < 0.5, "layouts A and B differ", [g["id"], ratio])
	var titles := {}
	var total_parts := 0
	var max_parts := 0
	var built := {}
	for e: Dictionary in games:
		var lvl := GameLibrary.generate(e["id"])
		var parts: Array = lvl["parts"]
		total_parts += parts.size()
		max_parts = maxi(max_parts, parts.size())
		_check(not titles.has(e["title"]), "unique title", e["title"])
		titles[e["title"]] = true
		_check(parts.size() >= 10 and parts.size() < Level.MAX_PARTS, "part count in range", [e["id"], parts.size()])
		var spawns := 0
		for p: Dictionary in parts:
			if p["t"] == "spawn":
				spawns += 1
		_check(spawns == 1, "exactly one spawn", [e["id"], spawns])
		if lvl.has("script"):
			var err := RooScript.new().compile(str(lvl["script"]))
			_check(err == "", "script compiles", [e["id"], err])
		var again := GameLibrary.generate(e["id"])
		_check(JSON.stringify(again) == JSON.stringify(lvl), "generation is deterministic", e["id"])
		var bkey := "%s/%d" % [e["genre"], int(e["variant"])]
		if not built.has(bkey):
			built[bkey] = true
			var proot := Node3D.new()
			add_child(proot)
			var shot := LevelPreview.build(proot, lvl)
			_check(proot.get_child_count() > 0 and (shot["eye"] as Vector3).is_finite(), "thumbnail preview builds", e["id"])
			proot.queue_free()
			var root := Node3D.new()
			add_child(root)
			var reg := Level.build_play(root, lvl)
			_check(root.get_child_count() > 0, "level builds", e["id"])
			if lvl.has("script"):
				var host := ScriptHost.new()
				host.source = str(lvl["script"])
				host.part_names = (reg["by_name"] as Dictionary).keys()
				add_child(host)
				_check(host.last_error == "", "script starts", [e["id"], host.last_error])
				host.queue_free()
			root.queue_free()
	_check(built.size() == GameLibrary.GENRES.size() * 2, "every layout was built", built.size())
	print("LIBRARYTEST games=%d layouts_built=%d avg_parts=%d max_parts=%d" % [
		games.size(), built.size(), total_parts / maxi(games.size(), 1), max_parts])
	if _fails.is_empty():
		print("LIBRARYTEST PASS")
	else:
		print("LIBRARYTEST FAIL: %d problem(s)" % _fails.size())
	get_tree().quit(0 if _fails.is_empty() else 1)
