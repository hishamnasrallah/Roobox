class_name PartVolume
extends Area3D
## Trigger volume for functional Studio parts.
##   kind "water"    - swim: slow fall, hold jump to swim up
##   kind "ladder"   - climb: push forward or hold jump to go up
##   kind "conveyor" - pushes the player along `direction`
##   kind "speed"    - speed boost for a few seconds
##   kind "teleport" - sends the player to `target`

@export var kind: String = "water"
var direction: Vector3 = Vector3.FORWARD
var speed: float = 6.0
var target: Vector3 = Vector3.INF
var _cooldown: float = 0.0


func setup(size: Vector3) -> void:
	collision_layer = 4
	collision_mask = 2
	monitorable = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	add_child(cs)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(body: Node3D) -> void:
	var p := body as Player
	if p == null:
		return
	match kind:
		"water":
			p.water_count += 1
		"ladder":
			p.climb_count += 1
		"speed":
			p.boost(3.0)
			Sfx.play("boing", -6.0, 1.6)
		"teleport":
			if _cooldown <= 0.0 and target.is_finite():
				p.teleport(target)
				_cooldown = 1.0


func _on_exit(body: Node3D) -> void:
	var p := body as Player
	if p == null:
		return
	match kind:
		"water":
			p.water_count = maxi(p.water_count - 1, 0)
		"ladder":
			p.climb_count = maxi(p.climb_count - 1, 0)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if kind != "conveyor":
		return
	for b in get_overlapping_bodies():
		var p := b as Player
		if p != null:
			p.external_velocity += global_transform.basis * direction * speed
