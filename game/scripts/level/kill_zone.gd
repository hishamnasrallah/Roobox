class_name KillZone
extends Area3D
## Lava / kill bricks: touching it sends the player back to the last checkpoint.


func setup(size: Vector3) -> void:
	collision_layer = 4
	collision_mask = 2
	monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		Game.kill_player()
