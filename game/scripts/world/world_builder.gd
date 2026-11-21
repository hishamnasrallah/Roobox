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
var _unit_meshes: Dictionary = {}


func _init(parent: Node3D) -> void:
	root = parent


## Adds a box. pos = center. rot = euler radians.
## kind: "tiled" (tile texture), "plain", "decor" (no shadow),
##       "ground" (tiled, always drawn, no shadow casting), "far" (always drawn).
func box(pos: Vector3, size: Vector3, color: Color, collide: bool = true,
		kind: String = "tiled", rot: Vector3 = Vector3.ZERO) -> void:
	part("box", pos, size, color, collide, kind, rot)


## Adds a primitive. shape: "box", "ramp" (wedge, high side at -X), "ball", "cyl".
func part(shape: String, pos: Vector3, size: Vector3, color: Color, collide: bool = true,
		kind: String = "tiled", rot: Vector3 = Vector3.ZERO) -> void:
	var rb := Basis.from_euler(rot)
	var xf := Transform3D(rb * Basis.from_scale(size), pos)
	var ck := Vector2i(floori(pos.x / CHUNK), floori(pos.z / CHUNK))
	var key := "%s|%s|%d|%d" % [kind, shape, ck.x, ck.y]
	if not _batches.has(key):
		_batches[key] = {"xforms": [], "colors": PackedColorArray(), "kind": kind, "chunk": ck, "shape": shape}
	var b: Dictionary = _batches[key]
	(b["xforms"] as Array).append(xf)
	var cols: PackedColorArray = b["colors"]
	cols.append(color)
	b["colors"] = cols
	box_count += 1

	if collide:
		var body := _body_for(ck)
		var col := CollisionShape3D.new()
		col.shape = collision_shape(shape, size)
		col.transform = Transform3D(rb, pos)
		body.add_child(col)


## Collision only (no visual) - e.g. the solid core of a truss.
func collider(shape: String, pos: Vector3, size: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	var ck := Vector2i(floori(pos.x / CHUNK), floori(pos.z / CHUNK))
	var body := _body_for(ck)
	var col := CollisionShape3D.new()
	col.shape = collision_shape(shape, size)
	col.transform = Transform3D(Basis.from_euler(rot), pos)
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
		mm.mesh = unit_mesh(b["shape"])
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


## Collision shape for a primitive of the given size (cached).
func collision_shape(shape: String, size: Vector3) -> Shape3D:
	var k := "%s|%s" % [shape, size.snapped(Vector3.ONE * 0.01)]
	if _shape_cache.has(k):
		return _shape_cache[k] as Shape3D
	var s: Shape3D
	match shape:
		"corner":
			var cc := ConvexPolygonShape3D.new()
			var cpts := PackedVector3Array()
			for v in CORNER_POINTS:
				cpts.append((v as Vector3) * size)
			cc.points = cpts
			s = cc
		"ramp":
			var c := ConvexPolygonShape3D.new()
			var pts := PackedVector3Array()
			for v in [Vector3(-0.5, -0.5, -0.5), Vector3(-0.5, -0.5, 0.5), Vector3(0.5, -0.5, -0.5),
					Vector3(0.5, -0.5, 0.5), Vector3(-0.5, 0.5, -0.5), Vector3(-0.5, 0.5, 0.5)]:
				pts.append((v as Vector3) * size)
			c.points = pts
			s = c
		"cone":
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0
			cm.bottom_radius = maxf(size.x, size.z) * 0.5
			cm.height = size.y
			cm.radial_segments = 12
			s = cm.create_convex_shape()
		"ball":
			var sp := SphereShape3D.new()
			sp.radius = maxf(size.x, maxf(size.y, size.z)) * 0.5
			s = sp
		"cyl":
			var cy := CylinderShape3D.new()
			cy.radius = maxf(size.x, size.z) * 0.5
			cy.height = size.y
			s = cy
		_:
			var bx := BoxShape3D.new()
			bx.size = size
			s = bx
	_shape_cache[k] = s
	return s


## Unit-sized mesh for a primitive (cached).
func unit_mesh(shape: String) -> Mesh:
	if _unit_meshes.has(shape):
		return _unit_meshes[shape] as Mesh
	var m: Mesh
	match shape:
		"corner":
			m = corner_mesh()
		"ramp":
			var pm := PrismMesh.new()
			pm.left_to_right = 0.0
			pm.size = Vector3.ONE
			m = pm
		"ball":
			var sm := SphereMesh.new()
			sm.radius = 0.5
			sm.height = 1.0
			sm.radial_segments = 20
			sm.rings = 10
			m = sm
		"cyl":
			var cm := CylinderMesh.new()
			cm.top_radius = 0.5
			cm.bottom_radius = 0.5
			cm.height = 1.0
			cm.radial_segments = 20
			m = cm
		"cone":
			var co := CylinderMesh.new()
			co.top_radius = 0.0
			co.bottom_radius = 0.5
			co.height = 1.0
			co.radial_segments = 20
			m = co
		_:
			m = BoxMesh.new()
	_unit_meshes[shape] = m
	return m


## Corner wedge: square base, apex above the (+X, -Z) corner.
const CORNER_POINTS: Array[Vector3] = [
	Vector3(-0.5, -0.5, -0.5), Vector3(0.5, -0.5, -0.5), Vector3(0.5, -0.5, 0.5),
	Vector3(-0.5, -0.5, 0.5), Vector3(0.5, 0.5, -0.5),
]


## Built double-sided so it shows correctly whatever the winding convention.
static func corner_mesh() -> ArrayMesh:
	var p := CORNER_POINTS
	var tris := [[p[0], p[1], p[2]], [p[0], p[2], p[3]], [p[0], p[1], p[4]],
		[p[1], p[2], p[4]], [p[2], p[3], p[4]], [p[3], p[0], p[4]]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri: Array in tris:
		for order in [[0, 1, 2], [0, 2, 1]]:
			var a: Vector3 = tri[order[0]]
			var b: Vector3 = tri[order[1]]
			var c: Vector3 = tri[order[2]]
			var n := Plane(a, b, c).normal
			for v in [a, b, c]:
				st.set_normal(n)
				st.add_vertex(v)
	return st.commit()


func _material(kind: String) -> StandardMaterial3D:
	if _materials.has(kind):
		return _materials[kind] as StandardMaterial3D
	if kind.begins_with("mat:"):
		_materials[kind] = Materials.batch_material(kind.substr(4))
		return _materials[kind] as StandardMaterial3D
	if kind.begins_with("neon|"):
		_materials[kind] = Materials.material("neon", Color.html(kind.substr(5)))
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
