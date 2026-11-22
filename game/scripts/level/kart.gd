class_name Kart
extends Node3D
## A drivable go-kart. Walk into it to get in, joystick / WASD to drive,
## jump to get out. The driver's own body does the driving; the kart model
## follows it (and follows remote drivers on other players' screens).

var index: int = 0
var color: Color = Color(1.0, 0.35, 0.35)
var max_speed: float = 22.0
var accel: float = 16.0
var brake: float = 30.0
var friction: float = 9.0
var turn: float = 2.3
var driver: Node3D = null

var _shape: CollisionShape3D


func _ready() -> void:
	add_to_group("karts")
	var paint := Fx.block_material(color)
	var dark := Fx.block_material(Color(0.12, 0.12, 0.15))
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 0.8, 3.6)
	_shape.shape = box
	_shape.position.y = 0.55
	body.add_child(_shape)
	_mesh(Vector3(0, 0.55, 0), Vector3(2.2, 0.5, 3.6), paint)
	_mesh(Vector3(0, 0.95, 0.5), Vector3(1.3, 0.35, 1.2), Fx.block_material(Color(0.15, 0.15, 0.2)))
	_mesh(Vector3(0, 1.25, 1.05), Vector3(1.3, 0.6, 0.15), paint)
	_mesh(Vector3(0, 1.0, -0.65), Vector3(0.12, 0.5, 0.12), dark)
	_mesh(Vector3(0, 1.25, -0.6), Vector3(0.7, 0.08, 0.08), dark)
	_mesh(Vector3(0, 0.75, -1.85), Vector3(2.0, 0.25, 0.15), Fx.glow_material(Color(1.0, 0.95, 0.7), 1.2))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_mesh(Vector3(sx * 1.2, 0.35, sz * 1.2), Vector3(0.45, 0.7, 0.75), dark)
	var area := Area3D.new()
	area.collision_layer = 4
	area.collision_mask = 2
	area.monitorable = false
	var acs := CollisionShape3D.new()
	var abox := BoxShape3D.new()
	abox.size = Vector3(2.6, 2.0, 4.0)
	acs.shape = abox
	acs.position.y = 1.0
	area.add_child(acs)
	add_child(area)
	area.body_entered.connect(_on_body)


func _mesh(at: Vector3, sz: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = m
	mi.position = at
	add_child(mi)


func _on_body(body: Node3D) -> void:
	if driver == null and body is Player:
		(body as Player).enter_vehicle(self)


func set_driver(d: Node3D) -> void:
	driver = d
	_shape.set_deferred("disabled", d != null)


func _process(_delta: float) -> void:
	if driver is Player and is_instance_valid(driver):
		var p := driver as Player
		global_position = p.get_global_transform_interpolated().origin
		rotation.y = p.car_yaw()


## Remote drivers: the kart follows their avatar.
func follow(pos: Vector3, yaw: float) -> void:
	global_position = pos
	rotation.y = yaw
