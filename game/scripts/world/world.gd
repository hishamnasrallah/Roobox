class_name World
extends Node3D
## The hub world: a big island with a spawn plaza and four zones.
##   North: Obby Land (course over the ocean)
##   East : Sky Tower (60m spiral climb)
##   West : Playground (trampolines, pyramid, ramp + slide, maze)
##   South: Village (houses, street lamps, lake + bridge)
## Static geometry is batched through WorldBuilder for mobile performance.

const PALETTE: Array[Color] = [
	Color(1.0, 0.35, 0.35), Color(1.0, 0.62, 0.2), Color(1.0, 0.85, 0.25),
	Color(0.35, 0.8, 0.4), Color(0.3, 0.6, 1.0), Color(0.65, 0.45, 1.0),
	Color(1.0, 0.45, 0.75),
]
const GRASS := Color(0.42, 0.76, 0.34)
const GRASS_DARK := Color(0.34, 0.66, 0.28)
const DIRT := Color(0.55, 0.38, 0.25)
const SAND := Color(0.93, 0.85, 0.6)
const STONE := Color(0.82, 0.84, 0.9)
const ROAD := Color(0.36, 0.38, 0.44)
const WOOD := Color(0.62, 0.44, 0.27)
const LEAVES := Color(0.3, 0.68, 0.3)
const YELLOW := Color(1.0, 0.85, 0.3)

const ISLAND_HALF := 160.0
const OBBY_O := Vector3(0, 0, -178)
const TOWER_O := Vector3(110, 0, 0)
const VILLAGE_O := Vector3(0, 0, 100)

var spawn_point: Vector3 = Vector3(0, 0.5, 12)
var b: WorldBuilder
var _rng := RandomNumberGenerator.new()
var _mat_cache: Dictionary = {}


func _ready() -> void:
	_rng.seed = 20261120
	b = WorldBuilder.new(self)
	_build_island()
	_build_plaza()
	_build_roads()
	_build_obby(OBBY_O)
	_build_tower(TOWER_O)
	_build_playground()
	_build_village(VILLAGE_O)
	_build_hills()
	_build_forest()
	_build_scatter()
	_build_scenery()
	b.build()


# ============================================================= helpers ===

func block(pos: Vector3, size: Vector3, color: Color, kind: String = "tiled",
		rot: Vector3 = Vector3.ZERO) -> void:
	b.box(pos, size, color, true, kind, rot)


## Solid box placed by the center of its TOP face.
func platform(top_center: Vector3, size: Vector3, color: Color, kind: String = "tiled") -> void:
	b.box(top_center - Vector3(0, size.y * 0.5, 0), size, color, true, kind)


func decor(pos: Vector3, size: Vector3, color: Color, kind: String = "decor",
		rot: Vector3 = Vector3.ZERO) -> void:
	b.box(pos, size, color, false, kind, rot)


func coin(pos: Vector3) -> void:
	var c := Coin.new()
	c.position = pos
	add_child(c)


func checkpoint(pos: Vector3, course: String = "") -> void:
	var cp := Checkpoint.new()
	cp.course_name = course
	cp.position = pos
	add_child(cp)


func label(pos: Vector3, text: String, color: Color, font_size: int = 120) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = font_size
	l.outline_size = maxi(12, font_size / 5)
	l.modulate = color
	l.outline_modulate = Color(0.06, 0.07, 0.15)
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.position = pos
	add_child(l)


func teleporter(pos: Vector3, target: Vector3, title: String, color: Color) -> void:
	var t := Teleporter.new()
	t.target = target
	t.title = title
	t.color = color
	t.position = pos
	add_child(t)


func glow_box(pos: Vector3, size: Vector3, color: Color, energy: float = 1.6) -> void:
	var key := "%s|%.2f" % [color.to_html(), energy]
	if not _mat_cache.has(key):
		_mat_cache[key] = Fx.glow_material(color, energy)
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = _mat_cache[key] as Material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	add_child(mi)


func tree(pos: Vector3, s: float = 1.0, pine: bool = false) -> void:
	var trunk := Color(0.45, 0.3, 0.18)
	block(pos + Vector3(0, 1.3 * s, 0), Vector3(0.7, 2.6, 0.7) * s, trunk, "plain")
	var leaf := LEAVES.lerp(GRASS_DARK, _rng.randf()).lightened(_rng.randf_range(-0.05, 0.1))
	if pine:
		block(pos + Vector3(0, 3.0 * s, 0), Vector3(3.4, 1.0, 3.4) * s, leaf.darkened(0.15), "plain")
		block(pos + Vector3(0, 4.0 * s, 0), Vector3(2.6, 1.0, 2.6) * s, leaf.darkened(0.1), "plain")
		block(pos + Vector3(0, 5.0 * s, 0), Vector3(1.7, 1.0, 1.7) * s, leaf.darkened(0.05), "plain")
		block(pos + Vector3(0, 5.9 * s, 0), Vector3(0.8, 0.8, 0.8) * s, leaf, "plain")
	else:
		block(pos + Vector3(0, 3.2 * s, 0), Vector3(3.2, 1.8, 3.2) * s, leaf, "plain")
		block(pos + Vector3(0, 4.6 * s, 0), Vector3(2.1, 1.2, 2.1) * s, leaf.lightened(0.08), "plain")


func _blocked(x: float, z: float) -> bool:
	if absf(x) > ISLAND_HALF - 8.0 or absf(z) > ISLAND_HALF - 8.0:
		return true
	if Vector2(x, z).length() < 70.0:
		return true
	if absf(x) < 9.0 or absf(z) < 9.0:
		return true # roads
	if Vector2(x - TOWER_O.x, z - TOWER_O.z).length() < 26.0:
		return true
	if x > -158.0 and x < -60.0 and z > -60.0 and z < 45.0:
		return true # playground
	if x > -32.0 and x < 72.0 and z > 40.0 and z < 152.0:
		return true # village
	for h: Vector3 in _hill_centers():
		if Vector2(x - h.x, z - h.z).length() < 24.0:
			return true
	return false


# ============================================================= island ===

func _build_island() -> void:
	platform(Vector3(0, 0, 0), Vector3(ISLAND_HALF * 2, 2, ISLAND_HALF * 2), GRASS, "ground")
	block(Vector3(0, -4.5, 0), Vector3(ISLAND_HALF * 2 - 4, 6, ISLAND_HALF * 2 - 4), DIRT, "far")
	block(Vector3(0, -1.1, 0), Vector3(ISLAND_HALF * 2 + 20, 1.6, ISLAND_HALF * 2 + 20), SAND, "ground")
	# Grass patches for variation.
	for i in 40:
		var x := _rng.randf_range(-150, 150)
		var z := _rng.randf_range(-150, 150)
		var s := _rng.randf_range(6, 16)
		decor(Vector3(x, 0.01, z), Vector3(s, 0.02, s * _rng.randf_range(0.6, 1.4)), GRASS_DARK, "decor",
			Vector3(0, _rng.randf_range(0, PI), 0))


func _build_plaza() -> void:
	platform(Vector3(0, 0.1, 0), Vector3(48, 0.2, 48), STONE)
	# Inlaid pattern.
	for i in 4:
		var a := i * PI * 0.5
		decor(Vector3(sin(a) * 15, 0.105, cos(a) * 15), Vector3(4, 0.02, 4), PALETTE[i], "decor",
			Vector3(0, PI * 0.25, 0))
	decor(Vector3(0, 0.105, 0), Vector3(16, 0.02, 16), Color(0.7, 0.72, 0.8), "decor")

	# Fountain.
	var rim := Color(0.95, 0.95, 1.0)
	block(Vector3(0, 0.55, -5), Vector3(10, 0.9, 0.8), rim)
	block(Vector3(0, 0.55, 5), Vector3(10, 0.9, 0.8), rim)
	block(Vector3(-5, 0.55, 0), Vector3(0.8, 0.9, 9.2), rim)
	block(Vector3(5, 0.55, 0), Vector3(0.8, 0.9, 9.2), rim)
	glow_box(Vector3(0, 0.6, 0), Vector3(9.2, 0.1, 9.2), Color(0.3, 0.65, 1.0), 0.6)
	block(Vector3(0, 1.7, 0), Vector3(1.4, 3.2, 1.4), rim)
	block(Vector3(0, 3.4, 0), Vector3(3.2, 0.4, 3.2), rim)
	glow_box(Vector3(0, 3.65, 0), Vector3(2.8, 0.1, 2.8), Color(0.35, 0.7, 1.0), 0.9)
	glow_box(Vector3(0, 4.6, 0), Vector3(0.5, 2.0, 0.5), Color(0.6, 0.85, 1.0), 1.4)

	# Lamps on plaza corners.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_lamp(Vector3(sx * 22.0, 0.1, sz * 22.0))

	label(Vector3(0, 11, -22), "ROOBOX", YELLOW, 260)
	label(Vector3(0, 8.4, -22), "step on a portal or walk the roads!", Color(1, 1, 1), 70)

	# Portals to every zone.
	teleporter(Vector3(-15, 0.1, -15), OBBY_O + Vector3(0, 0.6, 6), "OBBY LAND", Color(1.0, 0.5, 0.3))
	teleporter(Vector3(15, 0.1, -15), TOWER_O + Vector3(-11, 0.6, 0), "SKY TOWER", Color(0.6, 0.5, 1.0))
	teleporter(Vector3(-15, 0.1, 15), Vector3(-70, 0.6, 6), "PLAYGROUND", Color(0.3, 0.9, 0.5))
	teleporter(Vector3(15, 0.1, 15), VILLAGE_O + Vector3(0, 0.6, -36), "VILLAGE", Color(1.0, 0.8, 0.3))


func _lamp(pos: Vector3) -> void:
	block(pos + Vector3(0, 2.0, 0), Vector3(0.3, 4.0, 0.3), Color(0.25, 0.27, 0.33), "plain")
	glow_box(pos + Vector3(0, 4.3, 0), Vector3(0.8, 0.6, 0.8), Color(1.0, 0.9, 0.6), 2.2)


func _build_roads() -> void:
	var y := -0.02
	# North to the obby pier.
	decor(Vector3(0, y, -92), Vector3(8, 0.1, 136), ROAD, "plain")
	# East to the tower.
	decor(Vector3(60.5, y, 0), Vector3(73, 0.1, 8), ROAD, "plain")
	# West to the playground.
	decor(Vector3(-45, y, 0), Vector3(42, 0.1, 8), ROAD, "plain")
	# South through the village.
	decor(Vector3(0, y, 88), Vector3(8, 0.1, 128), ROAD, "plain")
	# Dashed centre lines.
	for i in 30:
		decor(Vector3(0, 0.04, -28 - i * 4.4), Vector3(0.35, 0.02, 2.2), Color(1, 1, 1))
		if i < 28:
			decor(Vector3(0, 0.04, 28 + i * 4.4), Vector3(0.35, 0.02, 2.2), Color(1, 1, 1))
		if i < 16:
			decor(Vector3(28 + i * 4.4, 0.04, 0), Vector3(2.2, 0.02, 0.35), Color(1, 1, 1))
		if i < 9:
			decor(Vector3(-28 - i * 4.4, 0.04, 0), Vector3(2.2, 0.02, 0.35), Color(1, 1, 1))


# ============================================================== obby ===

func _build_obby(o: Vector3) -> void:
	var course := "Obby Land"
	# Pier from the shore + wooden dock.
	platform(Vector3(0, 0, -163), Vector3(8, 0.6, 10), WOOD)
	platform(o, Vector3(24, 1, 24), WOOD)
	for sx in [-11.0, 11.0]:
		for sz in [-11.0, 11.0]:
			decor(o + Vector3(sx, -3.5, sz), Vector3(1, 6, 1), WOOD.darkened(0.35), "plain")
	checkpoint(o + Vector3(0, 0, 6), course)
	label(o + Vector3(0, 7.5, -9), "OBBY LAND", YELLOW, 170)
	label(o + Vector3(0, 6.0, -9), "reach the trophy!", Color(1, 1, 1), 70)
	coin(o + Vector3(-6, 1.2, 0))
	coin(o + Vector3(6, 1.2, 0))

	# Stepping stones.
	var xs := [0.0, 2.2, -1.6, 1.2, -0.4]
	for i in 5:
		var top := 0.6 * (i + 1)
		var p := o + Vector3(xs[i], top, -15.0 - 4.6 * i)
		platform(p, Vector3(3, 1, 3), PALETTE[i % PALETTE.size()])
		coin(p + Vector3(0, 1.3, 0))

	# Moving platforms.
	var y := 3.0
	_moving(o + Vector3(-5, y - 0.4, -41), Vector3(10, 0, 0), 4.2, 0.0, Vector3(4, 0.8, 4), PALETTE[4])
	_moving(o + Vector3(5, y - 0.4, -48), Vector3(-10, 0, 0), 3.6, 0.25, Vector3(4, 0.8, 4), PALETTE[5])
	_moving(o + Vector3(0, y - 0.4, -55), Vector3(0, 2.5, 0), 3.0, 0.0, Vector3(3.5, 0.8, 3.5), PALETTE[6])
	coin(o + Vector3(0, y + 1.4, -41))
	coin(o + Vector3(0, y + 1.4, -48))
	coin(o + Vector3(0, y + 4.0, -55))

	platform(o + Vector3(0, 4.5, -64), Vector3(11, 1, 11), STONE)
	checkpoint(o + Vector3(0, 4.5, -64))

	# Spinner arena + jump pad.
	var top_a := 4.5
	var cz := -78.0
	platform(o + Vector3(0, top_a, cz), Vector3(15, 1, 15), Color(0.95, 0.95, 1.0))
	block(o + Vector3(0, top_a - 1.2, cz), Vector3(15.6, 1.4, 15.6), PALETTE[0])
	var sp := Spinner.new()
	sp.position = o + Vector3(0, top_a, cz)
	add_child(sp)
	for c in [Vector2(5.5, 5.5), Vector2(-5.5, 5.5), Vector2(5.5, -5.5), Vector2(-5.5, -5.5)]:
		var cv: Vector2 = c
		coin(o + Vector3(cv.x, top_a + 1.2, cz + cv.y))
	var pad := JumpPad.new()
	pad.position = o + Vector3(0, top_a, cz - 6.0)
	add_child(pad)
	label(o + Vector3(0, top_a + 3.2, cz - 6.0), "BOING!", Color(0.4, 0.95, 1.0), 90)
	platform(o + Vector3(0, 11.0, -93), Vector3(8, 1, 8), PALETTE[2])
	coin(o + Vector3(0, 14.5, -86))

	# Lava hops.
	var top_l := 11.0
	var lava := MeshInstance3D.new()
	var lava_mesh := BoxMesh.new()
	lava_mesh.size = Vector3(30, 0.6, 40)
	lava.mesh = lava_mesh
	lava.position = o + Vector3(0, 5, -117)
	lava.material_override = Fx.glow_material(Color(1.0, 0.32, 0.08), 2.2)
	lava.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lava)
	var kz := KillZone.new()
	kz.position = o + Vector3(0, 5.6, -117)
	kz.setup(Vector3(30, 1.2, 40))
	add_child(kz)
	var hops := [
		Vector3(-2.0, top_l, -100), Vector3(2.0, top_l + 0.4, -105),
		Vector3(-1.8, top_l + 0.8, -110), Vector3(2.0, top_l + 1.2, -115),
		Vector3(0.0, top_l + 1.6, -120),
	]
	for i in hops.size():
		var h: Vector3 = hops[i]
		platform(o + h, Vector3(2.6, 0.8, 2.6), PALETTE[(i + 3) % PALETTE.size()])
		coin(o + h + Vector3(0, 1.3, 0))
	var beam_top := top_l + 1.6
	platform(o + Vector3(0, beam_top, -127.5), Vector3(1.4, 0.8, 11), STONE)
	_kill_brick(o + Vector3(0, beam_top, -126), Vector3(1.4, 0.35, 0.8))
	_kill_brick(o + Vector3(0, beam_top, -130), Vector3(1.4, 0.35, 0.8))
	platform(o + Vector3(0, beam_top, -138), Vector3(10, 1, 10), STONE)
	checkpoint(o + Vector3(0, beam_top, -138))

	# Spiral finale.
	var center := o + Vector3(0, 0, -152)
	var radius := 4.6
	var steps := 19
	var rise := 0.85
	var pillar_top := beam_top + rise * steps
	var pillar_h := pillar_top - 6.0
	block(center + Vector3(0, 6.0 + pillar_h * 0.5, 0), Vector3(3, pillar_h, 3), Color(0.92, 0.92, 0.98))
	for i in steps:
		var ang := deg_to_rad(30.0 * i)
		var p := center + Vector3(sin(ang) * radius, beam_top + rise * (i + 1), cos(ang) * radius)
		platform(p, Vector3(2.4, 0.6, 2.4), PALETTE[i % PALETTE.size()])
		if i % 3 == 1:
			coin(p + Vector3(0, 1.3, 0))
	var fz := center.z - radius - 7.4
	platform(Vector3(o.x, pillar_top, fz), Vector3(12, 1, 12), Color(1.0, 0.92, 0.6))
	block(Vector3(o.x, pillar_top - 1.3, fz), Vector3(12.6, 1.6, 12.6), PALETTE[5])
	var finish := FinishLine.new()
	finish.course_name = course
	finish.position = Vector3(o.x, pillar_top, fz - 2.0)
	add_child(finish)


func _moving(pos: Vector3, travel: Vector3, period: float, phase: float, size: Vector3, color: Color) -> void:
	var mp := MovingPlatform.new()
	mp.position = pos
	mp.travel = travel
	mp.period = period
	mp.phase = phase
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = Fx.block_material(color)
	mp.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	mp.add_child(col)
	var trim := MeshInstance3D.new()
	var trim_mesh := BoxMesh.new()
	trim_mesh.size = Vector3(size.x + 0.1, 0.12, size.z + 0.1)
	trim.mesh = trim_mesh
	trim.position.y = -size.y * 0.5
	trim.material_override = Fx.glow_material(color.lightened(0.3), 1.4)
	mp.add_child(trim)
	add_child(mp)


func _kill_brick(base: Vector3, size: Vector3) -> void:
	glow_box(base + Vector3(0, size.y * 0.5, 0), size, Color(1.0, 0.15, 0.2), 2.0)
	var kz := KillZone.new()
	kz.position = base + Vector3(0, size.y * 0.5, 0)
	kz.setup(size + Vector3(0.1, 0.2, 0.1))
	add_child(kz)


# ============================================================== tower ===

func _build_tower(t: Vector3) -> void:
	var course := "Sky Tower"
	platform(t + Vector3(0, 0.1, 0), Vector3(28, 0.2, 28), STONE)
	checkpoint(t + Vector3(-11, 0.1, 0), course)
	label(t + Vector3(-14, 9, 0), "SKY TOWER", Color(0.75, 0.65, 1.0), 170)
	label(t + Vector3(-14, 7.4, 0), "60m to the top!", Color(1, 1, 1), 70)

	block(t + Vector3(0, 30.25, 0), Vector3(6, 60.5, 6), Color(0.92, 0.92, 0.98))
	# Glowing bands every 10m.
	for k in 6:
		glow_box(t + Vector3(0, 10.0 * (k + 1) - 0.2, 0), Vector3(6.2, 0.3, 6.2), PALETTE[k], 1.2)

	var r := 7.5
	var a0 := PI # start on the west side, facing the road
	for i in 40:
		var ang := a0 + deg_to_rad(24.0 * i)
		var top := 1.5 * (i + 1)
		var p := t + Vector3(cos(ang) * r, top, sin(ang) * r)
		var s := 3.0 if i < 14 else (2.4 if i < 28 else 2.0)
		var landing := i == 9 or i == 19 or i == 29
		if landing:
			s = 4.2
		platform(p, Vector3(s, 0.7, s), PALETTE[i % PALETTE.size()])
		if landing:
			checkpoint(p)
		elif i % 4 == 2:
			coin(p + Vector3(0, 1.3, 0))

	platform(t + Vector3(0, 61.5, 0), Vector3(9, 1, 9), Color(1.0, 0.92, 0.6))
	var finish := FinishLine.new()
	finish.course_name = course
	finish.position = t + Vector3(0, 61.5, 0)
	add_child(finish)


# ========================================================= playground ===

func _build_playground() -> void:
	label(Vector3(-66, 8, -10), "PLAYGROUND", Color(0.45, 1.0, 0.55), 170)
	platform(Vector3(-104, 0.1, -8), Vector3(96, 0.2, 100), SAND, "plain")

	# Trampolines: stronger and stronger.
	var strengths := [14.0, 18.0, 24.0, 30.0, 36.0]
	for i in strengths.size():
		var jp := JumpPad.new()
		jp.strength = strengths[i]
		jp.color = PALETTE[i]
		jp.position = Vector3(-76, 0.1, -24 + i * 9.0)
		add_child(jp)
	platform(Vector3(-84, 19, 14), Vector3(7, 1, 7), PALETTE[5])
	coin(Vector3(-84, 20.3, 14))
	coin(Vector3(-84, 20.3, 12))
	platform(Vector3(-84, 12, -6), Vector3(6, 1, 6), PALETTE[3])
	coin(Vector3(-84, 13.3, -6))

	# Step pyramid.
	var sizes := [24.0, 19.0, 14.0, 9.0, 4.0]
	for k in sizes.size():
		var s: float = sizes[k]
		platform(Vector3(-96, 0.1 + 1.2 * (k + 1), -42), Vector3(s, 1.2, s), PALETTE[k])
	coin(Vector3(-96, 7.6, -42))

	# Ramp up to a tower, then a long slide down.
	var tower_top := 10.0
	block(Vector3(-130, tower_top * 0.5, 30), Vector3(6, tower_top, 6), Color(0.95, 0.95, 1.0))
	var ramp_len := sqrt(17.0 * 17.0 + tower_top * tower_top)
	var ramp_ang := atan2(tower_top, 17.0)
	block(Vector3(-130, tower_top * 0.5 - 0.25, 18.5), Vector3(4, 0.5, ramp_len), PALETTE[4], "tiled",
		Vector3(-ramp_ang, 0, 0))
	var slide_run := 22.0
	var slide_len := sqrt(slide_run * slide_run + tower_top * tower_top)
	var slide_ang := atan2(tower_top, slide_run)
	block(Vector3(-127 + slide_run * 0.5, tower_top * 0.5 - 0.25, 30), Vector3(slide_len, 0.5, 4),
		YELLOW, "plain", Vector3(0, 0, -slide_ang))
	for side in [-1.0, 1.0]:
		decor(Vector3(-127 + slide_run * 0.5, tower_top * 0.5 + 0.35, 30 + side * 2.1),
			Vector3(slide_len, 0.6, 0.2), PALETTE[0], "plain", Vector3(0, 0, -slide_ang))
	coin(Vector3(-130, tower_top + 1.3, 30))

	_build_maze(Vector3(-146, 0.1, -24), 8, 4.0)


## Recursive-backtracker hedge maze. `origin` = north-west corner.
func _build_maze(origin: Vector3, n: int, cell: float) -> void:
	var visited: Array[bool] = []
	visited.resize(n * n)
	visited.fill(false)
	# walls[i] = [north, east, south, west]
	var walls: Array = []
	for i in n * n:
		walls.append([true, true, true, true])
	var stack: Array[Vector2i] = [Vector2i(0, 0)]
	visited[0] = true
	var dirs := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	while not stack.is_empty():
		var c: Vector2i = stack.back()
		var options: Array[int] = []
		for d in 4:
			var nb: Vector2i = c + dirs[d]
			if nb.x >= 0 and nb.y >= 0 and nb.x < n and nb.y < n and not visited[nb.y * n + nb.x]:
				options.append(d)
		if options.is_empty():
			stack.pop_back()
			continue
		var d2: int = options[_rng.randi() % options.size()]
		var nxt: Vector2i = c + dirs[d2]
		var wa: Array = walls[c.y * n + c.x]
		wa[d2] = false
		var wb: Array = walls[nxt.y * n + nxt.x]
		wb[(d2 + 2) % 4] = false
		visited[nxt.y * n + nxt.x] = true
		stack.append(nxt)
	# Entrance (east side, last row) and goal (first cell).
	var we: Array = walls[(n - 1) * n + (n - 1)]
	we[1] = false

	var hedge := Color(0.22, 0.55, 0.25)
	var h := 2.8
	var th := 0.6
	for y in n:
		for x in n:
			var w: Array = walls[y * n + x]
			var cx := origin.x + (x + 0.5) * cell
			var cz := origin.z + (y + 0.5) * cell
			if w[0]:
				block(Vector3(cx, origin.y + h * 0.5, cz - cell * 0.5), Vector3(cell + th, h, th), hedge, "plain")
			if w[3]:
				block(Vector3(cx - cell * 0.5, origin.y + h * 0.5, cz), Vector3(th, h, cell + th), hedge, "plain")
			if y == n - 1 and w[2]:
				block(Vector3(cx, origin.y + h * 0.5, cz + cell * 0.5), Vector3(cell + th, h, th), hedge, "plain")
			if x == n - 1 and w[1]:
				block(Vector3(cx + cell * 0.5, origin.y + h * 0.5, cz), Vector3(th, h, cell + th), hedge, "plain")
	var goal := origin + Vector3(cell * 0.5, 1.2, cell * 0.5)
	coin(goal)
	coin(goal + Vector3(0, 0.0, 1.2))
	coin(goal + Vector3(1.2, 0.0, 0))
	label(origin + Vector3(n * cell * 0.5, 5.5, -2), "MAZE", Color(0.5, 1.0, 0.5), 110)


# ============================================================ village ===

func _build_village(v: Vector3) -> void:
	label(v + Vector3(-9, 7, -50), "VILLAGE", YELLOW, 160)
	var walls := [
		Color(1.0, 0.95, 0.85), Color(0.75, 0.88, 1.0), Color(1.0, 0.8, 0.85),
		Color(0.78, 0.95, 0.82), Color(1.0, 0.86, 0.7), Color(0.86, 0.8, 1.0),
		Color(0.97, 0.97, 0.97), Color(1.0, 0.93, 0.6),
	]
	var roofs := [Color(0.85, 0.25, 0.22), Color(0.2, 0.3, 0.6), Color(0.45, 0.3, 0.2), Color(0.25, 0.5, 0.3)]
	for i in 4:
		var z := v.z - 38 + i * 22.0
		_house(Vector3(v.x - 17, 0, z), 10.0, 9.0, 4.5, walls[(i * 2) % walls.size()], roofs[i % roofs.size()], 1.0)
		_house(Vector3(v.x + 17, 0, z), 10.0, 9.0, 4.5, walls[(i * 2 + 1) % walls.size()], roofs[(i + 2) % roofs.size()], -1.0)
		coin(Vector3(v.x - 17, 8.6, z))
	for i in 6:
		var z := v.z - 44 + i * 18.0
		_lamp(Vector3(v.x - 6, 0, z))
		_lamp(Vector3(v.x + 6, 0, z))

	# Lake with a bridge.
	var lake := v + Vector3(46, 0, 8)
	decor(lake + Vector3(0, 0.02, 0), Vector3(40, 0.06, 30), SAND, "decor")
	var water := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(36, 0.1, 26)
	water.mesh = wm
	water.position = lake + Vector3(0, 0.04, 0)
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.2, 0.55, 0.9)
	wmat.roughness = 0.05
	wmat.metallic = 0.25
	wmat.emission_enabled = true
	wmat.emission = Color(0.05, 0.2, 0.4)
	water.material_override = wmat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	platform(lake + Vector3(0, 0.1, 0), Vector3(40, 0.2, 3.2), WOOD)
	for side in [-1.0, 1.0]:
		decor(lake + Vector3(0, 0.7, side * 1.5), Vector3(40, 0.15, 0.15), WOOD.darkened(0.25), "plain")
		for k in 9:
			decor(lake + Vector3(-18 + k * 4.5, 0.45, side * 1.5), Vector3(0.2, 0.7, 0.2), WOOD.darkened(0.25), "plain")
	coin(lake + Vector3(0, 1.4, 0))
	coin(lake + Vector3(-10, 1.4, 0))
	coin(lake + Vector3(10, 1.4, 0))


func _house(c: Vector3, w: float, d: float, h: float, wall: Color, roof: Color, door_side: float) -> void:
	var th := 0.4
	platform(c + Vector3(0, 0.1, 0), Vector3(w, 0.2, d), Color(0.75, 0.6, 0.45))
	# Back wall.
	block(c + Vector3(-door_side * (w * 0.5 - th * 0.5), h * 0.5, 0), Vector3(th, h, d), wall)
	# Front wall with a door gap.
	var fx := c.x + door_side * (w * 0.5 - th * 0.5)
	var seg := d * 0.5 - 1.1
	block(Vector3(fx, h * 0.5, c.z - 1.1 - seg * 0.5), Vector3(th, h, seg), wall)
	block(Vector3(fx, h * 0.5, c.z + 1.1 + seg * 0.5), Vector3(th, h, seg), wall)
	block(Vector3(fx, 3.0 + (h - 3.0) * 0.5, c.z), Vector3(th, h - 3.0, 2.2), wall)
	decor(Vector3(fx + door_side * 0.22, 1.5, c.z), Vector3(0.06, 3.0, 2.3), wall.darkened(0.35), "plain")
	# Side walls with windows.
	for sz in [-1.0, 1.0]:
		block(Vector3(c.x, h * 0.5, c.z + sz * (d * 0.5 - th * 0.5)), Vector3(w, h, th), wall)
		decor(Vector3(c.x, 2.4, c.z + sz * (d * 0.5 + 0.03)), Vector3(2.2, 1.4, 0.06), Color(0.55, 0.8, 1.0), "plain")
	# Ceiling + pitched roof (climbable!).
	block(c + Vector3(0, h + 0.15, 0), Vector3(w, 0.3, d), wall.darkened(0.1))
	var hw := w * 0.5 + 0.5
	var ang := deg_to_rad(28.0)
	var slab := hw / cos(ang)
	block(Vector3(c.x - hw * 0.5, h + 0.3 + hw * 0.5 * tan(ang), c.z), Vector3(slab, 0.35, d + 1.0), roof, "plain",
		Vector3(0, 0, ang))
	block(Vector3(c.x + hw * 0.5, h + 0.3 + hw * 0.5 * tan(ang), c.z), Vector3(slab, 0.35, d + 1.0), roof, "plain",
		Vector3(0, 0, -ang))
	# Chimney.
	block(Vector3(c.x - door_side * 2.0, h + 2.6, c.z + 2.0), Vector3(0.9, 2.2, 0.9), Color(0.6, 0.35, 0.3), "plain")
	# Garden fence in front.
	var gx := c.x + door_side * (w * 0.5 + 2.6)
	for sz in [-1.0, 1.0]:
		decor(Vector3(gx, 0.45, c.z + sz * 3.2), Vector3(0.15, 0.9, 3.0), Color(1, 1, 1), "plain")


# ======================================================= hills/forest ===

func _hill_centers() -> Array[Vector3]:
	var a: Array[Vector3] = [
		Vector3(-115, 0, 115), Vector3(115, 0, 115), Vector3(115, 0, -115), Vector3(-110, 0, -115),
	]
	return a


func _build_hills() -> void:
	var sizes := [40.0, 32.0, 24.0, 16.0, 8.0]
	for hc: Vector3 in _hill_centers():
		for k in sizes.size():
			var s: float = sizes[k]
			var col := GRASS.lerp(GRASS_DARK, float(k % 2))
			platform(hc + Vector3(0, 1.2 * (k + 1), 0), Vector3(s, 1.2, s), col)
		tree(hc + Vector3(0, 6.0, 0), 0.9)
		coin(hc + Vector3(3, 7.3, 0))


func _build_forest() -> void:
	var placed := 0
	var tries := 0
	while placed < 150 and tries < 3000:
		tries += 1
		var x := _rng.randf_range(-ISLAND_HALF, ISLAND_HALF)
		var z := _rng.randf_range(-ISLAND_HALF, ISLAND_HALF)
		if _blocked(x, z):
			continue
		tree(Vector3(x, 0, z), _rng.randf_range(0.8, 1.35), _rng.randf() < 0.35)
		placed += 1
	# Rocks.
	for i in 45:
		var x := _rng.randf_range(-150, 150)
		var z := _rng.randf_range(-150, 150)
		if _blocked(x, z):
			continue
		var s := _rng.randf_range(1.0, 3.2)
		block(Vector3(x, s * 0.3, z), Vector3(s, s * 0.8, s * 1.2), Color(0.6, 0.62, 0.66).lightened(_rng.randf_range(-0.1, 0.1)),
			"plain", Vector3(0, _rng.randf_range(0, PI), 0))
	# Flowers.
	var flower_cols := [Color(1, 0.4, 0.5), Color(1, 0.9, 0.3), Color(0.7, 0.5, 1), Color(1, 1, 1), Color(1, 0.6, 0.2)]
	for i in 320:
		var x := _rng.randf_range(-150, 150)
		var z := _rng.randf_range(-150, 150)
		if absf(x) < 26.0 and absf(z) < 26.0:
			continue
		decor(Vector3(x, 0.18, z), Vector3(0.28, 0.36, 0.28), flower_cols[i % flower_cols.size()], "decor")


func _build_scatter() -> void:
	var placed := 0
	var tries := 0
	while placed < 36 and tries < 2000:
		tries += 1
		var x := _rng.randf_range(-150, 150)
		var z := _rng.randf_range(-150, 150)
		if _blocked(x, z) and Vector2(x, z).length() >= 70.0:
			continue
		if Vector2(x, z).length() < 28.0:
			continue
		coin(Vector3(x, 1.2, z))
		placed += 1


# ============================================================ scenery ===

func _build_scenery() -> void:
	var ocean := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(3000, 3000)
	ocean.mesh = plane
	ocean.position = Vector3(0, -1.0, 0)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.16, 0.47, 0.82)
	water.metallic = 0.3
	water.roughness = 0.06
	ocean.material_override = water
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ocean)

	# Distant mountains.
	for i in 26:
		var a := TAU * i / 26.0 + _rng.randf_range(-0.08, 0.08)
		var dist := _rng.randf_range(620, 820)
		var w := _rng.randf_range(90, 200)
		var hgt := _rng.randf_range(70, 190)
		var base := Vector3(cos(a) * dist, hgt * 0.5 - 2.0, sin(a) * dist)
		var col := Color(0.42, 0.52, 0.66).lerp(Color(0.5, 0.6, 0.72), _rng.randf())
		decor(base, Vector3(w, hgt, w * 0.8), col, "far", Vector3(0, a, 0))
		decor(base + Vector3(0, hgt * 0.5 - 6, 0), Vector3(w * 0.45, 14, w * 0.38), Color(0.95, 0.97, 1.0), "far",
			Vector3(0, a, 0))

	# Clouds.
	for i in 34:
		var c := Vector3(_rng.randf_range(-520, 520), _rng.randf_range(70, 110), _rng.randf_range(-520, 520))
		var w := _rng.randf_range(16, 40)
		decor(c, Vector3(w, 5, w * 0.6), Color(1, 1, 1), "far")
		decor(c + Vector3(w * 0.2, 3, 0), Vector3(w * 0.5, 4, w * 0.45), Color(1, 1, 1), "far")
