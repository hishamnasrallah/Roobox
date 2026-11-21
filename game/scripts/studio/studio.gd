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
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 600.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
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
	_add_part(part)
	_undo.append({"op": "add", "part": part})
	Sfx.play("pop", -6.0)
	_refresh_ui()
	return part


func paint(e: Dictionary) -> void:
	if e.is_empty():
		return
	var part: Dictionary = e["part"]
	var new_c := color_index if color_index >= 0 else 4
	if int(part["c"]) == new_c:
		return
	_undo.append({"op": "paint", "part": part, "old": int(part["c"])})
	part["c"] = new_c
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
		if not _sel_name.has_focus():
			_sel_name.text = str(part.get("n", ""))


func set_preset(id: String) -> void:
	preset_id = id
	tool = "build"
	_refresh_ui()


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
	var mi := MeshInstance3D.new()
	mi.mesh = _cache.unit_mesh(shape)
	mi.scale = s
	mi.material_override = _material(col, t == "kill" or t == "jumppad" or t == "coin")
	body.add_child(mi)
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
	for i in Level.COLORS.size():
		var cb := Button.new()
		cb.custom_minimum_size = Vector2(46, 46)
		cb.focus_mode = Control.FOCUS_NONE
		var ci := i
		cb.pressed.connect(func() -> void: set_color(ci))
		colors.add_child(cb)
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
