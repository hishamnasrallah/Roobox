class_name MovingPlatform
extends AnimatableBody3D
## Smooth ping-pong platform. Players standing on it are carried
## automatically by CharacterBody3D platform handling.

@export var travel: Vector3 = Vector3(8, 0, 0)
@export var period: float = 4.0
@export var phase: float = 0.0

var _origin: Vector3
var _t: float = 0.0


func _ready() -> void:
	_origin = position
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0


func _physics_process(delta: float) -> void:
	_t += delta
	var k := 0.5 - 0.5 * cos((_t / period + phase) * TAU)
	position = _origin + travel * k
