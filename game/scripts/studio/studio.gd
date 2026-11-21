class_name Studio
extends Node3D
## In-app game editor ("Studio"), modelled on what desktop game studios
## offer, adapted to touch screens:
##   Tools: SELECT, MOVE / SCALE / ROTATE (drag the 3D handles), BUILD,
##          PAINT, DELETE  + TERRAIN generator and EXPLORER (part list).
##   Snapping: grid 0.5 / 1 / 2 / 4 studs, turn step 15 / 45 / 90 degrees.
##   Properties: color, material, transparency, can-collide, anchored,
##          lock, motion, name (for scripts), sign text, group / ungroup.
##   Undo + redo, multi-select, copy, focus, models toolbox, scripts.
## Camera on touch: one finger orbits (tap = use tool), two fingers pinch
## to zoom and drag to pan, UP / DOWN buttons move the camera vertically.
## Desktop: WASD/QE move, drag to orbit, wheel zooms, Ctrl+Z / Ctrl+Y,
## Ctrl+D copy, Del delete, F focus, R rotate.
## Levels are plain data (see Level) saved under user://creations.

signal exit_requested
signal test_requested(level: Dictionary)

const SEL_TOOLS := ["select", "move", "scale", "rotate"]
const GRIDS: Array[float] = [0.5, 1.0, 2.0, 4.0]
const ROT_STEPS: Array[float] = [15.0, 45.0, 90.0]
const TABS: Array[String] = ["PARTS", "GAME", "NATURE", "FX", "MODELS", "COLOR", "MATERIAL"]
const TAB_CATS: Dictionary = {"PARTS": "parts", "GAME": "game", "NATURE": "nature", "FX": "fx"}
const HANDLE_LAYER := 8
const AXIS_COLORS: Array[Color] = [Color(1.0, 0.3, 0.3), Color(0.35, 1.0, 0.4), Color(0.35, 0.6, 1.0)]

var level: Dictionary = {}
var slot: String = ""

var tool: String = "build"
var preset_id: String = "block"
## When not "", BUILD places this model from the MODELS tab.
var model_id: String = ""
var rot_deg: float = 0.0
var rot_step: float = 90.0
var grid: float = 1.0
var color_index: int = -1   # -1 = preset default
var material_id: String = "plastic"
var multi: bool = false
## Build plane: lets you place parts in the air at the camera focus height.
var air_mode: bool = false

var _entries: Array = []    # [{part: Dictionary, node: Node3D}]
var _sel: Array = []        # selected entries
var _undo: Array = []
var _redo: Array = []
var _parts_root: Node3D
var _cache: WorldBuilder
var _mats: Dictionary = {}
var _group_counter: int = 0

# Camera.
var _cam: Camera3D
var _focus: Vector3 = Vector3(0, 0, 0)
var _yaw: float = 0.6
var _pitch: float = -0.75
var _dist: float = 30.0
var _vertical: float = 0.0
var _marker: MeshInstance3D
var _plane: MeshInstance3D

# Handles + dragging.
var _handles: Node3D
var _handles_dist: float = 0.0
var _highlights: Array[MeshInstance3D] = []
var _drag: Dictionary = {}
var _mouse_down: Vector2 = Vector2(-1, -1)
var _mouse_grab: bool = false

# UI.
var _ui: CanvasLayer
var _root: Control
var _touch: TouchControls
var _count_label: Label
var _msg: Label
var _name_edit: LineEdit
var _tool_buttons: Dictionary = {}
var _opt_buttons: Dictionary = {}
var _tab_buttons: Dictionary = {}
var _tab: String = "PARTS"
var _strip: HBoxContainer
var _strip_scroll: ScrollContainer
var _palette: Control
var _tile_buttons: Dictionary = {}
var _props: PanelContainer
var _prop_info: Label
var _prop_buttons: Dictionary = {}
var _sel_name: LineEdit
var _sign_row: HBoxContainer
var _sign_edit: LineEdit
var _explorer: PanelContainer
var _explorer_list: VBoxContainer
var _terrain_panel: PanelContainer
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
		var g := str(p.get("g", ""))
		if g.begins_with("g") and g.substr(1).is_valid_int():
			_group_counter = maxi(_group_counter, int(g.substr(1)))

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
	_handles = Node3D.new()
	_handles.name = "Handles"
	add_child(_handles)
	_focus = Level.spawn_point(level) - Vector3(0, 0.6, 0)

	_build_ui()
	_refresh_ui()
	_say("Tap to place parts. One finger: look around. Two fingers: zoom and move.")


# =============================================================== camera ===

func _process(delta: float) -> void:
	var look := Game.consume_look()
	_yaw = wrapf(_yaw - look.x, -PI, PI)
	_pitch = clampf(_pitch - look.y, -1.45, -0.08)
	_dist = clampf(_dist + Game.consume_zoom() * maxf(1.5, _dist * 0.12), 4.0, 160.0)

	var mv := Game.get_move_input()
	var speed := clampf(_dist * 0.9, 8.0, 60.0)
	_focus += (_right() * mv.x + _forward() * mv.y) * speed * delta
	var v := _vertical
	if not Game.input_blocked:
		if Input.is_key_pressed(KEY_E):
			v += 1.0
		if Input.is_key_pressed(KEY_Q):
			v -= 1.0
	_focus.y = clampf(_focus.y + v * speed * 0.6 * delta, -40.0, 400.0)

	var orbit := Basis.from_euler(Vector3(_pitch, _yaw, 0))
	_cam.global_transform = Transform3D(orbit, _focus + orbit * Vector3(0, 0, _dist))
	_marker.global_position = _focus
	_update_plane()
	if not _sel.is_empty() and tool in ["move", "scale", "rotate"] and _drag.is_empty():
		if absf(_dist - _handles_dist) > _handles_dist * 0.15:
			_rebuild_handles()
	if air_mode and _opt_buttons.has("air"):
		var t := "AIR %s" % _fmt(build_height())
		if (_opt_buttons["air"] as Button).text != t:
			(_opt_buttons["air"] as Button).text = t


func _forward() -> Vector3:
	return Vector3(-sin(_yaw), 0, -cos(_yaw))


func _right() -> Vector3:
	return Vector3(cos(_yaw), 0, -sin(_yaw))


func _on_pan(d: Vector2) -> void:
	var k := _dist * 0.004
	_focus -= _right() * d.x * k
	_focus += _forward() * d.y * k


## Frames the selection (or the whole level) with the camera.
func focus_selection() -> void:
	var box := _sel_aabb() if not _sel.is_empty() else _level_aabb()
	_focus = box.get_center()
	_dist = clampf(box.size.length() * 1.3 + 6.0, 6.0, 140.0)
	_rebuild_handles()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and not Game.input_blocked:
		_shortcut(key)
		return
	# Desktop mouse: drag handles, click to use the tool.
	var mb := event as InputEventMouseButton
	if mb != null and mb.device != InputEvent.DEVICE_ID_EMULATION and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_mouse_down = mb.position
			if try_grab(mb.position):
				_mouse_grab = true
				get_viewport().set_input_as_handled()
		else:
			if _mouse_grab:
				_mouse_grab = false
				end_drag()
				get_viewport().set_input_as_handled()
			elif _mouse_down.x >= 0.0 and mb.position.distance_to(_mouse_down) < 6.0:
				use_tool_at(mb.position)
			_mouse_down = Vector2(-1, -1)
		return
	var mm := event as InputEventMouseMotion
	if mm != null and _mouse_grab and mm.device != InputEvent.DEVICE_ID_EMULATION:
		drag_to(mm.position)
		get_viewport().set_input_as_handled()


func _shortcut(key: InputEventKey) -> void:
	var ctrl := key.ctrl_pressed or key.meta_pressed
	match key.keycode:
		KEY_Z:
			if ctrl:
				if key.shift_pressed:
					redo()
				else:
					undo()
		KEY_Y:
			if ctrl:
				redo()
		KEY_D:
			if ctrl:
				duplicate_selected()
		KEY_G:
			if ctrl:
				if key.shift_pressed:
					ungroup_selected()
				else:
					group_selected()
		KEY_DELETE, KEY_BACKSPACE:
			delete_selected()
		KEY_F:
			focus_selection()
		KEY_R:
			if _sel.is_empty():
				rotate_preset()
			else:
				rotate_selected()
		KEY_1:
			set_tool("select")
		KEY_2:
			set_tool("move")
		KEY_3:
			set_tool("scale")
		KEY_4:
			set_tool("rotate")
		KEY_5:
			set_tool("build")


# ================================================================ tools ===

## Raycast from the screen and apply the current tool.
func use_tool_at(screen_pos: Vector2) -> void:
	var from := _cam.project_ray_origin(screen_pos)
	var dir := _cam.project_ray_normal(screen_pos)
	var hit: Dictionary = {}
	if not (air_mode and tool == "build"):
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * 800.0, 1)
		hit = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		if tool == "build":
			var pp := plane_point(from, dir)
			if pp.is_finite():
				_build_at(pp, Vector3.UP)
		elif tool in SEL_TOOLS and not multi:
			select({})
		return
	var e := _entry_for(hit["collider"])
	match tool:
		"build":
			_build_at(hit["position"], hit["normal"])
		"paint":
			paint(e)
		"delete":
			remove(e)
		_:
			if not e.is_empty() and int((e["part"] as Dictionary).get("k", 0)) == 1:
				_say("This part is locked. Unlock it in EXPLORER.")
				return
			select(e)


func _build_at(point: Vector3, normal: Vector3) -> void:
	if model_id != "":
		place_model(model_id, point, normal)
	else:
		place_at(point, normal)


## Places the selected preset against a surface (point + normal).
func place_at(point: Vector3, normal: Vector3) -> Dictionary:
	if part_count() >= Level.MAX_PARTS:
		_say("Part limit reached (%d)." % Level.MAX_PARTS)
		return {}
	var pr := Level.preset(preset_id)
	var s := Level._vec(pr["s"], Vector3.ONE)
	var r90 := int(roundf(rot_deg / 90.0)) % 4 if is_zero_approx(fposmod(rot_deg, 90.0)) else 0
	var ws := Level.world_size(s, r90)
	var n := _dominant(normal)
	var c := point + n * (absf(n.x) * ws.x + absf(n.y) * ws.y + absf(n.z) * ws.z) * 0.5
	c.x = Level.snap_center(c.x, ws.x, grid)
	c.y = Level.snap_center(c.y, ws.y, grid)
	c.z = Level.snap_center(c.z, ws.z, grid)
	var t: String = pr["t"]
	var batch: Array = []
	if t == "spawn":
		for e: Dictionary in _entries.duplicate():
			if (e["part"] as Dictionary)["t"] == "spawn":
				batch.append({"op": "del", "part": e["part"], "index": _index_of(e["part"])})
				_remove_entry(e)
	var part := {"t": t, "p": Level._arr(c), "s": Level._arr(s), "r": 0,
		"c": color_index if color_index >= 0 else int(pr["c"])}
	Level.set_yaw_deg(part, rot_deg)
	if material_id != "plastic" and t in Level.SOLID:
		part["mat"] = material_id
	if t == "sign":
		part["txt"] = "Welcome!"
	_add_part(part)
	batch.append({"op": "add", "part": part, "index": _index_of(part)})
	_record({"op": "batch", "items": batch} if batch.size() > 1 else batch[0])
	Sfx.play("pop", -6.0)
	_refresh_ui()
	return part


## Places a whole model (MODELS tab) as one group. Returns its parts.
func place_model(id: String, point: Vector3, normal: Vector3 = Vector3.UP) -> Array:
	var list := Prefabs.parts(id)
	if list.is_empty():
		return []
	if part_count() + list.size() > Level.MAX_PARTS:
		_say("Part limit reached (%d)." % Level.MAX_PARTS)
		return []
	var n := _dominant(normal)
	var at := point + n * 0.01
	at.x = snappedf(at.x, grid)
	at.z = snappedf(at.z, grid)
	at.y = snappedf(at.y, minf(grid, 0.5)) if n.y > 0.5 else snappedf(at.y, grid)
	var placed := Prefabs.placed(id, at, rot_deg, _new_group())
	var batch: Array = []
	for p: Dictionary in placed:
		var clean := Level._clean_part(p)
		if clean.is_empty():
			continue
		_add_part(clean)
		batch.append({"op": "add", "part": clean, "index": _index_of(clean)})
	_record({"op": "batch", "items": batch})
	Sfx.play("pop", -4.0)
	_refresh_ui()
	_say("%s placed - SELECT it to move, turn or copy the whole model." % Prefabs.label(id))
	var out: Array = []
	for b: Dictionary in batch:
		out.append(b["part"])
	return out


func paint(e: Dictionary) -> void:
	if e.is_empty():
		return
	var part: Dictionary = e["part"]
	if int(part.get("k", 0)) == 1:
		_say("This part is locked.")
		return
	var item := {"op": "edit", "part": part, "old": part.duplicate(true)}
	_apply_paint(part)
	_commit_edits([item])
	Sfx.play("click")


func _apply_paint(part: Dictionary) -> void:
	if color_index >= 0:
		part["c"] = color_index
	if part["t"] in Level.SOLID:
		if material_id == "plastic":
			part.erase("mat")
		else:
			part["mat"] = material_id


func remove(e: Dictionary) -> void:
	if e.is_empty():
		return
	var part: Dictionary = e["part"]
	if part["t"] == "spawn":
		_say("Every game needs a SPAWN. Place a new one to move it.")
		return
	if int(part.get("k", 0)) == 1:
		_say("This part is locked. Unlock it in EXPLORER.")
		return
	_record({"op": "del", "part": part, "index": _index_of(part)})
	_remove_entry(e)
	Sfx.play("hit", -8.0)
	_after_change()


# ========================================================== undo / redo ===

func _record(op: Dictionary) -> void:
	_undo.append(op)
	_redo.clear()
	if _undo.size() > 300:
		_undo.pop_front()


func undo() -> void:
	if _undo.is_empty():
		_say("Nothing to undo.")
		return
	_redo.append(_apply_inverse(_undo.pop_back()))
	_after_change()


func redo() -> void:
	if _redo.is_empty():
		_say("Nothing to redo.")
		return
	_undo.append(_apply_inverse(_redo.pop_back()))
	_after_change()


## Reverts `op` and returns the op that would re-apply it.
func _apply_inverse(op: Dictionary) -> Dictionary:
	match str(op["op"]):
		"add":
			var part: Dictionary = op["part"]
			var idx := _index_of(part)
			var e := _entry_of_part(part)
			if not e.is_empty():
				_remove_entry(e)
			return {"op": "del", "part": part, "index": idx}
		"del":
			_add_part(op["part"], int(op.get("index", -1)))
			return {"op": "add", "part": op["part"], "index": int(op.get("index", -1))}
		"edit":
			var p2: Dictionary = op["part"]
			var cur: Dictionary = p2.duplicate(true)
			p2.clear()
			p2.merge(op["old"] as Dictionary)
			var e2 := _entry_of_part(p2)
			if not e2.is_empty():
				_rebuild_entry(e2)
			return {"op": "edit", "part": p2, "old": cur}
		"batch":
			var items: Array = op["items"]
			var inv: Array = []
			for i in range(items.size() - 1, -1, -1):
				inv.append(_apply_inverse(items[i]))
			return {"op": "batch", "items": inv}
	return op


func _after_change() -> void:
	var keep: Array = []
	for e in _sel:
		if _entries.has(e):
			keep.append(e)
	_sel = keep
	_update_selection()
	_refresh_ui()
	if _explorer != null and _explorer.visible:
		_fill_explorer()


# ============================================================ build plane ===

## Height of the build plane (snapped to the grid).
func build_height() -> float:
	return snappedf(_focus.y, grid)


func set_build_height(h: float) -> void:
	_focus.y = h


## Where a ray meets the build plane (Vector3.INF if it doesn't).
func plane_point(origin: Vector3, dir: Vector3) -> Vector3:
	if absf(dir.y) < 0.0001:
		return Vector3.INF
	var t := (build_height() - origin.y) / dir.y
	if t < 0.0 or t > 500.0:
		return Vector3.INF
	return origin + dir * t


func toggle_air() -> void:
	air_mode = not air_mode
	_say("AIR mode: tap anywhere to build at height %s (UP/DOWN to change)" % _fmt(build_height()) if air_mode else "AIR mode off: parts stick to surfaces")
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
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_plane.material_override = m
		_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_plane)
	_plane.visible = tool == "build"
	var m2 := _plane.material_override as StandardMaterial3D
	m2.albedo_color = Color(0.4, 0.8, 1.0, 0.35 if air_mode else 0.12)
	m2.uv1_scale = Vector3.ONE / grid
	_plane.global_position = Vector3(snappedf(_focus.x, grid), build_height() + 0.01, snappedf(_focus.z, grid))


# ============================================================= settings ===

func rotate_preset() -> void:
	rot_deg = fposmod(rot_deg + rot_step, 360.0)
	_refresh_ui()


func set_tool(t: String) -> void:
	tool = t
	if not (t in SEL_TOOLS):
		select({})
	_update_selection()
	_refresh_ui()


func set_grid(g: float) -> void:
	grid = g
	_refresh_ui()


func cycle_grid() -> void:
	set_grid(GRIDS[(GRIDS.find(grid) + 1) % GRIDS.size()])
	_say("Grid: %s stud%s" % [_fmt(grid), "" if grid == 1.0 else "s"])


func set_rot_step(deg: float) -> void:
	rot_step = deg
	_refresh_ui()


func cycle_rot_step() -> void:
	set_rot_step(ROT_STEPS[(ROT_STEPS.find(rot_step) + 1) % ROT_STEPS.size()])
	_say("Turn step: %d degrees" % int(rot_step))


func toggle_multi() -> void:
	multi = not multi
	_say("MULTI-SELECT on: tap parts to add or remove them" if multi else "MULTI-SELECT off")
	_refresh_ui()


func set_preset(id: String) -> void:
	preset_id = id
	model_id = ""
	set_tool("build")


func set_model(id: String) -> void:
	model_id = id
	set_tool("build")


func set_material(id: String) -> void:
	material_id = id
	if not _sel.is_empty() and tool in SEL_TOOLS:
		var items := _snapshot_sel()
		for e in _sel:
			_apply_paint(e["part"])
		_commit_edits(items)
	_refresh_ui()


func set_color(i: int) -> void:
	color_index = i
	if not _sel.is_empty() and tool in SEL_TOOLS:
		var items := _snapshot_sel()
		for e in _sel:
			(e["part"] as Dictionary)["c"] = i
		_commit_edits(items)
	_refresh_ui()


func cycle_env() -> void:
	var cur := str(level.get("env", "day"))
	var next := Level.ENVS[(Level.ENVS.find(cur) + 1) % Level.ENVS.size()]
	if next == "day":
		level.erase("env")
	else:
		level["env"] = next
	if get_parent() != null and get_parent().has_method("apply_env"):
		get_parent().call("apply_env", next)
	_refresh_ui()


func part_count() -> int:
	return (level["parts"] as Array).size()


func save() -> bool:
	if slot == "":
		slot = Level.new_slot()
	var ok := Level.save_slot(slot, level)
	_say("Saved!" if ok else "Could not save.")
	return ok


# ============================================================ selection ===

func select(e: Dictionary) -> void:
	if e.is_empty():
		_sel = []
	else:
		var group := _group_entries(e)
		if multi:
			if _sel.has(e):
				for g in group:
					_sel.erase(g)
			else:
				for g in group:
					if not _sel.has(g):
						_sel.append(g)
		else:
			_sel = group
	_update_selection()


func selected_part() -> Dictionary:
	return _sel[0]["part"] if not _sel.is_empty() else {}


func selection_size() -> int:
	return _sel.size()


func _group_entries(e: Dictionary) -> Array:
	var g := str((e["part"] as Dictionary).get("g", ""))
	if g == "":
		return [e]
	var out: Array = [e]
	for o: Dictionary in _entries:
		if o != e and str((o["part"] as Dictionary).get("g", "")) == g:
			out.append(o)
	return out


func _snapshot_sel() -> Array:
	var items: Array = []
	for e in _sel:
		items.append({"op": "edit", "part": e["part"], "old": (e["part"] as Dictionary).duplicate(true)})
	return items


## Records the parts that really changed as one undo step and redraws them.
func _commit_edits(items: Array) -> void:
	var changed: Array = []
	for it: Dictionary in items:
		if it["old"] != it["part"]:
			changed.append(it)
			var e := _entry_of_part(it["part"])
			if not e.is_empty():
				_rebuild_entry(e)
	if changed.is_empty():
		return
	_record({"op": "batch", "items": changed} if changed.size() > 1 else changed[0])
	_update_selection()


## Moves the selection by whole grid steps.
func move_selected(d: Vector3) -> void:
	var items := _snapshot_sel()
	for e in _sel:
		var part: Dictionary = e["part"]
		part["p"] = Level._arr(Level.pos(part) + d * grid)
	_commit_edits(items)


## Grows/shrinks the selected parts along one local axis.
func resize_selected(axis: int, delta: float) -> void:
	var items := _snapshot_sel()
	for e in _sel:
		var part: Dictionary = e["part"]
		var s := Level.size(part)
		var v := clampf(s[axis] + delta, minf(grid, 0.5), 128.0)
		var grow := v - s[axis]
		s[axis] = v
		part["s"] = Level._arr(s)
		if axis == 1:
			# Grow upwards so it stays on whatever it stands on.
			part["p"] = Level._arr(Level.pos(part) + Vector3(0, grow * 0.5, 0))
	_commit_edits(items)


## Turns the selection by the turn step around its center.
func rotate_selected(dir: float = 1.0) -> void:
	if _sel.is_empty():
		return
	var items := _snapshot_sel()
	var pivot := _sel_aabb().get_center() if _sel.size() > 1 else Level.pos(_sel[0]["part"])
	_turn_parts(items, pivot, rot_step * dir)
	_commit_edits(items)


func _turn_parts(items: Array, pivot: Vector3, deg: float) -> void:
	var b := Basis(Vector3.UP, deg_to_rad(deg))
	for it: Dictionary in items:
		var part: Dictionary = it["part"]
		var old: Dictionary = it["old"]
		var p := Level.pos(old)
		part["p"] = Level._arr(pivot + b * (p - pivot))
		Level.set_yaw_deg(part, Level.yaw_deg(old) + deg)


func duplicate_selected() -> Dictionary:
	if _sel.is_empty():
		return {}
	var box := _sel_aabb()
	var offset := Vector3(snappedf(box.size.x, grid) if box.size.x >= grid else grid, 0, 0)
	var groups: Dictionary = {}
	var batch: Array = []
	var copies: Array = []
	for e in _sel:
		var src: Dictionary = e["part"]
		if src["t"] == "spawn":
			continue
		if part_count() >= Level.MAX_PARTS:
			_say("Part limit reached (%d)." % Level.MAX_PARTS)
			break
		var copy: Dictionary = src.duplicate(true)
		copy["p"] = Level._arr(Level.pos(src) + offset)
		copy.erase("k")
		if src.has("g"):
			var g := str(src["g"])
			if not groups.has(g):
				groups[g] = _new_group()
			copy["g"] = groups[g]
		_add_part(copy)
		batch.append({"op": "add", "part": copy, "index": _index_of(copy)})
		copies.append(copy)
	if copies.is_empty():
		_say("There can only be one SPAWN.")
		return {}
	_record({"op": "batch", "items": batch} if batch.size() > 1 else batch[0])
	_sel = []
	for c: Dictionary in copies:
		_sel.append(_entry_of_part(c))
	_update_selection()
	_refresh_ui()
	return copies[0]


func cycle_motion() -> void:
	if _sel.is_empty():
		return
	var first: Dictionary = _sel[0]["part"]
	if not (first["t"] in Level.SOLID):
		_say("Only solid parts can move.")
		return
	var i := Level.MOTIONS.find(str(first.get("m", "")))
	var next := Level.MOTIONS[(i + 1) % Level.MOTIONS.size()]
	var items := _snapshot_sel()
	for e in _sel:
		var part: Dictionary = e["part"]
		if not (part["t"] in Level.SOLID):
			continue
		if next == "":
			part.erase("m")
		else:
			part["m"] = next
			part.erase("u")
	_commit_edits(items)


func name_selected(text: String) -> void:
	if _sel.is_empty():
		return
	var part: Dictionary = _sel[0]["part"]
	var item := {"op": "edit", "part": part, "old": part.duplicate(true)}
	var n := Level.clean_name(text)
	if n == "":
		part.erase("n")
	else:
		part["n"] = n
	_commit_edits([item])
	_say("Named \"%s\" - scripts can find it with world.find(\"%s\")" % [n, n] if n != "" else "Name removed.")


func set_sign_text(text: String) -> void:
	if _sel.is_empty() or (_sel[0]["part"] as Dictionary)["t"] != "sign":
		return
	var part: Dictionary = _sel[0]["part"]
	var item := {"op": "edit", "part": part, "old": part.duplicate(true)}
	part["txt"] = text.strip_edges().substr(0, 60)
	_commit_edits([item])


func delete_selected() -> void:
	if _sel.is_empty():
		return
	var batch: Array = []
	for e in _sel.duplicate():
		var part: Dictionary = e["part"]
		if part["t"] == "spawn":
			continue
		batch.append({"op": "del", "part": part, "index": _index_of(part)})
		_remove_entry(e)
	_sel = []
	if not batch.is_empty():
		_record({"op": "batch", "items": batch} if batch.size() > 1 else batch[0])
		Sfx.play("hit", -8.0)
	_after_change()


## Cycles transparency 0 / 25 / 50 / 75 % on the selection.
func cycle_transparency() -> void:
	if _sel.is_empty():
		return
	var cur := float((_sel[0]["part"] as Dictionary).get("a", 0.0))
	var idx := 0
	for i in Level.ALPHAS.size():
		if is_equal_approx(Level.ALPHAS[i], cur):
			idx = i
	set_transparency(Level.ALPHAS[(idx + 1) % Level.ALPHAS.size()])


func set_transparency(a: float) -> void:
	var items := _snapshot_sel()
	for e in _sel:
		var part: Dictionary = e["part"]
		if not (part["t"] in Level.SOLID):
			continue
		if a <= 0.01:
			part.erase("a")
		else:
			part["a"] = a
	_commit_edits(items)


## Toggles a 0/1 property on the selection: "nc" (can't collide),
## "u" (unanchored / physics), "k" (locked).
func toggle_flag(key: String) -> void:
	if _sel.is_empty():
		return
	var on := int((_sel[0]["part"] as Dictionary).get(key, 0)) != 1
	var items := _snapshot_sel()
	for e in _sel:
		var part: Dictionary = e["part"]
		if key != "k" and not (part["t"] in Level.SOLID):
			continue
		if on:
			part[key] = 1
			if key == "u":
				part.erase("m")
		else:
			part.erase(key)
	_commit_edits(items)
	match key:
		"nc":
			_say("Players walk through it now." if on else "It is solid again.")
		"u":
			_say("Unanchored: it falls and can be pushed when you play." if on else "Anchored: it stays in place.")
		"k":
			_say("Locked: taps won't select it (unlock in EXPLORER)." if on else "Unlocked.")


func group_selected() -> void:
	if _sel.size() < 2:
		_say("Select 2 or more parts (MULTI) to group them.")
		return
	var items := _snapshot_sel()
	var g := _new_group()
	for e in _sel:
		(e["part"] as Dictionary)["g"] = g
	_commit_edits(items)
	_say("Grouped %d parts - tapping one selects the whole group." % _sel.size())


func ungroup_selected() -> void:
	var items := _snapshot_sel()
	for e in _sel:
		(e["part"] as Dictionary).erase("g")
	_commit_edits(items)
	if not _sel.is_empty():
		_sel = [_sel[0]]
		_update_selection()
	_say("Ungrouped.")


func unlock_all() -> void:
	var items: Array = []
	for e: Dictionary in _entries:
		var part: Dictionary = e["part"]
		if int(part.get("k", 0)) == 1:
			items.append({"op": "edit", "part": part, "old": part.duplicate(true)})
			part.erase("k")
	_commit_edits(items)
	_say("Unlocked %d parts." % items.size())
	if _explorer != null and _explorer.visible:
		_fill_explorer()


func _new_group() -> String:
	_group_counter += 1
	return "g%d" % _group_counter


# ============================================================== terrain ===

## Adds a generated landscape around the camera focus (one undo step).
func generate_terrain(kind: String) -> int:
	var center := Vector3(snappedf(_focus.x, 4.0), 0.0, snappedf(_focus.z, 4.0))
	var list := TerrainGen.generate(kind, center, randi() % 100000)
	if part_count() + list.size() > Level.MAX_PARTS:
		_say("Not enough room: terrain needs %d parts." % list.size())
		return 0
	var batch: Array = []
	for p: Dictionary in list:
		var clean := Level._clean_part(p)
		if clean.is_empty():
			continue
		_add_part(clean)
		batch.append({"op": "add", "part": clean, "index": _index_of(clean)})
	_record({"op": "batch", "items": batch})
	_after_change()
	_say("%s terrain added (%d parts). It is locked so building on it is easy." % [TerrainGen.LABELS.get(kind, kind), batch.size()])
	return batch.size()


func clear_terrain() -> void:
	var batch: Array = []
	for e: Dictionary in _entries.duplicate():
		var part: Dictionary = e["part"]
		if str(part.get("g", "")) == "terrain":
			batch.append({"op": "del", "part": part, "index": _index_of(part)})
			_remove_entry(e)
	if not batch.is_empty():
		_record({"op": "batch", "items": batch})
	_after_change()
	_say("Terrain removed." if not batch.is_empty() else "There is no terrain.")


# ====================================================== transform drag ===

## Starts dragging a 3D handle under the finger/mouse. Returns true if one
## was hit (the camera then ignores that touch).
func try_grab(screen_pos: Vector2) -> bool:
	if _sel.is_empty() or not (tool in ["move", "scale", "rotate"]) or _handles.get_child_count() == 0:
		return false
	var from := _cam.project_ray_origin(screen_pos)
	var dir := _cam.project_ray_normal(screen_pos)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 800.0, HANDLE_LAYER)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return false
	var body := hit["collider"] as Node
	if body == null or not body.has_meta("handle_kind"):
		return false
	begin_transform(str(body.get_meta("handle_kind")), body.get_meta("handle_axis") as Vector3)
	_drag["start"] = screen_pos
	_drag["origin"] = (body as Node3D).global_position
	return true


func drag_to(screen_pos: Vector2) -> void:
	if _drag.is_empty():
		return
	var start: Vector2 = _drag["start"]
	if str(_drag["kind"]) == "rotate":
		update_transform((screen_pos.x - start.x) * 0.5)
		return
	var origin: Vector3 = _drag["origin"]
	var axis: Vector3 = _drag["axis"]
	var p0 := _cam.unproject_position(origin)
	var p1 := _cam.unproject_position(origin + axis)
	var sdir := p1 - p0
	if sdir.length() < 2.0:
		return
	update_transform((screen_pos - start).dot(sdir) / sdir.length_squared())


func end_drag() -> void:
	end_transform()


## Transform API (used by the handles, and by tests):
## kind "move" (axis = world direction), "scale" (axis = the part's local
## face direction in world space), "rotate" (amount in degrees).
func begin_transform(kind: String, axis: Vector3) -> void:
	_drag = {"kind": kind, "axis": axis.normalized(), "items": _snapshot_sel(), "applied": 0.0,
		"pivot": _sel_aabb().get_center()}


func update_transform(amount: float) -> void:
	if _drag.is_empty():
		return
	var kind := str(_drag["kind"])
	var step := rot_step if kind == "rotate" else grid
	var d := snappedf(amount, step)
	if is_equal_approx(d, float(_drag["applied"])):
		return
	_drag["applied"] = d
	var axis: Vector3 = _drag["axis"]
	var items: Array = _drag["items"]
	match kind:
		"move":
			for it: Dictionary in items:
				(it["part"] as Dictionary)["p"] = Level._arr(Level.pos(it["old"]) + axis * d)
		"scale":
			for it: Dictionary in items:
				var part: Dictionary = it["part"]
				var old: Dictionary = it["old"]
				var bas := Basis(Vector3.UP, Level.yaw(old))
				var local := bas.inverse() * axis
				var ai := 0
				if absf(local.y) > absf(local.x) and absf(local.y) > absf(local.z):
					ai = 1
				elif absf(local.z) > absf(local.x):
					ai = 2
				var s := Level.size(old)
				var v := clampf(s[ai] + d, minf(grid, 0.5), 128.0)
				var grow := v - s[ai]
				s[ai] = v
				part["s"] = Level._arr(s)
				part["p"] = Level._arr(Level.pos(old) + axis * grow * 0.5)
		"rotate":
			_turn_parts(items, _drag["pivot"], d)
	for it: Dictionary in items:
		var e := _entry_of_part(it["part"])
		if not e.is_empty():
			_rebuild_entry(e)
	_update_selection(false)
	_say_info()


func end_transform() -> void:
	if _drag.is_empty():
		return
	var items: Array = _drag["items"]
	_drag = {}
	var changed: Array = []
	for it: Dictionary in items:
		if it["old"] != it["part"]:
			changed.append(it)
	if not changed.is_empty():
		_record({"op": "batch", "items": changed} if changed.size() > 1 else changed[0])
	_update_selection()


func _say_info() -> void:
	if _drag.is_empty():
		return
	var kind := str(_drag["kind"])
	var d := float(_drag["applied"])
	if kind == "rotate":
		_say("Turn %+d degrees" % int(d))
	else:
		_say("%s %+s studs" % ["Move" if kind == "move" else "Size", _fmt(d)])


# ============================================================ highlight ===

func _update_selection(rebuild_handles: bool = true) -> void:
	for h in _highlights:
		h.visible = false
	var shown := 0
	if _sel.size() > 60:
		var box := _sel_aabb()
		var h0 := _highlight(0)
		h0.mesh = _cache.unit_mesh("box")
		h0.global_position = box.get_center()
		h0.rotation = Vector3.ZERO
		h0.scale = box.size + Vector3.ONE * 0.2
		h0.visible = true
	else:
		for e in _sel:
			var part: Dictionary = e["part"]
			var h := _highlight(shown)
			h.mesh = _cache.unit_mesh(Level.part_shape(part["t"]))
			h.global_position = Level.pos(part)
			h.rotation = Vector3(0, Level.yaw(part), 0)
			h.scale = Level.size(part) + Vector3.ONE * 0.12
			h.visible = true
			shown += 1
	if rebuild_handles:
		_rebuild_handles()
	_refresh_props()


func _highlight(i: int) -> MeshInstance3D:
	while _highlights.size() <= i:
		var mi := MeshInstance3D.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1.0, 0.85, 0.2, 0.3)
		mat.no_depth_test = true
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_highlights.append(mi)
	return _highlights[i]


func _rebuild_handles() -> void:
	for c in _handles.get_children():
		c.queue_free()
	_handles_dist = _dist
	if _sel.is_empty() or not (tool in ["move", "scale", "rotate"]):
		return
	var box := _sel_aabb()
	var center := box.get_center()
	var k := clampf(_dist * 0.035, 0.5, 4.0)
	match tool:
		"move":
			for ai in 3:
				for sgn in [-1.0, 1.0]:
					var axis := Vector3.ZERO
					axis[ai] = sgn
					var at := center + axis * (box.size[ai] * 0.5 + 1.2 * k)
					_add_handle("move", axis, at, AXIS_COLORS[ai], k, true)
		"scale":
			var part: Dictionary = _sel[0]["part"]
			var bas := Basis(Vector3.UP, Level.yaw(part))
			var s := Level.size(part)
			var c := Level.pos(part)
			for ai in 3:
				for sgn in [-1.0, 1.0]:
					var local := Vector3.ZERO
					local[ai] = sgn
					var axis := bas * local
					var at := c + axis * (s[ai] * 0.5 + 0.9 * k)
					_add_handle("scale", axis, at, AXIS_COLORS[ai], k, false)
		"rotate":
			var r := maxf(box.size.x, box.size.z) * 0.5 + 1.5 * k
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = r - 0.12 * k
			tm.outer_radius = r + 0.12 * k
			ring.mesh = tm
			ring.material_override = _handle_mat(Color(1.0, 0.85, 0.2))
			ring.position = center
			_handles.add_child(ring)
			for i in 4:
				var a := TAU * i / 4.0
				_add_handle("rotate", Vector3.UP, center + Vector3(cos(a) * r, 0, sin(a) * r), Color(1.0, 0.85, 0.2), k, false)


func _add_handle(kind: String, axis: Vector3, at: Vector3, col: Color, k: float, arrow: bool) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = HANDLE_LAYER
	body.collision_mask = 0
	body.set_meta("handle_kind", kind)
	body.set_meta("handle_axis", axis)
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.9 * k
	cs.shape = sp
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	if arrow:
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.4 * k
		cm.height = 0.9 * k
		mi.mesh = cm
		var shaft := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.1 * k
		sm.bottom_radius = 0.1 * k
		sm.height = 1.0 * k
		shaft.mesh = sm
		shaft.position = Vector3(0, -0.9 * k, 0)
		shaft.material_override = _handle_mat(col)
		mi.add_child(shaft)
	else:
		var bm := SphereMesh.new()
		bm.radius = 0.35 * k
		bm.height = 0.7 * k
		mi.mesh = bm
	mi.material_override = _handle_mat(col)
	body.add_child(mi)
	_handles.add_child(body)
	body.global_position = at
	if arrow:
		# Point the cone (+Y) along the axis.
		var up := axis.normalized()
		var side := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
		var x := side.cross(up).normalized()
		mi.basis = Basis(x, up, x.cross(up))


func _handle_mat(col: Color) -> StandardMaterial3D:
	var key := "handle|" + col.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = col
		m.no_depth_test = true
		m.render_priority = 10
		_mats[key] = m
	return _mats[key] as StandardMaterial3D


func _sel_aabb() -> AABB:
	var box := AABB()
	var first := true
	for e in _sel:
		var a := Level.part_aabb(e["part"])
		box = a if first else box.merge(a)
		first = false
	return box


func _level_aabb() -> AABB:
	var box := AABB(Vector3(-8, 0, -8), Vector3(16, 4, 16))
	var first := true
	for p: Dictionary in level["parts"]:
		var a := Level.part_aabb(p)
		if a.size.x * a.size.z > 2000.0:
			continue
		box = a if first else box.merge(a)
		first = false
	return box


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


func _index_of(part: Dictionary) -> int:
	var parts: Array = level["parts"]
	for i in parts.size():
		if is_same(parts[i], part):
			return i
	return -1


func _remove_entry(e: Dictionary, _unused: bool = true) -> void:
	_sel.erase(e)
	(e["node"] as Node).queue_free()
	_entries.erase(e)
	var idx := _index_of(e["part"])
	if idx >= 0:
		(level["parts"] as Array).remove_at(idx)


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
	var tags: Array[String] = []
	if t in Level.SPECIAL:
		tags.append(str(Level.preset(t)["label"]))
	if part.has("n"):
		tags.append("\"%s\"" % part["n"])
	if part.has("m"):
		tags.append(str(Level.MOTION_LABELS.get(part["m"], "")))
	if int(part.get("u", 0)) == 1:
		tags.append("PHYSICS")
	if int(part.get("nc", 0)) == 1:
		tags.append("GHOST")
	if not tags.is_empty() and not (t in ["tree", "sign", "light"] and tags.size() == 1):
		var l := Label3D.new()
		l.text = "\n".join(tags)
		l.font_size = 56
		l.outline_size = 12
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
			body.add_child(Level._sign_label(str(part.get("txt", "")), Vector3.ZERO, s, Vector3.ZERO))
			return
		"ladder":
			body.add_child(Level._ladder_visual(Vector3.ZERO, s, Vector3.ZERO))
			return
		"truss":
			var holder := Node3D.new()
			body.add_child(holder)
			var tb := WorldBuilder.new(holder)
			Level.truss_beams(tb, Vector3.ZERO, s, Vector3.ZERO, col)
			tb.build()
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
		"fire", "smoke", "sparkles":
			var fx := Level.effect_node(t, col, s)
			body.add_child(fx)
			var wire := StandardMaterial3D.new()
			wire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			wire.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			wire.albedo_color = Color(col, 0.18)
			_mesh(body, Vector3.ZERO, s, wire)
			return
	var glow := t in ["kill", "jumppad", "coin", "speed", "teleport", "conveyor"]
	var mi := MeshInstance3D.new()
	mi.mesh = _cache.unit_mesh(shape)
	mi.scale = s
	if t in Level.SOLID:
		mi.material_override = Level.part_material(part) if part.has("a") else _part_material(mat, col)
	else:
		mi.material_override = _material(col, glow)
	body.add_child(mi)


func _mesh(body: Node3D, at: Vector3, sz: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _cache.unit_mesh("box")
	mi.position = at
	mi.scale = sz
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


static func _dominant(normal: Vector3) -> Vector3:
	var n := Vector3.ZERO
	var a := normal.abs()
	if a.y >= a.x and a.y >= a.z:
		n.y = signf(normal.y) if normal.y != 0.0 else 1.0
	elif a.x >= a.z:
		n.x = signf(normal.x)
	else:
		n.z = signf(normal.z)
	return n


static func _fmt(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v


# =================================================================== UI ===

func _btn(text: String, color: Color, font: int = 16, h: float = 48.0, w: float = 0.0) -> Button:
	var b := UiStyle.button(text, color, font, h)
	if w > 0.0:
		b.custom_minimum_size.x = w
	b.focus_mode = Control.FOCUS_NONE
	return b


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_root)

	_touch = TouchControls.new()
	_touch.show_jump = false
	_touch.joystick_enabled = false
	_touch.tapped.connect(use_tool_at)
	_touch.panned.connect(_on_pan)
	_touch.grab_begin = try_grab
	_touch.grab_move = drag_to
	_touch.grab_end = end_drag
	_root.add_child(_touch)

	_build_top_bar()
	_build_rail()
	_build_options()
	_build_props()
	_build_palette()

	_msg = UiStyle.label(22, Color(1.0, 0.9, 0.5))
	_msg.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.offset_left = -420
	_msg.offset_right = 420
	_msg.offset_top = 126
	_root.add_child(_msg)


func _panel_box() -> StyleBoxFlat:
	var sb := UiStyle.box(Color(0.07, 0.09, 0.18, 0.88), 16, 8)
	sb.border_color = Color(1, 1, 1, 0.12)
	sb.set_border_width_all(2)
	return sb


func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 8
	bar.offset_right = -8
	bar.offset_top = 6
	bar.offset_bottom = 64
	bar.add_theme_stylebox_override("panel", _panel_box())
	_root.add_child(bar)
	_touch.blockers.append(bar)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	bar.add_child(top)
	var ex := _btn("EXIT", Color(0.6, 0.3, 0.3), 16, 44, 80)
	ex.pressed.connect(_on_exit)
	top.add_child(ex)
	_name_edit = UiStyle.line_edit("Game name", 20)
	_name_edit.text = str(level.get("name", "My Game"))
	_name_edit.max_length = 32
	_name_edit.custom_minimum_size = Vector2(220, 44)
	_name_edit.text_changed.connect(_on_name_changed)
	_name_edit.focus_entered.connect(_block_input.bind(true))
	_name_edit.focus_exited.connect(_block_input.bind(false))
	top.add_child(_name_edit)
	_count_label = UiStyle.label(16, Color(1, 1, 1, 0.75))
	_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(_count_label)
	for spec in [["UNDO", Color(0.35, 0.38, 0.52), undo], ["REDO", Color(0.35, 0.38, 0.52), redo],
			["SCRIPT", Color(0.2, 0.5, 0.6), open_script], ["SAVE", Color(0.2, 0.6, 0.35), save],
			["TEST", Color(0.95, 0.55, 0.2), _on_test], ["PUBLISH", Color(0.6, 0.35, 0.95), _on_publish]]:
		var b := _btn(spec[0], spec[1], 16, 44, 92)
		b.pressed.connect(spec[2])
		top.add_child(b)


func _build_rail() -> void:
	var rail := PanelContainer.new()
	rail.position = Vector2(8, 70)
	rail.add_theme_stylebox_override("panel", _panel_box())
	_root.add_child(rail)
	_touch.blockers.append(rail)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	rail.add_child(vb)
	for t in ["select", "move", "scale", "rotate", "build", "paint", "delete"]:
		var b := _btn(t.to_upper(), Color(0.25, 0.3, 0.48), 15, 46, 104)
		b.pressed.connect(set_tool.bind(t))
		vb.add_child(b)
		_tool_buttons[t] = b
	var sep := HSeparator.new()
	vb.add_child(sep)
	var tb := _btn("TERRAIN", Color(0.25, 0.5, 0.35), 15, 46, 104)
	tb.pressed.connect(toggle_terrain_panel)
	vb.add_child(tb)
	var eb := _btn("EXPLORER", Color(0.3, 0.4, 0.6), 15, 46, 104)
	eb.pressed.connect(toggle_explorer)
	vb.add_child(eb)


func _build_options() -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(134, 70)
	row.add_theme_constant_override("separation", 5)
	_root.add_child(row)
	_touch.blockers.append(row)
	var specs := [["grid", "GRID 1", cycle_grid, 96], ["turn", "TURN 90", cycle_rot_step, 100],
		["rot", "ROTATE", rotate_preset, 104], ["air", "AIR", toggle_air, 86],
		["multi", "MULTI", toggle_multi, 84], ["focus", "FOCUS", focus_selection, 84],
		["sky", "SKY", cycle_env, 116]]
	for spec in specs:
		var b := _btn(spec[1], Color(0.25, 0.3, 0.48), 14, 42, spec[3])
		b.pressed.connect(spec[2])
		row.add_child(b)
		_opt_buttons[spec[0]] = b
	for spec in [["UP", 1.0], ["DOWN", -1.0]]:
		var vb := _btn(spec[0], Color(0.3, 0.33, 0.45), 14, 42, 74)
		vb.button_down.connect(_set_vertical.bind(spec[1]))
		vb.button_up.connect(_set_vertical.bind(0.0))
		row.add_child(vb)


func _set_vertical(v: float) -> void:
	_vertical = v


func _block_input(on: bool) -> void:
	Game.input_blocked = on


func _on_name_changed(t: String) -> void:
	level["name"] = t.strip_edges()


# ----------------------------------------------------------- properties ---

func _build_props() -> void:
	_props = PanelContainer.new()
	_props.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_props.offset_left = -360
	_props.offset_right = -8
	_props.offset_top = 120
	_props.offset_bottom = -168
	_props.add_theme_stylebox_override("panel", _panel_box())
	_props.visible = false
	_root.add_child(_props)
	_touch.blockers.append(_props)
	var scroll := TouchScroll.make(false)
	_props.add_child(scroll)
	var sv := VBoxContainer.new()
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sv.add_theme_constant_override("separation", 6)
	scroll.add_child(sv)
	_prop_info = UiStyle.label(16, Color(1.0, 0.85, 0.3))
	_prop_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sv.add_child(_prop_info)
	for row_spec in [["MOVE", [["X-", 0, -1.0], ["X+", 0, 1.0], ["Y-", 1, -1.0], ["Y+", 1, 1.0], ["Z-", 2, -1.0], ["Z+", 2, 1.0]]],
			["SIZE", [["W-", 0, -1.0], ["W+", 0, 1.0], ["H-", 1, -1.0], ["H+", 1, 1.0], ["D-", 2, -1.0], ["D+", 2, 1.0]]]]:
		var lab := UiStyle.label(13, Color(1, 1, 1, 0.65))
		lab.text = row_spec[0]
		sv.add_child(lab)
		var grid_row := HBoxContainer.new()
		grid_row.add_theme_constant_override("separation", 3)
		sv.add_child(grid_row)
		for bspec in row_spec[1]:
			var bb := _btn(bspec[0], AXIS_COLORS[int(bspec[1])].darkened(0.45), 14, 40, 50)
			if row_spec[0] == "MOVE":
				var dv := Vector3.ZERO
				dv[int(bspec[1])] = float(bspec[2])
				bb.pressed.connect(move_selected.bind(dv))
			else:
				bb.pressed.connect(_resize_step.bind(int(bspec[1]), float(bspec[2])))
			grid_row.add_child(bb)
	var turn := HBoxContainer.new()
	turn.add_theme_constant_override("separation", 3)
	sv.add_child(turn)
	for spec in [["TURN LEFT", -1.0], ["TURN RIGHT", 1.0]]:
		var tb := _btn(spec[0], Color(0.45, 0.35, 0.15), 14, 40)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.pressed.connect(rotate_selected.bind(spec[1]))
		turn.add_child(tb)
	var toggles := GridContainer.new()
	toggles.columns = 2
	toggles.add_theme_constant_override("h_separation", 4)
	toggles.add_theme_constant_override("v_separation", 4)
	sv.add_child(toggles)
	var specs := [["anchored", toggle_flag.bind("u")], ["collide", toggle_flag.bind("nc")],
		["alpha", cycle_transparency], ["lock", toggle_flag.bind("k")],
		["motion", cycle_motion], ["focus", focus_selection],
		["group", group_selected], ["ungroup", ungroup_selected],
		["copy", duplicate_selected], ["delete", delete_selected]]
	for spec in specs:
		var b := _btn(str(spec[0]).to_upper(), Color(0.3, 0.33, 0.5) if spec[0] != "delete" else Color(0.6, 0.3, 0.3), 13, 40)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(spec[1])
		toggles.add_child(b)
		_prop_buttons[spec[0]] = b
	var nrow := HBoxContainer.new()
	nrow.add_theme_constant_override("separation", 4)
	sv.add_child(nrow)
	_sel_name = UiStyle.line_edit("name (for scripts)", 16)
	_sel_name.custom_minimum_size.y = 40
	_sel_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sel_name.max_length = 24
	_sel_name.focus_entered.connect(_block_input.bind(true))
	_sel_name.focus_exited.connect(_block_input.bind(false))
	_sel_name.text_submitted.connect(name_selected)
	nrow.add_child(_sel_name)
	var nb := _btn("SET", Color(0.2, 0.6, 0.35), 14, 40, 64)
	nb.pressed.connect(_name_from_field)
	nrow.add_child(nb)
	_sign_row = HBoxContainer.new()
	_sign_row.add_theme_constant_override("separation", 4)
	sv.add_child(_sign_row)
	_sign_edit = UiStyle.line_edit("sign text", 16)
	_sign_edit.custom_minimum_size.y = 40
	_sign_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sign_edit.max_length = 60
	_sign_edit.focus_entered.connect(_block_input.bind(true))
	_sign_edit.focus_exited.connect(_block_input.bind(false))
	_sign_edit.text_submitted.connect(set_sign_text)
	_sign_row.add_child(_sign_edit)
	var sb := _btn("TEXT", Color(0.2, 0.6, 0.35), 14, 40, 64)
	sb.pressed.connect(_sign_from_field)
	_sign_row.add_child(sb)


func _resize_step(axis: int, dir: float) -> void:
	resize_selected(axis, dir * grid)


func _name_from_field() -> void:
	name_selected(_sel_name.text)


func _sign_from_field() -> void:
	set_sign_text(_sign_edit.text)


func _refresh_props() -> void:
	if _props == null:
		return
	_props.visible = not _sel.is_empty()
	if _sel.is_empty():
		return
	var part: Dictionary = _sel[0]["part"]
	var s := Level.size(part)
	var kind := str(Level.preset(part["t"]).get("label", part["t"])) if part["t"] in Level.SPECIAL else str(part["t"]).to_upper()
	var info := "%s  %sx%sx%s" % [kind, _fmt(s.x), _fmt(s.y), _fmt(s.z)]
	if _sel.size() > 1:
		info += "   (%d selected)" % _sel.size()
	if part.has("g"):
		info += "\nGroup: " + str(part["g"])
	if part.has("n"):
		info += "\nName: \"%s\"" % part["n"]
	_prop_info.text = info
	(_prop_buttons["anchored"] as Button).text = "ANCHORED: %s" % ("NO" if int(part.get("u", 0)) == 1 else "YES")
	(_prop_buttons["collide"] as Button).text = "COLLIDE: %s" % ("NO" if int(part.get("nc", 0)) == 1 else "YES")
	(_prop_buttons["alpha"] as Button).text = "SEE-THROUGH %d%%" % int(float(part.get("a", 0.0)) * 100.0)
	(_prop_buttons["lock"] as Button).text = "LOCKED" if int(part.get("k", 0)) == 1 else "LOCK"
	(_prop_buttons["motion"] as Button).text = "MOTION: %s" % Level.MOTION_LABELS.get(str(part.get("m", "")), "NONE")
	var solid: bool = part["t"] in Level.SOLID
	for k in ["anchored", "collide", "alpha", "motion"]:
		(_prop_buttons[k] as Button).disabled = not solid
	(_prop_buttons["group"] as Button).disabled = _sel.size() < 2
	(_prop_buttons["ungroup"] as Button).disabled = not part.has("g")
	_sign_row.visible = part["t"] == "sign"
	if part["t"] == "sign" and not _sign_edit.has_focus():
		_sign_edit.text = str(part.get("txt", ""))
	if not _sel_name.has_focus():
		_sel_name.text = str(part.get("n", ""))


# -------------------------------------------------------------- palette ---

func _build_palette() -> void:
	var pal := PanelContainer.new()
	pal.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	pal.offset_left = 128
	pal.offset_right = -8
	pal.offset_top = -162
	pal.offset_bottom = -6
	pal.add_theme_stylebox_override("panel", _panel_box())
	_root.add_child(pal)
	_touch.blockers.append(pal)
	_palette = pal
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	pal.add_child(vb)
	var tabs_scroll := TouchScroll.make(true)
	tabs_scroll.custom_minimum_size.y = 40
	vb.add_child(tabs_scroll)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 5)
	tabs_scroll.add_child(tabs)
	for t in TABS:
		var b := _btn(t, Color(0.22, 0.26, 0.4), 14, 38, 104)
		b.pressed.connect(_set_tab.bind(t))
		tabs.add_child(b)
		_tab_buttons[t] = b
	_strip_scroll = TouchScroll.make(true)
	_strip_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_strip_scroll)
	_strip = HBoxContainer.new()
	_strip.add_theme_constant_override("separation", 6)
	_strip_scroll.add_child(_strip)
	_fill_strip()


func _set_tab(t: String) -> void:
	_tab = t
	_fill_strip()
	_refresh_ui()


func _fill_strip() -> void:
	for c in _strip.get_children():
		c.queue_free()
	_tile_buttons.clear()
	_strip_scroll.scroll_horizontal = 0
	match _tab:
		"COLOR":
			for i in Level.COLORS.size():
				var cb := Button.new()
				cb.custom_minimum_size = Vector2(62, 62)
				cb.focus_mode = Control.FOCUS_NONE
				cb.pressed.connect(set_color.bind(i))
				_strip.add_child(cb)
				_tile_buttons["c%d" % i] = cb
		"MATERIAL":
			for m: Dictionary in Materials.LIST:
				var mb := _tile(str(m["name"]).to_upper(), Materials.info(m["id"])["ui"])
				if m["id"] != "plastic" and m["id"] != "neon" and m["id"] != "wool":
					mb.icon = Materials.texture(m["id"])
				mb.pressed.connect(set_material.bind(str(m["id"])))
				_tile_buttons["m:" + str(m["id"])] = mb
		"MODELS":
			for m: Dictionary in Prefabs.MODELS:
				var id: String = m["id"]
				var tb := _tile(m["label"], Color(0.3, 0.32, 0.5))
				tb.pressed.connect(set_model.bind(id))
				_tile_buttons["model:" + id] = tb
				Thumbs.request("model_" + id, _model_level.bind(id), _set_icon.bind(tb), Vector2i(128, 128))
		_:
			var cat: String = TAB_CATS.get(_tab, "parts")
			for pr: Dictionary in Level.PRESETS:
				if str(pr.get("cat", "parts")) != cat:
					continue
				var pid: String = pr["id"]
				var special: bool = pr["t"] in Level.SPECIAL
				var tb2 := _tile(pr["label"], Color(0.45, 0.25, 0.3) if special else Color(0.25, 0.4, 0.6))
				tb2.pressed.connect(set_preset.bind(pid))
				_tile_buttons["p:" + pid] = tb2
				Thumbs.request("part_" + pid, _preset_level.bind(pid), _set_icon.bind(tb2), Vector2i(128, 128))
	_refresh_ui()


func _tile(text: String, color: Color) -> Button:
	var b := _btn(text, color, 12, 96, 100)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.expand_icon = true
	b.clip_text = true
	b.add_theme_constant_override("icon_max_width", 62)
	_strip.add_child(b)
	return b


func _set_icon(tex: Texture2D, b: Button) -> void:
	if is_instance_valid(b):
		b.icon = tex


func _model_level(id: String) -> Dictionary:
	return Prefabs.preview_level(id)


func _preset_level(pid: String) -> Dictionary:
	var pr := Level.preset(pid)
	var s := Level._vec(pr["s"], Vector3.ONE)
	var p := {"t": pr["t"], "p": [0, s.y * 0.5, 0], "s": pr["s"], "r": 0, "c": pr["c"]}
	if pr["t"] == "sign":
		p["txt"] = "Hi!"
	return {"v": Level.VERSION, "name": pid, "parts": [p]}


# ------------------------------------------------------ explorer/terrain ---

func toggle_explorer() -> void:
	if _explorer == null:
		_explorer = PanelContainer.new()
		_explorer.position = Vector2(134, 120)
		_explorer.custom_minimum_size = Vector2(380, 420)
		_explorer.add_theme_stylebox_override("panel", _panel_box())
		_root.add_child(_explorer)
		_touch.blockers.append(_explorer)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 6)
		_explorer.add_child(vb)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 4)
		vb.add_child(head)
		var t := UiStyle.label(20, Color(1.0, 0.85, 0.3))
		t.text = "EXPLORER"
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(t)
		var ub := _btn("UNLOCK ALL", Color(0.3, 0.4, 0.6), 13, 36, 110)
		ub.pressed.connect(unlock_all)
		head.add_child(ub)
		var cb := _btn("CLOSE", Color(0.5, 0.3, 0.3), 13, 36, 76)
		cb.pressed.connect(toggle_explorer)
		head.add_child(cb)
		var scroll := TouchScroll.make(false)
		scroll.custom_minimum_size.y = 360
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vb.add_child(scroll)
		_explorer_list = VBoxContainer.new()
		_explorer_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_explorer_list.add_theme_constant_override("separation", 3)
		scroll.add_child(_explorer_list)
		_explorer.visible = false
	_explorer.visible = not _explorer.visible
	if _explorer.visible:
		if _terrain_panel != null:
			_terrain_panel.visible = false
		_fill_explorer()


func _fill_explorer() -> void:
	for c in _explorer_list.get_children():
		c.queue_free()
	var groups: Dictionary = {}
	var shown := 0
	var parts: Array = level["parts"]
	for i in range(parts.size() - 1, -1, -1):
		var p: Dictionary = parts[i]
		var g := str(p.get("g", ""))
		if g != "":
			if groups.has(g):
				groups[g] = int(groups[g]) + 1
				continue
			groups[g] = 1
		if shown >= 150:
			continue
		shown += 1
		var label := str(Level.preset(p["t"]).get("label", p["t"])) if p["t"] in Level.SPECIAL else str(p["t"]).to_upper()
		if g != "":
			label = "GROUP %s" % g
		if p.has("n"):
			label += "  \"%s\"" % p["n"]
		if int(p.get("k", 0)) == 1:
			label += "  [LOCKED]"
		var b := _btn(label, Color(0.2, 0.24, 0.38), 13, 36)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_explorer_pick.bind(p))
		_explorer_list.add_child(b)
	var foot := UiStyle.label(13, Color(1, 1, 1, 0.6))
	foot.text = "%d parts, %d groups. Newest first." % [parts.size(), groups.size()]
	_explorer_list.add_child(foot)


func _explorer_pick(part: Dictionary) -> void:
	var e := _entry_of_part(part)
	if e.is_empty():
		return
	if not (tool in SEL_TOOLS):
		set_tool("select")
	var was := multi
	multi = false
	select(e)
	multi = was
	focus_selection()


func toggle_terrain_panel() -> void:
	if _terrain_panel == null:
		_terrain_panel = PanelContainer.new()
		_terrain_panel.position = Vector2(134, 120)
		_terrain_panel.add_theme_stylebox_override("panel", _panel_box())
		_root.add_child(_terrain_panel)
		_touch.blockers.append(_terrain_panel)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 6)
		_terrain_panel.add_child(vb)
		var t := UiStyle.label(20, Color(1.0, 0.85, 0.3))
		t.text = "TERRAIN GENERATOR"
		vb.add_child(t)
		var info := UiStyle.label(13, Color(1, 1, 1, 0.7))
		info.text = "Makes a 64x64 landscape around the white dot."
		vb.add_child(info)
		var g := GridContainer.new()
		g.columns = 3
		g.add_theme_constant_override("h_separation", 5)
		g.add_theme_constant_override("v_separation", 5)
		vb.add_child(g)
		for k in TerrainGen.KINDS:
			var b := _btn(TerrainGen.LABELS[k], Color(0.25, 0.5, 0.35), 14, 44, 120)
			b.pressed.connect(_terrain_pressed.bind(k))
			g.add_child(b)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		vb.add_child(row)
		var cb := _btn("CLEAR TERRAIN", Color(0.6, 0.3, 0.3), 14, 42)
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.pressed.connect(clear_terrain)
		row.add_child(cb)
		var close := _btn("CLOSE", Color(0.35, 0.38, 0.52), 14, 42, 90)
		close.pressed.connect(toggle_terrain_panel)
		row.add_child(close)
		_terrain_panel.visible = false
	_terrain_panel.visible = not _terrain_panel.visible
	if _terrain_panel.visible and _explorer != null:
		_explorer.visible = false


func _terrain_pressed(kind: String) -> void:
	generate_terrain(kind)
	_terrain_panel.visible = false


# =============================================================== script ===

func open_script() -> void:
	if _script_panel == null:
		_build_script_panel()
	_code.text = str(level.get("script", ""))
	_script_status.text = "Write Lua-style code. Tap a template to start."
	_script_panel.visible = true
	_palette.visible = false
	Game.input_blocked = true


func close_script() -> void:
	set_script_text(_code.text)
	_script_panel.visible = false
	_palette.visible = true
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
	_script_panel = PanelContainer.new()
	_script_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_script_panel.offset_left = 24
	_script_panel.offset_right = -24
	_script_panel.offset_top = 16
	_script_panel.offset_bottom = -16
	_script_panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	_root.add_child(_script_panel)
	_touch.blockers.append(_script_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_script_panel.add_child(vb)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	vb.add_child(head)
	var title := UiStyle.label(28, Color(1.0, 0.85, 0.3))
	title.text = "SCRIPT"
	head.add_child(title)
	var tpl_scroll := TouchScroll.make(true)
	tpl_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tpl_scroll.custom_minimum_size.y = 46
	head.add_child(tpl_scroll)
	var tpls := HBoxContainer.new()
	tpls.add_theme_constant_override("separation", 6)
	tpl_scroll.add_child(tpls)
	for tpl: Array in ScriptTemplates.TEMPLATES:
		var tb := _btn(tpl[0], Color(0.3, 0.36, 0.55), 14, 42, 100)
		tb.pressed.connect(_use_template.bind(str(tpl[1])))
		tpls.add_child(tb)
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
	_code.focus_entered.connect(_block_input.bind(true))
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
		var b := _btn(spec[0], spec[1], 18, 52, 120)
		b.pressed.connect(spec[2])
		foot.add_child(b)


func _use_template(code_text: String) -> void:
	_code.text = code_text


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


# ============================================================== refresh ===

func _refresh_ui() -> void:
	if _count_label == null:
		return
	_count_label.text = "  %d / %d parts" % [part_count(), Level.MAX_PARTS]
	var on_col := Color(0.95, 0.55, 0.2)
	var off_col := Color(0.25, 0.3, 0.48)
	for t: String in _tool_buttons:
		(_tool_buttons[t] as Button).add_theme_stylebox_override("normal", UiStyle.box(on_col if t == tool else off_col, 18, 10))
	for t2: String in _tab_buttons:
		(_tab_buttons[t2] as Button).add_theme_stylebox_override("normal", UiStyle.box(Color(0.3, 0.55, 0.85) if t2 == _tab else Color(0.22, 0.26, 0.4), 18, 10))
	for key: String in _tile_buttons:
		var b: Button = _tile_buttons[key]
		var active := false
		var base := Color(0.25, 0.4, 0.6)
		if key.begins_with("p:"):
			var pid := key.substr(2)
			active = tool == "build" and model_id == "" and pid == preset_id
			base = Color(0.45, 0.25, 0.3) if Level.preset(pid)["t"] in Level.SPECIAL else Color(0.25, 0.4, 0.6)
		elif key.begins_with("model:"):
			active = tool == "build" and key.substr(6) == model_id
			base = Color(0.3, 0.32, 0.5)
		elif key.begins_with("m:"):
			active = key.substr(2) == material_id
			base = (Materials.info(key.substr(2))["ui"] as Color).darkened(0.35)
		elif key.begins_with("c"):
			var ci := int(key.substr(1))
			active = ci == color_index
			base = Level.COLORS[ci]
		var sb := UiStyle.box(base, 14, 6)
		sb.border_color = Color(1.0, 0.85, 0.25) if active else Color(0, 0, 0, 0.3)
		sb.set_border_width_all(4 if active else 2)
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, sb)
	if _opt_buttons.is_empty():
		return
	(_opt_buttons["grid"] as Button).text = "GRID %s" % _fmt(grid)
	(_opt_buttons["turn"] as Button).text = "TURN %d" % int(rot_step)
	(_opt_buttons["rot"] as Button).text = "ROTATE %d" % int(rot_deg)
	(_opt_buttons["sky"] as Button).text = "SKY: " + str(level.get("env", "day")).to_upper()
	(_opt_buttons["air"] as Button).text = "AIR %s" % _fmt(build_height()) if air_mode else "AIR"
	(_opt_buttons["air"] as Button).add_theme_stylebox_override("normal", UiStyle.box(Color(0.2, 0.6, 0.8) if air_mode else off_col, 18, 10))
	(_opt_buttons["multi"] as Button).add_theme_stylebox_override("normal", UiStyle.box(Color(0.2, 0.6, 0.8) if multi else off_col, 18, 10))


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
