class_name Fx
extends RefCounted
## Small helpers for materials and one-shot particle bursts.
## Everything is procedural so the APK stays tiny.

static var _tile_texture: ImageTexture = null
static var _particle_mesh_cache: Dictionary = {}


## Soft "toy plastic" material with a subtle world-space tile pattern.
static func block_material(color: Color, tiled: bool = true, roughness: float = 0.55) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic_specular = 0.4
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.6
	if tiled:
		m.albedo_texture = tile_texture()
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(0.5, 0.5, 0.5)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


static func glow_material(color: Color, energy: float = 1.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.roughness = 0.3
	return m


static func metal_material(color: Color, energy: float = 0.35) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.85
	m.roughness = 0.25
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


## 64x64 tile: flat face with a lighter bevel line, gives depth cues on floors.
static func tile_texture() -> ImageTexture:
	if _tile_texture != null:
		return _tile_texture
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.92, 0.92, 0.92))
	var edge := Color(1.0, 1.0, 1.0)
	var shade := Color(0.8, 0.8, 0.8)
	for i in size:
		for w in 3:
			img.set_pixel(i, w, edge)
			img.set_pixel(w, i, edge)
			img.set_pixel(i, size - 1 - w, shade)
			img.set_pixel(size - 1 - w, i, shade)
	img.generate_mipmaps()
	_tile_texture = ImageTexture.create_from_image(img)
	return _tile_texture


static func _particle_mesh(size: float) -> BoxMesh:
	var key := snappedf(size, 0.01)
	if _particle_mesh_cache.has(key):
		return _particle_mesh_cache[key] as BoxMesh
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * size
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	_particle_mesh_cache[key] = mesh
	return mesh


## Spawns a one-shot CPU particle burst that frees itself.
static func burst(parent: Node, pos: Vector3, color: Color, amount: int = 16,
		speed: float = 5.0, size: float = 0.18, lifetime: float = 0.7,
		gravity: float = -12.0, rainbow: bool = false, spread: float = 180.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = lifetime
	p.explosiveness = 0.95
	p.mesh = _particle_mesh(size)
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, gravity, 0)
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.7, 0.8))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	p.color = color
	if rainbow:
		p.hue_variation_min = -1.0
		p.hue_variation_max = 1.0
	p.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)
