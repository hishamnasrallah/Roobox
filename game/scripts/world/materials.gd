class_name Materials
extends RefCounted
## Building materials with procedurally generated 16x16 pixel textures
## (original art, generated at runtime - nothing copied, no image files).
## "tint" materials take the part color; the others have their own look.

const LIST: Array[Dictionary] = [
	{"id": "plastic", "name": "PLASTIC", "tint": true, "ui": Color(0.9, 0.9, 0.95)},
	{"id": "grass", "name": "GRASS", "ui": Color(0.36, 0.7, 0.3)},
	{"id": "dirt", "name": "DIRT", "ui": Color(0.5, 0.34, 0.22)},
	{"id": "stone", "name": "STONE", "ui": Color(0.55, 0.56, 0.58)},
	{"id": "cobble", "name": "COBBLE", "ui": Color(0.45, 0.46, 0.48)},
	{"id": "planks", "name": "PLANKS", "ui": Color(0.72, 0.53, 0.32)},
	{"id": "log", "name": "LOG", "ui": Color(0.42, 0.29, 0.17)},
	{"id": "leaves", "name": "LEAVES", "ui": Color(0.2, 0.52, 0.2)},
	{"id": "sand", "name": "SAND", "ui": Color(0.92, 0.84, 0.6)},
	{"id": "snow", "name": "SNOW", "ui": Color(0.95, 0.97, 1.0)},
	{"id": "ice", "name": "ICE", "ui": Color(0.65, 0.85, 1.0)},
	{"id": "glass", "name": "GLASS", "ui": Color(0.75, 0.9, 1.0)},
	{"id": "brick", "name": "BRICK", "ui": Color(0.7, 0.3, 0.25)},
	{"id": "metal", "name": "METAL", "ui": Color(0.7, 0.72, 0.76)},
	{"id": "gold", "name": "GOLD", "ui": Color(1.0, 0.8, 0.25)},
	{"id": "basalt", "name": "BASALT", "ui": Color(0.2, 0.2, 0.23)},
	{"id": "wool", "name": "WOOL", "tint": true, "ui": Color(0.95, 0.95, 0.95)},
	{"id": "neon", "name": "NEON", "tint": true, "ui": Color(0.4, 1.0, 0.9)},
]

static var _textures: Dictionary = {}
static var _materials: Dictionary = {}


static func exists(id: String) -> bool:
	for m in LIST:
		if m["id"] == id:
			return true
	return false


static func info(id: String) -> Dictionary:
	for m in LIST:
		if m["id"] == id:
			return m
	return LIST[0]


static func is_tinted(id: String) -> bool:
	return bool(info(id).get("tint", false))


## Material for a single part (not batched).
static func material(id: String, tint: Color) -> StandardMaterial3D:
	var key := "%s|%s" % [id, tint.to_html()]
	if not _materials.has(key):
		_materials[key] = _make(id, tint, false)
	return _materials[key] as StandardMaterial3D


## Material for MultiMesh batches: the tint comes from the instance color.
static func batch_material(id: String) -> StandardMaterial3D:
	var key := "batch|" + id
	if not _materials.has(key):
		_materials[key] = _make(id, Color.WHITE, true)
	return _materials[key] as StandardMaterial3D


static func _make(id: String, tint: Color, batched: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.roughness = 0.85
	m.metallic_specular = 0.35
	if id == "plastic":
		m.albedo_texture = Fx.tile_texture()
		m.uv1_scale = Vector3(0.5, 0.5, 0.5)
		m.roughness = 0.5
		m.metallic_specular = 0.5
		m.rim_enabled = true
		m.rim = 0.18
	elif id == "neon":
		m.emission_enabled = true
		m.emission = tint
		m.emission_energy_multiplier = 2.2
		m.roughness = 0.3
	else:
		m.albedo_texture = texture(id)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		m.uv1_scale = Vector3.ONE
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	match id:
		"ice":
			m.roughness = 0.08
			m.metallic_specular = 0.8
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(1, 1, 1, 0.82)
		"glass":
			m.roughness = 0.05
			m.metallic_specular = 0.9
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(1, 1, 1, 0.35)
		"metal":
			m.metallic = 0.8
			m.roughness = 0.35
		"gold":
			m.metallic = 0.9
			m.roughness = 0.25
	if is_tinted(id):
		if batched:
			m.vertex_color_use_as_albedo = true
			m.vertex_color_is_srgb = true
		else:
			m.albedo_color = Color(tint, m.albedo_color.a)
	return m


# ------------------------------------------------------------ textures ---

static func texture(id: String) -> ImageTexture:
	if _textures.has(id):
		return _textures[id] as ImageTexture
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	match id:
		"grass":
			_noise(img, rng, Color(0.33, 0.66, 0.27), 0.12)
			for i in 26:
				img.set_pixel(rng.randi() % 16, rng.randi() % 16, Color(0.45, 0.8, 0.35))
		"dirt":
			_noise(img, rng, Color(0.5, 0.34, 0.22), 0.14)
			for i in 14:
				img.set_pixel(rng.randi() % 16, rng.randi() % 16, Color(0.36, 0.24, 0.15))
		"stone":
			_noise(img, rng, Color(0.55, 0.56, 0.58), 0.1)
			for i in 10:
				var x := rng.randi() % 15
				var y := rng.randi() % 16
				img.set_pixel(x, y, Color(0.42, 0.43, 0.45))
				img.set_pixel(x + 1, y, Color(0.42, 0.43, 0.45))
		"cobble":
			_noise(img, rng, Color(0.5, 0.5, 0.52), 0.12)
			var mortar := Color(0.3, 0.3, 0.32)
			for y in 16:
				for x in 16:
					var row := y / 5
					if y % 5 == 0 or (x + row * 3) % 6 == 0:
						img.set_pixel(x, y, mortar)
		"planks":
			for y in 16:
				for x in 16:
					var base := Color(0.72, 0.53, 0.32).darkened(rng.randf_range(0.0, 0.1))
					if y % 4 == 3:
						base = Color(0.48, 0.33, 0.18)
					elif (x + (y / 4) * 7) % 16 == 0:
						base = Color(0.55, 0.39, 0.22)
					img.set_pixel(x, y, base)
		"log":
			for y in 16:
				for x in 16:
					var c := Color(0.42, 0.29, 0.17)
					if x % 4 == 0:
						c = Color(0.32, 0.21, 0.12)
					img.set_pixel(x, y, c.darkened(rng.randf_range(0.0, 0.12)))
		"leaves":
			_noise(img, rng, Color(0.2, 0.52, 0.2), 0.2)
			for i in 30:
				img.set_pixel(rng.randi() % 16, rng.randi() % 16, Color(0.12, 0.35, 0.12))
		"sand":
			_noise(img, rng, Color(0.92, 0.84, 0.6), 0.06)
		"snow":
			_noise(img, rng, Color(0.95, 0.97, 1.0), 0.04)
			for i in 8:
				img.set_pixel(rng.randi() % 16, rng.randi() % 16, Color(0.85, 0.9, 1.0))
		"ice":
			_noise(img, rng, Color(0.65, 0.85, 1.0), 0.05)
			for i in 6:
				var x := rng.randi() % 14
				var y := rng.randi() % 14
				img.set_pixel(x, y, Color(0.9, 0.97, 1.0))
				img.set_pixel(x + 1, y + 1, Color(0.9, 0.97, 1.0))
		"glass":
			img.fill(Color(0.75, 0.9, 1.0))
			for i in 16:
				img.set_pixel(i, 0, Color.WHITE)
				img.set_pixel(0, i, Color.WHITE)
				img.set_pixel(i, 15, Color(0.85, 0.95, 1.0))
				img.set_pixel(15, i, Color(0.85, 0.95, 1.0))
			img.set_pixel(3, 3, Color.WHITE)
			img.set_pixel(4, 2, Color.WHITE)
		"brick":
			for y in 16:
				for x in 16:
					var c := Color(0.7, 0.3, 0.25).darkened(rng.randf_range(0.0, 0.15))
					var row := y / 4
					if y % 4 == 3 or (x + (row % 2) * 4) % 8 == 7:
						c = Color(0.82, 0.78, 0.72)
					img.set_pixel(x, y, c)
		"metal":
			for y in 16:
				var c := Color(0.68, 0.7, 0.74).darkened(rng.randf_range(0.0, 0.08))
				for x in 16:
					img.set_pixel(x, y, c.lightened(rng.randf_range(0.0, 0.04)))
			img.set_pixel(2, 2, Color(0.5, 0.5, 0.55))
			img.set_pixel(13, 13, Color(0.5, 0.5, 0.55))
		"gold":
			_noise(img, rng, Color(1.0, 0.8, 0.25), 0.1)
			for i in 6:
				img.set_pixel(rng.randi() % 16, rng.randi() % 16, Color(1.0, 0.95, 0.6))
		"basalt":
			_noise(img, rng, Color(0.2, 0.2, 0.23), 0.1)
			for i in 10:
				img.set_pixel(rng.randi() % 16, rng.randi() % 16, Color(0.32, 0.18, 0.12))
		"wool":
			_noise(img, rng, Color(0.95, 0.95, 0.95), 0.08)
		_:
			img.fill(Color.WHITE)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_textures[id] = tex
	return tex


static func _noise(img: Image, rng: RandomNumberGenerator, base: Color, amount: float) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var d := rng.randf_range(-amount, amount)
			img.set_pixel(x, y, Color(clampf(base.r + d, 0, 1), clampf(base.g + d, 0, 1), clampf(base.b + d, 0, 1)))
