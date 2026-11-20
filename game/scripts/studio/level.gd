class_name Level
extends RefCounted
## User-made game ("creation") format + helpers shared by Studio and the
## UGC experience. A level is plain JSON-friendly data:
##   {v, name, parts: [{t, p:[x,y,z], s:[x,y,z], r:0..3, c:color_index}]}
## p = center, s = size (before rotation), r = yaw in 90 degree steps.

const VERSION := 1
const MAX_PARTS := 2500
const GRID := 1.0

const COLORS: Array[Color] = [
	Color(0.82, 0.84, 0.9), Color(0.3, 0.32, 0.38), Color(0.42, 0.76, 0.34), Color(0.55, 0.38, 0.25),
	Color(1.0, 0.35, 0.35), Color(1.0, 0.62, 0.2), Color(1.0, 0.85, 0.25), Color(0.35, 0.8, 0.4),
	Color(0.3, 0.6, 1.0), Color(0.65, 0.45, 1.0), Color(1.0, 0.45, 0.75), Color(0.97, 0.97, 1.0),
]

## Toolbox presets: {id, label, t (type), s (size), c (default color)}.
const PRESETS: Array[Dictionary] = [
	{"id": "block", "label": "BLOCK", "t": "block", "s": [2, 2, 2], "c": 4},
	{"id": "plate", "label": "PLATE", "t": "block", "s": [4, 1, 4], "c": 8},
	{"id": "floor", "label": "FLOOR", "t": "block", "s": [8, 1, 8], "c": 2},
	{"id": "beam", "label": "BEAM", "t": "block", "s": [1, 1, 6], "c": 5},
	{"id": "wall", "label": "WALL", "t": "block", "s": [6, 4, 1], "c": 11},
	{"id": "pillar", "label": "PILLAR", "t": "block", "s": [1, 6, 1], "c": 0},
	{"id": "ramp", "label": "RAMP", "t": "ramp", "s": [4, 2, 2], "c": 6},
	{"id": "ball", "label": "BALL", "t": "ball", "s": [2, 2, 2], "c": 9},
	{"id": "cyl", "label": "ROUND", "t": "cyl", "s": [2, 2, 2], "c": 10},
	{"id": "spawn", "label": "SPAWN", "t": "spawn", "s": [4, 1, 4], "c": 8},
	{"id": "checkpoint", "label": "CHECKPOINT", "t": "checkpoint", "s": [4, 1, 4], "c": 7},
	{"id": "kill", "label": "LAVA", "t": "kill", "s": [2, 1, 2], "c": 4},
	{"id": "jumppad", "label": "JUMP PAD", "t": "jumppad", "s": [3, 1, 3], "c": 8},
	{"id": "coin", "label": "COIN", "t": "coin", "s": [1, 1, 1], "c": 6},
	{"id": "finish", "label": "FINISH", "t": "finish", "s": [4, 1, 4], "c": 6},
]

const SPECIAL := ["spawn", "checkpoint", "kill", "jumppad", "coin", "finish"]
const SOLID := ["block", "ramp", "ball", "cyl"]


static func new_level(level_name: String = "My Game") -> Dictionary:
	return {
		"v": VERSION,
		"name": level_name,
		"parts": [
			{"t": "block", "p": [0, -0.5, 0], "s": [64, 1, 64], "r": 0, "c": 0},
			{"t": "spawn", "p": [0, 0.5, 0], "s": [4, 1, 4], "r": 0, "c": 8},
		],
	}


static func preset(id: String) -> Dictionary:
	for p in PRESETS:
		if p["id"] == id:
			return p
	return PRESETS[0]


## Validates/cleans data coming from disk or the network.
static func sanitize(data: Variant) -> Dictionary:
	var out := new_level()
	if not (data is Dictionary):
		return out
	var d: Dictionary = data
	out["name"] = str(d.get("name", "Untitled")).strip_edges().substr(0, 32)
	var parts: Array = []
	var raw: Variant = d.get("parts", [])
	if raw is Array:
		for item in raw:
			if parts.size() >= MAX_PARTS:
				break
			if not (item is Dictionary):
				continue
			var p := _clean_part(item)
			if not p.is_empty():
				parts.append(p)
	if not parts.is_empty():
		out["parts"] = parts
	return out


static func _clean_part(item: Dictionary) -> Dictionary:
	var t := str(item.get("t", ""))
	if not (t in SOLID or t in SPECIAL):
		return {}
	var p := _vec(item.get("p"), Vector3.ZERO)
	var s := _vec(item.get("s"), Vector3.ONE)
	if not p.is_finite() or p.length() > 2000.0:
		return {}
	s = s.clamp(Vector3.ONE * 0.25, Vector3.ONE * 128.0)
	return {"t": t, "p": _arr(p), "s": _arr(s), "r": clampi(int(item.get("r", 0)), 0, 3),
		"c": clampi(int(item.get("c", 0)), 0, COLORS.size() - 1)}


static func _vec(v: Variant, fallback: Vector3) -> Vector3:
	if v is Array and (v as Array).size() == 3:
		var a: Array = v
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return fallback


static func _arr(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]


static func pos(part: Dictionary) -> Vector3:
	return _vec(part["p"], Vector3.ZERO)


static func size(part: Dictionary) -> Vector3:
	return _vec(part["s"], Vector3.ONE)


static func yaw(part: Dictionary) -> float:
	return int(part.get("r", 0)) * PI * 0.5


## Size along world axes after rotation (x/z swap for 90/270 degrees).
static func world_size(s: Vector3, r: int) -> Vector3:
	return Vector3(s.z, s.y, s.x) if r % 2 == 1 else s


static func spawn_point(level: Dictionary) -> Vector3:
	for p: Dictionary in level["parts"]:
		if p["t"] == "spawn":
			var sp := pos(p)
			return sp + Vector3(0, size(p).y * 0.5 + 0.6, 0)
	return Vector3(0, 2, 0)


## Snap a center coordinate so the part edges sit on the grid.
static func snap_center(v: float, s: float) -> float:
	return roundf((v - s * 0.5) / GRID) * GRID + s * 0.5


static func part_shape(t: String) -> String:
	match t:
		"ramp":
			return "ramp"
		"ball":
			return "ball"
		"cyl", "checkpoint", "jumppad", "spawn", "finish":
			return "cyl" if t == "cyl" else "box"
	return "box"


## Builds a playable world from a level under `parent`.
## Solid parts are batched; special parts become gameplay nodes.
static func build_play(parent: Node3D, level: Dictionary) -> void:
	var b := WorldBuilder.new(parent)
	var course: String = level.get("name", "Custom Game")
	for p: Dictionary in level["parts"]:
		var t: String = p["t"]
		var at := pos(p)
		var sz := size(p)
		var rot := Vector3(0, yaw(p), 0)
		var col: Color = COLORS[int(p["c"])]
		match t:
			"block", "ramp", "ball", "cyl":
				b.part(part_shape(t), at, sz, col, true, "tiled", rot)
			"spawn":
				b.part("box", at, sz, col, true, "tiled", rot)
			"checkpoint":
				b.part("box", at, sz, col.darkened(0.2), true, "tiled", rot)
				var cp := Checkpoint.new()
				cp.position = at + Vector3(0, sz.y * 0.5, 0)
				parent.add_child(cp)
			"kill":
				var mi := MeshInstance3D.new()
				var m := BoxMesh.new()
				m.size = sz
				mi.mesh = m
				mi.material_override = Fx.glow_material(Color(1.0, 0.3, 0.1), 2.0)
				mi.position = at
				mi.rotation = rot
				parent.add_child(mi)
				b.part("box", at - Vector3(0, 0.05, 0), sz - Vector3(0, 0.1, 0), col, true, "plain", rot)
				var kz := KillZone.new()
				kz.position = at
				kz.rotation = rot
				kz.setup(sz + Vector3(0.1, 0.25, 0.1))
				parent.add_child(kz)
			"jumppad":
				b.part("box", at, sz, Color(0.2, 0.22, 0.3), true, "plain", rot)
				var jp := JumpPad.new()
				jp.color = col
				jp.position = at + Vector3(0, sz.y * 0.5, 0)
				parent.add_child(jp)
			"coin":
				var c := Coin.new()
				c.position = at
				parent.add_child(c)
			"finish":
				b.part("box", at, sz, col, true, "tiled", rot)
				var fl := FinishLine.new()
				fl.course_name = course
				fl.position = at + Vector3(0, sz.y * 0.5, 0)
				parent.add_child(fl)
	b.build()


# ------------------------------------------------------------ storage ---

const DIR := "user://creations"


static func list_saved() -> Array:
	var out: Array = []
	DirAccess.make_dir_recursive_absolute(DIR)
	var d := DirAccess.open(DIR)
	if d == null:
		return out
	for f in d.get_files():
		if not f.ends_with(".json"):
			continue
		var slot := f.trim_suffix(".json")
		var lvl := load_slot(slot)
		out.append({"slot": slot, "name": lvl["name"], "parts": (lvl["parts"] as Array).size(),
			"modified": FileAccess.get_modified_time(DIR + "/" + f)})
	out.sort_custom(func(a: Dictionary, b2: Dictionary) -> bool: return int(a["modified"]) > int(b2["modified"]))
	return out


static func new_slot() -> String:
	return "g" + Crypto.new().generate_random_bytes(6).hex_encode()


static func save_slot(slot: String, level: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open("%s/%s.json" % [DIR, slot], FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(level))
	return true


static func load_slot(slot: String) -> Dictionary:
	var path := "%s/%s.json" % [DIR, slot]
	if not FileAccess.file_exists(path):
		return new_level()
	return sanitize(JSON.parse_string(FileAccess.get_file_as_string(path)))


static func delete_slot(slot: String) -> void:
	DirAccess.remove_absolute("%s/%s.json" % [DIR, slot])
