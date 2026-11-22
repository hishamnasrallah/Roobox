class_name Tools
extends RefCounted
## Tools that go in the backpack (hotbar). Index in LIST is sent over the
## network so other players see what you hold.
##   sword       - USE to swing, hits players in front of you (25 damage)
##   flashlight  - a light in your hand
##   speedcoil   - run faster while held
##   gravitycoil - jump higher while held
##   balloon     - fall slowly while held

const LIST: Array[String] = ["sword", "flashlight", "speedcoil", "gravitycoil", "balloon"]
const INFO := {
	"sword": {"name": "SWORD", "color": Color(0.8, 0.85, 0.95), "use": true},
	"flashlight": {"name": "FLASHLIGHT", "color": Color(1.0, 0.95, 0.6), "use": false},
	"speedcoil": {"name": "SPEED COIL", "color": Color(1.0, 0.3, 0.3), "use": false},
	"gravitycoil": {"name": "GRAVITY COIL", "color": Color(0.35, 0.6, 1.0), "use": false},
	"balloon": {"name": "BALLOON", "color": Color(1.0, 0.4, 0.6), "use": false},
}
const SWORD_DAMAGE := 25.0
const SWORD_RANGE := 4.0


static func exists(id: String) -> bool:
	return INFO.has(id)


static func label(id: String) -> String:
	return str(INFO.get(id, {"name": id.to_upper()})["name"])


static func color(id: String) -> Color:
	return INFO.get(id, {"color": Color.WHITE})["color"]


static func usable(id: String) -> bool:
	return bool(INFO.get(id, {"use": false})["use"])


## The model of a tool (held in the hand or shown on a pickup), +Y = up.
static func model(id: String) -> Node3D:
	var root := Node3D.new()
	var col := color(id)
	match id:
		"sword":
			_box(root, Vector3(0, 0.75, 0), Vector3(0.1, 1.3, 0.04), Fx.metal_material(col, 0.15))
			_box(root, Vector3(0, 0.08, 0), Vector3(0.45, 0.08, 0.1), Fx.metal_material(Color(0.95, 0.75, 0.25), 0.2))
			_box(root, Vector3(0, -0.15, 0), Vector3(0.09, 0.36, 0.09), Fx.block_material(Color(0.35, 0.2, 0.1)))
		"flashlight":
			var body := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.11
			cm.bottom_radius = 0.08
			cm.height = 0.55
			body.mesh = cm
			body.material_override = Fx.block_material(Color(0.2, 0.2, 0.25))
			root.add_child(body)
			_box(root, Vector3(0, 0.29, 0), Vector3(0.2, 0.04, 0.2), Fx.glow_material(col, 2.0))
		"balloon":
			var ball := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.4
			sm.height = 0.9
			ball.mesh = sm
			ball.material_override = Fx.block_material(col, false, 0.2)
			ball.position.y = 1.8
			root.add_child(ball)
			_box(root, Vector3(0, 0.75, 0), Vector3(0.02, 1.5, 0.02), Fx.block_material(Color(1, 1, 1)))
		_:
			for i in 4:
				var ring := MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = 0.12
				tm.outer_radius = 0.2
				ring.mesh = tm
				ring.material_override = Fx.glow_material(col, 1.4)
				ring.position.y = i * 0.14
				root.add_child(ring)
	return root


static func _box(root: Node3D, at: Vector3, sz: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = m
	mi.position = at
	root.add_child(mi)
