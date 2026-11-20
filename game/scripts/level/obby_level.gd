class_name ObbyLevel
extends Node3D
## Procedurally assembled obstacle course ("obby"):
##   spawn island -> stepping stones -> moving platforms -> checkpoint 1
##   -> spinner arena -> jump pad -> lava hop -> checkpoint 2
##   -> spiral tower -> finish.
## Forward direction is -Z.

const PALETTE: Array[Color] = [
	Color(1.0, 0.35, 0.35),
	Color(1.0, 0.62, 0.2),
	Color(1.0, 0.85, 0.25),
	Color(0.35, 0.8, 0.4),
	Color(0.3, 0.6, 1.0),
	Color(0.65, 0.45, 1.0),
	Color(1.0, 0.45, 0.75),
]

const GRASS := Color(0.42, 0.78, 0.36)
const DIRT := Color(0.55, 0.38, 0.25)
const STONE := Color(0.82, 0.84, 0.9)

var _mat_cache: Dictionary = {}

## Where the player starts.
var spawn_point: Vector3 = Vector3(0, 0.2, 6)


func _ready() -> void:
	Game.checkpoint_position = spawn_point
	_build_spawn()
	_build_stepping_stones()
	_build_moving_section()
	_build_spinner_arena()
	_build_lava_section()
	_build_tower()
	_build_scenery()


# ------------------------------------------------------------- helpers ---

func _material(color: Color, tiled: bool = true) -> StandardMaterial3D:
	var key := "%s|%s" % [color.to_html(), tiled]
	if not _mat_cache.has(key):
		_mat_cache[key] = Fx.block_material(color, tiled)
	return _mat_cache[key] as StandardMaterial3D


## Static solid box. `pos` is the CENTER of the box.
func block(pos: Vector3, size: Vector3, color: Color, tiled: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _material(color, tiled)
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	add_child(body)
	return body


## Box placed by its TOP surface height (handy for platforms).
func platform(x: float, top: float, z: float, size: Vector3, color: Color) -> StaticBody3D:
	return block(Vector3(x, top - size.y * 0.5, z), size, color)


func decor(pos: Vector3, size: Vector3, color: Color, tiled: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _material(color, tiled)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func coin(pos: Vector3) -> void:
	var c := Coin.new()
	c.position = pos
	add_child(c)


func checkpoint(pos: Vector3, idx: int) -> void:
	var cp := Checkpoint.new()
	cp.index = idx
	cp.position = pos
	add_child(cp)


func tree(pos: Vector3, s: float = 1.0) -> void:
	block(pos + Vector3(0, 1.2 * s, 0), Vector3(0.6, 2.4, 0.6) * s, Color(0.45, 0.3, 0.18), false)
	block(pos + Vector3(0, 3.0 * s, 0), Vector3(2.8, 1.6, 2.8) * s, Color(0.3, 0.7, 0.3), false)
	block(pos + Vector3(0, 4.3 * s, 0), Vector3(1.8, 1.1, 1.8) * s, Color(0.38, 0.8, 0.36), false)


func sign_label(pos: Vector3, text: String, color: Color, font_size: int = 120) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = font_size
	l.outline_size = 28
	l.modulate = color
	l.outline_modulate = Color(0.06, 0.07, 0.15)
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.position = pos
	add_child(l)


# ------------------------------------------------------------- sections ---

func _build_spawn() -> void:
	# Floating grass island.
	platform(0, 0, 0, Vector3(24, 1.2, 24), GRASS)
	block(Vector3(0, -2.4, 0), Vector3(21, 2.4, 21), DIRT)
	block(Vector3(0, -4.6, 0), Vector3(15, 2.0, 15), DIRT.darkened(0.15))
	block(Vector3(0, -6.2, 0), Vector3(8, 1.2, 8), DIRT.darkened(0.3))

	checkpoint(Vector3(0, 0, 6), 0)
	sign_label(Vector3(0, 6.0, -9), "ROOBOX OBBY", Color(1.0, 0.85, 0.3), 150)
	sign_label(Vector3(0, 4.6, -9), "reach the trophy!", Color(1, 1, 1), 70)

	tree(Vector3(-8.5, 0, -8))
	tree(Vector3(8.5, 0, 7), 1.15)
	tree(Vector3(-8, 0, 8), 0.9)
	tree(Vector3(9, 0, -7.5))

	# Little decorative steps to play with.
	platform(-6, 0.6, 1, Vector3(2, 0.6, 2), PALETTE[4])
	platform(-6, 1.2, -1.5, Vector3(2, 0.6, 2), PALETTE[5])
	platform(6, 0.8, 2, Vector3(2.5, 0.8, 2.5), PALETTE[0])
	coin(Vector3(-6, 2.5, -1.5))
	coin(Vector3(6, 2.2, 2))
	coin(Vector3(0, 1.2, -4))


func _build_stepping_stones() -> void:
	var xs := [0.0, 2.2, -1.6, 1.2, -0.4]
	for i in 5:
		var top := 0.6 * (i + 1)
		var z := -15.0 - 4.6 * i
		var x: float = xs[i]
		platform(x, top, z, Vector3(3, 1, 3), PALETTE[i % PALETTE.size()])
		coin(Vector3(x, top + 1.3, z))


func _build_moving_section() -> void:
	var y := 3.0
	var a := MovingPlatform.new()
	a.position = Vector3(-5, y - 0.4, -41)
	a.travel = Vector3(10, 0, 0)
	a.period = 4.2
	_add_platform_visual(a, Vector3(4, 0.8, 4), PALETTE[4])
	add_child(a)

	var b := MovingPlatform.new()
	b.position = Vector3(5, y - 0.4, -48)
	b.travel = Vector3(-10, 0, 0)
	b.period = 3.6
	b.phase = 0.25
	_add_platform_visual(b, Vector3(4, 0.8, 4), PALETTE[5])
	add_child(b)

	var c := MovingPlatform.new()
	c.position = Vector3(0, y - 0.4, -55)
	c.travel = Vector3(0, 2.5, 0)
	c.period = 3.0
	_add_platform_visual(c, Vector3(3.5, 0.8, 3.5), PALETTE[6])
	add_child(c)

	coin(Vector3(0, y + 1.4, -41))
	coin(Vector3(0, y + 1.4, -48))
	coin(Vector3(0, y + 4.0, -55))

	# Checkpoint 1.
	platform(0, 4.5, -64, Vector3(11, 1, 11), STONE)
	checkpoint(Vector3(0, 4.5, -64), 1)


func _add_platform_visual(body: AnimatableBody3D, size: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _material(color)
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	# Glowing trim so moving platforms read as "special".
	var trim := MeshInstance3D.new()
	var trim_mesh := BoxMesh.new()
	trim_mesh.size = Vector3(size.x + 0.1, 0.12, size.z + 0.1)
	trim.mesh = trim_mesh
	trim.position.y = -size.y * 0.5
	trim.material_override = Fx.glow_material(color.lightened(0.3), 1.4)
	body.add_child(trim)


func _build_spinner_arena() -> void:
	var top := 4.5
	var cz := -78.0
	platform(0, top, cz, Vector3(15, 1, 15), Color(0.95, 0.95, 1.0))
	# Coloured rim.
	block(Vector3(0, top - 1.2, cz), Vector3(15.6, 1.4, 15.6), PALETTE[0])
	var sp := Spinner.new()
	sp.position = Vector3(0, top, cz)
	add_child(sp)
	coin(Vector3(5.5, top + 1.2, cz + 5.5))
	coin(Vector3(-5.5, top + 1.2, cz + 5.5))
	coin(Vector3(5.5, top + 1.2, cz - 5.5))
	coin(Vector3(-5.5, top + 1.2, cz - 5.5))

	# Jump pad up to the high ledge.
	var pad := JumpPad.new()
	pad.position = Vector3(0, top, cz - 6.0)
	add_child(pad)

	platform(0, 11.0, -93, Vector3(8, 1, 8), PALETTE[2])
	coin(Vector3(0, 14.5, -86))
	sign_label(Vector3(0, top + 3.2, cz - 6.0), "BOING!", Color(0.4, 0.95, 1.0), 90)


func _build_lava_section() -> void:
	var top := 11.0
	# Lava pool far below the hops.
	var lava_y := 5.0
	var lava := MeshInstance3D.new()
	var lava_mesh := BoxMesh.new()
	lava_mesh.size = Vector3(30, 0.6, 40)
	lava.mesh = lava_mesh
	lava.position = Vector3(0, lava_y, -117)
	lava.material_override = Fx.glow_material(Color(1.0, 0.32, 0.08), 2.2)
	lava.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lava)
	var kz := KillZone.new()
	kz.position = Vector3(0, lava_y + 0.6, -117)
	kz.setup(Vector3(30, 1.2, 40))
	add_child(kz)

	var lava_light := OmniLight3D.new()
	lava_light.light_color = Color(1.0, 0.45, 0.15)
	lava_light.light_energy = 3.0
	lava_light.omni_range = 22.0
	lava_light.position = Vector3(0, lava_y + 3.0, -117)
	add_child(lava_light)

	# Zig-zag hops.
	var hops := [
		Vector3(-2.0, top, -100), Vector3(2.0, top + 0.4, -105),
		Vector3(-1.8, top + 0.8, -110), Vector3(2.0, top + 1.2, -115),
		Vector3(0.0, top + 1.6, -120),
	]
	for i in hops.size():
		var h: Vector3 = hops[i]
		platform(h.x, h.y, h.z, Vector3(2.6, 0.8, 2.6), PALETTE[(i + 3) % PALETTE.size()])
		coin(Vector3(h.x, h.y + 1.3, h.z))

	# Narrow beam with kill bricks on it.
	var beam_top := top + 1.6
	platform(0, beam_top, -127.5, Vector3(1.4, 0.8, 11), STONE)
	_kill_brick(Vector3(0, beam_top, -126), Vector3(1.4, 0.35, 0.8))
	_kill_brick(Vector3(0, beam_top, -130), Vector3(1.4, 0.35, 0.8))

	# Checkpoint 2.
	platform(0, beam_top, -138, Vector3(10, 1, 10), STONE)
	checkpoint(Vector3(0, beam_top, -138), 2)


func _kill_brick(base: Vector3, size: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = Fx.glow_material(Color(1.0, 0.15, 0.2), 2.0)
	mi.position = base + Vector3(0, size.y * 0.5, 0)
	add_child(mi)
	var kz := KillZone.new()
	kz.position = mi.position
	kz.setup(size + Vector3(0.1, 0.2, 0.1))
	add_child(kz)


func _build_tower() -> void:
	var base_top := 12.6
	var center := Vector3(0, 0, -152)
	var radius := 4.6
	var steps := 19
	var rise := 0.85

	# Central pillar.
	var pillar_top := base_top + rise * steps
	var pillar_h := pillar_top - 6.0
	block(Vector3(center.x, 6.0 + pillar_h * 0.5, center.z), Vector3(3, pillar_h, 3), Color(0.92, 0.92, 0.98))

	# Spiral steps, starting on the side facing checkpoint 2 (+Z).
	for i in steps:
		var ang := deg_to_rad(30.0 * i)
		var x := center.x + sin(ang) * radius
		var z := center.z + cos(ang) * radius
		var top := base_top + rise * (i + 1)
		platform(x, top, z, Vector3(2.4, 0.6, 2.4), PALETTE[i % PALETTE.size()])
		if i % 3 == 1:
			coin(Vector3(x, top + 1.3, z))

	# Finish platform.
	var fz := center.z - radius - 7.4
	platform(0, pillar_top, fz, Vector3(12, 1, 12), Color(1.0, 0.92, 0.6))
	block(Vector3(0, pillar_top - 1.3, fz), Vector3(12.6, 1.6, 12.6), PALETTE[5])
	var finish := FinishLine.new()
	finish.position = Vector3(0, pillar_top, fz - 2.0)
	add_child(finish)


func _build_scenery() -> void:
	# Ocean far below.
	var ocean := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1400, 1400)
	ocean.mesh = plane
	ocean.position = Vector3(0, -28, -80)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.18, 0.5, 0.85)
	water.metallic = 0.3
	water.roughness = 0.08
	ocean.material_override = water
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ocean)

	# Distant floating islands.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 9:
		var side := -1.0 if i % 2 == 0 else 1.0
		var pos := Vector3(side * rng.randf_range(35, 70), rng.randf_range(-12, 14), rng.randf_range(-180, 30))
		var s := rng.randf_range(5, 11)
		decor(pos, Vector3(s, 1.4, s), GRASS, true)
		decor(pos + Vector3(0, -1.8, 0), Vector3(s * 0.8, 2.2, s * 0.8), DIRT)
		decor(pos + Vector3(0, -3.6, 0), Vector3(s * 0.45, 1.6, s * 0.45), DIRT.darkened(0.25))
		if rng.randf() < 0.7:
			var tp := pos + Vector3(rng.randf_range(-s * 0.3, s * 0.3), 0.7, rng.randf_range(-s * 0.3, s * 0.3))
			decor(tp + Vector3(0, 1.2, 0), Vector3(0.6, 2.4, 0.6), Color(0.45, 0.3, 0.18))
			decor(tp + Vector3(0, 3.0, 0), Vector3(2.6, 1.6, 2.6), Color(0.3, 0.7, 0.3))

	# Clouds.
	for i in 14:
		var c := Vector3(rng.randf_range(-90, 90), rng.randf_range(28, 45), rng.randf_range(-220, 60))
		var w := rng.randf_range(6, 14)
		decor(c, Vector3(w, 2.2, w * 0.6), Color(1, 1, 1))
		decor(c + Vector3(w * 0.25, 1.2, 0), Vector3(w * 0.5, 1.8, w * 0.45), Color(1, 1, 1))
