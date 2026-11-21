class_name AvatarItems
extends RefCounted
## Avatar shop catalog. Every item is built from primitives at runtime,
## so the APK stays small. Slots: hat, face, neck, back (one item each).

const ITEMS: Array[Dictionary] = [
	{"id": "party_hat", "name": "Party Hat", "slot": "hat", "price": 50, "color": Color(1.0, 0.4, 0.7)},
	{"id": "beanie", "name": "Beanie", "slot": "hat", "price": 80, "color": Color(0.3, 0.55, 1.0)},
	{"id": "cap", "name": "Cap", "slot": "hat", "price": 100, "color": Color(0.95, 0.25, 0.3)},
	{"id": "headphones", "name": "Headphones", "slot": "hat", "price": 200, "color": Color(0.15, 0.15, 0.2)},
	{"id": "top_hat", "name": "Top Hat", "slot": "hat", "price": 250, "color": Color(0.1, 0.1, 0.12)},
	{"id": "cowboy", "name": "Cowboy Hat", "slot": "hat", "price": 300, "color": Color(0.55, 0.35, 0.18)},
	{"id": "horns", "name": "Viking Horns", "slot": "hat", "price": 400, "color": Color(0.95, 0.92, 0.8)},
	{"id": "crown", "name": "Crown", "slot": "hat", "price": 600, "color": Color(1.0, 0.8, 0.2)},
	{"id": "halo", "name": "Halo", "slot": "hat", "price": 800, "color": Color(1.0, 0.95, 0.5)},
	{"id": "glasses", "name": "Glasses", "slot": "face", "price": 90, "color": Color(0.2, 0.25, 0.4)},
	{"id": "sunglasses", "name": "Sunglasses", "slot": "face", "price": 150, "color": Color(0.05, 0.05, 0.08)},
	{"id": "scarf", "name": "Scarf", "slot": "neck", "price": 120, "color": Color(0.9, 0.3, 0.25)},
	{"id": "backpack", "name": "Backpack", "slot": "back", "price": 200, "color": Color(0.3, 0.6, 0.35)},
	{"id": "cape", "name": "Hero Cape", "slot": "back", "price": 450, "color": Color(0.85, 0.15, 0.2)},
	{"id": "wings", "name": "Angel Wings", "slot": "back", "price": 1000, "color": Color(1.0, 1.0, 1.0)},
]
const SLOTS: Array[String] = ["hat", "face", "neck", "back"]


static func get_item(id: String) -> Dictionary:
	for it in ITEMS:
		if it["id"] == id:
			return it
	return {}


static func exists(id: String) -> bool:
	return not get_item(id).is_empty()


## Attaches an item's meshes. `head` and `torso` are the avatar's joints
## (head origin = neck; torso origin = hips).
static func build(id: String, head: Node3D, torso: Node3D) -> void:
	var it := get_item(id)
	if it.is_empty():
		return
	var c: Color = it["color"]
	match id:
		"party_hat":
			_cone(head, Vector3(0, 0.8, 0), 0.22, 0.42, c)
			_ball(head, Vector3(0, 1.02, 0), 0.06, Color(1, 1, 0.4))
		"beanie":
			_box(head, Vector3(0, 0.66, 0.02), Vector3(0.64, 0.24, 0.62), c)
			_ball(head, Vector3(0, 0.82, 0.02), 0.08, c.lightened(0.4))
		"cap":
			_box(head, Vector3(0, 0.63, 0.02), Vector3(0.63, 0.16, 0.6), c)
			_box(head, Vector3(0, 0.57, -0.4), Vector3(0.58, 0.05, 0.32), c.darkened(0.2))
		"headphones":
			_box(head, Vector3(0, 0.64, 0), Vector3(0.68, 0.06, 0.12), c)
			_box(head, Vector3(-0.34, 0.32, 0), Vector3(0.1, 0.24, 0.24), c)
			_box(head, Vector3(0.34, 0.32, 0), Vector3(0.1, 0.24, 0.24), c)
		"top_hat":
			_cyl(head, Vector3(0, 0.62, 0), 0.42, 0.04, c)
			_cyl(head, Vector3(0, 0.87, 0), 0.26, 0.46, c)
			_cyl(head, Vector3(0, 0.7, 0), 0.265, 0.07, Color(0.8, 0.15, 0.2))
		"cowboy":
			_cyl(head, Vector3(0, 0.61, 0), 0.56, 0.04, c)
			_cyl(head, Vector3(0, 0.74, 0), 0.26, 0.24, c)
		"horns":
			_box(head, Vector3(0, 0.62, 0), Vector3(0.64, 0.1, 0.62), Color(0.55, 0.55, 0.6))
			for sx in [-1.0, 1.0]:
				var h := _cone(head, Vector3(sx * 0.36, 0.72, 0), 0.08, 0.34, c)
				h.rotation.z = -sx * 0.7
		"crown":
			var gold := Fx.metal_material(c, 0.3)
			_cyl(head, Vector3(0, 0.66, 0), 0.3, 0.12, c).material_override = gold
			for i in 6:
				var a := TAU * i / 6.0
				_box(head, Vector3(cos(a) * 0.26, 0.78, sin(a) * 0.26), Vector3(0.08, 0.14, 0.08), c).material_override = gold
		"halo":
			var t := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.2
			tm.outer_radius = 0.26
			t.mesh = tm
			t.position = Vector3(0, 0.9, 0)
			t.material_override = Fx.glow_material(c, 2.0)
			head.add_child(t)
		"glasses":
			for sx in [-1.0, 1.0]:
				_box(head, Vector3(sx * 0.13, 0.36, -0.3), Vector3(0.18, 0.13, 0.02), c)
			_box(head, Vector3(0, 0.38, -0.3), Vector3(0.08, 0.03, 0.02), c)
		"sunglasses":
			var m := _box(head, Vector3(0, 0.36, -0.3), Vector3(0.52, 0.11, 0.04), c)
			var sm := StandardMaterial3D.new()
			sm.albedo_color = c
			sm.metallic = 0.6
			sm.roughness = 0.1
			m.material_override = sm
		"scarf":
			_box(torso, Vector3(0, 0.8, 0), Vector3(0.72, 0.14, 0.5), c)
			_box(torso, Vector3(0.22, 0.6, -0.25), Vector3(0.14, 0.34, 0.04), c)
		"backpack":
			_box(torso, Vector3(0, 0.4, 0.33), Vector3(0.52, 0.6, 0.24), c)
			_box(torso, Vector3(0, 0.25, 0.46), Vector3(0.36, 0.22, 0.04), c.darkened(0.2))
		"cape":
			var cp := _box(torso, Vector3(0, 0.25, 0.26), Vector3(0.8, 1.05, 0.04), c)
			cp.rotation.x = 0.12
		"wings":
			for sx in [-1.0, 1.0]:
				var w := _box(torso, Vector3(sx * 0.5, 0.55, 0.32), Vector3(0.75, 0.5, 0.04), c)
				w.rotation = Vector3(0, -sx * 0.45, sx * 0.25)
				w.material_override = Fx.glow_material(c, 0.6)


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.4
	m.metallic_specular = 0.6
	return m


static func _box(parent: Node3D, pos: Vector3, size: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = pos
	mi.material_override = _mat(c)
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node3D, pos: Vector3, radius: float, height: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	mi.mesh = m
	mi.position = pos
	mi.material_override = _mat(c)
	parent.add_child(mi)
	return mi


static func _cone(parent: Node3D, pos: Vector3, radius: float, height: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = radius
	m.height = height
	mi.mesh = m
	mi.position = pos
	mi.material_override = _mat(c)
	parent.add_child(mi)
	return mi


static func _ball(parent: Node3D, pos: Vector3, radius: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	mi.mesh = m
	mi.position = pos
	mi.material_override = _mat(c)
	parent.add_child(mi)
	return mi
