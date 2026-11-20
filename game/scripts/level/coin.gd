class_name Coin
extends Area3D
## Spinning, bobbing collectible.

var _visual: MeshInstance3D
var _t: float = 0.0
var _taken: bool = false


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitorable = false
	_t = randf() * TAU

	_visual = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.45
	mesh.bottom_radius = 0.45
	mesh.height = 0.12
	mesh.radial_segments = 24
	_visual.mesh = mesh
	_visual.rotation.x = PI * 0.5
	_visual.material_override = Fx.metal_material(Color(1.0, 0.78, 0.15), 0.45)
	_visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_visual)

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.8
	shape.shape = sphere
	add_child(shape)

	Game.register_coin()
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _taken:
		return
	_t += delta
	_visual.rotation = Vector3(PI * 0.5, 0.0, _t * 3.0)
	_visual.position.y = sin(_t * 2.5) * 0.15


func _on_body_entered(body: Node3D) -> void:
	if _taken or not (body is Player):
		return
	_taken = true
	set_deferred("monitoring", false)
	Game.add_coin()
	Fx.burst(get_parent(), global_position, Color(1.0, 0.85, 0.25), 14, 5.0, 0.12, 0.5, -6.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_visual, "scale", Vector3(1.8, 1.8, 1.8), 0.15)
	tw.tween_property(_visual, "position:y", 1.2, 0.25)
	tw.chain().tween_property(_visual, "scale", Vector3.ZERO, 0.12)
	tw.chain().tween_callback(queue_free)
