class_name LevelPreview
extends RefCounted
## Builds a visual-only copy of a level (no physics, no gameplay nodes)
## for thumbnails and icons, and picks a good camera shot for it.


## Builds the level under `parent` and returns a camera shot:
## {target: Vector3, eye: Vector3}
static func build(parent: Node3D, level: Dictionary) -> Dictionary:
	var b := WorldBuilder.new(parent)
	var parts: Array = level.get("parts", [])
	var spawn := Level.spawn_point(level)
	var box := AABB()
	var have_box := false
	var near := AABB()
	var have_near := false
	for p: Dictionary in parts:
		_add(parent, b, p)
		var pa := Level.part_aabb(p)
		var big := pa.size.x * pa.size.z > 1500.0
		if big:
			continue
		if have_box:
			box = box.merge(pa)
		else:
			box = pa
			have_box = true
		if pa.get_center().distance_to(spawn) < 42.0:
			if have_near:
				near = near.merge(pa)
			else:
				near = pa
				have_near = true
	b.build()
	if not have_box:
		box = AABB(spawn - Vector3(8, 4, 8), Vector3(16, 8, 16))
	return shot(box, near if have_near else box, spawn)


## Camera framing: whole map when it is compact, otherwise a hero shot
## from behind the spawn looking along the course.
static func shot(box: AABB, near: AABB, spawn: Vector3) -> Dictionary:
	var radius := box.size.length() * 0.5
	if radius <= 34.0:
		var c := box.get_center()
		var dir := Vector3(0.75, 0.62, 0.95).normalized()
		return {"target": c, "eye": c + dir * maxf(radius * 1.9, 5.0)}
	var toward := box.get_center() - spawn
	toward.y = 0.0
	if toward.length() < 1.0:
		toward = Vector3(0, 0, -1)
	toward = toward.normalized()
	var side := toward.cross(Vector3.UP)
	var target := near.get_center().lerp(spawn + toward * 14.0, 0.5)
	var nr := clampf(near.size.length() * 0.5, 14.0, 40.0)
	var eye := target - toward * nr * 1.25 + side * nr * 0.45 + Vector3.UP * nr * 0.8
	return {"target": target, "eye": eye}


static func _add(parent: Node3D, b: WorldBuilder, p: Dictionary) -> void:
	var t: String = p["t"]
	var at := Level.pos(p)
	var sz := Level.size(p)
	var rot := Vector3(0, Level.yaw(p), 0)
	var col: Color = Level.COLORS[clampi(int(p.get("c", 0)), 0, Level.COLORS.size() - 1)]
	var mat: String = p.get("mat", "plastic")
	match t:
		"block", "ramp", "ball", "cyl", "cone", "corner":
			if p.has("a"):
				var mi := MeshInstance3D.new()
				mi.mesh = b.unit_mesh(Level.part_shape(t))
				mi.scale = sz
				mi.position = at
				mi.rotation = rot
				mi.material_override = Level.part_material(p)
				parent.add_child(mi)
			else:
				b.part(Level.part_shape(t), at, sz, Level.mat_color(mat, col), false, Level.mat_kind(mat, col), rot)
		"stairs":
			for st: Array in Level.stair_steps(sz):
				b.part("box", at + Basis.from_euler(rot) * (st[0] as Vector3), st[1], Level.mat_color(mat, col), false, Level.mat_kind(mat, col), rot)
		"spawn", "checkpoint", "finish":
			b.part("box", at, sz, col, false, "tiled", rot)
		"kill":
			b.part("box", at, sz, Color(1.0, 0.4, 0.1), false, "neon|" + Color(1.0, 0.4, 0.1).to_html(), rot)
		"spikes":
			b.part("box", at - Vector3(0, sz.y * 0.35, 0), Vector3(sz.x, sz.y * 0.3, sz.z), col, false, "plain", rot)
			b.part("cone", at + Vector3(0, sz.y * 0.1, 0), Vector3(sz.x * 0.6, sz.y * 0.8, sz.z * 0.6), Color(0.75, 0.75, 0.8), false, "plain", rot)
		"jumppad", "speed", "conveyor", "teleport":
			var top := {"jumppad": col, "speed": Color(1.0, 0.85, 0.2), "conveyor": Color(0.3, 0.3, 0.35), "teleport": Color(0.7, 0.4, 1.0)}[t] as Color
			b.part("box", at, sz, Color(0.2, 0.22, 0.28), false, "plain", rot)
			b.part("box", at + Vector3(0, sz.y * 0.5 + 0.03, 0), Vector3(sz.x * 0.9, 0.06, sz.z * 0.9), top, false, "neon|" + top.to_html(), rot)
		"water":
			var wm := MeshInstance3D.new()
			var wbox := BoxMesh.new()
			wbox.size = sz
			wm.mesh = wbox
			var wmat := StandardMaterial3D.new()
			wmat.albedo_color = Color(0.2, 0.5, 0.95, 0.5)
			wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			wmat.roughness = 0.05
			wm.material_override = wmat
			wm.position = at
			wm.rotation = rot
			parent.add_child(wm)
		"ladder":
			parent.add_child(Level._ladder_visual(at, sz, rot))
		"truss":
			Level.truss_beams(b, at, sz, rot, col)
		"light":
			b.part("ball", at, Vector3.ONE * 0.6, col, false, "neon|" + col.to_html(), rot)
		"speedcoil", "gravitycoil":
			var gc := Color(1.0, 0.3, 0.3) if t == "speedcoil" else Color(0.35, 0.6, 1.0)
			b.part("cyl", at, Vector3(0.8, 1.2, 0.8), gc, false, "neon|" + gc.to_html(), rot)
		"fire", "smoke", "sparkles":
			var c2 := Color(1.0, 0.5, 0.15) if t == "fire" else (Color(0.6, 0.6, 0.62) if t == "smoke" else col)
			b.part("cone", at, sz * Vector3(0.5, 0.8, 0.5), c2, false, "neon|" + c2.to_html() if t != "smoke" else "plain", rot)
		"sign":
			b.part("box", at, sz, Color(0.72, 0.53, 0.32), false, "mat:planks", rot)
		"tree":
			b.part("box", at + Vector3(0, -sz.y * 0.2, 0), Vector3(sz.x * 0.25, sz.y * 0.6, sz.z * 0.25), Color.WHITE, false, "mat:log", rot)
			b.part("box", at + Vector3(0, sz.y * 0.25, 0), Vector3(sz.x, sz.y * 0.5, sz.z), Color.WHITE, false, "mat:leaves", rot)
		"coin":
			b.part("cyl", at, Vector3(0.9, 0.2, 0.9), Color(1.0, 0.82, 0.2), false, "neon|" + Color(1.0, 0.82, 0.2).to_html(), Vector3(PI * 0.5, 0, 0))
