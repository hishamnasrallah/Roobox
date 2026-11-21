class_name SpinningPart
extends AnimatableBody3D
## A part that keeps spinning around its vertical axis (Studio "SPIN").

@export var speed: float = 1.2


func _ready() -> void:
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0


func _physics_process(delta: float) -> void:
	rotation.y += speed * delta
