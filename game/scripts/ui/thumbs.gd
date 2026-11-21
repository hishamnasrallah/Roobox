class_name Thumbs
extends Node
## Renders real 3D thumbnails of levels (games, creations, Studio parts)
## in an off-screen SubViewport, one at a time, and caches them as JPGs in
## user://thumbs so they are instant the next time.
##
##   Thumbs.request("lib_g:obby:meadow", provider, callback, Vector2i(400, 225))
## provider: Callable() -> Dictionary (the level, only called if needed)
## callback: Callable(texture: Texture2D) (skipped if its object is gone)
##
## On a headless build (CI, dedicated server) nothing is rendered; cards
## keep their drawn fallback art.

const DIR := "user://thumbs"
const VERSION := 3

static var _inst: Thumbs = null
static var _mem: Dictionary = {}

var _queue: Array = []
var _busy: bool = false


static func enabled() -> bool:
	return DisplayServer.get_name() != "headless"


static func request(key: String, provider: Callable, callback: Callable, px: Vector2i = Vector2i(400, 225)) -> void:
	var full := "%s_v%d_%dx%d" % [key.validate_filename(), VERSION, px.x, px.y]
	if _mem.has(full):
		callback.call(_mem[full])
		return
	if not enabled():
		return
	var path := "%s/%s.jpg" % [DIR, full]
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			var tex := ImageTexture.create_from_image(img)
			_remember(full, tex)
			callback.call(tex)
			return
	if _inst == null or not is_instance_valid(_inst):
		_inst = Thumbs.new()
		_inst.name = "Thumbs"
		var tree := Engine.get_main_loop() as SceneTree
		tree.root.add_child.call_deferred(_inst)
	_inst._queue.append({"key": full, "path": path, "provider": provider, "callback": callback, "px": px})
	_inst.set_process(true)


## Small memory cache (oldest entries are dropped; the disk cache stays).
static func _remember(key: String, tex: Texture2D) -> void:
	_mem[key] = tex
	while _mem.size() > 80:
		_mem.erase(_mem.keys()[0])


## Drops queued work (e.g. when a game starts).
static func cancel_all() -> void:
	if _inst != null and is_instance_valid(_inst):
		_inst._queue.clear()


func _process(_delta: float) -> void:
	if _busy:
		return
	if _queue.is_empty():
		set_process(false)
		return
	var job: Dictionary = _queue.pop_front()
	var cb: Callable = job["callback"]
	if not cb.is_valid():
		return
	if _mem.has(job["key"]):
		cb.call(_mem[job["key"]])
		return
	_render(job)


func _render(job: Dictionary) -> void:
	_busy = true
	var level: Dictionary = (job["provider"] as Callable).call()
	var px: Vector2i = job["px"]
	var vp := SubViewport.new()
	vp.size = px
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	_environment(world, str(level.get("env", "day")))
	var shot := LevelPreview.build(world, level)
	var cam := Camera3D.new()
	cam.fov = 48.0
	cam.far = 900.0
	world.add_child(cam)
	cam.look_at_from_position(shot["eye"], shot["target"], Vector3.UP)
	cam.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	if img != null and not img.is_empty():
		img.convert(Image.FORMAT_RGB8)
		DirAccess.make_dir_recursive_absolute(DIR)
		img.save_jpg(job["path"], 0.86)
		var tex := ImageTexture.create_from_image(img)
		_remember(job["key"], tex)
		var cb: Callable = job["callback"]
		if cb.is_valid():
			cb.call(tex)
	vp.queue_free()
	_busy = false


static func _environment(parent: Node3D, preset: String) -> void:
	var top := Color(0.22, 0.47, 0.95)
	var horizon := Color(0.68, 0.84, 1.0)
	var ground := Color(0.16, 0.38, 0.7)
	var sun_col := Color(1.0, 0.96, 0.88)
	var sun_e := 1.3
	var ambient := 0.85
	match preset:
		"sunset":
			top = Color(0.25, 0.28, 0.6)
			horizon = Color(1.0, 0.58, 0.32)
			ground = Color(0.35, 0.22, 0.3)
			sun_col = Color(1.0, 0.7, 0.45)
			sun_e = 1.05
			ambient = 0.7
		"night":
			top = Color(0.01, 0.02, 0.07)
			horizon = Color(0.09, 0.12, 0.26)
			ground = Color(0.02, 0.03, 0.08)
			sun_col = Color(0.6, 0.7, 1.0)
			sun_e = 0.45
			ambient = 0.5
		"space":
			top = Color(0.0, 0.0, 0.03)
			horizon = Color(0.14, 0.05, 0.24)
			ground = Color(0.0, 0.0, 0.02)
			ambient = 0.55
		"fog":
			top = Color(0.6, 0.64, 0.7)
			horizon = Color(0.75, 0.78, 0.82)
			ground = Color(0.6, 0.62, 0.66)
			sun_e = 0.7
			ambient = 0.95
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_horizon_color = horizon
	sky_mat.ground_bottom_color = ground
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = ambient
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = sun_col
	sun.light_energy = sun_e
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	parent.add_child(sun)
