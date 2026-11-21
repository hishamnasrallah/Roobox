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


func _ready() -> void:
	var games := GameLibrary.all()
	_check(games.size() == GameLibrary.count() and games.size() >= 200, "at least 200 games", games.size())
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
		if not built.has(e["genre"]):
			built[e["genre"]] = true
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
	print("LIBRARYTEST games=%d genres_built=%d avg_parts=%d max_parts=%d" % [
		games.size(), built.size(), total_parts / maxi(games.size(), 1), max_parts])
	if _fails.is_empty():
		print("LIBRARYTEST PASS")
	else:
		print("LIBRARYTEST FAIL: %d problem(s)" % _fails.size())
	get_tree().quit(0 if _fails.is_empty() else 1)
