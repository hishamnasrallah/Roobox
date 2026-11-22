extends Experience
## Plays a user-made level (from Studio, local creations or COMMUNITY).
## The level data comes from Game.pending_level. Scripts run in a
## ScriptHost on the authority; this node applies their events and
## reports touches on named parts.

## A named part was touched by the local player.
signal touched(part_name: String)

var level: Dictionary = {}
## {by_index: {i: Node3D}, by_name: {name: [Node3D]}} for scripts.
var registry: Dictionary = {}
var score: int = -1
var status_text: String = ""
var _touch_cooldown: Dictionary = {}
## Team spawns {color: [pos]} (empty = no teams) and my team color.
var teams: Dictionary = {}
var my_team: int = -1


func setup() -> void:
	level = Level.sanitize(Game.pending_level)
	registry = Level.build_play(self, level)
	spawn_point = Level.spawn_point(level)
	var lowest := spawn_point.y
	for p: Dictionary in level["parts"]:
		lowest = minf(lowest, Level.pos(p).y - Level.size(p).y)
	kill_height = lowest - 25.0
	var sky_label := Label3D.new()
	sky_label.text = str(level["name"])
	sky_label.font_size = 160
	sky_label.outline_size = 32
	sky_label.modulate = Color(1.0, 0.85, 0.3)
	sky_label.outline_modulate = Color(0.06, 0.07, 0.15)
	sky_label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sky_label.position = spawn_point + Vector3(0, 7, -8)
	add_child(sky_label)
	_add_touch_areas()
	teams = Level.team_spawns(level)
	var host := get_parent()
	if host != null and host.has_method("apply_env"):
		host.call("apply_env", str(level.get("env", "day")))


func has_script() -> bool:
	return str(level.get("script", "")).strip_edges() != ""


func part_names() -> Array:
	return (registry.get("by_name", {}) as Dictionary).keys()


## Team name of a player ("" when the game has no teams).
func team_name(peer_id: int) -> String:
	var t := Level.team_for(peer_id, teams)
	return Level.COLOR_NAMES[t] if t >= 0 else ""


func team_color(peer_id: int) -> Color:
	var t := Level.team_for(peer_id, teams)
	return Level.COLORS[t] if t >= 0 else Color(1, 1, 1)


func part_position(n: String) -> Vector3:
	var nodes: Array = _nodes_for(n)
	for node in nodes:
		if is_instance_valid(node):
			return (node as Node3D).global_position
	return Vector3.ZERO


func on_player_ready(p: Player) -> void:
	Game.checkpoint_position = spawn_point
	if not teams.is_empty():
		my_team = Level.team_for(Network.my_id(), teams)
		var spots: Array = teams[my_team]
		var at: Vector3 = spots[randi() % spots.size()]
		Game.spawn_point = at
		Game.checkpoint_position = at
		p.teleport(at)
		if hud != null:
			hud.show_toast(tr("You are on the %s team") % tr(Level.COLOR_NAMES[my_team]), Level.COLORS[my_team])
	for part: Dictionary in level["parts"]:
		if part["t"] == "finish":
			Game.start_course(str(level["name"]))
			break
	_refresh_status()


# ------------------------------------------------------------ touches ---

func _add_touch_areas() -> void:
	var byn: Dictionary = registry.get("by_name", {})
	for n: String in byn:
		for node: Node3D in byn[n]:
			var area := Area3D.new()
			area.collision_layer = 4
			area.collision_mask = 2
			area.monitorable = false
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			var mesh := node.get_node_or_null("Mesh") as MeshInstance3D
			box.size = (mesh.scale if mesh != null else Vector3.ONE) + Vector3(0.4, 0.5, 0.4)
			cs.shape = box
			area.add_child(cs)
			node.add_child(area)
			var token := "%s#%d" % [n, int(node.get_meta("part_index", -1))]
			area.body_entered.connect(_on_area_entered.bind(token))


func _on_area_entered(body: Node3D, n: String) -> void:
	if not (body is Player):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_touch_cooldown.get(n, -10.0)) < 0.4:
		return
	_touch_cooldown[n] = now
	touched.emit(n)


# ------------------------------------------------------------- events ---

func apply_event(ev: Dictionary) -> void:
	match str(ev.get("t", "")):
		"level":
			if ev.get("state") is Dictionary:
				apply_event(ev["state"])
		"script_state":
			if int(ev.get("score", 0)) != 0:
				score = int(ev["score"])
			status_text = str(ev.get("status", ""))
			for op in ev.get("ops", []):
				if op is Dictionary:
					apply_event(op)
			if ev.get("stats") is Dictionary and hud != null:
				hud.set_leaderstats(ev["stats"])
			_refresh_status()
		"stats":
			if ev.get("s") is Dictionary and hud != null:
				hud.set_leaderstats(ev["s"])
		"sop":
			_world_op(str(ev["n"]), str(ev["op"]), ev.get("a", []))
		"pop":
			if int(ev.get("to", -1)) == Network.my_id():
				_player_op(str(ev["op"]), ev.get("a", []))
		"msg":
			if hud != null:
				hud.show_toast(str(ev.get("text", "")), Color(1, 1, 1))
		"status":
			status_text = str(ev.get("text", ""))
			_refresh_status()
		"score":
			score = int(ev.get("v", 0))
			_refresh_status()
		"snd":
			Sfx.play(str(ev.get("n", "click")))
		"gui":
			if hud != null:
				hud.set_gui(str(ev.get("id", "")), str(ev.get("k", "label")), str(ev.get("text", "")))
		"script_error":
			if hud != null and (Game.testing or Network.mode != "client"):
				hud.add_chat_line("Script error: %s" % ev.get("msg", ""), Color(1.0, 0.45, 0.45))


func _refresh_status() -> void:
	var parts: Array[String] = []
	if score >= 0:
		parts.append("Score: %d" % score)
	if status_text != "":
		parts.append(status_text)
	if Game.testing:
		parts.append("TEST MODE - MENU returns to the editor")
	set_status("   -   ".join(parts), Color(1.0, 0.85, 0.3))


## Nodes for "name" (every part with that name) or "name#index" (one part).
func _nodes_for(n: String) -> Array:
	if n.contains("#"):
		var node: Variant = (registry.get("by_index", {}) as Dictionary).get(int(n.get_slice("#", 1)))
		if node != null and is_instance_valid(node) and (node as Node).get_meta("part_name", "") == n.get_slice("#", 0):
			return [node]
		return []
	return (registry.get("by_name", {}) as Dictionary).get(n, [])


func _world_op(n: String, op: String, a: Array) -> void:
	var nodes: Array = _nodes_for(n)
	var byn: Dictionary = registry.get("by_name", {})
	for node in nodes.duplicate():
		if not is_instance_valid(node):
			continue
		var body := node as Node3D
		var mesh := body.get_node_or_null("Mesh") as MeshInstance3D
		var shape := body.get_node_or_null("Shape") as CollisionShape3D
		match op:
			"color":
				if mesh != null:
					mesh.material_override = Fx.block_material(Level.COLORS[clampi(int(a[0]), 0, Level.COLORS.size() - 1)])
			"visible":
				if mesh != null:
					mesh.visible = bool(a[0])
			"solid":
				if shape != null:
					shape.set_deferred("disabled", not bool(a[0]))
			"move":
				var target := Vector3(a[0], a[1], a[2])
				var secs := float(a[3]) if a.size() > 3 else 0.0
				if secs > 0.0:
					var tw := create_tween()
					tw.tween_property(body, "global_position", target, secs).set_trans(Tween.TRANS_SINE)
				else:
					body.global_position = target
			"destroy":
				body.queue_free()
				(byn.get(n.get_slice("#", 0), []) as Array).erase(node)


func _player_op(op: String, a: Array) -> void:
	if player == null:
		return
	match op:
		"teleport":
			player.teleport(Vector3(a[0], a[1], a[2]))
		"kill":
			Game.kill_player()
		"coins":
			var n := int(a[0])
			Game.coins += n
			Game.lifetime_coins = maxi(Game.lifetime_coins + n, 0)
			Game.coins_changed.emit(Game.coins)
			Sfx.play("coin")
		"speed":
			player.max_speed = float(a[0])
		"jump":
			player.jump_velocity = float(a[0])
		"message":
			if hud != null:
				hud.show_toast(str(a[0]), Color(0.6, 0.9, 1.0))
		"damage":
			player.damage(float(a[0]) if a.size() > 0 else 0.0)
		"give_tool":
			if a.size() > 0:
				Game.give_tool(str(a[0]))
		"save":
			if a.size() >= 2 and not Game.testing:
				GameData.save_value(GameData.game_key(level), str(a[0]), a[1])
		"badge":
			var bname := str(a[0]) if a.size() > 0 else ""
			if bname != "" and not Game.testing:
				Game.award_badge("game:%s:%s" % [str(level.get("name", "Game")).replace(":", " "), bname.replace(":", " ")])
			elif bname != "" and hud != null:
				hud.show_toast("BADGE (test): " + bname, Color(1.0, 0.85, 0.3))
