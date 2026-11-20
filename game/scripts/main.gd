extends Node3D
## Entry point: assembles lighting, level, player, camera and HUD.

var level: ObbyLevel
var player: Player
var avatar: Avatar
var camera_rig: CameraRig
var hud: Hud
var _smoke_time: float = 0.0
var _smoke_done: bool = false


func _ready() -> void:
	_build_environment()

	level = ObbyLevel.new()
	level.name = "Level"
	add_child(level)

	player = Player.new()
	player.name = "Player"
	player.position = level.spawn_point
	level.add_child(player)

	avatar = Avatar.new()
	avatar.name = "Avatar"
	avatar.rotation.y = PI
	level.add_child(avatar)
	player.avatar = avatar

	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	camera_rig.target = player
	add_child(camera_rig)
	player.camera_rig = camera_rig
	camera_rig.snap()

	hud = Hud.new()
	add_child(hud)
	hud.refresh_coins()


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
	env.ambient_light_energy = 0.75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.84, 1.0)
	env.fog_density = 0.0022
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


## CI smoke test: in headless mode, report that the scene really ran.
func _process(delta: float) -> void:
	if _smoke_done or DisplayServer.get_name() != "headless":
		return
	_smoke_time += delta
	if _smoke_time >= 5.0:
		_smoke_done = true
		print("SMOKE OK coins=%d on_floor=%s player=%s" % [
			Game.total_coins, player.is_on_floor(), player.global_position.snapped(Vector3.ONE * 0.01)])
