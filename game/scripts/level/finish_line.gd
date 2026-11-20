class_name FinishLine
extends Area3D
## Goal: golden trophy + arch. Celebrates with confetti.

@export var course_name: String = "Course"

var _trophy: Node3D
var _t: float = 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitorable = false

	var gold := Fx.metal_material(Color(1.0, 0.78, 0.2), 0.35)

	# Pedestal.
	var ped := MeshInstance3D.new()
	var ped_mesh := CylinderMesh.new()
	ped_mesh.top_radius = 1.1
	ped_mesh.bottom_radius = 1.3
	ped_mesh.height = 1.0
	ped.mesh = ped_mesh
	ped.position.y = 0.5
	ped.material_override = Fx.block_material(Color(0.95, 0.95, 1.0), false)
	add_child(ped)

	# Trophy (cup + handles + base).
	_trophy = Node3D.new()
	_trophy.position.y = 1.0
	_trophy.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_trophy)
	_add_cyl(_trophy, Vector3(0, 0.1, 0), 0.45, 0.55, 0.2, gold)
	_add_cyl(_trophy, Vector3(0, 0.45, 0), 0.12, 0.12, 0.5, gold)
	_add_cyl(_trophy, Vector3(0, 1.05, 0), 0.65, 0.3, 0.8, gold)
	_add_cyl(_trophy, Vector3(-0.7, 1.15, 0), 0.12, 0.12, 0.45, gold)
	_add_cyl(_trophy, Vector3(0.7, 1.15, 0), 0.12, 0.12, 0.45, gold)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.4)
	light.light_energy = 2.0
	light.omni_range = 7.0
	light.position.y = 2.6
	add_child(light)

	var label := Label3D.new()
	label.text = "FINISH"
	label.font_size = 160
	label.outline_size = 36
	label.modulate = Color(1.0, 0.85, 0.25)
	label.outline_modulate = Color(0.15, 0.08, 0.02)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 4.6
	add_child(label)

	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 2.4
	cyl.height = 4.0
	shape.shape = cyl
	shape.position.y = 2.0
	add_child(shape)

	body_entered.connect(_on_body_entered)


func _add_cyl(parent: Node3D, pos: Vector3, top: float, bottom: float, h: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	mi.mesh = m
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)


func _process(delta: float) -> void:
	_t += delta
	_trophy.rotation.y = _t * 1.2
	_trophy.position.y = 1.0 + sin(_t * 2.0) * 0.08


func _on_body_entered(body: Node3D) -> void:
	if not (body is Player) or Game.current_course != course_name:
		return
	Game.complete_course(course_name)
	for i in 4:
		var offset := Vector3(randf_range(-3, 3), 3.0 + randf() * 2.0, randf_range(-3, 3))
		Fx.burst(get_parent(), global_position + offset, Color(1, 0.3, 0.3), 40, 10.0, 0.18, 2.2, -7.0, true)
		await get_tree().create_timer(0.25).timeout
