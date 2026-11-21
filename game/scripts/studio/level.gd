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
	{"id": "cube", "label": "CUBE", "t": "block", "s": [1, 1, 1], "c": 2},
	{"id": "block", "label": "BLOCK", "t": "block", "s": [2, 2, 2], "c": 4},
	{"id": "half", "label": "HALF", "t": "block", "s": [2, 1, 2], "c": 0},
	{"id": "plate", "label": "PLATE", "t": "block", "s": [4, 1, 4], "c": 8},
	{"id": "floor", "label": "FLOOR", "t": "block", "s": [8, 1, 8], "c": 2},
	{"id": "beam", "label": "BEAM", "t": "block", "s": [1, 1, 6], "c": 5},
	{"id": "wall", "label": "WALL", "t": "block", "s": [6, 4, 1], "c": 11},
	{"id": "pillar", "label": "PILLAR", "t": "block", "s": [1, 6, 1], "c": 0},
	{"id": "ramp", "label": "RAMP", "t": "ramp", "s": [4, 2, 2], "c": 6},
	{"id": "stairs", "label": "STAIRS", "t": "stairs", "s": [2, 2, 4], "c": 0},
	{"id": "cone", "label": "CONE", "t": "cone", "s": [2, 2, 2], "c": 5},
	{"id": "ball", "label": "BALL", "t": "ball", "s": [2, 2, 2], "c": 9},
	{"id": "cyl", "label": "ROUND", "t": "cyl", "s": [2, 2, 2], "c": 10},
	{"id": "spawn", "label": "SPAWN", "t": "spawn", "s": [4, 1, 4], "c": 8},
	{"id": "checkpoint", "label": "CHECKPOINT", "t": "checkpoint", "s": [4, 1, 4], "c": 7},
	{"id": "kill", "label": "LAVA", "t": "kill", "s": [2, 1, 2], "c": 4},
	{"id": "spikes", "label": "SPIKES", "t": "spikes", "s": [2, 1, 2], "c": 1},
	{"id": "jumppad", "label": "JUMP PAD", "t": "jumppad", "s": [3, 1, 3], "c": 8},
	{"id": "speed", "label": "SPEED PAD", "t": "speed", "s": [3, 1, 3], "c": 6},
	{"id": "conveyor", "label": "CONVEYOR", "t": "conveyor", "s": [2, 1, 6], "c": 1},
	{"id": "teleport", "label": "TELEPORT", "t": "teleport", "s": [3, 1, 3], "c": 9},
	{"id": "water", "label": "WATER", "t": "water", "s": [4, 4, 4], "c": 8},
	{"id": "ladder", "label": "LADDER", "t": "ladder", "s": [2, 6, 1], "c": 3},
	{"id": "coin", "label": "COIN", "t": "coin", "s": [1, 1, 1], "c": 6},
	{"id": "light", "label": "LIGHT", "t": "light", "s": [1, 1, 1], "c": 6},
	{"id": "sign", "label": "SIGN", "t": "sign", "s": [4, 2, 1], "c": 3},
	{"id": "tree", "label": "TREE", "t": "tree", "s": [3, 6, 3], "c": 7},
	{"id": "finish", "label": "FINISH", "t": "finish", "s": [4, 1, 4], "c": 6},
]

const SPECIAL := ["spawn", "checkpoint", "kill", "jumppad", "coin", "finish", "spikes", "speed",
	"conveyor", "teleport", "water", "ladder", "light", "sign", "tree"]
const SOLID := ["block", "ramp", "ball", "cyl", "stairs", "cone"]
const ENVS: Array[String] = ["day", "sunset", "night", "space", "fog"]
const MAX_LIGHTS := 24

## Motion presets for solid parts: id -> label.
const MOTIONS: Array[String] = ["", "slide_x", "slide_z", "lift", "spin", "spin_fast"]
const MOTION_LABELS: Dictionary = {
	"": "NONE", "slide_x": "SLIDE X", "slide_z": "SLIDE Z", "lift": "LIFT",
	"spin": "SPIN", "spin_fast": "SPIN FAST",
}
const MAX_SCRIPT := 20000


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
	var env := str(d.get("env", "day"))
	if env in ENVS and env != "day":
		out["env"] = env
	var script_text := str(d.get("script", ""))
	if script_text != "":
		out["script"] = script_text.substr(0, MAX_SCRIPT)
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
	var out := {"t": t, "p": _arr(p), "s": _arr(s), "r": clampi(int(item.get("r", 0)), 0, 3),
		"c": clampi(int(item.get("c", 0)), 0, COLORS.size() - 1)}
	var n := clean_name(str(item.get("n", "")))
	if n != "":
		out["n"] = n
	var m := str(item.get("m", ""))
	if m != "" and m in MOTIONS and t in SOLID:
		out["m"] = m
	var mat := str(item.get("mat", "plastic"))
	if mat != "plastic" and Materials.exists(mat):
		out["mat"] = mat
	if t == "sign":
		out["txt"] = str(item.get("txt", "Hello!")).strip_edges().substr(0, 60)
	return out


## Part names (used by scripts): letters, digits, _ and -, max 24.
static func clean_name(text: String) -> String:
	var out := ""
	for ch in text.strip_edges():
		if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "_" or ch == "-":
			out += ch
	return out.substr(0, 24)


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
		"cone":
			return "cone"
		"cyl", "checkpoint", "jumppad", "spawn", "finish":
			return "cyl" if t == "cyl" else "box"
	return "box"


## Builds a playable world from a level under `parent`.
## Static solid parts are batched; moving/named parts get their own body
## (so scripts can change them); special parts become gameplay nodes.
## Returns {by_index: {i: Node3D}, by_name: {name: [Node3D]}}.
static func build_play(parent: Node3D, level: Dictionary) -> Dictionary:
	var b := WorldBuilder.new(parent)
	var course: String = level.get("name", "Custom Game")
	var reg := {"by_index": {}, "by_name": {}}
	var teleports: Array = []
	var lights := 0
	var parts: Array = level["parts"]
	for i in parts.size():
		var p: Dictionary = parts[i]
		var t: String = p["t"]
		var at := pos(p)
		var sz := size(p)
		var rot := Vector3(0, yaw(p), 0)
		var col: Color = COLORS[int(p["c"])]
		if (t in SOLID or t == "kill") and (p.has("m") or p.has("n")):
			var node := _dynamic_part(parent, b, p)
			node.set_meta("part_index", i)
			(reg["by_index"] as Dictionary)[i] = node
			if p.has("n"):
				var byn: Dictionary = reg["by_name"]
				if not byn.has(p["n"]):
					byn[p["n"]] = []
				(byn[p["n"]] as Array).append(node)
			continue
		var mat: String = p.get("mat", "plastic")
		match t:
			"block", "ramp", "ball", "cyl", "cone":
				b.part(part_shape(t), at, sz, mat_color(mat, col), true, mat_kind(mat, col), rot)
			"stairs":
				for st: Array in stair_steps(sz):
					b.part("box", at + Basis.from_euler(rot) * (st[0] as Vector3), st[1], mat_color(mat, col), true, mat_kind(mat, col), rot)
			"spawn":
				b.part("box", at, sz, col, true, "tiled", rot)
			"checkpoint":
				b.part("box", at, sz, col.darkened(0.2), true, "tiled", rot)
				var cp := Checkpoint.new()
				cp.position = at + Vector3(0, sz.y * 0.5, 0)
				parent.add_child(cp)
			"kill", "spikes":
				if t == "kill":
					var mi := MeshInstance3D.new()
					var m := BoxMesh.new()
					m.size = sz
					mi.mesh = m
					mi.material_override = Fx.glow_material(Color(1.0, 0.3, 0.1), 2.0)
					mi.position = at
					mi.rotation = rot
					parent.add_child(mi)
				else:
					b.part("box", at - Vector3(0, sz.y * 0.35, 0), Vector3(sz.x, sz.y * 0.3, sz.z), col, true, "plain", rot)
					_spikes(parent, at, sz, rot)
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
			"speed", "conveyor", "teleport":
				var top_col := {"speed": Color(1.0, 0.85, 0.2), "conveyor": Color(0.3, 0.3, 0.35), "teleport": Color(0.7, 0.4, 1.0)}[t] as Color
				b.part("box", at, sz, Color(0.2, 0.22, 0.28), true, "plain", rot)
				var glow := MeshInstance3D.new()
				var gm := BoxMesh.new()
				gm.size = Vector3(sz.x * 0.9, 0.06, sz.z * 0.9)
				glow.mesh = gm
				glow.material_override = Fx.glow_material(top_col, 1.4 if t != "conveyor" else 0.2)
				glow.position = at + Vector3(0, sz.y * 0.5 + 0.03, 0)
				glow.rotation = rot
				parent.add_child(glow)
				if t == "conveyor":
					for k in int(maxf(sz.z / 1.5, 1.0)):
						var arrow := MeshInstance3D.new()
						var am := BoxMesh.new()
						am.size = Vector3(sz.x * 0.5, 0.08, 0.3)
						arrow.mesh = am
						arrow.material_override = Fx.glow_material(Color(1.0, 0.85, 0.2), 1.2)
						arrow.position = at + Basis.from_euler(rot) * Vector3(0, sz.y * 0.5 + 0.06, sz.z * 0.5 - 0.75 - k * 1.5)
						arrow.rotation = rot
						parent.add_child(arrow)
				var vol := PartVolume.new()
				vol.kind = t
				vol.position = at + Vector3(0, sz.y * 0.5 + 0.6, 0)
				vol.rotation = rot
				vol.setup(Vector3(sz.x, 1.4, sz.z))
				parent.add_child(vol)
				if t == "teleport":
					vol.set_meta("tp_name", str(p.get("n", "")))
					teleports.append(vol)
			"water":
				var wm := MeshInstance3D.new()
				var wbox := BoxMesh.new()
				wbox.size = sz
				wm.mesh = wbox
				var wmat := StandardMaterial3D.new()
				wmat.albedo_color = Color(0.2, 0.5, 0.95, 0.45)
				wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				wmat.roughness = 0.05
				wmat.cull_mode = BaseMaterial3D.CULL_DISABLED
				wm.material_override = wmat
				wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				wm.position = at
				wm.rotation = rot
				parent.add_child(wm)
				var wv := PartVolume.new()
				wv.kind = "water"
				wv.position = at
				wv.rotation = rot
				wv.setup(sz)
				parent.add_child(wv)
			"ladder":
				parent.add_child(_ladder_visual(at, sz, rot))
				var lv := PartVolume.new()
				lv.kind = "ladder"
				lv.position = at
				lv.rotation = rot
				lv.setup(sz + Vector3(0.2, 0.4, 1.2))
				parent.add_child(lv)
			"light":
				if lights < MAX_LIGHTS:
					lights += 1
					var bulb := MeshInstance3D.new()
					var sm := SphereMesh.new()
					sm.radius = 0.3
					sm.height = 0.6
					bulb.mesh = sm
					bulb.material_override = Fx.glow_material(col, 3.0)
					bulb.position = at
					parent.add_child(bulb)
					var ol := OmniLight3D.new()
					ol.light_color = col
					ol.light_energy = 2.0
					ol.omni_range = 12.0
					ol.position = at
					parent.add_child(ol)
			"sign":
				b.part("box", at, sz, Color(0.72, 0.53, 0.32), true, "mat:planks", rot)
				parent.add_child(_sign_label(str(p.get("txt", "")), at, sz, rot))
			"tree":
				b.part("box", at + Vector3(0, -sz.y * 0.2, 0), Vector3(sz.x * 0.25, sz.y * 0.6, sz.z * 0.25), Color.WHITE, true, "mat:log", rot)
				b.part("box", at + Vector3(0, sz.y * 0.25, 0), Vector3(sz.x, sz.y * 0.5, sz.z), Color.WHITE, true, "mat:leaves", rot)
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
	# Pair teleporters that share a name (each sends you to the next one).
	var groups: Dictionary = {}
	for tp: PartVolume in teleports:
		var n: String = tp.get_meta("tp_name")
		if n == "":
			continue
		if not groups.has(n):
			groups[n] = []
		(groups[n] as Array).append(tp)
	for n: String in groups:
		var g: Array = groups[n]
		if g.size() < 2:
			continue
		for i in g.size():
			var nxt: PartVolume = g[(i + 1) % g.size()]
			(g[i] as PartVolume).target = nxt.position + Vector3(0, 0.6, 0) + Basis.from_euler(nxt.rotation) * Vector3(0, 0, -2.0)
	b.build()
	return reg


## A solid part as its own physics body (moving, spinning or scriptable).
static func _dynamic_part(parent: Node3D, b: WorldBuilder, p: Dictionary) -> Node3D:
	var t: String = p["t"]
	var sz := size(p)
	var shape := part_shape(t)
	var m: String = p.get("m", "")
	var body: Node3D
	match m:
		"slide_x", "slide_z", "lift":
			var mp := MovingPlatform.new()
			mp.travel = {"slide_x": Vector3(8, 0, 0), "slide_z": Vector3(0, 0, 8), "lift": Vector3(0, 6, 0)}[m]
			mp.period = 4.0
			body = mp
		"spin", "spin_fast":
			var sp := SpinningPart.new()
			sp.speed = 1.2 if m == "spin" else 3.0
			body = sp
		_:
			var sb := StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0
			body = sb
	body.position = pos(p)
	body.rotation.y = yaw(p)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = b.unit_mesh(shape)
	mi.scale = sz
	mi.material_override = Materials.material(str(p.get("mat", "plastic")), COLORS[int(p["c"])]) if p.get("mat", "plastic") != "plastic" else Fx.block_material(COLORS[int(p["c"])])
	if t == "kill":
		mi.material_override = Fx.glow_material(Color(1.0, 0.3, 0.1), 2.0)
		var kz := KillZone.new()
		kz.setup(sz + Vector3(0.1, 0.25, 0.1))
		body.add_child(kz)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	cs.shape = b.collision_shape(shape, sz)
	body.add_child(cs)
	parent.add_child(body)
	return body


## Batch kind for a material (WorldBuilder).
static func mat_kind(mat: String, col: Color) -> String:
	if mat == "plastic" or not Materials.exists(mat):
		return "tiled"
	if mat == "neon":
		return "neon|" + col.to_html()
	return "mat:" + mat


## Instance color for a material: tinted materials use the part color.
static func mat_color(mat: String, col: Color) -> Color:
	return col if mat == "plastic" or Materials.is_tinted(mat) else Color.WHITE


## Stair steps inside a part of size s, rising toward local -Z:
## [[local_center, size], ...]
static func stair_steps(s: Vector3) -> Array:
	var out: Array = []
	var n := 4
	for k in n:
		var h := s.y * (k + 1) / n
		var d := s.z / n
		out.append([Vector3(0, -s.y * 0.5 + h * 0.5, s.z * 0.5 - d * (k + 0.5)), Vector3(s.x, h, d)])
	return out


static func _spikes(parent: Node3D, at: Vector3, sz: Vector3, rot: Vector3) -> void:
	var nx := maxi(int(sz.x), 1)
	var nz := maxi(int(sz.z), 1)
	var mat := Fx.metal_material(Color(0.75, 0.75, 0.8), 0.0)
	for ix in nx:
		for iz in nz:
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0
			cm.bottom_radius = 0.35
			cm.height = sz.y * 0.8
			mi.mesh = cm
			mi.material_override = mat
			var local := Vector3(-sz.x * 0.5 + (ix + 0.5) * sz.x / nx, sz.y * 0.1, -sz.z * 0.5 + (iz + 0.5) * sz.z / nz)
			mi.position = at + Basis.from_euler(rot) * local
			parent.add_child(mi)


static func _ladder_visual(at: Vector3, sz: Vector3, rot: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = at
	root.rotation = rot
	var wood := Materials.material("log", Color.WHITE)
	for sx in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.15, sz.y, 0.15)
		rail.mesh = rm
		rail.material_override = wood
		rail.position = Vector3(sx * (sz.x * 0.5 - 0.1), 0, 0)
		root.add_child(rail)
	var rungs := int(sz.y / 0.5)
	for i in rungs:
		var rung := MeshInstance3D.new()
		var rgm := BoxMesh.new()
		rgm.size = Vector3(sz.x, 0.08, 0.12)
		rung.mesh = rgm
		rung.material_override = wood
		rung.position = Vector3(0, -sz.y * 0.5 + 0.25 + i * 0.5, 0)
		root.add_child(rung)
	return root


static func _sign_label(text: String, at: Vector3, sz: Vector3, rot: Vector3) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 72
	l.outline_size = 12
	l.width = sz.x * 180.0
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.modulate = Color(0.15, 0.1, 0.05)
	l.outline_modulate = Color(1, 0.95, 0.85, 0.6)
	l.pixel_size = 0.006
	l.position = at + Basis.from_euler(rot) * Vector3(0, 0, -sz.z * 0.5 - 0.02)
	l.rotation = rot
	return l


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
