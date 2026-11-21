extends Node3D
## Entry point.
##   Normal:        menu (Discover) -> experience (solo / host / join / online)
##   --server:      dedicated headless server  [--experience id] [--port n]
##   --selftest:    automated input test (CI)
##   --modetest id: run an experience solo and check its round loop (CI)
##   --nettest:     automated multiplayer test client (CI)
##   --backendtest: Nakama integration test (CI)

var experience: Experience
var game_mode: GameMode
var player: Player
var avatar: Avatar
var camera_rig: CameraRig
var hud: Hud
var menu: MainMenu
var studio: Studio

var _menu_stage: Node3D
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
	if args.has("--shoptest"):
		add_child(load("res://scripts/debug/shop_test.gd").new())
		return
	if args.has("--backendtest"):
		var bt: Node = load("res://scripts/debug/backend_test.gd").new()
		bt.set("url", _arg(args, "--backend", "http://127.0.0.1:7350"))
		add_child(bt)
		return

	Game.reset_run()
	if args.has("--name"):
		Game.player_name = _arg(args, "--name", Game.player_name)
	_build_environment()

	Network.connection_failed.connect(_on_connection_failed)
	Network.disconnected.connect(_on_disconnected)
	Network.welcomed.connect(_on_welcomed)
	Network.player_joined.connect(_on_player_joined)
	Network.player_left.connect(_on_player_left)
	Network.state_received.connect(_on_state_received)
	Network.mode_event.connect(_on_network_mode_event)

	if Game.resume_studio != "":
		var resume := Game.resume_studio
		Game.resume_studio = ""
		_start_studio(resume)
	elif args.has("--studiotest"):
		_start_studio("")
		var st: Node = load("res://scripts/debug/studio_test.gd").new()
		st.set("main", self)
		add_child(st)
	elif args.has("--selftest"):
		_start_game("island")
		var t: Node = load("res://scripts/debug/self_test.gd").new()
		t.set("main", self)
		add_child(t)
	elif args.has("--modetest"):
		var exp_id := _arg(args, "--modetest", "lava_rising")
		_start_game(exp_id)
		var mt: Node = load("res://scripts/debug/mode_test.gd").new()
		mt.set("main", self)
		mt.set("exp_id", exp_id)
		add_child(mt)
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
	var exp_id := _arg(args, "--experience", Catalog.DEFAULT_ID)
	if not Catalog.has(exp_id):
		exp_id = Catalog.DEFAULT_ID
	var err := Network.start_dedicated(port, exp_id)
	if err != OK:
		printerr("[server] failed to start on port %d (error %d)" % [port, err])
		get_tree().quit(1)
		return
	_start_mode(exp_id)


func _start_mode(exp_id: String) -> void:
	game_mode = Catalog.create_mode(exp_id)
	if game_mode == null:
		Network.snapshot_provider = Callable()
		return
	game_mode.event.connect(_on_authority_event)
	Network.snapshot_provider = game_mode.snapshot
	add_child(game_mode)


func _on_authority_event(ev: Dictionary, reliable: bool) -> void:
	if experience != null:
		experience.apply_event(ev)
	Network.send_mode_event(ev, reliable)


func _on_network_mode_event(ev: Dictionary) -> void:
	if experience != null and Network.mode == "client":
		experience.apply_event(ev)


# --------------------------------------------------------------- menu ---

func _show_menu() -> void:
	_build_menu_stage()
	menu = MainMenu.new()
	add_child(menu)
	menu.play_requested.connect(_on_play_requested)
	menu.profile_changed.connect(_rebuild_preview)
	menu.studio_requested.connect(_start_studio)

	_menu_cam = Camera3D.new()
	_menu_cam.fov = 55
	_menu_cam.far = 1500
	_menu_cam.h_offset = -2.4
	add_child(_menu_cam)
	_menu_cam.make_current()
	_rebuild_preview()
	if Game.backend_url != "" and not Backend.online and not Backend.busy:
		Backend.connect_backend()


func _build_menu_stage() -> void:
	_menu_stage = Node3D.new()
	add_child(_menu_stage)
	var b := WorldBuilder.new(_menu_stage)
	b.box(Vector3(0, -1, 0), Vector3(40, 2, 40), World.GRASS, true, "ground")
	b.box(Vector3(0, -3.5, 0), Vector3(36, 3, 36), World.DIRT, false, "plain")
	b.box(Vector3(0, 0.1, 0), Vector3(6, 0.2, 6), World.STONE, false, "tiled")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 10:
		var a := TAU * i / 10.0
		var p := Vector3(cos(a) * rng.randf_range(10, 16), 0, sin(a) * rng.randf_range(10, 16))
		b.box(p + Vector3(0, 1.3, 0), Vector3(0.7, 2.6, 0.7), Color(0.45, 0.3, 0.18), false, "plain")
		b.box(p + Vector3(0, 3.2, 0), Vector3(3.0, 1.8, 3.0), World.LEAVES, false, "plain")
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		b.box(Vector3(cos(a) * 6.5, 0.6, sin(a) * 6.5), Vector3(1.2, 1.2, 1.2), World.PALETTE[i], false, "tiled",
			Vector3(0, a, 0))
	b.build()
	var ocean := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2000, 2000)
	ocean.mesh = plane
	ocean.position.y = -2.0
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.16, 0.47, 0.82)
	water.roughness = 0.06
	water.metallic = 0.3
	ocean.material_override = water
	_menu_stage.add_child(ocean)


func _rebuild_preview() -> void:
	if _preview != null:
		_preview.queue_free()
	_preview = Avatar.new()
	_preview.apply_profile(Game.profile())
	_preview.position = Vector3(0, 0.2, 0)
	add_child(_preview)


func _on_play_requested(exp_id: String, mode: String, address: String) -> void:
	match mode:
		"offline":
			Network.leave()
			Network.experience_id = exp_id
			_start_game(exp_id)
		"host":
			Network.experience_id = exp_id
			var err := Network.host()
			if err != OK:
				menu.show_status("Could not host a game (error %d). Is another game already hosting?" % err, true)
				return
			_start_game(exp_id)
		"online":
			menu.set_busy(true)
			menu.show_status("Finding a %s server..." % Catalog.get_entry(exp_id)["title"])
			var servers: Array = await Backend.game_servers(exp_id)
			if menu == null:
				return
			if servers.is_empty():
				menu.set_busy(false)
				menu.show_status("No online server for this game yet. Try SOLO or HOST.", true)
				return
			_on_play_requested(exp_id, "client", str(servers[0]))
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
		menu.show_status("Connection timed out. Check the address and that the server is running.", true)


func _on_welcomed(exp_id: String, snapshot: Dictionary) -> void:
	if _in_game:
		return
	if exp_id == "ugc":
		Game.pending_level = Level.sanitize(snapshot.get("level", {}))
		Game.testing = false
	_start_game(exp_id)
	if not snapshot.is_empty() and experience != null:
		experience.apply_event(snapshot)
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

func _clear_menu() -> void:
	for n: Node in [menu, _menu_cam, _preview, _menu_stage, studio]:
		if n != null:
			n.queue_free()
	menu = null
	_menu_cam = null
	_preview = null
	_menu_stage = null
	studio = null


# ------------------------------------------------------------- studio ---

func _start_studio(slot: String) -> void:
	_clear_menu()
	studio = Studio.new()
	studio.name = "Studio"
	if slot == "":
		studio.slot = Level.new_slot()
		studio.level = Level.new_level("%s's Game" % Game.player_name)
	else:
		studio.slot = slot
		studio.level = Level.load_slot(slot)
	studio.exit_requested.connect(func() -> void: Game.restart())
	studio.test_requested.connect(_on_studio_test)
	add_child(studio)


func _on_studio_test(level: Dictionary) -> void:
	Game.pending_level = level.duplicate(true)
	Game.testing = true
	Game.studio_slot = studio.slot
	Network.leave()
	_start_game("ugc")


func _start_game(exp_id: String) -> void:
	if _in_game:
		return
	_in_game = true
	_clear_menu()

	experience = Catalog.create(exp_id)
	add_child(experience)
	experience.setup()
	Game.spawn_point = experience.spawn_point
	Game.checkpoint_position = experience.spawn_point

	var spawn := experience.spawn_point
	if Network.is_online():
		spawn += Vector3(randf_range(-3, 3), 0, randf_range(-1.5, 1.5))

	player = Player.new()
	player.name = "Player"
	player.position = spawn
	player.kill_height = experience.kill_height
	experience.add_child(player)

	avatar = Avatar.new()
	avatar.name = "Avatar"
	avatar.apply_profile(Game.profile())
	avatar.rotation.y = PI
	experience.add_child(avatar)
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
	hud.menu_pressed.connect(_back_to_menu)
	hud.refresh_coins()

	experience.player = player
	experience.hud = hud
	experience.status_changed.connect(hud.set_mode_status)
	experience.on_player_ready(player)

	if Network.mode == "offline" or Network.mode == "host":
		_start_mode(exp_id)
	if exp_id == "ugc":
		Network.snapshot_provider = func() -> Dictionary: return {"t": "level", "level": Game.pending_level}

	var title: String = Catalog.get_entry(exp_id)["title"]
	match Network.mode:
		"host":
			var ips := Network.local_addresses()
			var ip_text := ", ".join(ips) if ips.size() > 0 else "this device"
			hud.set_info("HOSTING %s - friends join with IP: %s" % [title, ip_text])
			hud.add_chat_line("You are hosting %s. Share your IP: %s" % [title, ip_text], Color(0.6, 0.85, 1.0))
		"client":
			hud.set_info("%s - online" % title)

	for id: int in Network.players:
		if id != Network.my_id():
			_add_remote(id, Network.players[id])


func _back_to_menu() -> void:
	if Game.testing:
		Game.resume_studio = Game.studio_slot
		Game.testing = false
	Network.leave()
	if Backend.online:
		await Backend.push_progress()
	Game.restart()


func _go_home() -> void:
	if player == null:
		return
	Game.reset_checkpoint_to_spawn()
	player.kill_height = experience.kill_height
	player.teleport(experience.spawn_point)


# ------------------------------------------------------------ network ---

func _add_remote(id: int, info: Dictionary) -> void:
	if _remotes.has(id) or experience == null:
		return
	var rp := RemotePlayer.new()
	rp.name = "Remote_%d" % id
	experience.add_child(rp)
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
		hud.add_chat_line("Lost connection - press MENU to go back.", Color(1.0, 0.7, 0.5))
		hud.set_info("")


# ------------------------------------------------------------ process ---

func _process(delta: float) -> void:
	if _menu_cam != null and _preview != null:
		_menu_t += delta
		var target := _preview.global_position + Vector3(0, 1.3, 0)
		var ang := _menu_t * 0.15
		_menu_cam.global_position = target + Vector3(sin(ang) * 6.5, 1.4, cos(ang) * 6.5)
		_menu_cam.look_at(target)
		_preview.rotation.y = ang + PI * 0.15
		_preview.animate(delta, 0.0, true, 0.0)

	# CI smoke test: headless run without args opens the menu, then starts solo.
	if _headless and not _smoke_done and not OS.get_cmdline_user_args().has("--nettest"):
		_smoke_time += delta
		if menu != null and _smoke_time > 1.0:
			_on_play_requested(Catalog.DEFAULT_ID, "offline", "")
		if _smoke_time >= 5.0 and player != null:
			_smoke_done = true
			print("SMOKE OK experience=%s coins=%d on_floor=%s player=%s" % [
				experience.id, Game.total_coins, player.is_on_floor(),
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
