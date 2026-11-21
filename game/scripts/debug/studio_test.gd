extends Node
## CI test for Roobox Studio:
##   godot --headless --path game --fixed-fps 60 -- --studiotest
## Places parts, rotates, paints, deletes, undoes, saves/loads, then
## test-plays the creation and checks the player stands on the spawn.

var main: Node3D
var _fails: Array[String] = []


func _ready() -> void:
	_run()


func _check(ok: bool, what: String, detail: Variant = "") -> void:
	print("STUDIOTEST %s %s %s" % ["ok  " if ok else "FAIL", what, str(detail) if not ok else ""])
	if not ok:
		_fails.append(what)


func _p(part: Dictionary) -> Vector3:
	return Level.pos(part)


func _run() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var st: Studio = main.get("studio")
	_check(st != null, "studio opened")
	if st == null:
		_finish()
		return
	var n0 := st.part_count()
	_check(n0 == 2, "new level has baseplate + spawn", n0)

	st.set_preset("block")
	var p1 := st.place_at(Vector3(6, 0, 6), Vector3.UP)
	_check(_p(p1) == Vector3(6, 1, 6), "block snaps onto the baseplate", p1)
	var p2 := st.place_at(Vector3(6.3, 2.0, 6.2), Vector3.UP)
	_check(_p(p2) == Vector3(6, 3, 6), "block stacks on top", p2)
	var p3 := st.place_at(Vector3(7, 1, 6), Vector3.RIGHT)
	_check(_p(p3) == Vector3(8, 1, 6), "block attaches to a side face", p3)

	st.set_preset("ramp")
	st.rotate_preset()
	var p4 := st.place_at(Vector3(-6, 0, -6), Vector3.UP)
	_check(int(p4.get("r", -1)) == 1 and p4["t"] == "ramp", "rotated ramp", p4)
	st.rotate_preset()
	st.rotate_preset()
	st.rotate_preset()

	var i := 0
	for id in ["checkpoint", "kill", "jumppad", "coin", "finish"]:
		st.set_preset(id)
		st.place_at(Vector3(-20 + i * 8, 0, -20), Vector3.UP)
		i += 1
	st.set_preset("spawn")
	st.place_at(Vector3(10, 0, -10), Vector3.UP)
	var spawns := 0
	for p: Dictionary in st.level["parts"]:
		if p["t"] == "spawn":
			spawns += 1
	_check(spawns == 1, "only one spawn after moving it", spawns)

	var before := st.part_count()
	st.set_color(9)
	st.paint(st._entry_of_part(p3))
	_check(int(p3["c"]) == 9, "paint changes color", p3)
	st.remove(st._entry_of_part(p3))
	_check(st.part_count() == before - 1, "delete removes the part")
	st.undo()
	_check(st.part_count() == before, "undo restores the deleted part")
	st.undo()
	_check(int(p3["c"]) != 9, "undo reverts the paint", p3)

	# --- Select tool: move, resize, motion, name, copy, undo ---
	st.set_tool("select")
	st.select(st._entry_of_part(p1))
	_check(not st.selected_part().is_empty(), "select a part")
	st.move_selected(Vector3(1, 0, 0))
	_check(_p(p1) == Vector3(7, 1, 6), "move selected part", p1)
	st.resize_selected(1, 2.0)
	_check(Level.size(p1) == Vector3(2, 4, 2) and _p(p1) == Vector3(7, 2, 6), "resize grows upwards", p1)
	st.cycle_motion()
	_check(str(p1.get("m", "")) == "slide_x", "motion preset", p1)
	st.name_selected("door")
	_check(str(p1.get("n", "")) == "door", "name a part", p1)
	var n_before := st.part_count()
	var copy := st.duplicate_selected()
	_check(st.part_count() == n_before + 1 and _p(copy) == Vector3(9, 2, 6) and copy.get("n", "") == "door",
		"duplicate keeps settings and sits next to it", copy)
	st.undo()
	_check(st.part_count() == n_before, "undo duplicate")
	st.select(st._entry_of_part(p1))
	st.undo()
	_check(not p1.has("n") and str(p1.get("m", "")) == "slide_x", "undo name keeps motion", p1)
	st.select(st._entry_of_part(p1))
	st.name_selected("door")

	var bad := st.set_script_text("on_touch('door', function(p)\n  p:give_coins(")
	_check(bad.begins_with("line "), "script syntax errors are reported", bad)
	var good := st.set_script_text("""on_start(function()
  world.find("door"):set_color(9)
  score.set(3)
  ui.status("hello")
end)
every(0.5, function() score.add(1) end)
on_touch("door", function(p)
  p:give_coins(7)
  p:message("hi " .. p.name)
end)
""")
	_check(good == "", "valid script compiles", good)

	_check(st.save(), "save to disk")
	var slot := st.slot
	var loaded := Level.load_slot(slot)
	_check((loaded["parts"] as Array).size() == st.part_count(), "load gives the same parts",
		[(loaded["parts"] as Array).size(), st.part_count()])

	# Test-play the creation.
	st._on_test()
	await get_tree().create_timer(2.5).timeout
	var ex: Experience = main.get("experience")
	var player: Player = main.get("player")
	_check(ex != null and ex.id == "ugc", "test play starts the ugc experience")
	_check(player != null and player.is_on_floor(), "player stands on the spawn",
		player.global_position if player != null else null)
	_check(Game.total_coins >= 1, "coin part became a collectible", Game.total_coins)
	_check(Game.current_course != "", "finish part starts the course timer")
	var reg: Dictionary = ex.get("registry") if ex != null else {}
	var named: Array = (reg.get("by_name", {}) as Dictionary).get("door", [])
	_check(named.size() == 1 and named[0] is MovingPlatform, "named moving part is a MovingPlatform in play", named)
	var host: Node = main.get("game_mode")
	_check(host is ScriptHost and (host as ScriptHost).last_error == "", "script host runs without errors",
		(host as ScriptHost).last_error if host is ScriptHost else host)
	_check(int(ex.get("score")) >= 5, "script timers update the score", ex.get("score"))
	if named.size() == 1:
		var mesh := (named[0] as Node).get_node_or_null("Mesh") as MeshInstance3D
		var mat := mesh.material_override as StandardMaterial3D if mesh != null else null
		_check(mat != null and mat.albedo_color.is_equal_approx(Level.COLORS[9]), "script recolors the named part")
	var coins_before := Game.lifetime_coins
	main.call("_on_ugc_touched", "door")
	await get_tree().process_frame
	_check(Game.lifetime_coins == coins_before + 7, "on_touch gives coins to the player",
		[coins_before, Game.lifetime_coins])
	Level.delete_slot(slot)
	_finish()


func _finish() -> void:
	if _fails.is_empty():
		print("STUDIOTEST PASS")
	else:
		print("STUDIOTEST FAIL: " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)
