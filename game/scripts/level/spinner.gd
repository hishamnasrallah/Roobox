class_name Spinner
extends Node3D
## Rotating sweeper bar. Touching the bar knocks the player away
## (tangential + upward push). Jump over it!

@export var length: float = 13.0
@export var speed: float = 1.6
@export var push_strength: float = 15.0

var _arm: Node3D


func _ready() -> void:
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.6
	pole_mesh.bottom_radius = 0.8
	pole_mesh.height = 1.6
	pole.mesh = pole_mesh
	pole.material_override = Fx.block_material(Color(0.25, 0.27, 0.35), false)
	pole.position.y = 0.8
	add_child(pole)

	_arm = Node3D.new()
	_arm.position.y = 0.85
	add_child(_arm)

	var bar := MeshInstance3D.new()
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(length, 0.45, 0.45)
	bar.mesh = bar_mesh
	bar.material_override = Fx.glow_material(Color(1.0, 0.25, 0.35), 0.9)
	_arm.add_child(bar)

	var cap := MeshInstance3D.new()
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.75
	cap_mesh.bottom_radius = 0.75
	cap_mesh.height = 0.6
	cap.mesh = cap_mesh
	cap.material_override = Fx.metal_material(Color(1.0, 0.8, 0.2), 0.2)
	_arm.add_child(cap)

	var area := Area3D.new()
	area.collision_layer = 4
	area.collision_mask = 2
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length, 0.6, 0.7)
	shape.shape = box
	area.add_child(shape)
	_arm.add_child(area)
	area.body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_arm.rotation.y += speed * delta


func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if player == null:
		return
	var radial := player.global_position - global_position
	radial.y = 0.0
	if radial.length_squared() < 0.01:
		radial = Vector3.FORWARD
	var tangent := Vector3.UP.cross(radial).normalized() * signf(speed)
	var push := (tangent * 0.85 + radial.normalized() * 0.4).normalized() * push_strength
	push.y = 7.5
	player.knockback(push)
	Fx.burst(get_parent(), player.global_position + Vector3(0, 1, 0), Color(1, 0.4, 0.45), 10, 5.0, 0.15, 0.5)
