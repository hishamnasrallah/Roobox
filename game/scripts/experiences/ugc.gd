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
	var host := get_parent()
	if host != null and host.has_method("apply_env"):
		host.call("apply_env", str(level.get("env", "day")))


func has_script() -> bool:
	return str(level.get("script", "")).strip_edges() != ""


func part_names() -> Array:
	return (registry.get("by_name", {}) as Dictionary).keys()


func part_position(n: String) -> Vector3:
	var nodes: Array = (registry.get("by_name", {}) as Dictionary).get(n, [])
	for node in nodes:
		if is_instance_valid(node):
			return (node as Node3D).global_position
	return Vector3.ZERO


func on_player_ready(_p: Player) -> void:
	Game.checkpoint_position = spawn_point
	for p: Dictionary in level["parts"]:
		if p["t"] == "finish":
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
			area.body_entered.connect(_on_area_entered.bind(n))


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
			_refresh_status()
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


func _world_op(n: String, op: String, a: Array) -> void:
	var byn: Dictionary = registry.get("by_name", {})
	var nodes: Array = byn.get(n, [])
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
				nodes.erase(node)


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
