extends Experience
## Obby Rush: an endless obby. Every stage is generated from its number,
## so all players see the same course, and it gets harder as you go.

const STAGE_LEN := 34.0
const BASE_Y := 20.0
const AHEAD := 3
const BEHIND := 2

var _stages: Dictionary = {}   # stage number -> Node3D
var _current: int = 0
var _mats: Dictionary = {}


func setup() -> void:
	spawn_point = Vector3(0, BASE_Y + 0.6, 4)
	kill_height = BASE_Y - 16.0
	var start := Node3D.new()
	add_child(start)
	_box(start, Vector3(0, BASE_Y - 0.5, 0), Vector3(14, 1, 14), Color(0.3, 0.6, 1.0))
	var title := Label3D.new()
	title.text = "OBBY RUSH"
	title.font_size = 200
	title.outline_size = 40
	title.modulate = Color(0.5, 0.8, 1.0)
	title.outline_modulate = Color(0.05, 0.08, 0.2)
	title.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	title.position = Vector3(0, BASE_Y + 7, -4)
	add_child(title)
	# Scenery: ocean far below.
	var ocean := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(3000, 3000)
	ocean.mesh = plane
	ocean.position = Vector3(0, -2, -400)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.16, 0.47, 0.82)
	water.roughness = 0.06
	water.metallic = 0.3
	ocean.material_override = water
	add_child(ocean)
	_ensure_stages(0)


static func stage_y(k: int) -> float:
	return BASE_Y + k * 0.6


static func stage_origin(k: int) -> Vector3:
	return Vector3(0, stage_y(k), -k * STAGE_LEN)


func on_player_ready(_p: Player) -> void:
	Game.checkpoint_position = spawn_point
	set_status("Stage 0   -   Best %d" % int(Game.best_scores.get("obby_rush", 0)), Color(1, 1, 1))


func _on_stage_reached(body: Node3D, k: int) -> void:
	if not (body is Player) or k <= _current:
		return
	_current = k
	Game.set_checkpoint(stage_origin(k) + Vector3(0, 0.6, 0))
	if player != null:
		player.kill_height = stage_y(k) - 16.0
	var best := report_score("obby_rush", k)
	if hud != null:
		hud.show_toast("STAGE %d%s" % [k, "  NEW BEST!" if best else ""], Color(0.5, 0.85, 1.0))
	set_status("Stage %d   -   Best %d" % [k, int(Game.best_scores.get("obby_rush", 0))], Color(1, 1, 1))
	_ensure_stages(k)


func _ensure_stages(k: int) -> void:
	for s in range(maxi(0, k - BEHIND), k + AHEAD + 1):
		if not _stages.has(s):
			_stages[s] = _build_stage(s)
	for s: int in _stages.keys():
		if s < k - BEHIND:
			(_stages[s] as Node).queue_free()
			_stages.erase(s)


# ---------------------------------------------------------- generation ---

func _build_stage(k: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Stage%d" % k
	add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = k * 7919 + 17
	var d := clampf(k / 40.0, 0.0, 1.0)
	var o := stage_origin(k)
	var col: Color = World.PALETTE[k % World.PALETTE.size()]

	# Checkpoint pad at the stage start (stage 0 starts on the spawn island).
	if k > 0:
		_box(root, o - Vector3(0, 0.5, 0), Vector3(6, 1, 6), col.lightened(0.2))
		var cp := Checkpoint.new()
		cp.position = o
		root.add_child(cp)
		cp.body_entered.connect(_on_stage_reached.bind(k))
		var label := Label3D.new()
		label.text = str(k)
		label.font_size = 150
		label.outline_size = 30
		label.modulate = col.lightened(0.3)
		label.outline_modulate = Color(0.05, 0.05, 0.12)
		label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		label.position = o + Vector3(-4, 4, 0)
		root.add_child(label)

	# Obstacles from the pad edge to the next pad.
	var z := o.z - (3.0 if k > 0 else 7.0)
	var end_z := o.z - STAGE_LEN + 3.0
	var y := o.y
	while z - end_z > 7.0:
		var kind := rng.randi() % 5
		match kind:
			0:
				z = _seg_hops(root, rng, z, y, d, col)
			1:
				z = _seg_beam(root, rng, z, y, d, col)
			2:
				z = _seg_bricks(root, rng, z, y, d, col)
			3:
				z = _seg_steps(root, rng, z, y, d, col)
			_:
				z = _seg_mover(root, rng, z, y, d, col)
	# Final hop to the next pad if the remaining gap is large.
	if z - end_z > 3.2:
		var mid := (z + end_z) * 0.5
		_box(root, Vector3(0, y - 0.3, mid), Vector3(2.4, 0.6, 2.4), col)
	return root


func _seg_hops(root: Node3D, rng: RandomNumberGenerator, z: float, y: float, d: float, col: Color) -> float:
	var size := lerpf(3.0, 1.7, d)
	for i in 3:
		var gap := lerpf(1.4, 3.0, d) * rng.randf_range(0.85, 1.1)
		z -= gap + size * 0.5
		_box(root, Vector3(rng.randf_range(-2.5, 2.5), y - 0.3, z), Vector3(size, 0.6, size), col)
		z -= size * 0.5
	return z


func _seg_beam(root: Node3D, rng: RandomNumberGenerator, z: float, y: float, d: float, col: Color) -> float:
	var length := rng.randf_range(7.0, 10.0)
	var width := lerpf(1.5, 0.75, d)
	z -= 1.4
	_box(root, Vector3(0, y - 0.3, z - length * 0.5), Vector3(width, 0.6, length), col.darkened(0.15))
	return z - length


func _seg_bricks(root: Node3D, rng: RandomNumberGenerator, z: float, y: float, d: float, col: Color) -> float:
	var length := 9.0
	z -= 1.4
	_box(root, Vector3(0, y - 0.3, z - length * 0.5), Vector3(3.2, 0.6, length), col)
	var count := 1 + int(d * 2.0) + rng.randi() % 2
	for i in count:
		var bz := z - length * (i + 1) / float(count + 1)
		_kill_brick(root, Vector3(0, y + 0.2, bz), Vector3(3.2, 0.4, 0.7))
	return z - length


func _seg_steps(root: Node3D, rng: RandomNumberGenerator, z: float, y: float, d: float, col: Color) -> float:
	var size := lerpf(2.6, 1.8, d)
	var h := y
	for i in 4:
		z -= lerpf(1.2, 2.2, d) + size * 0.5
		h += 0.9 if i < 2 else -0.9
		_box(root, Vector3(rng.randf_range(-1.5, 1.5), h - 0.3, z), Vector3(size, 0.6, size), col.lightened(0.1 * i))
		z -= size * 0.5
	return z


func _seg_mover(root: Node3D, rng: RandomNumberGenerator, z: float, y: float, d: float, col: Color) -> float:
	var size := lerpf(3.4, 2.4, d)
	z -= 1.6 + size * 0.5
	var mp := MovingPlatform.new()
	mp.position = Vector3(-4.0, y - 0.3, z)
	mp.travel = Vector3(8.0, 0, 0)
	mp.period = lerpf(4.0, 2.4, d)
	mp.phase = rng.randf()
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size, 0.6, size)
	mi.mesh = mesh
	mi.material_override = _mat(col.lightened(0.25))
	mp.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	cs.shape = shape
	mp.add_child(cs)
	root.add_child(mp)
	return z - size * 0.5 - 0.4


func _kill_brick(root: Node3D, pos: Vector3, size: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = Fx.glow_material(Color(1.0, 0.15, 0.2), 2.0)
	mi.position = pos
	root.add_child(mi)
	var kz := KillZone.new()
	kz.position = pos
	kz.setup(size + Vector3(0.1, 0.2, 0.1))
	root.add_child(kz)


func _box(root: Node3D, pos: Vector3, size: Vector3, col: Color) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _mat(col)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	root.add_child(body)


func _mat(col: Color) -> StandardMaterial3D:
	var key := col.to_html()
	if not _mats.has(key):
		_mats[key] = Fx.block_material(col)
	return _mats[key] as StandardMaterial3D
