extends Node3D
## Entry point.
##   Normal:      main menu -> game (solo / host / join)
##   --server:    dedicated headless server (also auto in "dedicated_server" exports)
##   --selftest:  automated input test (CI)
##   --nettest:   automated multiplayer test client (CI)

var world: World
var player: Player
var avatar: Avatar
var camera_rig: CameraRig
var hud: Hud
var menu: MainMenu

var _menu_cam: Camera3D
var _preview: Avatar
var _menu_t: float = 0.0
var _remotes: Dictionary = {}   # peer id -> RemotePlayer
var _in_game: bool = false
var _headless: bool = false
var _smoke_time: float = 0.0
var _smoke_done: bool = false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_headless = DisplayServer.get_name() == "headless"
	if OS.has_feature("dedicated_server") or args.has("--server"):
		_run_server(args)
		return

	Game.reset_run()
	if args.has("--name"):
		Game.player_name = _arg(args, "--name", Game.player_name)
	_build_environment()
	world = World.new()
	world.name = "World"
	add_child(world)
	Game.spawn_point = world.spawn_point
	Game.checkpoint_position = world.spawn_point

	Network.connection_succeeded.connect(_on_connection_succeeded)
	Network.connection_failed.connect(_on_connection_failed)
	Network.disconnected.connect(_on_disconnected)
	Network.player_joined.connect(_on_player_joined)
	Network.player_left.connect(_on_player_left)
	Network.state_received.connect(_on_state_received)

	if args.has("--selftest"):
		_start_game()
		var t: Node = load("res://scripts/debug/self_test.gd").new()
		t.set("main", self)
		add_child(t)
	elif args.has("--nettest"):
		var port := int(_arg(args, "--port", str(Network.DEFAULT_PORT)))
		Network.join("127.0.0.1", port)
	else:
		_show_menu()


func _arg(args: PackedStringArray, key: String, fallback: String) -> String:
	var i := args.find(key)
	if i >= 0 and i + 1 < args.size():
		return args[i + 1]
	return fallback


# ------------------------------------------------------------- server ---

func _run_server(args: PackedStringArray) -> void:
	Engine.max_fps = 60
	var port := int(_arg(args, "--port", str(Network.DEFAULT_PORT)))
	var err := Network.start_dedicated(port)
	if err != OK:
		printerr("[server] failed to start on port %d (error %d)" % [port, err])
		get_tree().quit(1)


# --------------------------------------------------------------- menu ---

func _show_menu() -> void:
	menu = MainMenu.new()
	add_child(menu)
	menu.play_requested.connect(_on_play_requested)
	menu.profile_changed.connect(_rebuild_preview)

	_menu_cam = Camera3D.new()
	_menu_cam.fov = 60
	_menu_cam.far = 1500
	_menu_cam.h_offset = -1.7
	add_child(_menu_cam)
	_menu_cam.make_current()
	_rebuild_preview()


func _rebuild_preview() -> void:
	if _preview != null:
		_preview.queue_free()
	_preview = Avatar.new()
	_preview.apply_profile(Game.profile())
	_preview.position = Vector3(world.spawn_point.x, 0.1, world.spawn_point.z)
	add_child(_preview)


func _on_play_requested(mode: String, address: String) -> void:
	match mode:
		"offline":
			Network.leave()
			_start_game()
		"host":
			var err := Network.host()
			if err != OK:
				menu.show_status("Could not host a game (error %d). Is another game already hosting?" % err, true)
				return
			_start_game()
		"client":
			var parsed := Network.parse_address(address)
			var err := Network.join(parsed[0], parsed[1])
			if err != OK:
				menu.show_status("Bad address (error %d)." % err, true)
				return
			menu.set_busy(true)
			menu.show_status("Connecting to %s:%d ..." % [parsed[0], parsed[1]])
			get_tree().create_timer(10.0).timeout.connect(_on_connect_timeout)


func _on_connect_timeout() -> void:
	if _in_game or Network.mode != "client":
		return
	Network.leave()
	if menu != null:
		menu.set_busy(false)
		menu.show_status("Connection timed out. Check the IP and that both devices are on the same Wi-Fi.", true)


func _on_connection_succeeded() -> void:
	if _in_game:
		return
	_start_game()
	if OS.get_cmdline_user_args().has("--nettest"):
		var t: Node = load("res://scripts/debug/net_test.gd").new()
		t.set("main", self)
		add_child(t)


func _on_connection_failed(reason: String) -> void:
	if OS.get_cmdline_user_args().has("--nettest"):
		print("NETTEST FAIL connection failed: ", reason)
		get_tree().quit(1)
		return
	if menu != null:
		menu.set_busy(false)
		menu.show_status(reason, true)


# --------------------------------------------------------------- game ---

func _start_game() -> void:
	if _in_game:
		return
	_in_game = true
	if menu != null:
		menu.queue_free()
		menu = null
	if _menu_cam != null:
		_menu_cam.queue_free()
		_menu_cam = null
	if _preview != null:
		_preview.queue_free()
		_preview = null

	var spawn := world.spawn_point
	if Network.is_online():
		spawn += Vector3(randf_range(-4, 4), 0, randf_range(-1.5, 1.5))

	player = Player.new()
	player.name = "Player"
	player.position = spawn
	world.add_child(player)

	avatar = Avatar.new()
	avatar.name = "Avatar"
	avatar.apply_profile(Game.profile())
	avatar.rotation.y = PI
	world.add_child(avatar)
	player.avatar = avatar

	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	camera_rig.target = player
	add_child(camera_rig)
	player.camera_rig = camera_rig
	camera_rig.snap()

	hud = Hud.new()
	add_child(hud)
	hud.home_pressed.connect(_go_home)
	hud.refresh_coins()

	match Network.mode:
		"host":
			var ips := Network.local_addresses()
			var ip_text := ", ".join(ips) if ips.size() > 0 else "this device"
			hud.set_info("HOSTING - friends join with IP: %s" % ip_text)
			hud.add_chat_line("You are hosting. Share your IP: %s" % ip_text, Color(0.6, 0.85, 1.0))
		"client":
			hud.set_info("Online: %s" % Game.server_address)

	for id: int in Network.players:
		if id != Network.my_id():
			_add_remote(id, Network.players[id])


func _go_home() -> void:
	if player == null:
		return
	Game.reset_checkpoint_to_spawn()
	player.teleport(world.spawn_point)


# ------------------------------------------------------------ network ---

func _add_remote(id: int, info: Dictionary) -> void:
	if _remotes.has(id) or world == null:
		return
	var rp := RemotePlayer.new()
	rp.name = "Remote_%d" % id
	world.add_child(rp)
	rp.setup(id, info)
	_remotes[id] = rp


func _on_player_joined(id: int, info: Dictionary) -> void:
	if _in_game and id != Network.my_id():
		_add_remote(id, info)


func _on_player_left(id: int) -> void:
	if _remotes.has(id):
		(_remotes[id] as Node).queue_free()
		_remotes.erase(id)


func _on_state_received(id: int, pos: Vector3, yaw: float, vel: Vector3, flags: int) -> void:
	if not _in_game or id == Network.my_id():
		return
	if not _remotes.has(id) and Network.players.has(id):
		_add_remote(id, Network.players[id])
	if _remotes.has(id):
		(_remotes[id] as RemotePlayer).push_state(pos, yaw, vel, flags)


func _on_disconnected() -> void:
	for id: int in _remotes:
		(_remotes[id] as Node).queue_free()
	_remotes.clear()
	if hud != null:
		hud.show_toast("DISCONNECTED", Color(1.0, 0.5, 0.4))
		hud.add_chat_line("Lost connection - you are playing solo now.", Color(1.0, 0.7, 0.5))
		hud.set_info("")


# ------------------------------------------------------------ process ---

func _process(delta: float) -> void:
	if _menu_cam != null and _preview != null:
		_menu_t += delta
		var target := _preview.global_position + Vector3(0, 1.3, 0)
		var ang := _menu_t * 0.18
		_menu_cam.global_position = target + Vector3(sin(ang) * 6.0, 1.2, cos(ang) * 6.0)
		_menu_cam.look_at(target)
		_preview.rotation.y = ang + PI * 0.15
		_preview.animate(delta, 0.0, true, 0.0)

	# CI smoke test: headless run without args opens the menu, then starts solo.
	if _headless and not _smoke_done and world != null:
		_smoke_time += delta
		if menu != null and _smoke_time > 1.0:
			_on_play_requested("offline", "")
		if _smoke_time >= 5.0 and player != null:
			_smoke_done = true
			print("SMOKE OK coins=%d boxes=%d on_floor=%s player=%s" % [
				Game.total_coins, world.b.box_count, player.is_on_floor(),
				player.global_position.snapped(Vector3.ONE * 0.01)])


# -------------------------------------------------------- environment ---

func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.47, 0.95)
	sky_mat.sky_horizon_color = Color(0.68, 0.84, 1.0)
	sky_mat.sky_curve = 0.12
	sky_mat.ground_bottom_color = Color(0.16, 0.38, 0.7)
	sky_mat.ground_horizon_color = Color(0.68, 0.84, 1.0)
	sky_mat.sun_angle_max = 20.0
	sky_mat.sun_curve = 0.1

	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.84, 1.0)
	env.fog_density = 0.0016
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.04

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_fade_start = 0.85
	add_child(sun)
