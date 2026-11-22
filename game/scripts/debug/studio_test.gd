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

	# --- Materials + new parts ---
	st.set_tool("build")
	st.set_material("brick")
	st.set_preset("cube")
	var bc := st.place_at(Vector3(15.3, 0, 15.6), Vector3.UP)
	_check(bc.get("mat", "") == "brick" and Level.size(bc) == Vector3.ONE and _p(bc) == Vector3(15.5, 0.5, 15.5),
		"1x1 brick cube on the grid", bc)
	st.set_material("plastic")
	var k := 0
	for id in ["stairs", "cone", "spikes", "speed", "conveyor", "water", "ladder", "light", "sign", "tree"]:
		st.set_preset(id)
		st.place_at(Vector3(-28 + k * 5, 0, 26), Vector3.UP)
		k += 1
	st.set_preset("teleport")
	var tp1 := st.place_at(Vector3(20, 0, -20), Vector3.UP)
	var tp2 := st.place_at(Vector3(-20, 0, 20), Vector3.UP)
	st.set_tool("select")
	for tp in [tp1, tp2]:
		st.select(st._entry_of_part(tp))
		st.name_selected("tp")
	st.set_tool("build")
	st.cycle_env()
	_check(str(st.level.get("env", "")) == "sunset", "sky preset cycles", st.level.get("env"))

	# --- AIR building on the plane ---
	st.set_tool("build")
	st.set_preset("block")
	st.set_build_height(10.0)
	var pp := st.plane_point(Vector3(3.2, 30, 3.4), Vector3(0, -1, 0))
	_check(pp.is_equal_approx(Vector3(3.2, 10, 3.4)), "ray meets the build plane", pp)
	var air := st.place_at(pp, Vector3.UP)
	_check(_p(air) == Vector3(3, 11, 3), "place a block in the air", air)
	st.set_build_height(0.0)

	# --- Studio tools: models, groups, handles, snapping, redo, properties ---
	st.set_tool("build")
	st.set_grid(1.0)
	var mparts := st.place_model("house", Vector3(30, 0, 30))
	_check(mparts.size() >= 8 and str((mparts[0] as Dictionary).get("g", "")) != "", "model is placed as a group", mparts.size())
	st.set_tool("select")
	st.select(st._entry_of_part(mparts[0]))
	_check(st.selection_size() == mparts.size(), "selecting one part selects the whole model", st.selection_size())
	st.set_tool("move")
	var mbefore := _p(mparts[0])
	st.begin_transform("move", Vector3.RIGHT)
	st.update_transform(3.4)
	st.end_transform()
	_check(_p(mparts[0]).is_equal_approx(mbefore + Vector3(3, 0, 0)), "move handle snaps to the grid", _p(mparts[0]))
	st.undo()
	_check(_p(mparts[0]).is_equal_approx(mbefore), "undo a handle drag", _p(mparts[0]))
	st.redo()
	_check(_p(mparts[0]).is_equal_approx(mbefore + Vector3(3, 0, 0)), "redo a handle drag", _p(mparts[0]))
	st.set_tool("rotate")
	st.set_rot_step(90.0)
	st.begin_transform("rotate", Vector3.UP)
	st.update_transform(100.0)
	st.end_transform()
	_check(int((mparts[0] as Dictionary).get("r", 0)) == 1, "rotate handle turns the model in 90 degree steps", mparts[0])
	st.set_tool("build")
	st.set_preset("block")
	var free := st.place_at(Vector3(-30, 0, 30), Vector3.UP)
	st.set_tool("scale")
	st.select(st._entry_of_part(free))
	st.begin_transform("scale", Vector3.UP)
	st.update_transform(2.2)
	st.end_transform()
	_check(Level.size(free) == Vector3(2, 4, 2) and _p(free) == Vector3(-30, 2, 30), "scale handle grows one face", free)
	st.set_rot_step(15.0)
	st.rotate_selected()
	_check(is_equal_approx(float(free.get("ry", 0.0)), 15.0), "free rotation in 15 degree steps", free)
	st.set_transparency(0.5)
	st.toggle_flag("nc")
	st.toggle_flag("u")
	_check(is_equal_approx(float(free.get("a", 0.0)), 0.5) and free.get("nc", 0) == 1 and free.get("u", 0) == 1,
		"transparency / can-collide / anchored properties", free)
	st.set_rot_step(90.0)
	st.set_tool("build")
	st.set_preset("cube")
	var qa := st.place_at(Vector3(-36, 0, 36), Vector3.UP)
	var qb := st.place_at(Vector3(-40, 0, 36), Vector3.UP)
	st.set_tool("select")
	st.toggle_multi()
	st.select(st._entry_of_part(qa))
	st.select(st._entry_of_part(qb))
	_check(st.selection_size() == 2, "multi-select", st.selection_size())
	st.group_selected()
	st.toggle_multi()
	st.select({})
	st.select(st._entry_of_part(qa))
	_check(st.selection_size() == 2 and qa.get("g", "") == qb.get("g", "x"), "group selects together", [qa, qb])
	st.ungroup_selected()
	_check(not qa.has("g") and not qb.has("g"), "ungroup")
	st.select({})
	var n_terrain := st.part_count()
	var added := st.generate_terrain("hills")
	_check(added > 100 and st.part_count() == n_terrain + added, "terrain generator", added)
	st.clear_terrain()
	_check(st.part_count() == n_terrain, "clear terrain", st.part_count())
	st.set_tool("select")
	st.select(st._entry_of_part(free))
	_check(st.copy_to_clipboard() == 1, "copy to clipboard")
	var n_paste := st.part_count()
	var pasted := st.paste_clipboard()
	_check(pasted.size() == 1 and st.part_count() == n_paste + 1, "paste from clipboard", pasted.size())
	st.select({})
	st.set_tool("build")
	var kk := 0
	st.set_preset("seat")
	st.place_at(Vector3(-20, 0, 10), Vector3.UP)
	st.set_preset("kart")
	st.place_at(Vector3(20, 0, 20), Vector3.UP)
	for id in ["corner", "truss", "fire", "smoke", "sparkles", "speedcoil", "gravitycoil"]:
		st.set_preset(id)
		var np := st.place_at(Vector3(-28 + kk * 5, 0, -34), Vector3.UP)
		_check(not np.is_empty() and np["t"] == id, "place " + id)
		kk += 1

	var bad := st.set_script_text("on_touch('door', function(p)\n  p:give_coins(")
	_check(bad.begins_with("line "), "script syntax errors are reported", bad)
	var good := st.set_script_text("""on_start(function()
  world.find("door"):set_color(9)
  score.set(3)
  ui.status("hello")
end)
every(0.5, function() score.add(1) end)
on_join(function(p)
  p:set_stat("Joined", 1)
  p:set_data("visits", (p:get_data("visits") or 0) + 1)
end)
on_touch("door", function(p)
  p:add_stat("Touches", 1)
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
	var vols := {}
	var tp_ok := false
	for n in ex.get_children():
		if n is PartVolume:
			vols[(n as PartVolume).kind] = true
			if (n as PartVolume).kind == "teleport" and (n as PartVolume).target.is_finite():
				tp_ok = true
	_check(vols.has("water") and vols.has("ladder") and vols.has("speed") and vols.has("conveyor"),
		"functional parts become volumes in play", vols.keys())
	_check(tp_ok, "teleports with the same name are paired")
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
	var door_index := -1
	var lparts: Array = (ex.get("level") as Dictionary)["parts"] if ex != null else []
	for li in lparts.size():
		if str((lparts[li] as Dictionary).get("n", "")) == "door":
			door_index = li
	main.call("_on_ugc_touched", "door#%d" % door_index)
	await get_tree().process_frame
	_check(Game.lifetime_coins == coins_before + 14, "per-part touch tokens reach on_touch", [door_index, Game.lifetime_coins])
	var hs := host as ScriptHost
	_check(hs != null and float((hs._stats.get(Network.my_id(), {}) as Dictionary).get("Touches", 0)) >= 2.0,
		"player stats for the leaderboard", hs._stats if hs != null else null)
	Game.emote_requested.emit("wave")
	_check(player.avatar.emote == "wave" and player.emote_index() == 1, "emote plays and is sent over the network")
	_check(Game.has_badge("dancer"), "emote badge")
	player.give_gear("speedcoil")
	_check(is_equal_approx(player.gear_speed, 1.6), "speed coil gear")
	var gears := 0
	for n3 in ex.get_children():
		if n3 is GearPickup:
			gears += 1
	_check(gears == 2, "coil parts become pickups in play", gears)
	_check(hs != null and float((hs._stats.get(Network.my_id(), {}) as Dictionary).get("Joined", 0)) == 1.0
		and float((hs._pdata.get(Network.my_id(), {}) as Dictionary).get("visits", 0)) == 1.0,
		"on_join runs with saved player data", hs._pdata if hs != null else null)
	var kart: Kart = null
	var seat: Seat = null
	for n4 in ex.get_children():
		if n4 is Kart:
			kart = n4
		elif n4 is Seat:
			seat = n4
	_check(kart != null and seat != null, "seat and kart parts exist in play")
	if seat != null:
		player.sit_on(seat)
		await get_tree().physics_frame
		_check(player.seat_node == seat and player.avatar.emote == "sit", "sitting on a seat")
		player.leave_seat()
		await get_tree().create_timer(1.3).timeout
	if kart != null:
		player.enter_vehicle(kart)
		_check(player.vehicle == kart and kart.driver == player, "getting into a kart")
		Game.touch_move = Vector2(0, 1)
		var k0 := player.global_position
		await get_tree().create_timer(1.0).timeout
		Game.touch_move = Vector2.ZERO
		_check(player.global_position.distance_to(k0) > 3.0 and kart.global_position.distance_to(player.global_position) < 1.0,
			"driving moves the player and the kart", [k0, player.global_position])
		player.leave_seat()
		_check(player.vehicle == null and kart.driver == null, "getting out of the kart")
	var phys := false
	for n2 in ex.get_children():
		if n2 is RigidBody3D:
			phys = true
	_check(phys, "unanchored part becomes a physics body in play")
	Level.delete_slot(slot)
	_finish()


func _finish() -> void:
	if _fails.is_empty():
		print("STUDIOTEST PASS")
	else:
		print("STUDIOTEST FAIL: " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)
