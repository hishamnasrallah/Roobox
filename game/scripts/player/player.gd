class_name Player
extends CharacterBody3D
## Responsive platformer controller: acceleration curves, coyote time,
## jump buffering, variable jump height, moving-platform support.
## The visual Avatar is a separate node that follows the
## physics-interpolated transform, so motion is smooth at any frame rate.

signal jumped
signal landed(impact_speed: float)

@export var max_speed: float = 8.5
@export var ground_accel: float = 75.0
@export var ground_decel: float = 60.0
@export var air_accel: float = 28.0
@export var jump_velocity: float = 12.0
@export var gravity: float = 32.0
@export var fall_multiplier: float = 1.45
@export var jump_cut: float = 0.5
@export var coyote_time: float = 0.12
@export var turn_speed: float = 14.0
@export var kill_height: float = -7.0

var avatar: Avatar = null
var camera_rig: CameraRig = null

var _coyote: float = 0.0
var _was_on_floor: bool = true
var _prev_vy: float = 0.0
var _jumping: bool = false
var _control_lock: float = 0.0
var _dead: bool = false
var _target_yaw: float = PI
var _net_timer: float = 0.0

const NET_RATE := 1.0 / 20.0


func _ready() -> void:
	Game.player = self
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50.0)
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_ADD_VELOCITY

	var shape := CapsuleShape3D.new()
	shape.radius = 0.45
	shape.height = 2.2
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = 1.1
	add_child(col)

	Game.player_died.connect(_on_died)


func _physics_process(delta: float) -> void:
	if _dead:
		return

	var on_floor := is_on_floor()
	if on_floor:
		_coyote = coyote_time
		_jumping = false
	else:
		_coyote -= delta

	# --- Horizontal movement relative to the camera ---
	var input := Game.get_move_input()
	var yaw := camera_rig.yaw if camera_rig != null else 0.0
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var wish := right * input.x + forward * input.y
	var target := wish * max_speed

	var accel := air_accel
	if on_floor:
		accel = ground_accel if wish.length_squared() > 0.0025 else ground_decel
	if _control_lock > 0.0:
		_control_lock -= delta
		accel *= 0.12

	var hv := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, accel * delta)
	velocity.x = hv.x
	velocity.z = hv.z

	# --- Gravity ---
	if not on_floor:
		var g := gravity
		if velocity.y < 0.0:
			g *= fall_multiplier
		velocity.y = maxf(velocity.y - g * delta, -48.0)

	# --- Jump (buffered + coyote) ---
	if _coyote > 0.0 and Game.consume_jump():
		velocity.y = jump_velocity
		_coyote = 0.0
		_jumping = true
		jumped.emit()
		Sfx.play("jump", -4.0)
		if avatar != null:
			avatar.on_jump()
		Fx.burst(get_parent(), global_position + Vector3(0, 0.1, 0), Color(1, 1, 1, 0.9), 8, 3.0, 0.14, 0.4, -4.0, false, 70.0)

	# Release early for a short hop.
	if _jumping and velocity.y > 0.0 and not Game.is_jump_held():
		velocity.y *= jump_cut
		_jumping = false

	_prev_vy = velocity.y
	move_and_slide()

	var now_on_floor := is_on_floor()
	if now_on_floor and not _was_on_floor:
		var impact := -_prev_vy
		landed.emit(impact)
		if avatar != null and impact > 3.0:
			avatar.on_land(impact)
		if impact > 9.0:
			Sfx.play("land", -6.0)
		if impact > 14.0:
			Fx.burst(get_parent(), global_position + Vector3(0, 0.1, 0), Color(1, 1, 1, 0.9), 12, 4.0, 0.16, 0.45, -6.0, false, 80.0)
	_was_on_floor = now_on_floor

	if hv.length_squared() > 0.25:
		_target_yaw = atan2(-hv.x, -hv.z)

	if global_position.y < kill_height:
		Game.kill_player()

	_net_timer += delta
	if _net_timer >= NET_RATE and Network.is_online():
		_net_timer = 0.0
		var flags := (1 if is_on_floor() else 0) | (2 if _dead else 0)
		var net_yaw := avatar.rotation.y if avatar != null else _target_yaw
		Network.send_state(global_position, net_yaw, get_real_velocity(), flags)


func _process(delta: float) -> void:
	if avatar == null:
		return
	var t := get_global_transform_interpolated()
	avatar.global_position = t.origin
	avatar.rotation.y = lerp_angle(avatar.rotation.y, _target_yaw, 1.0 - exp(-turn_speed * delta))
	var hs := Vector2(velocity.x, velocity.z).length()
	avatar.animate(delta, hs / max_speed, is_on_floor() or _dead, velocity.y)


func get_speed_ratio() -> float:
	return Vector2(velocity.x, velocity.z).length() / max_speed


## Strong push (spinners, bumpers). Briefly reduces player control.
func knockback(v: Vector3) -> void:
	if _dead:
		return
	velocity = v
	_control_lock = 0.35
	_jumping = false


## Vertical launch (jump pads).
func launch(strength: float) -> void:
	if _dead:
		return
	velocity.y = strength
	_coyote = 0.0
	_jumping = false
	if avatar != null:
		avatar.on_jump()


## Instantly move the player (portals, home button).
func teleport(pos: Vector3) -> void:
	Sfx.play("teleport")
	Fx.burst(get_parent(), global_position + Vector3(0, 1, 0), Color(0.6, 0.85, 1.0), 16, 5.0, 0.15, 0.6, -2.0)
	global_position = pos
	velocity = Vector3.ZERO
	_control_lock = 0.0
	reset_physics_interpolation()
	if avatar != null:
		avatar.global_position = pos
		avatar.on_land(10.0)
	Fx.burst(get_parent(), pos + Vector3(0, 1, 0), Color(0.6, 0.85, 1.0), 16, 5.0, 0.15, 0.6, -2.0)
	Game.notify_respawned()


func _on_died() -> void:
	if _dead:
		return
	_dead = true
	velocity = Vector3.ZERO
	Sfx.play("die")
	if Network.is_online():
		Network.send_state(global_position, _target_yaw, Vector3.ZERO, 2)
	var poof_pos := global_position + Vector3(0, 1.0, 0)
	if avatar != null:
		Fx.burst(get_parent(), poof_pos, avatar.shirt_color, 22, 7.0, 0.22, 0.9, -14.0)
		Fx.burst(get_parent(), poof_pos, avatar.skin_color, 10, 6.0, 0.2, 0.9, -14.0)
		avatar.visible = false
	await get_tree().create_timer(0.9).timeout
	_respawn()


func _respawn() -> void:
	global_position = Game.checkpoint_position
	velocity = Vector3.ZERO
	_control_lock = 0.0
	_was_on_floor = false
	reset_physics_interpolation()
	if avatar != null:
		avatar.global_position = global_position
		avatar.visible = true
		avatar.on_land(16.0)
	_dead = false
	Game.notify_respawned()
