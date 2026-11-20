extends Experience
## Color Drop: stand on the called color before the other tiles vanish.

const N := 12
const TILE := 3.6
const Y := 12.0
const COLORS: Array[Color] = [
	Color(1.0, 0.3, 0.3), Color(1.0, 0.6, 0.15), Color(1.0, 0.9, 0.25),
	Color(0.3, 0.85, 0.4), Color(0.3, 0.55, 1.0), Color(0.7, 0.4, 1.0),
]
const NAMES: Array[String] = ["RED", "ORANGE", "YELLOW", "GREEN", "BLUE", "PURPLE"]

var _mm: MultiMesh
var _shapes: Array[CollisionShape3D] = []
var _tile_colors: PackedInt32Array = PackedInt32Array()
var _board: Label3D
var _lobby: Vector3
var _playing: bool = false
var _survived: int = 0
var _state: String = "waiting"
var _timer: float = 0.0
var _color: int = 0


func setup() -> void:
	var half := N * TILE * 0.5
	_lobby = Vector3(0, Y, half + 12.0)
	spawn_point = _lobby + Vector3(0, 0.6, 2)
	kill_height = Y - 10.0

	var b := WorldBuilder.new(self)
	b.box(_lobby - Vector3(0, 0.5, 0), Vector3(18, 1, 14), Color(0.85, 0.87, 0.95), true, "tiled")
	b.box(_lobby - Vector3(0, 2.0, 0), Vector3(15, 2, 11), Color(0.45, 0.47, 0.6), true, "plain")
	# Frame around the arena (decor) + distant islands for depth.
	for s in [-1.0, 1.0]:
		b.box(Vector3(s * (half + 0.6), Y - 0.6, 0), Vector3(0.6, 0.6, half * 2 + 1.8), Color(0.2, 0.22, 0.3), false, "plain")
		b.box(Vector3(0, Y - 0.6, s * (half + 0.6)), Vector3(half * 2 + 1.8, 0.6, 0.6), Color(0.2, 0.22, 0.3), false, "plain")
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 14:
		var a := TAU * i / 14.0
		var d := rng.randf_range(90, 160)
		var w := rng.randf_range(10, 22)
		b.box(Vector3(cos(a) * d, rng.randf_range(-20, 10), sin(a) * d), Vector3(w, 4, w), COLORS[i % COLORS.size()].darkened(0.2), false, "decor")
	b.build()

	# Tiles: one MultiMesh for visuals + one body with a shape per tile.
	var tile_mesh := BoxMesh.new()
	tile_mesh.size = Vector3(TILE - 0.15, 0.6, TILE - 0.15)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.35
	mat.metallic_specular = 0.6
	mat.emission_enabled = true
	mat.emission = Color(0.08, 0.08, 0.08)
	tile_mesh.material = mat
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = tile_mesh
	_mm.instance_count = N * N
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	add_child(mmi)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var shape := BoxShape3D.new()
	shape.size = Vector3(TILE - 0.15, 0.6, TILE - 0.15)
	_tile_colors.resize(N * N)
	for i in N * N:
		var col := CollisionShape3D.new()
		col.shape = shape
		col.position = _tile_pos(i)
		body.add_child(col)
		_shapes.append(col)
	_apply_pattern(12345, 0)

	_board = Label3D.new()
	_board.font_size = 260
	_board.outline_size = 50
	_board.outline_modulate = Color(0.05, 0.05, 0.1)
	_board.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_board.position = Vector3(0, Y + 16, -half - 4)
	_board.text = "COLOR DROP"
	_board.modulate = Color(1, 1, 1)
	add_child(_board)


func _tile_pos(i: int) -> Vector3:
	var x := i % N
	var z := i / N
	var half := N * TILE * 0.5
	return Vector3(-half + (x + 0.5) * TILE, Y - 0.3, -half + (z + 0.5) * TILE)


func _apply_pattern(pattern_seed: int, target: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern_seed
	var count := 0
	for i in N * N:
		_tile_colors[i] = rng.randi() % COLORS.size()
		if _tile_colors[i] == target:
			count += 1
	while count < 12:
		var k := rng.randi() % (N * N)
		if _tile_colors[k] != target:
			_tile_colors[k] = target
			count += 1
	for i in N * N:
		_show_tile(i, true)


func _show_tile(i: int, visible_tile: bool) -> void:
	var pos := _tile_pos(i)
	if visible_tile:
		_mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos))
		_mm.set_instance_color(i, COLORS[_tile_colors[i]])
	else:
		_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.001), pos - Vector3(0, 60, 0)))
	_shapes[i].set_deferred("disabled", not visible_tile)


func _drop(target: int) -> void:
	for i in N * N:
		if _tile_colors[i] != target:
			_show_tile(i, false)


func on_player_ready(_p: Player) -> void:
	Game.checkpoint_position = spawn_point
	Game.player_died.connect(_on_player_died)


func apply_event(ev: Dictionary) -> void:
	match str(ev.get("t", "")):
		"waiting":
			_state = "waiting"
			_timer = float(ev.get("time", 8.0))
			_end_game(false)
		"round":
			var r := int(ev["round"])
			_color = int(ev["color"])
			_apply_pattern(int(ev["seed"]), _color)
			_state = "think"
			_timer = float(ev["think"])
			if r == 1 and player != null and not _playing:
				_start_playing()
			elif _playing:
				_survived = r - 1
			_board.text = NAMES[_color]
			_board.modulate = COLORS[_color]
			if _playing:
				Sfx.play("pop")
		"drop":
			_state = "drop"
			_drop(int(ev["color"]))
			_board.text = NAMES[int(ev["color"])] + "!"
		"ended":
			_state = "ended"
			if _playing:
				_survived = int(ev["round"])
				Sfx.play("win")
				_end_game(true)
		"snapshot":
			_state = "late"
			_color = int(ev.get("color", 0))
			_apply_pattern(int(ev.get("seed", 1)), _color)


func _start_playing() -> void:
	_playing = true
	_survived = 0
	var i := randi() % (N * N)
	player.teleport(_tile_pos(i) + Vector3(0, 0.8, 0))
	_toast("GET READY!", Color(1, 1, 1))


func _end_game(won: bool) -> void:
	if not _playing:
		return
	_playing = false
	var best := report_score("color_drop", _survived)
	if won:
		_toast("YOU SURVIVED ALL %d ROUNDS!%s" % [_survived, "  NEW BEST!" if best else ""], Color(1.0, 0.85, 0.3))
	if player != null:
		player.teleport(spawn_point)


func _on_player_died() -> void:
	if not _playing:
		return
	_playing = false
	var best := report_score("color_drop", _survived)
	_toast("OUT! You survived %d rounds%s" % [_survived, "  NEW BEST!" if best else ""], Color(1.0, 0.5, 0.4))


func _process(delta: float) -> void:
	_timer = maxf(_timer - delta, 0.0)
	match _state:
		"waiting":
			set_status("Game starts in %d..." % ceili(_timer), Color(1, 1, 1))
			_board.text = "COLOR DROP"
			_board.modulate = Color(1, 1, 1)
		"think":
			var who := "Go to" if _playing else "Next:"
			set_status("%s %s   %.1f" % [who, NAMES[_color], _timer], COLORS[_color])
		"drop":
			set_status("Hold on!" if _playing else "Spectating...", COLORS[_color])
		"ended":
			set_status("Game over!", Color(1.0, 0.85, 0.3))
		"late":
			set_status("Game in progress - you'll join the next one", Color(1, 1, 1))


func _toast(text: String, color: Color) -> void:
	if hud != null:
		hud.show_toast(text, color)
