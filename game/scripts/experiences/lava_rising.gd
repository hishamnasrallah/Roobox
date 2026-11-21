extends Experience
## Lava Rising: climb the floating tower, the lava keeps rising.
## Round timing and lava height come from LavaMode (the authority).

const HALF := 34.0
const LOBBY := Vector3(64, 0, 0)

var _b: WorldBuilder
var _lava: MeshInstance3D
var _lava_h: float = -1.0
var _target_h: float = -1.0
var _state: String = "waiting"
var _wait_left: float = 0.0
var _alive: bool = false
var _survive_t: float = 0.0
var _rng := RandomNumberGenerator.new()


func setup() -> void:
	_rng.seed = 4242
	_b = WorldBuilder.new(self)
	spawn_point = LOBBY + Vector3(0, 0.6, 3)
	kill_height = -25.0

	# Arena floor.
	_b.box(Vector3(0, -0.5, 0), Vector3(HALF * 2, 1, HALF * 2), Color(0.36, 0.34, 0.38), true, "tiled")
	_build_tower()

	# Lobby island.
	_b.box(LOBBY + Vector3(0, -0.5, 0), Vector3(20, 1, 20), Color(0.42, 0.76, 0.34), true, "tiled")
	_b.box(LOBBY + Vector3(0, -2.5, 0), Vector3(17, 3, 17), Color(0.55, 0.38, 0.25), true, "plain")
	var title := Label3D.new()
	title.text = "LAVA RISING"
	title.font_size = 200
	title.outline_size = 40
	title.modulate = Color(1.0, 0.55, 0.2)
	title.outline_modulate = Color(0.15, 0.05, 0.02)
	title.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	title.position = LOBBY + Vector3(0, 8, -6)
	add_child(title)
	_b.build()

	# Lava sheet.
	_lava = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(HALF * 2 + 2, 2.0, HALF * 2 + 2)
	_lava.mesh = mesh
	_lava.material_override = Fx.glow_material(Color(1.0, 0.33, 0.08), 2.4)
	_lava.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lava.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_lava)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.45, 0.15)
	light.light_energy = 2.5
	light.omni_range = 40.0
	_lava.add_child(light)
	light.position.y = 4.0
	_place_lava()


const START_PAD_TOP := 0.6


func _build_tower() -> void:
	# Start pad in the middle: everyone spawns here, the climb starts right next to it.
	_b.box(Vector3(0, START_PAD_TOP * 0.5, 0), Vector3(9, START_PAD_TOP, 9), Color(0.95, 0.95, 1.0), true, "tiled")
	var top := Vector3.ZERO
	for path in 2:
		top = _build_path(Vector3(0, START_PAD_TOP, 0), PI * path + _rng.randf_range(-0.3, 0.3), path)
	# Summit on the last path's top.
	_b.box(top + Vector3(0, 1.0, 0), Vector3(7, 0.8, 7), Color(1.0, 0.92, 0.6), true, "tiled")
	var flag := Label3D.new()
	flag.text = "SUMMIT"
	flag.font_size = 120
	flag.outline_size = 24
	flag.modulate = Color(1, 0.9, 0.4)
	flag.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	flag.position = top + Vector3(0, 5, 0)
	add_child(flag)


## One climbing path: platforms close together, gentle at first.
func _build_path(start: Vector3, ang: float, path: int) -> Vector3:
	var colors := World.PALETTE
	var p := start
	for i in 66:
		var early := i < 10
		ang += _rng.randf_range(0.35, 0.9)
		var step := _rng.randf_range(3.4, 3.9) if early else _rng.randf_range(3.6, 4.3)
		var rise := _rng.randf_range(0.8, 1.0) if early else _rng.randf_range(1.0, 1.35)
		if i == 0:
			step = 5.6
			rise = 0.7
		var next := p + Vector3(cos(ang) * step, rise, sin(ang) * step)
		if Vector2(next.x, next.z).length() > 25.0:
			ang += PI * 0.65
			next = p + Vector3(cos(ang) * step, rise, sin(ang) * step)
		p = next
		var s := 3.2 if i < 36 else 2.7
		_b.box(p - Vector3(0, 0.3, 0), Vector3(s, 0.6, s), colors[(i + path * 3) % colors.size()], true, "tiled")
		if i > 4 and _rng.randf() < 0.4:
			var side := p + Vector3(_rng.randf_range(-6, 6), _rng.randf_range(-1.0, 0.6), _rng.randf_range(-6, 6))
			if Vector2(side.x, side.z).length() < 30.0:
				_b.box(side - Vector3(0, 0.3, 0), Vector3(2.6, 0.6, 2.6), colors[(i + 5) % colors.size()], true, "tiled")
	return p


func on_player_ready(_p: Player) -> void:
	Game.checkpoint_position = spawn_point
	Game.player_died.connect(_on_player_died)


func apply_event(ev: Dictionary) -> void:
	match str(ev.get("t", "")):
		"lava":
			_target_h = float(ev["h"])
		"state":
			_state = str(ev["s"])
			_target_h = float(ev.get("h", _target_h))
			match _state:
				"waiting":
					_wait_left = float(ev.get("time", 8.0))
					_lava_h = _target_h
					_send_to_lobby()
				"running":
					if not bool(ev.get("late", false)):
						_join_round()
				"ended":
					if _alive:
						_alive = false
						Sfx.play("win")
						var best := report_score("lava_rising", int(_survive_t))
						_toast("YOU SURVIVED! %.0fs%s" % [_survive_t, "  NEW BEST!" if best else ""], Color(1.0, 0.85, 0.3))


func _join_round() -> void:
	_lava_h = _target_h
	if player == null:
		return
	_alive = true
	_survive_t = 0.0
	var a := randf() * TAU
	player.teleport(Vector3(cos(a) * 2.5, START_PAD_TOP + 0.6, sin(a) * 2.5))
	_toast("CLIMB! THE LAVA IS RISING", Color(1.0, 0.55, 0.2))


func _send_to_lobby() -> void:
	_alive = false
	if player != null and _in_arena(player.global_position):
		player.teleport(spawn_point)


func _in_arena(pos: Vector3) -> bool:
	return absf(pos.x) < HALF + 1.0 and absf(pos.z) < HALF + 1.0


func _on_player_died() -> void:
	if not _alive:
		return
	_alive = false
	var best := report_score("lava_rising", int(_survive_t))
	_toast("BURNED! You lasted %.1fs%s" % [_survive_t, "  NEW BEST!" if best else ""], Color(1.0, 0.45, 0.3))


func _process(delta: float) -> void:
	_lava_h = lerpf(_lava_h, _target_h, 1.0 - exp(-6.0 * delta))
	_place_lava()
	match _state:
		"waiting":
			_wait_left = maxf(_wait_left - delta, 0.0)
			set_status("Next round in %d..." % ceili(_wait_left), Color(1, 1, 1))
		"running":
			if _alive:
				_survive_t += delta
				set_status("LAVA %dm   -   You: %.1fs" % [int(_lava_h), _survive_t], Color(1.0, 0.6, 0.3))
			else:
				set_status("Spectating - lava at %dm. Wait for the next round!" % int(_lava_h), Color(1, 1, 1))
		"ended":
			set_status("Round over!", Color(1.0, 0.85, 0.3))
	if player != null and _alive and _state == "running":
		var pos := player.global_position
		if _in_arena(pos) and pos.y < _lava_h + 0.2:
			Game.kill_player()


func _place_lava() -> void:
	if _lava != null:
		_lava.position = Vector3(0, _lava_h - 1.0, 0)


func _toast(text: String, color: Color) -> void:
	if hud != null:
		hud.show_toast(text, color)
