class_name JumpPad
extends Area3D
## Bouncy pad that launches the player upward.

@export var strength: float = 22.0
@export var color: Color = Color(0.2, 0.9, 1.0)

var _top: MeshInstance3D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitorable = false

	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 1.3
	base_mesh.bottom_radius = 1.45
	base_mesh.height = 0.3
	base.mesh = base_mesh
	base.position.y = 0.15
	base.material_override = Fx.block_material(Color(0.2, 0.22, 0.3), false)
	add_child(base)

	_top = MeshInstance3D.new()
	var top_mesh := CylinderMesh.new()
	top_mesh.top_radius = 1.05
	top_mesh.bottom_radius = 1.05
	top_mesh.height = 0.16
	_top.mesh = top_mesh
	_top.position.y = 0.36
	_top.material_override = Fx.glow_material(color, 1.6)
	add_child(_top)

	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.2
	cyl.height = 0.9
	shape.shape = cyl
	shape.position.y = 0.5
	add_child(shape)

	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if player == null:
		return
	player.launch(strength)
	Sfx.play("boing", 0.0, clampf(22.0 / strength, 0.7, 1.4))
	Fx.burst(get_parent(), global_position + Vector3(0, 0.5, 0), color, 18, 8.0, 0.16, 0.6, -10.0, false, 30.0)
	var tw := create_tween()
	tw.tween_property(_top, "scale", Vector3(1.2, 0.3, 1.2), 0.06)
	tw.tween_property(_top, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
