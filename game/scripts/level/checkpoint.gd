class_name Checkpoint
extends Area3D
## Respawn point. Turns green (and waves its flag) when reached.

@export var index: int = 1
## If set, touching this checkpoint (re)starts the named course timer.
@export var course_name: String = ""

var _pad_mat: StandardMaterial3D
var _flag: MeshInstance3D
var _active: bool = false
var _t: float = 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitorable = false

	var pad := MeshInstance3D.new()
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = 1.6
	pad_mesh.bottom_radius = 1.7
	pad_mesh.height = 0.2
	pad.mesh = pad_mesh
	pad.position.y = 0.1
	_pad_mat = Fx.glow_material(Color(0.55, 0.58, 0.7), 0.3)
	pad.material_override = _pad_mat
	add_child(pad)

	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.07
	pole_mesh.bottom_radius = 0.07
	pole_mesh.height = 3.2
	pole.mesh = pole_mesh
	pole.position = Vector3(1.3, 1.6, 0)
	pole.material_override = Fx.metal_material(Color(0.85, 0.85, 0.9), 0.0)
	add_child(pole)

	_flag = MeshInstance3D.new()
	var flag_mesh := BoxMesh.new()
	flag_mesh.size = Vector3(1.1, 0.7, 0.05)
	_flag.mesh = flag_mesh
	_flag.position = Vector3(1.3 - 0.6, 2.8, 0)
	_flag.material_override = Fx.glow_material(Color(0.6, 0.62, 0.72), 0.2)
	_flag.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_flag)

	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.7
	cyl.height = 3.0
	shape.shape = cyl
	shape.position.y = 1.5
	add_child(shape)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _active:
		_t += delta
		_flag.rotation.y = sin(_t * 4.0) * 0.18


func _on_body_entered(body: Node3D) -> void:
	if not (body is Player):
		return
	if course_name != "":
		Game.start_course(course_name)
	var spot := global_position + Vector3(0, 0.6, 0)
	if Game.checkpoint_position.distance_to(spot) > 0.5:
		Game.set_checkpoint(spot)
		_set_active(not _active)
	elif not _active:
		_set_active(false)


func _set_active(celebrate: bool) -> void:
	_active = true
	var green := Color(0.3, 1.0, 0.45)
	_pad_mat.albedo_color = green
	_pad_mat.emission = green
	_pad_mat.emission_energy_multiplier = 1.2
	var flag_mat := _flag.material_override as StandardMaterial3D
	flag_mat.albedo_color = green
	flag_mat.emission = green
	if celebrate:
		Fx.burst(get_parent(), global_position + Vector3(0, 1, 0), green, 24, 7.0, 0.16, 0.8, -8.0)
