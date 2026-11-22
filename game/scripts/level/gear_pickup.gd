class_name GearPickup
extends Area3D
## A tool on a glowing stand. Touch it to put the tool in your backpack
## (see Tools). It comes back for the next player after a few seconds.

const RESPAWN := 6.0
## Kept for older code: tool id -> {name, color}.
const INFO := Tools.INFO

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
	var stand := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.55
	cm.bottom_radius = 0.65
	cm.height = 0.2
	stand.mesh = cm
	stand.material_override = Fx.glow_material(Tools.color(kind), 0.6)
	stand.position.y = -0.9
	add_child(stand)
	_visual = Node3D.new()
	add_child(_visual)
	var m := Tools.model(kind)
	m.position.y = -0.5
	_visual.add_child(m)
	var label := Label3D.new()
	label.text = Tools.label(kind)
	label.font_size = 48
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 1.2
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
	if Game.give_tool(kind):
		_cooldown = RESPAWN
		_visual.visible = false
