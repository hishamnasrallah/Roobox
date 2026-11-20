class_name WorldBuilder
extends RefCounted
## Batches thousands of static boxes into a few MultiMesh draw calls
## (grouped by spatial chunk + material kind) and puts their collision
## into one StaticBody3D per chunk. This is what makes a big world run
## smoothly on phones.

const CHUNK := 64.0
## Chunks further than this are not drawn (fog hides the cut).
const DRAW_DISTANCE := 340.0

var root: Node3D
var box_count: int = 0

var _batches: Dictionary = {}     # "kind|cx|cz" -> {xforms: Array, colors: PackedColorArray}
var _bodies: Dictionary = {}      # Vector2i -> StaticBody3D
var _shape_cache: Dictionary = {} # Vector3 -> BoxShape3D
var _materials: Dictionary = {}
var _unit_box := BoxMesh.new()


func _init(parent: Node3D) -> void:
	root = parent


## Adds a box. pos = center. rot = euler radians.
## kind: "tiled" (tile texture), "plain", "decor" (no shadow),
##       "ground" (tiled, always drawn, no shadow casting), "far" (always drawn).
func box(pos: Vector3, size: Vector3, color: Color, collide: bool = true,
		kind: String = "tiled", rot: Vector3 = Vector3.ZERO) -> void:
	var rb := Basis.from_euler(rot)
	var xf := Transform3D(rb * Basis.from_scale(size), pos)
	var ck := Vector2i(floori(pos.x / CHUNK), floori(pos.z / CHUNK))
	var key := "%s|%d|%d" % [kind, ck.x, ck.y]
	if not _batches.has(key):
		_batches[key] = {"xforms": [], "colors": PackedColorArray(), "kind": kind, "chunk": ck}
	var b: Dictionary = _batches[key]
	(b["xforms"] as Array).append(xf)
	var cols: PackedColorArray = b["colors"]
	cols.append(color)
	b["colors"] = cols
	box_count += 1

	if collide:
		var body := _body_for(ck)
		var col := CollisionShape3D.new()
		col.shape = _shape(size)
		col.transform = Transform3D(rb, pos)
		body.add_child(col)


## Creates the MultiMesh instances. Call once after adding everything.
func build() -> void:
	for key: String in _batches:
		var b: Dictionary = _batches[key]
		var xforms: Array = b["xforms"]
		var colors: PackedColorArray = b["colors"]
		var kind: String = b["kind"]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _unit_box
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, xforms[i])
			mm.set_instance_color(i, colors[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _material(kind)
		if kind == "decor" or kind == "far" or kind == "ground":
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if kind != "far" and kind != "ground":
			mmi.visibility_range_end = DRAW_DISTANCE
			mmi.visibility_range_end_margin = 30.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		root.add_child(mmi)
	_batches.clear()


func _body_for(ck: Vector2i) -> StaticBody3D:
	if _bodies.has(ck):
		return _bodies[ck] as StaticBody3D
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	_bodies[ck] = body
	return body


func _shape(size: Vector3) -> BoxShape3D:
	var k := size.snapped(Vector3.ONE * 0.01)
	if not _shape_cache.has(k):
		var s := BoxShape3D.new()
		s.size = k
		_shape_cache[k] = s
	return _shape_cache[k] as BoxShape3D


func _material(kind: String) -> StandardMaterial3D:
	if _materials.has(kind):
		return _materials[kind] as StandardMaterial3D
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.albedo_color = Color(1, 1, 1)
	m.roughness = 0.5
	m.metallic_specular = 0.5
	m.rim_enabled = true
	m.rim = 0.18
	m.rim_tint = 0.6
	if kind == "tiled" or kind == "ground":
		m.albedo_texture = Fx.tile_texture()
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(0.5, 0.5, 0.5)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_materials[kind] = m
	return m
