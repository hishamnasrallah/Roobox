class_name GearPickup
extends Area3D
## Gear you pick up by touching it (like classic "coils"):
##   speedcoil   - run 60% faster until you respawn
##   gravitycoil - jump much higher (lower gravity) until you respawn
## The pickup hides for a few seconds after it is taken.

const RESPAWN := 6.0
const INFO := {
	"speedcoil": {"name": "SPEED COIL", "color": Color(1.0, 0.3, 0.3)},
	"gravitycoil": {"name": "GRAVITY COIL", "color": Color(0.35, 0.6, 1.0)},
}

var kind: String = "speedcoil"
var _visual: Node3D
var _t: float = 0.0
var _cooldown: float = 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitorable = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 2.2, 1.6)
	cs.shape = box
	add_child(cs)
	var col: Color = INFO.get(kind, INFO["speedcoil"])["color"]
	_visual = Node3D.new()
	add_child(_visual)
	for i in 4:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.28
		tm.outer_radius = 0.42
		ring.mesh = tm
		ring.material_override = Fx.glow_material(col, 1.6)
		ring.position.y = -0.45 + i * 0.3
		_visual.add_child(ring)
	var handle := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.1
	cm.bottom_radius = 0.1
	cm.height = 0.5
	handle.mesh = cm
	handle.material_override = Fx.metal_material(Color(0.8, 0.8, 0.85), 0.1)
	handle.position.y = -0.8
	_visual.add_child(handle)
	var label := Label3D.new()
	label.text = str(INFO.get(kind, INFO["speedcoil"])["name"])
	label.font_size = 48
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 1.0
	_visual.add_child(label)
	body_entered.connect(_on_body)


func _process(delta: float) -> void:
	_t += delta
	_visual.rotation.y = _t * 1.6
	_visual.position.y = sin(_t * 2.0) * 0.15
	if _cooldown > 0.0:
		_cooldown -= delta
		if _cooldown <= 0.0:
			_visual.visible = true


func _on_body(body: Node3D) -> void:
	if _cooldown > 0.0 or not (body is Player):
		return
	_cooldown = RESPAWN
	_visual.visible = false
	(body as Player).give_gear(kind)
