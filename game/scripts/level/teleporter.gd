class_name Teleporter
extends Area3D
## Glowing portal pad: step on it to travel to `target`.

@export var target: Vector3 = Vector3.ZERO
@export var title: String = "PORTAL"
@export var color: Color = Color(0.4, 0.8, 1.0)

var _ring: MeshInstance3D
var _t: float = 0.0
var _cooldown: float = 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitorable = false

	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 2.2
	base_mesh.bottom_radius = 2.4
	base_mesh.height = 0.3
	base.mesh = base_mesh
	base.position.y = 0.15
	base.material_override = Fx.block_material(Color(0.2, 0.22, 0.3), false)
	add_child(base)

	var glow := MeshInstance3D.new()
	var glow_mesh := CylinderMesh.new()
	glow_mesh.top_radius = 1.8
	glow_mesh.bottom_radius = 1.8
	glow_mesh.height = 0.1
	glow.mesh = glow_mesh
	glow.position.y = 0.33
	glow.material_override = Fx.glow_material(color, 2.0)
	add_child(glow)

	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.6
	torus.outer_radius = 1.85
	_ring.mesh = torus
	_ring.material_override = Fx.glow_material(color.lightened(0.3), 2.5)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_ring)

	var label := Label3D.new()
	label.text = title
	label.font_size = 110
	label.outline_size = 26
	label.modulate = color.lightened(0.4)
	label.outline_modulate = Color(0.05, 0.06, 0.14)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 4.2
	add_child(label)

	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.8
	cyl.height = 2.0
	shape.shape = cyl
	shape.position.y = 1.0
	add_child(shape)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	_ring.position.y = 1.2 + sin(_t * 2.0) * 0.6
	_ring.rotation.y = _t


func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if player == null or _cooldown > 0.0:
		return
	_cooldown = 1.0
	Game.checkpoint_position = target
	Game.current_course = ""
	player.teleport(target)
