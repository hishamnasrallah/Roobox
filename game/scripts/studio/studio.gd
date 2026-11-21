class_name Studio
extends Node3D
## In-app game editor ("Studio").
##   Joystick / WASD: move the camera   Drag: orbit   Pinch / wheel: zoom
##   Tap / click: use the current tool (BUILD, PAINT, DELETE)
## Levels are plain data (see Level) saved under user://creations.

signal exit_requested
signal test_requested(level: Dictionary)

var level: Dictionary = {}
var slot: String = ""

var tool: String = "build"
var preset_id: String = "block"
var rot_steps: int = 0
var color_index: int = -1   # -1 = preset default
var material_id: String = "plastic"

var _entries: Array = []    # [{part: Dictionary, node: Node3D}]
var _undo: Array = []
var _parts_root: Node3D
var _cache: WorldBuilder
var _mats: Dictionary = {}

# Camera.
var _cam: Camera3D
var _focus: Vector3 = Vector3(0, 0, 0)
var _yaw: float = 0.6
var _pitch: float = -0.75
var _dist: float = 30.0
var _vertical: float = 0.0
var _marker: MeshInstance3D

# UI.
var _ui: CanvasLayer
var _touch: TouchControls
var _count_label: Label
var _msg: Label
var _name_edit: LineEdit
var _tool_buttons: Dictionary = {}
var _preset_buttons: Dictionary = {}
var _color_buttons: Array[Button] = []
var _rot_button: Button
var _mouse_down: Vector2 = Vector2(-1, -1)
var _selected: Dictionary = {}
var _highlight: MeshInstance3D
var _sel_panel: PanelContainer
var _sel_info: Label
var _sel_motion: Button
var _sel_name: LineEdit
var _script_panel: Control
var _sign_row: HBoxContainer
var _sign_edit: LineEdit
var _mat_toggle: Button
var _mat_row: HBoxContainer
var _color_row: HBoxContainer
var _mat_buttons: Dictionary = {}
var _env_button: Button
## Build plane: lets you place parts in the air at the camera focus height.
var air_mode: bool = false
var _plane: MeshInstance3D
var _air_button: Button
var _code: CodeEdit
var _script_status: Label


func _ready() -> void:
	if level.is_empty():
		level = Level.new_level()
	_cache = WorldBuilder.new(self)
	_parts_root = Node3D.new()
	_parts_root.name = "Parts"
	add_child(_parts_root)
	for p: Dictionary in level["parts"]:
		_spawn_node(p)

	_cam = Camera3D.new()
	_cam.fov = 65
	_cam.far = 1200
	add_child(_cam)
	_cam.make_current()
	_marker = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.25
	sm.height = 0.5
	_marker.mesh = sm
	_marker.material_override = Fx.glow_material(Color(1, 1, 1), 1.5)
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marker)
	_focus = Level.spawn_point(level) - Vector3(0, 0.6, 0)

	_build_ui()
	_refresh_ui()
	_say("Tap the world to place parts. Drag to look around.")


# =============================================================== camera ===

func _process(delta: float) -> void:
	var look := Game.consume_look()
	_yaw = wrapf(_yaw - look.x, -PI, PI)
	_pitch = clampf(_pitch - look.y, -1.45, -0.08)
	_dist = clampf(_dist + Game.consume_zoom() * maxf(1.5, _dist * 0.12), 4.0, 140.0)

	var mv := Game.get_move_input()
	var fwd := Vector3(-sin(_yaw), 0, -cos(_yaw))
	var right := Vector3(cos(_yaw), 0, -sin(_yaw))
	var speed := clampf(_dist * 0.9, 8.0, 60.0)
	_focus += (right * mv.x + fwd * mv.y) * speed * delta
	var v := _vertical
	if Input.is_key_pressed(KEY_E):
		v += 1.0
	if Input.is_key_pressed(KEY_Q):
		v -= 1.0
	_focus.y = clampf(_focus.y + v * speed * 0.6 * delta, -20.0, 400.0)

	var orbit := Basis.from_euler(Vector3(_pitch, _yaw, 0))
	_cam.global_transform = Transform3D(orbit, _focus + orbit * Vector3(0, 0, _dist))
	_marker.global_position = _focus
	_update_plane()
	if air_mode and _air_button != null and _air_button.text != "AIR %d" % int(build_height()):
		_air_button.text = "AIR %d" % int(build_height())


func _unhandled_input(event: InputEvent) -> void:
	# Desktop: a left click without dragging uses the tool.
	var mb := event as InputEventMouseButton
	if mb == null or mb.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_mouse_down = mb.position
		elif _mouse_down.x >= 0.0 and mb.position.distance_to(_mouse_down) < 6.0:
			use_tool_at(mb.position)
			_mouse_down = Vector2(-1, -1)


# ================================================================ tools ===

## Raycast from the screen and apply the current tool.
func use_tool_at(screen_pos: Vector2) -> void:
	var from := _cam.project_ray_origin(screen_pos)
	var dir := _cam.project_ray_normal(screen_pos)
	var hit: Dictionary = {}
	if not (air_mode and tool == "build"):
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * 600.0, 1)
		hit = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		# Nothing hit (or AIR mode): build on the plane at the focus height.
		if tool == "build":
			var pp := plane_point(from, dir)
			if pp.is_finite():
				place_at(pp, Vector3.UP)
		return
	var collider: Object = hit["collider"]
	match tool:
		"build":
			place_at(hit["position"], hit["normal"])
		"select":
			select(_entry_for(collider))
		"paint":
			paint(_entry_for(collider))
		"delete":
			remove(_entry_for(collider))


## Places the selected preset against a surface (point + normal).
func place_at(point: Vector3, normal: Vector3) -> Dictionary:
	if (level["parts"] as Array).size() >= Level.MAX_PARTS:
		_say("Part limit reached (%d)." % Level.MAX_PARTS)
		return {}
	var pr := Level.preset(preset_id)
	var s := Level._vec(pr["s"], Vector3.ONE)
	var ws := Level.world_size(s, rot_steps)
	# Dominant axis of the surface normal.
	var n := Vector3.ZERO
	var a := normal.abs()
	if a.y >= a.x and a.y >= a.z:
		n.y = signf(normal.y)
	elif a.x >= a.z:
		n.x = signf(normal.x)
	else:
		n.z = signf(normal.z)
	var c := point + n * (absf(n.x) * ws.x + absf(n.y) * ws.y + absf(n.z) * ws.z) * 0.5
	c.x = Level.snap_center(c.x, ws.x)
	c.y = Level.snap_center(c.y, ws.y)
	c.z = Level.snap_center(c.z, ws.z)
	var t: String = pr["t"]
	if t == "spawn":
		for e: Dictionary in _entries.duplicate():
			if (e["part"] as Dictionary)["t"] == "spawn":
				_remove_entry(e, false)
	var part := {"t": t, "p": Level._arr(c), "s": Level._arr(s), "r": rot_steps,
		"c": color_index if color_index >= 0 else int(pr["c"])}
	if material_id != "plastic" and t in Level.SOLID:
		part["mat"] = material_id
	if t == "sign":
		part["txt"] = "Welcome!"
	_add_part(part)
	_undo.append({"op": "add", "part": part})
	Sfx.play("pop", -6.0)
	_refresh_ui()
	return part


func paint(e: Dictionary) -> void:
	if e.is_empty():
		return
	var part: Dictionary = e["part"]
	var new_c := color_index if color_index >= 0 else int(part["c"])
	var new_mat := material_id if part["t"] in Level.SOLID else str(part.get("mat", "plastic"))
	if int(part["c"]) == new_c and str(part.get("mat", "plastic")) == new_mat:
		return
	_undo.append({"op": "edit", "part": part, "old": part.duplicate(true)})
	part["c"] = new_c
	if new_mat == "plastic":
		part.erase("mat")
	else:
		part["mat"] = new_mat
	_rebuild_entry(e)
	Sfx.play("click")


func remove(e: Dictionary) -> void:
	if e.is_empty():
		return
	if is_same(e, _selected):
		select({})
	var part: Dictionary = e["part"]
	if part["t"] == "spawn":
		_say("Every game needs a SPAWN. Place a new one to move it.")
		return
	var idx := -1
	var parts: Array = level["parts"]
	for i in parts.size():
		if is_same(parts[i], part):
			idx = i
			break
	_undo.append({"op": "del", "part": part, "index": idx})
	_remove_entry(e, true)
	Sfx.play("hit", -8.0)
	_refresh_ui()


func undo() -> void:
	if _undo.is_empty():
		_say("Nothing to undo.")
		return
	var u: Dictionary = _undo.pop_back()
	var part: Dictionary = u["part"]
	match str(u["op"]):
		"add":
			var e := _entry_of_part(part)
			if not e.is_empty():
				_remove_entry(e, true)
		"del":
			_add_part(part, int(u.get("index", -1)))
		"paint":
			part["c"] = u["old"]
			var e2 := _entry_of_part(part)
			if not e2.is_empty():
				_rebuild_entry(e2)
		"edit":
			part.clear()
			part.merge(u["old"] as Dictionary)
			var e3 := _entry_of_part(part)
			if not e3.is_empty():
				_rebuild_entry(e3)
	_update_selection()
	_refresh_ui()


## Height of the build plane (snapped to the grid).
func build_height() -> float:
	return roundf(_focus.y)


func set_build_height(h: float) -> void:
	_focus.y = h


## Where a ray meets the build plane (Vector3.INF if it doesn't).
func plane_point(origin: Vector3, dir: Vector3) -> Vector3:
	if absf(dir.y) < 0.0001:
		return Vector3.INF
	var t := (build_height() - origin.y) / dir.y
	if t < 0.0 or t > 400.0:
		return Vector3.INF
	return origin + dir * t


func toggle_air() -> void:
	air_mode = not air_mode
	_say("AIR mode: tap anywhere to build at height %d (UP/DOWN to change)" % int(build_height()) if air_mode else "AIR mode off: parts stick to surfaces")
	_refresh_ui()


func _update_plane() -> void:
	if _plane == null:
		_plane = MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(48, 48)
		_plane.mesh = pm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = Fx.tile_texture()
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_plane.material_override = m
		_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_plane)
	_plane.visible = tool == "build"
	var m2 := _plane.material_override as StandardMaterial3D
	m2.albedo_color = Color(0.4, 0.8, 1.0, 0.35 if air_mode else 0.12)
	_plane.global_position = Vector3(roundf(_focus.x), build_height() + 0.01, roundf(_focus.z))


func rotate_preset() -> void:
	rot_steps = (rot_steps + 1) % 4
	_refresh_ui()


func set_tool(t: String) -> void:
	tool = t
	if t != "select":
		select({})
	_refresh_ui()


# ============================================================ selection ===

func select(e: Dictionary) -> void:
	_selected = e
	_update_selection()


func selected_part() -> Dictionary:
	return _selected["part"] if not _selected.is_empty() else {}


func _begin_edit() -> Dictionary:
	if _selected.is_empty():
		return {}
	var part: Dictionary = _selected["part"]
	_undo.append({"op": "edit", "part": part, "old": part.duplicate(true)})
	return part


func _end_edit() -> void:
	_rebuild_entry(_selected)
	_update_selection()


## Moves the selected part by whole grid steps.
func move_selected(d: Vector3) -> void:
	var part := _begin_edit()
	if part.is_empty():
		return
	part["p"] = Level._arr(Level.pos(part) + d * Level.GRID)
	_end_edit()


## Grows/shrinks the selected part along one local axis (keeps it on the grid).
func resize_selected(axis: int, delta: float) -> void:
	var part := _begin_edit()
	if part.is_empty():
		return
	var s := Level.size(part)
	var v := clampf(s[axis] + delta, 1.0, 64.0)
	var grow := v - s[axis]
	s[axis] = v
	part["s"] = Level._arr(s)
	if axis == 1:
		# Grow upwards so it stays on whatever it stands on.
		part["p"] = Level._arr(Level.pos(part) + Vector3(0, grow * 0.5, 0))
	_end_edit()


func rotate_selected() -> void:
	var part := _begin_edit()
	if part.is_empty():
		return
	part["r"] = (int(part.get("r", 0)) + 1) % 4
	_end_edit()


func duplicate_selected() -> Dictionary:
	if _selected.is_empty():
		return {}
	var src: Dictionary = _selected["part"]
	if src["t"] == "spawn":
		_say("There can only be one SPAWN.")
		return {}
	var copy: Dictionary = src.duplicate(true)
	var ws := Level.world_size(Level.size(src), int(src.get("r", 0)))
	copy["p"] = Level._arr(Level.pos(src) + Vector3(ws.x, 0, 0))
	_add_part(copy)
	_undo.append({"op": "add", "part": copy})
	select(_entry_of_part(copy))
	_refresh_ui()
	return copy


func cycle_motion() -> void:
	var part := _begin_edit()
	if part.is_empty():
		return
	if not (part["t"] in Level.SOLID):
		_undo.pop_back()
		_say("Only solid parts can move.")
		return
	var i := Level.MOTIONS.find(str(part.get("m", "")))
	var next := Level.MOTIONS[(i + 1) % Level.MOTIONS.size()]
	if next == "":
		part.erase("m")
	else:
		part["m"] = next
	_end_edit()


func name_selected(text: String) -> void:
	var part := _begin_edit()
	if part.is_empty():
		return
	var n := Level.clean_name(text)
	if n == "":
		part.erase("n")
	else:
		part["n"] = n
	_end_edit()
	_say("Named \"%s\" - scripts can find it with world.find(\"%s\")" % [n, n] if n != "" else "Name removed.")


func delete_selected() -> void:
	if not _selected.is_empty():
		remove(_selected)


func _update_selection() -> void:
	if _highlight == null:
		_highlight = MeshInstance3D.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1.0, 0.85, 0.2, 0.35)
		mat.no_depth_test = true
		_highlight.material_override = mat
		_highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_highlight)
	if _selected.is_empty() or not is_instance_valid(_selected.get("node")):
		_selected = {}
		_highlight.visible = false
		if _sel_panel != null:
			_sel_panel.visible = false
		return
	var part: Dictionary = _selected["part"]
	_highlight.visible = true
	_highlight.mesh = _cache.unit_mesh(Level.part_shape(part["t"]))
	_highlight.global_position = Level.pos(part)
	_highlight.rotation = Vector3(0, Level.yaw(part), 0)
	_highlight.scale = Level.size(part) + Vector3.ONE * 0.12
	if _sel_panel != null:
		_sel_panel.visible = true
		var s := Level.size(part)
		_sel_info.text = "%s  %dx%dx%d%s" % [str(Level.preset(part["t"]).get("label", part["t"])) if part["t"] in Level.SPECIAL else str(part["t"]).to_upper(),
			int(s.x), int(s.y), int(s.z), ("  \"%s\"" % part["n"]) if part.has("n") else ""]
		_sel_motion.text = "MOTION: %s" % Level.MOTION_LABELS.get(str(part.get("m", "")), "NONE")
		_sel_motion.disabled = not (part["t"] in Level.SOLID)
		_sign_row.visible = part["t"] == "sign"
		if part["t"] == "sign" and not _sign_edit.has_focus():
			_sign_edit.text = str(part.get("txt", ""))
		if not _sel_name.has_focus():
			_sel_name.text = str(part.get("n", ""))


func set_preset(id: String) -> void:
	preset_id = id
	tool = "build"
	_refresh_ui()


func set_material(id: String) -> void:
	material_id = id
	_refresh_ui()


func cycle_env() -> void:
	var cur := str(level.get("env", "day"))
	var next := Level.ENVS[(Level.ENVS.find(cur) + 1) % Level.ENVS.size()]
	if next == "day":
		level.erase("env")
	else:
		level["env"] = next
	if get_parent().has_method("apply_env"):
		get_parent().call("apply_env", next)
	_refresh_ui()


func set_sign_text(text: String) -> void:
	var part := _begin_edit()
	if part.is_empty():
		return
	if part["t"] != "sign":
		_undo.pop_back()
		return
	part["txt"] = text.strip_edges().substr(0, 60)
	_end_edit()


func set_color(i: int) -> void:
	color_index = i
	_refresh_ui()


func part_count() -> int:
	return (level["parts"] as Array).size()


func save() -> bool:
	if slot == "":
		slot = Level.new_slot()
	var ok := Level.save_slot(slot, level)
	_say("Saved!" if ok else "Could not save.")
	return ok


# ================================================================ parts ===

func _add_part(part: Dictionary, index: int = -1) -> void:
	var parts: Array = level["parts"]
	if index >= 0 and index <= parts.size():
		parts.insert(index, part)
	else:
		parts.append(part)
	_spawn_node(part)


func _spawn_node(part: Dictionary) -> void:
	_entries.append({"part": part, "node": _make_node(part)})


func _remove_entry(e: Dictionary, _record: bool) -> void:
	if is_same(e, _selected):
		_selected = {}
	(e["node"] as Node).queue_free()
	_entries.erase(e)
	var parts: Array = level["parts"]
	for i in parts.size():
		if is_same(parts[i], e["part"]):
			parts.remove_at(i)
			break


func _rebuild_entry(e: Dictionary) -> void:
	(e["node"] as Node).queue_free()
	e["node"] = _make_node(e["part"])


func _entry_for(collider: Object) -> Dictionary:
	for e: Dictionary in _entries:
		if e["node"] == collider:
			return e
	return {}


func _entry_of_part(part: Dictionary) -> Dictionary:
	for e: Dictionary in _entries:
		if is_same(e["part"], part):
			return e
	return {}


func _make_node(part: Dictionary) -> Node3D:
	var t: String = part["t"]
	var s := Level.size(part)
	var col: Color = Level.COLORS[int(part["c"])]
	var shape := Level.part_shape(t)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Level.pos(part)
	body.rotation.y = Level.yaw(part)
	_add_visual(body, part, t, s, col, shape)
	var cs := CollisionShape3D.new()
	cs.shape = _cache.collision_shape(shape, s)
	body.add_child(cs)
	var tag := ""
	if t in Level.SPECIAL:
		tag = str(Level.preset(t)["label"])
	if part.has("n"):
		tag = ("%s\n" % tag if tag != "" else "") + "\"%s\"" % part["n"]
	if part.has("m"):
		tag = ("%s\n" % tag if tag != "" else "") + str(Level.MOTION_LABELS.get(part["m"], ""))
	if tag != "":
		var l := Label3D.new()
		l.text = tag
		l.font_size = 64
		l.outline_size = 14
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.position.y = s.y * 0.5 + 0.8
		body.add_child(l)
	_parts_root.add_child(body)
	return body


func _add_visual(body: Node3D, part: Dictionary, t: String, s: Vector3, col: Color, shape: String) -> void:
	var mat := str(part.get("mat", "plastic"))
	match t:
		"stairs":
			for st: Array in Level.stair_steps(s):
				var step := MeshInstance3D.new()
				step.mesh = _cache.unit_mesh("box")
				step.position = st[0]
				step.scale = st[1]
				step.material_override = _part_material(mat, col)
				body.add_child(step)
			return
		"tree":
			_mesh(body, Vector3(0, -s.y * 0.2, 0), Vector3(s.x * 0.25, s.y * 0.6, s.z * 0.25), Materials.material("log", Color.WHITE))
			_mesh(body, Vector3(0, s.y * 0.25, 0), s * Vector3(1, 0.5, 1), Materials.material("leaves", Color.WHITE))
			return
		"sign":
			_mesh(body, Vector3.ZERO, s, Materials.material("planks", Color.WHITE))
			var lbl := Level._sign_label(str(part.get("txt", "")), Vector3.ZERO, s, Vector3.ZERO)
			body.add_child(lbl)
			return
		"ladder":
			body.add_child(Level._ladder_visual(Vector3.ZERO, s, Vector3.ZERO))
			return
		"spikes":
			_mesh(body, Vector3(0, -s.y * 0.35, 0), Vector3(s.x, s.y * 0.3, s.z), _material(col, false))
			Level._spikes(body, Vector3.ZERO, s, Vector3.ZERO)
			return
		"water":
			var wm := StandardMaterial3D.new()
			wm.albedo_color = Color(0.2, 0.5, 0.95, 0.45)
			wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_mesh(body, Vector3.ZERO, s, wm)
			return
		"light":
			var bulb := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.35
			sm.height = 0.7
			bulb.mesh = sm
			bulb.material_override = Fx.glow_material(col, 3.0)
			body.add_child(bulb)
			return
	var glow := t in ["kill", "jumppad", "coin", "speed", "teleport", "conveyor"]
	var mi := MeshInstance3D.new()
	mi.mesh = _cache.unit_mesh(shape)
	mi.scale = s
	mi.material_override = _material(col, glow) if not (t in Level.SOLID) else _part_material(mat, col)
	body.add_child(mi)


func _mesh(body: Node3D, pos: Vector3, size: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _cache.unit_mesh("box")
	mi.position = pos
	mi.scale = size
	mi.material_override = m
	body.add_child(mi)


func _part_material(mat: String, col: Color) -> StandardMaterial3D:
	if mat == "plastic":
		return _material(col, false)
	return Materials.material(mat, col)


func _material(col: Color, glow: bool) -> StandardMaterial3D:
	var key := "%s|%s" % [col.to_html(), glow]
	if not _mats.has(key):
		_mats[key] = Fx.glow_material(col, 1.2) if glow else Fx.block_material(col)
	return _mats[key] as StandardMaterial3D


# =================================================================== UI ===

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(root)

	_touch = TouchControls.new()
	_touch.show_jump = false
	_touch.tapped.connect(use_tool_at)
	root.add_child(_touch)

	# Top bar.
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16
	top.offset_right = -16
	top.offset_top = 12
	top.offset_bottom = 76
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)
	_name_edit = UiStyle.line_edit("Game name", 24)
	_name_edit.text = str(level.get("name", "My Game"))
	_name_edit.max_length = 32
	_name_edit.custom_minimum_size.x = 260
	_name_edit.text_changed.connect(func(t: String) -> void: level["name"] = t.strip_edges())
	_name_edit.focus_entered.connect(func() -> void: Game.input_blocked = true)
	_name_edit.focus_exited.connect(func() -> void: Game.input_blocked = false)
	top.add_child(_name_edit)
	_count_label = UiStyle.label(20, Color(1, 1, 1, 0.8))
	_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(_count_label)
	for spec in [["UNDO", Color(0.4, 0.42, 0.55), undo], ["SAVE", Color(0.2, 0.6, 0.35), save],
			["SCRIPT", Color(0.2, 0.5, 0.6), open_script],
			["TEST", Color(0.95, 0.55, 0.2), _on_test], ["PUBLISH", Color(0.6, 0.35, 0.95), _on_publish],
			["EXIT", Color(0.6, 0.3, 0.3), _on_exit]]:
		var b := UiStyle.button(spec[0], spec[1], 20, 58)
		b.custom_minimum_size.x = 112
		b.pressed.connect(spec[2])
		top.add_child(b)

	# Tools row (under the top bar).
	var tools := HBoxContainer.new()
	tools.position = Vector2(16, 84)
	tools.add_theme_constant_override("separation", 6)
	root.add_child(tools)
	for t in ["build", "select", "paint", "delete"]:
		var tb := UiStyle.button(t.to_upper(), Color(0.25, 0.3, 0.48), 18, 50)
		tb.custom_minimum_size.x = 116
		var tool_id: String = t
		tb.pressed.connect(func() -> void: set_tool(tool_id))
		tools.add_child(tb)
		_tool_buttons[t] = tb
	_rot_button = UiStyle.button("ROTATE", Color(0.25, 0.3, 0.48), 18, 50)
	_rot_button.custom_minimum_size.x = 130
	_rot_button.pressed.connect(rotate_preset)
	tools.add_child(_rot_button)
	_air_button = UiStyle.button("AIR", Color(0.25, 0.3, 0.48), 18, 50)
	_air_button.custom_minimum_size.x = 90
	_air_button.pressed.connect(toggle_air)
	tools.add_child(_air_button)
	_env_button = UiStyle.button("SKY", Color(0.25, 0.3, 0.48), 18, 50)
	_env_button.custom_minimum_size.x = 120
	_env_button.pressed.connect(cycle_env)
	tools.add_child(_env_button)
	for spec in [["UP", 1.0], ["DOWN", -1.0]]:
		var vb := UiStyle.button(spec[0], Color(0.3, 0.33, 0.45), 18, 50)
		vb.custom_minimum_size.x = 96
		var dirv: float = spec[1]
		vb.button_down.connect(func() -> void: _vertical = dirv)
		vb.button_up.connect(func() -> void: _vertical = 0.0)
		tools.add_child(vb)
	_touch.blockers.append(tools)

	# Selection panel (right).
	_sel_panel = PanelContainer.new()
	_sel_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_sel_panel.offset_left = -360
	_sel_panel.offset_right = -12
	_sel_panel.offset_top = 144
	_sel_panel.add_theme_stylebox_override("panel", UiStyle.box(Color(0.08, 0.1, 0.2, 0.85), 16, 12))
	_sel_panel.visible = false
	root.add_child(_sel_panel)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 6)
	_sel_panel.add_child(sv)
	_sel_info = UiStyle.label(18, Color(1.0, 0.85, 0.3))
	sv.add_child(_sel_info)
	for row_spec in [["MOVE", [["X-", 0, -1.0], ["X+", 0, 1.0], ["Y-", 1, -1.0], ["Y+", 1, 1.0], ["Z-", 2, -1.0], ["Z+", 2, 1.0]]],
			["SIZE", [["W-", 0, -1.0], ["W+", 0, 1.0], ["H-", 1, -1.0], ["H+", 1, 1.0], ["D-", 2, -1.0], ["D+", 2, 1.0]]]]:
		var lab := UiStyle.label(14, Color(1, 1, 1, 0.7))
		lab.text = row_spec[0]
		sv.add_child(lab)
		var grid := HBoxContainer.new()
		grid.add_theme_constant_override("separation", 4)
		sv.add_child(grid)
		for bspec in row_spec[1]:
			var bb := UiStyle.button(bspec[0], Color(0.3, 0.36, 0.55), 15, 42)
			bb.custom_minimum_size.x = 52
			var axis: int = bspec[1]
			var amount: float = bspec[2]
			if row_spec[0] == "MOVE":
				var dv := Vector3.ZERO
				dv[axis] = amount
				bb.pressed.connect(func() -> void: move_selected(dv))
			else:
				bb.pressed.connect(func() -> void: resize_selected(axis, amount))
			grid.add_child(bb)
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 4)
	sv.add_child(acts)
	for aspec in [["ROTATE", rotate_selected], ["COPY", duplicate_selected], ["DELETE", delete_selected]]:
		var ab := UiStyle.button(aspec[0], Color(0.45, 0.3, 0.55) if aspec[0] != "DELETE" else Color(0.6, 0.3, 0.3), 15, 44)
		ab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ab.pressed.connect(aspec[1])
		acts.add_child(ab)
	_sel_motion = UiStyle.button("MOTION: NONE", Color(0.2, 0.5, 0.6), 15, 44)
	_sel_motion.pressed.connect(cycle_motion)
	sv.add_child(_sel_motion)
	var nrow := HBoxContainer.new()
	nrow.add_theme_constant_override("separation", 4)
	sv.add_child(nrow)
	_sel_name = UiStyle.line_edit("name (for scripts)", 18)
	_sel_name.custom_minimum_size.y = 44
	_sel_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sel_name.max_length = 24
	_sel_name.focus_entered.connect(func() -> void: Game.input_blocked = true)
	_sel_name.focus_exited.connect(func() -> void: Game.input_blocked = false)
	_sel_name.text_submitted.connect(func(t: String) -> void: name_selected(t))
	nrow.add_child(_sel_name)
	var nb := UiStyle.button("SET", Color(0.2, 0.6, 0.35), 15, 44)
	nb.custom_minimum_size.x = 70
	nb.pressed.connect(func() -> void: name_selected(_sel_name.text))
	nrow.add_child(nb)
	_sign_row = HBoxContainer.new()
	_sign_row.add_theme_constant_override("separation", 4)
	sv.add_child(_sign_row)
	_sign_edit = UiStyle.line_edit("sign text", 18)
	_sign_edit.custom_minimum_size.y = 44
	_sign_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sign_edit.max_length = 60
	_sign_edit.focus_entered.connect(func() -> void: Game.input_blocked = true)
	_sign_edit.focus_exited.connect(func() -> void: Game.input_blocked = false)
	_sign_edit.text_submitted.connect(func(t: String) -> void: set_sign_text(t))
	_sign_row.add_child(_sign_edit)
	var sbtn := UiStyle.button("TEXT", Color(0.2, 0.6, 0.35), 15, 44)
	sbtn.custom_minimum_size.x = 70
	sbtn.pressed.connect(func() -> void: set_sign_text(_sign_edit.text))
	_sign_row.add_child(sbtn)
	_touch.blockers.append(_sel_panel)

	# Bottom: colors + presets.
	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 340
	bottom.offset_right = -16
	bottom.offset_top = -150
	bottom.offset_bottom = -10
	bottom.add_theme_constant_override("separation", 8)
	root.add_child(bottom)
	var colors := HBoxContainer.new()
	colors.add_theme_constant_override("separation", 6)
	bottom.add_child(colors)
	_mat_toggle = UiStyle.button("COLORS", Color(0.35, 0.3, 0.5), 15, 46)
	_mat_toggle.custom_minimum_size.x = 104
	_mat_toggle.pressed.connect(_toggle_swatches)
	colors.add_child(_mat_toggle)
	_mat_row = HBoxContainer.new()
	_mat_row.add_theme_constant_override("separation", 4)
	_mat_row.visible = false
	colors.add_child(_mat_row)
	for m: Dictionary in Materials.LIST:
		var mb := Button.new()
		mb.custom_minimum_size = Vector2(46, 46)
		mb.focus_mode = Control.FOCUS_NONE
		mb.tooltip_text = m["name"]
		if m["id"] != "plastic" and m["id"] != "neon" and m["id"] != "wool":
			mb.icon = Materials.texture(m["id"])
			mb.expand_icon = true
		var mid: String = m["id"]
		mb.pressed.connect(func() -> void: set_material(mid))
		_mat_row.add_child(mb)
		_mat_buttons[mid] = mb
	_color_row = HBoxContainer.new()
	_color_row.add_theme_constant_override("separation", 6)
	colors.add_child(_color_row)
	for i in Level.COLORS.size():
		var cb := Button.new()
		cb.custom_minimum_size = Vector2(46, 46)
		cb.focus_mode = Control.FOCUS_NONE
		var ci := i
		cb.pressed.connect(func() -> void: set_color(ci))
		_color_row.add_child(cb)
		_color_buttons.append(cb)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 76
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bottom.add_child(scroll)
	var presets := HBoxContainer.new()
	presets.add_theme_constant_override("separation", 6)
	scroll.add_child(presets)
	for pr: Dictionary in Level.PRESETS:
		var special: bool = pr["t"] in Level.SPECIAL
		var pb := UiStyle.button(pr["label"], Color(0.45, 0.25, 0.3) if special else Color(0.25, 0.4, 0.6), 18, 62)
		pb.custom_minimum_size.x = 132
		var pid: String = pr["id"]
		pb.pressed.connect(func() -> void: set_preset(pid))
		presets.add_child(pb)
		_preset_buttons[pid] = pb
	_touch.blockers.append(bottom)

	_msg = UiStyle.label(24, Color(1.0, 0.9, 0.5))
	_msg.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.offset_left = -500
	_msg.offset_right = 500
	_msg.offset_top = 90
	root.add_child(_msg)


# =============================================================== script ===

func open_script() -> void:
	if _script_panel == null:
		_build_script_panel()
	_code.text = str(level.get("script", ""))
	_script_status.text = "Write Lua-style code. Tap a template to start."
	_script_panel.visible = true
	Game.input_blocked = true


func close_script() -> void:
	set_script_text(_code.text)
	_script_panel.visible = false
	Game.input_blocked = false


## Stores the script on the level and returns "" or the first syntax error.
func set_script_text(text: String) -> String:
	if text.strip_edges() == "":
		level.erase("script")
		return ""
	level["script"] = text.substr(0, Level.MAX_SCRIPT)
	return RooScript.new().compile(text)


func _check_script() -> void:
	var err := RooScript.new().compile(_code.text)
	_script_status.text = "No errors - press TEST to try it!" if err == "" else "Error: " + err
	_script_status.label_settings.font_color = Color(0.5, 1.0, 0.6) if err == "" else Color(1.0, 0.5, 0.5)


func _build_script_panel() -> void:
	var root: Control = _ui.get_child(0)
	_script_panel = PanelContainer.new()
	_script_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_script_panel.offset_left = 24
	_script_panel.offset_right = -24
	_script_panel.offset_top = 16
	_script_panel.offset_bottom = -16
	_script_panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	root.add_child(_script_panel)
	_touch.blockers.append(_script_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_script_panel.add_child(vb)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	vb.add_child(head)
	var title := UiStyle.label(30, Color(1.0, 0.85, 0.3))
	title.text = "SCRIPT"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	for tpl: Array in ScriptTemplates.TEMPLATES:
		var tb := UiStyle.button(tpl[0], Color(0.3, 0.36, 0.55), 15, 44)
		tb.custom_minimum_size.x = 100
		var code_text: String = tpl[1]
		tb.pressed.connect(func() -> void: _code.text = code_text)
		head.add_child(tb)
	var help := UiStyle.label(13, Color(1, 1, 1, 0.7))
	help.text = ScriptTemplates.HELP
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(help)
	_code = CodeEdit.new()
	_code.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_code.gutters_draw_line_numbers = true
	_code.indent_automatic = true
	_code.indent_size = 2
	_code.add_theme_font_size_override("font_size", 20)
	_code.syntax_highlighter = _highlighter()
	_code.focus_entered.connect(func() -> void: Game.input_blocked = true)
	vb.add_child(_code)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	vb.add_child(foot)
	_script_status = UiStyle.label(18)
	_script_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_script_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.add_child(_script_status)
	for spec in [["CHECK", Color(0.25, 0.5, 0.95), _check_script],
			["CLEAR", Color(0.6, 0.3, 0.3), _clear_code],
			["DONE", Color(0.2, 0.72, 0.35), close_script]]:
		var b := UiStyle.button(spec[0], spec[1], 18, 52)
		b.custom_minimum_size.x = 120
		b.pressed.connect(spec[2])
		foot.add_child(b)


func _toggle_swatches() -> void:
	_mat_row.visible = not _mat_row.visible
	_color_row.visible = not _mat_row.visible
	_refresh_ui()


func _clear_code() -> void:
	_code.text = ""


func _highlighter() -> CodeHighlighter:
	var h := CodeHighlighter.new()
	h.number_color = Color(0.7, 0.9, 1.0)
	h.symbol_color = Color(0.85, 0.85, 0.95)
	h.function_color = Color(0.55, 0.85, 1.0)
	h.member_variable_color = Color(0.9, 0.9, 1.0)
	for kw in RooScript.KEYWORDS:
		h.add_keyword_color(kw, Color(1.0, 0.55, 0.7))
	for g in ["on_start", "on_touch", "after", "every", "cancel", "world", "ui", "score", "print", "math", "string", "table", "pairs", "ipairs"]:
		h.add_member_keyword_color(g, Color(1.0, 0.85, 0.4))
		h.add_keyword_color(g, Color(1.0, 0.85, 0.4))
	h.add_color_region("--", "", Color(0.5, 0.6, 0.55), true)
	h.add_color_region("\"", "\"", Color(0.6, 1.0, 0.6))
	h.add_color_region("'", "'", Color(0.6, 1.0, 0.6))
	return h


func _refresh_ui() -> void:
	if _count_label == null:
		return
	_count_label.text = "  %d / %d parts" % [part_count(), Level.MAX_PARTS]
	for t: String in _tool_buttons:
		var on := t == tool
		(_tool_buttons[t] as Button).add_theme_stylebox_override("normal",
			UiStyle.box(Color(0.95, 0.55, 0.2) if on else Color(0.25, 0.3, 0.48), 18, 10))
	for id: String in _preset_buttons:
		var pr := Level.preset(id)
		var special: bool = pr["t"] in Level.SPECIAL
		var base := Color(0.45, 0.25, 0.3) if special else Color(0.25, 0.4, 0.6)
		(_preset_buttons[id] as Button).add_theme_stylebox_override("normal",
			UiStyle.box(Color(0.95, 0.55, 0.2) if id == preset_id and tool == "build" else base, 18, 10))
	for i in _color_buttons.size():
		var sb := UiStyle.box(Level.COLORS[i], 10, 0)
		sb.border_color = Color(1, 1, 1) if i == color_index else Color(0, 0, 0, 0.35)
		sb.set_border_width_all(5 if i == color_index else 2)
		for st in ["normal", "hover", "pressed"]:
			_color_buttons[i].add_theme_stylebox_override(st, sb)
	_rot_button.text = "ROTATE %d" % (rot_steps * 90)
	if _env_button != null:
		_env_button.text = "SKY: " + str(level.get("env", "day")).to_upper()
	for mid: String in _mat_buttons:
		var mbtn: Button = _mat_buttons[mid]
		var msb := UiStyle.box(Materials.info(mid)["ui"], 10, 0)
		msb.border_color = Color(1, 1, 1) if mid == material_id else Color(0, 0, 0, 0.35)
		msb.set_border_width_all(5 if mid == material_id else 2)
		for st2 in ["normal", "hover", "pressed"]:
			mbtn.add_theme_stylebox_override(st2, msb)
	if _mat_toggle != null:
		_mat_toggle.text = "MATERIAL" if _mat_row.visible else "COLORS"
	if _air_button != null:
		_air_button.text = "AIR %d" % int(build_height()) if air_mode else "AIR"
		_air_button.add_theme_stylebox_override("normal",
			UiStyle.box(Color(0.2, 0.6, 0.8) if air_mode else Color(0.25, 0.3, 0.48), 18, 10))


func _say(text: String) -> void:
	if _msg == null:
		return
	_msg.text = text
	_msg.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(_msg, "modulate:a", 0.0, 0.6)


func _on_test() -> void:
	save()
	test_requested.emit(level)


func _on_publish() -> void:
	save()
	if not Backend.online:
		_say("Connect an account server (menu > SETTINGS) to publish.")
		return
	_say("Publishing...")
	var ok: bool = await Backend.publish_game(slot, level)
	_say("Published! Players can find it in COMMUNITY." if ok else "Publish failed - try again.")


func _on_exit() -> void:
	save()
	exit_requested.emit()
