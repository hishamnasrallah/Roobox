class_name Prefabs
extends RefCounted
## Studio "MODELS" toolbox: ready-made builds made of normal parts.
## Each model is a list of parts relative to its bottom-center (y = 0).
## Placing a model adds all its parts as one group, so SELECT picks the
## whole thing and it can be moved, rotated, copied or ungrouped.

const MODELS: Array[Dictionary] = [
	{"id": "house", "label": "HOUSE"},
	{"id": "tower", "label": "TOWER"},
	{"id": "castle_wall", "label": "CASTLE WALL"},
	{"id": "bridge", "label": "BRIDGE"},
	{"id": "fence", "label": "FENCE"},
	{"id": "lamp", "label": "LAMP POST"},
	{"id": "pine", "label": "PINE TREE"},
	{"id": "oak", "label": "BIG TREE"},
	{"id": "bush", "label": "BUSH"},
	{"id": "rocks", "label": "ROCKS"},
	{"id": "table", "label": "TABLE"},
	{"id": "bed", "label": "BED"},
	{"id": "kart", "label": "KART"},
	{"id": "arch", "label": "ARCH"},
	{"id": "fountain", "label": "FOUNTAIN"},
	{"id": "watchtower", "label": "WATCHTOWER"},
	{"id": "campfire", "label": "CAMPFIRE"},
	{"id": "stall", "label": "MARKET STALL"},
	{"id": "flag", "label": "FLAG"},
	{"id": "obby_kit", "label": "OBBY KIT"},
]


static func label(id: String) -> String:
	for m in MODELS:
		if m["id"] == id:
			return m["label"]
	return id.to_upper()


static func _p(t: String, p: Vector3, s: Vector3, c: int, mat: String = "", extra: Dictionary = {}) -> Dictionary:
	var d := {"t": t, "p": [p.x, p.y, p.z], "s": [s.x, s.y, s.z], "r": 0, "c": c}
	if mat != "":
		d["mat"] = mat
	d.merge(extra, true)
	return d


## Parts of a model (relative positions, unrotated).
static func parts(id: String) -> Array:
	var out: Array = []
	match id:
		"house":
			var h := 4.0
			out.append(_p("block", Vector3(0, 0.25, 0), Vector3(8, 0.5, 8), 3, "planks"))
			out.append(_p("block", Vector3(0, h * 0.5 + 0.5, -3.5), Vector3(8, h, 1), 11, "brick"))
			out.append(_p("block", Vector3(-3.5, h * 0.5 + 0.5, 0), Vector3(1, h, 6), 11, "brick"))
			out.append(_p("block", Vector3(3.5, h * 0.5 + 0.5, 0), Vector3(1, h, 6), 11, "brick"))
			out.append(_p("block", Vector3(-2.5, h * 0.5 + 0.5, 3.5), Vector3(3, h, 1), 11, "brick"))
			out.append(_p("block", Vector3(2.5, h * 0.5 + 0.5, 3.5), Vector3(3, h, 1), 11, "brick"))
			out.append(_p("block", Vector3(0, h + 0.25, 3.5), Vector3(2, 1.5, 1), 11, "brick"))
			out.append(_p("block", Vector3(-3.5, 2.6, 0), Vector3(1.1, 1.4, 2), 8, "glass"))
			out.append(_p("block", Vector3(3.5, 2.6, 0), Vector3(1.1, 1.4, 2), 8, "glass"))
			out.append(_p("ramp", Vector3(-2.25, h + 1.75, 0), Vector3(4.5, 2.5, 9), 4, "", {"r": 2}))
			out.append(_p("ramp", Vector3(2.25, h + 1.75, 0), Vector3(4.5, 2.5, 9), 4))
		"tower":
			out.append(_p("cyl", Vector3(0, 5, 0), Vector3(5, 10, 5), 0, "cobble"))
			out.append(_p("cyl", Vector3(0, 10.5, 0), Vector3(6, 1, 6), 1, "stone"))
			out.append(_p("cone", Vector3(0, 13, 0), Vector3(6.4, 4, 6.4), 4))
			out.append(_p("block", Vector3(0, 1.5, 2.55), Vector3(1.6, 3, 0.2), 3, "planks"))
			out.append(_p("ladder", Vector3(0, 6, 3.1), Vector3(2, 9, 1), 3))
		"castle_wall":
			out.append(_p("block", Vector3(0, 2.5, 0), Vector3(12, 5, 2), 0, "cobble"))
			for i in 6:
				if i % 2 == 0:
					out.append(_p("block", Vector3(-5 + i * 2, 5.75, 0), Vector3(2, 1.5, 2), 0, "cobble"))
		"bridge":
			out.append(_p("block", Vector3(0, 0.25, 0), Vector3(3, 0.5, 12), 3, "planks"))
			for sx in [-1.0, 1.0]:
				out.append(_p("block", Vector3(sx * 1.4, 1.2, 0), Vector3(0.2, 0.2, 12), 3, "log"))
				for k in 4:
					out.append(_p("block", Vector3(sx * 1.4, 0.75, -4.5 + k * 3), Vector3(0.25, 1, 0.25), 3, "log"))
		"fence":
			for k in 4:
				out.append(_p("block", Vector3(-4.5 + k * 3, 0.75, 0), Vector3(0.3, 1.5, 0.3), 3, "log"))
			out.append(_p("block", Vector3(0, 0.6, 0), Vector3(9.5, 0.2, 0.15), 3, "planks"))
			out.append(_p("block", Vector3(0, 1.2, 0), Vector3(9.5, 0.2, 0.15), 3, "planks"))
		"lamp":
			out.append(_p("cyl", Vector3(0, 0.15, 0), Vector3(1, 0.3, 1), 1, "metal"))
			out.append(_p("cyl", Vector3(0, 2.4, 0), Vector3(0.3, 4.5, 0.3), 1, "metal"))
			out.append(_p("light", Vector3(0, 4.9, 0), Vector3.ONE, 6))
		"pine":
			out.append(_p("block", Vector3(0, 1.5, 0), Vector3(0.8, 3, 0.8), 3, "log"))
			out.append(_p("cone", Vector3(0, 3.5, 0), Vector3(4, 3, 4), 7, "leaves"))
			out.append(_p("cone", Vector3(0, 5.3, 0), Vector3(3, 2.6, 3), 7, "leaves"))
			out.append(_p("cone", Vector3(0, 6.9, 0), Vector3(2, 2.2, 2), 7, "leaves"))
		"oak":
			out.append(_p("block", Vector3(0, 2.5, 0), Vector3(1.2, 5, 1.2), 3, "log"))
			out.append(_p("block", Vector3(0, 6, 0), Vector3(6, 3, 6), 7, "leaves"))
			out.append(_p("block", Vector3(0, 8, 0), Vector3(4, 1.5, 4), 7, "leaves"))
			out.append(_p("block", Vector3(1.5, 4.2, 0), Vector3(2, 0.6, 0.6), 3, "log"))
		"bush":
			out.append(_p("ball", Vector3(0, 0.9, 0), Vector3(2, 1.8, 2), 7, "leaves"))
			out.append(_p("ball", Vector3(1.1, 0.7, 0.4), Vector3(1.4, 1.4, 1.4), 7, "leaves"))
			out.append(_p("ball", Vector3(-1, 0.6, -0.3), Vector3(1.2, 1.2, 1.2), 7, "leaves"))
		"rocks":
			out.append(_p("block", Vector3(0, 1, 0), Vector3(2.5, 2, 2.2), 1, "stone", {"ry": 20.0}))
			out.append(_p("block", Vector3(1.8, 0.6, 0.8), Vector3(1.4, 1.2, 1.4), 1, "stone", {"ry": 50.0}))
			out.append(_p("block", Vector3(-1.4, 0.4, 1), Vector3(1, 0.8, 1), 1, "basalt", {"ry": 35.0}))
		"table":
			out.append(_p("block", Vector3(0, 1.4, 0), Vector3(3, 0.2, 2), 3, "planks"))
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					out.append(_p("block", Vector3(sx * 1.3, 0.65, sz * 0.8), Vector3(0.2, 1.3, 0.2), 3, "log"))
			for sx in [-1.0, 1.0]:
				out.append(_p("block", Vector3(sx * 2.2, 0.8, 0), Vector3(1, 0.2, 1), 3, "planks"))
				out.append(_p("block", Vector3(sx * 2.2, 0.35, 0), Vector3(0.3, 0.7, 0.3), 3, "log"))
				out.append(_p("block", Vector3(sx * 2.65, 1.3, 0), Vector3(0.1, 1, 1), 3, "planks"))
		"bed":
			out.append(_p("block", Vector3(0, 0.4, 0), Vector3(2.2, 0.8, 4), 3, "planks"))
			out.append(_p("block", Vector3(0, 0.95, 0.3), Vector3(2, 0.3, 3.2), 4, "wool"))
			out.append(_p("block", Vector3(0, 1, -1.5), Vector3(1.6, 0.4, 0.8), 11, "wool"))
			out.append(_p("block", Vector3(0, 1.2, -2.05), Vector3(2.2, 1.6, 0.1), 3, "planks"))
		"kart":
			out.append(_p("block", Vector3(0, 0.7, 0), Vector3(2.2, 0.6, 3.6), 4))
			out.append(_p("block", Vector3(0, 1.3, 0.4), Vector3(1.4, 0.6, 1.2), 1))
			out.append(_p("block", Vector3(0, 1.4, -0.9), Vector3(1.6, 0.2, 0.6), 11, "glass"))
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					out.append(_p("block", Vector3(sx * 1.25, 0.45, sz * 1.2), Vector3(0.4, 0.9, 0.9), 1))
		"arch":
			out.append(_p("block", Vector3(-2.5, 2.5, 0), Vector3(1.5, 5, 1.5), 0, "stone"))
			out.append(_p("block", Vector3(2.5, 2.5, 0), Vector3(1.5, 5, 1.5), 0, "stone"))
			out.append(_p("block", Vector3(0, 5.5, 0), Vector3(7, 1, 1.5), 0, "stone"))
			out.append(_p("corner", Vector3(-1.25, 4.5, 0), Vector3(1, 1, 1.5), 0, "stone", {"r": 2}))
			out.append(_p("corner", Vector3(1.25, 4.5, 0), Vector3(1, 1, 1.5), 0, "stone", {"r": 3}))
		"fountain":
			out.append(_p("cyl", Vector3(0, 0.5, 0), Vector3(7, 1, 7), 0, "stone"))
			out.append(_p("water", Vector3(0, 1.3, 0), Vector3(5, 0.6, 5), 8))
			out.append(_p("cyl", Vector3(0, 2, 0), Vector3(1, 3, 1), 0, "stone"))
			out.append(_p("cyl", Vector3(0, 3.6, 0), Vector3(2.4, 0.3, 2.4), 0, "stone"))
			out.append(_p("sparkles", Vector3(0, 4.6, 0), Vector3(2, 1.5, 2), 8))
		"watchtower":
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					out.append(_p("block", Vector3(sx * 1.6, 3, sz * 1.6), Vector3(0.5, 6, 0.5), 3, "log"))
			out.append(_p("block", Vector3(0, 6.25, 0), Vector3(4.4, 0.5, 4.4), 3, "planks"))
			out.append(_p("block", Vector3(0, 7.2, -2.1), Vector3(4.4, 1.4, 0.2), 3, "planks"))
			out.append(_p("block", Vector3(-2.1, 7.2, 0), Vector3(0.2, 1.4, 4.4), 3, "planks"))
			out.append(_p("block", Vector3(2.1, 7.2, 0), Vector3(0.2, 1.4, 4.4), 3, "planks"))
			out.append(_p("ladder", Vector3(0, 3.4, 2.4), Vector3(2, 6.8, 1), 3))
			out.append(_p("ramp", Vector3(-1.2, 9, 0), Vector3(2.4, 1.2, 5), 4, "", {"r": 2}))
			out.append(_p("ramp", Vector3(1.2, 9, 0), Vector3(2.4, 1.2, 5), 4))
		"campfire":
			out.append(_p("block", Vector3(0, 0.2, 0), Vector3(2, 0.4, 0.4), 3, "log", {"ry": 30.0}))
			out.append(_p("block", Vector3(0, 0.2, 0), Vector3(2, 0.4, 0.4), 3, "log", {"ry": 150.0}))
			out.append(_p("fire", Vector3(0, 0.9, 0), Vector3(1.4, 1.4, 1.4), 5))
			for k in 6:
				var a := TAU * k / 6.0
				out.append(_p("block", Vector3(cos(a) * 1.3, 0.2, sin(a) * 1.3), Vector3(0.5, 0.4, 0.5), 1, "stone"))
		"stall":
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					out.append(_p("block", Vector3(sx * 1.8, 1.5, sz * 1.1), Vector3(0.25, 3, 0.25), 3, "log"))
			out.append(_p("block", Vector3(0, 1, 1.1), Vector3(3.8, 0.2, 1), 3, "planks"))
			out.append(_p("ramp", Vector3(0, 3.3, 0), Vector3(2.8, 0.6, 4.2), 4, "wool", {"r": 1}))
			out.append(_p("block", Vector3(-1, 1.4, 1.1), Vector3(0.6, 0.6, 0.6), 6))
			out.append(_p("block", Vector3(0.6, 1.4, 1.1), Vector3(0.6, 0.6, 0.6), 7))
		"flag":
			out.append(_p("cyl", Vector3(0, 3, 0), Vector3(0.25, 6, 0.25), 0, "metal"))
			out.append(_p("block", Vector3(1, 5.3, 0), Vector3(2, 1.2, 0.1), 4, "wool"))
			out.append(_p("ball", Vector3(0, 6.1, 0), Vector3(0.4, 0.4, 0.4), 6, "gold"))
		"obby_kit":
			out.append(_p("block", Vector3(0, 0.5, 0), Vector3(3, 1, 3), 2))
			out.append(_p("block", Vector3(0, 1.5, -4.5), Vector3(2, 1, 2), 8))
			out.append(_p("block", Vector3(2, 2.5, -8.5), Vector3(2, 1, 2), 6))
			out.append(_p("kill", Vector3(0, 0.5, -8.5), Vector3(4, 1, 2), 4))
			out.append(_p("block", Vector3(0, 3.5, -12.5), Vector3(1, 1, 4), 9))
			out.append(_p("checkpoint", Vector3(0, 4.5, -17), Vector3(4, 1, 4), 7))
	return out


## The model's parts placed at `at` (bottom-center), turned by yaw degrees.
static func placed(id: String, at: Vector3, yaw_deg: float, group: String) -> Array:
	var b := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	var out: Array = []
	for p: Dictionary in parts(id):
		var q: Dictionary = p.duplicate(true)
		var local := Level.pos(p)
		q["p"] = Level._arr(at + b * local)
		Level.set_yaw_deg(q, Level.yaw_deg(p) + yaw_deg)
		q["g"] = group
		out.append(q)
	return out


## A small level containing just this model (for its toolbox icon).
static func preview_level(id: String) -> Dictionary:
	return {"v": Level.VERSION, "name": id, "parts": placed(id, Vector3.ZERO, 0.0, "m")}
