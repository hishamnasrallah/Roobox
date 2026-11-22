class_name Seat
extends Node3D
## A chair you sit on by walking into it. Jump to stand up.

var color: Color = Color(0.55, 0.38, 0.25)
var size: Vector3 = Vector3(2, 1, 2)


func _ready() -> void:
	var wood := Fx.block_material(color)
	var base := StaticBody3D.new()
	base.collision_layer = 1
	base.collision_mask = 0
	add_child(base)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, size.y * 0.5, size.z)
	cs.shape = box
	cs.position.y = -size.y * 0.25
	base.add_child(cs)
	_mesh(Vector3(0, -size.y * 0.25, 0), Vector3(size.x, size.y * 0.5, size.z), wood)
	_mesh(Vector3(0, size.y * 0.5, size.z * 0.42), Vector3(size.x, size.y * 1.2, size.z * 0.16), wood)
	var area := Area3D.new()
	area.collision_layer = 4
	area.collision_mask = 2
	area.monitorable = false
	var acs := CollisionShape3D.new()
	var abox := BoxShape3D.new()
	abox.size = Vector3(size.x * 0.8, 1.2, size.z * 0.8)
	acs.shape = abox
	acs.position.y = 0.5
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


## Where the sitter's feet go (the sit pose lowers the hips onto the seat).
func seat_point() -> Vector3:
	return global_position + Vector3(0, -0.3, 0) + global_basis * Vector3(0, 0, size.z * 0.1)


func _on_body(body: Node3D) -> void:
	if body is Player:
		(body as Player).sit_on(self)
