class_name Player
extends CharacterBody3D
## Responsive platformer controller: acceleration curves, coyote time,
## jump buffering, variable jump height, moving-platform support.
## The visual Avatar is a separate node that follows the
## physics-interpolated transform, so motion is smooth at any frame rate.

signal jumped
signal landed(impact_speed: float)
## Sword swing (main checks which other players were hit).
signal swung(origin: Vector3, forward: Vector3)

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

## Functional parts (see PartVolume).
var water_count: int = 0
var climb_count: int = 0
var external_velocity: Vector3 = Vector3.ZERO
var _boost_t: float = 0.0
## Seat or kart we are in (null = on foot).
var seat_node: Node3D = null
var vehicle: Kart = null
var _seat_cool: float = 0.0
var _car_speed: float = 0.0
var _car_yaw: float = 0.0
## Gear effects (from the held tool, see Tools).
var gear_speed: float = 1.0
var gear_gravity: float = 1.0
var max_health: float = 100.0
var health: float = 100.0
var _regen_wait: float = 0.0
var _swing_cool: float = 0.0
var _swing_flag: bool = false

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
	Game.emote_requested.connect(play_emote)
	Game.tool_used.connect(use_tool)
	Game.backpack_changed.connect(_on_backpack)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_seat_cool = maxf(_seat_cool - delta, 0.0)
	_swing_cool = maxf(_swing_cool - delta, 0.0)
	_update_tool_effects(delta)
	if seat_node != null:
		if not is_instance_valid(seat_node):
			leave_seat()
		elif vehicle != null:
			_drive(delta)
			return
		else:
			_sit(delta)
			return

	var on_floor := is_on_floor()
	if on_floor:
		_coyote = coyote_time
		_jumping = false
	else:
		_coyote -= delta

	# --- Horizontal movement relative to the camera ---
	var input := Game.get_move_input()
	if input.length() > 0.1 and avatar != null and avatar.emote != "":
		avatar.emote = ""
	var yaw := camera_rig.yaw if camera_rig != null else 0.0
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var wish := right * input.x + forward * input.y
	var speed_now := max_speed * gear_speed * (1.8 if _boost_t > 0.0 else 1.0)
	_boost_t = maxf(_boost_t - delta, 0.0)
	var target := wish * speed_now

	var accel := air_accel
	if on_floor:
		accel = ground_accel if wish.length_squared() > 0.0025 else ground_decel
	if _control_lock > 0.0:
		_control_lock -= delta
		accel *= 0.12

	var hv := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, accel * delta)
	velocity.x = hv.x
	velocity.z = hv.z

	# --- Gravity / swimming / climbing ---
	if climb_count > 0 and (input.y > 0.2 or Game.is_jump_held()):
		velocity.y = 5.5
	elif water_count > 0:
		velocity.y = maxf(velocity.y - gravity * 0.2 * delta, -3.0)
		if Game.is_jump_held():
			velocity.y = move_toward(velocity.y, 4.5, 25.0 * delta)
	elif not on_floor:
		var g := gravity * gear_gravity
		if velocity.y < 0.0:
			g *= fall_multiplier
		var max_fall := -4.0 if Game.held_tool_id() == "balloon" else -48.0
		velocity.y = maxf(velocity.y - g * delta, max_fall)

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
	var ext := external_velocity
	external_velocity = Vector3.ZERO
	velocity += ext
	move_and_slide()
	velocity -= ext
	if is_on_wall() and (on_floor or _was_on_floor) and wish.length_squared() > 0.01 and velocity.y <= 0.5:
		_try_step_up(wish.normalized())

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

	_send_net(delta)


func _send_net(delta: float) -> void:
	_net_timer += delta
	if _net_timer >= NET_RATE and Network.is_online():
		_net_timer = 0.0
		var flags := (1 if is_on_floor() else 0) | (2 if _dead else 0) | (emote_index() << 2)
		if vehicle != null:
			flags |= (vehicle.index + 1) << 7
		flags |= (Tools.LIST.find(Game.held_tool_id()) + 1) << 17
		if _swing_flag:
			flags |= 1 << 21
		var net_yaw := avatar.rotation.y if avatar != null else _target_yaw
		Network.send_state(global_position, net_yaw, get_real_velocity(), flags)


# -------------------------------------------------------- seats / karts ---

func sit_on(seat: Node3D) -> void:
	if seat_node != null or _seat_cool > 0.0 or _dead:
		return
	seat_node = seat
	velocity = Vector3.ZERO
	_target_yaw = seat.global_rotation.y
	if avatar != null:
		avatar.play_emote("sit")


func enter_vehicle(kart: Kart) -> void:
	if seat_node != null or _seat_cool > 0.0 or _dead or kart.driver != null:
		return
	seat_node = kart
	vehicle = kart
	kart.set_driver(self)
	global_position = kart.global_position + Vector3(0, 0.1, 0)
	_car_yaw = kart.global_rotation.y
	_car_speed = 0.0
	reset_physics_interpolation()
	if avatar != null:
		avatar.play_emote("sit")
	Game.notice.emit("Joystick to drive - JUMP to get out")


func leave_seat() -> void:
	if vehicle != null and is_instance_valid(vehicle):
		vehicle.set_driver(null)
		var side := Basis(Vector3.UP, _car_yaw) * Vector3(2.0, 0, 0)
		global_position += side + Vector3(0, 0.5, 0)
	elif seat_node != null and is_instance_valid(seat_node):
		global_position += seat_node.global_basis * Vector3(0, 0.5, -1.4)
	seat_node = null
	vehicle = null
	_seat_cool = 1.2
	velocity = Vector3(0, 6.0, 0)
	if avatar != null:
		avatar.emote = ""
	reset_physics_interpolation()


func car_yaw() -> float:
	return _car_yaw


func _sit(delta: float) -> void:
	var seat := seat_node as Seat
	global_position = seat.seat_point() if seat != null else seat_node.global_position
	velocity = Vector3.ZERO
	if avatar != null and avatar.emote != "sit":
		avatar.play_emote("sit")
	if Game.consume_jump() or Game.get_move_input().length() > 0.6:
		leave_seat()
	_send_net(delta)


func _drive(delta: float) -> void:
	var input := Game.get_move_input()
	var target := input.y * vehicle.max_speed
	var rate := vehicle.friction
	if absf(input.y) > 0.1:
		rate = vehicle.brake if signf(target) != signf(_car_speed) and absf(_car_speed) > 0.5 else vehicle.accel
	_car_speed = move_toward(_car_speed, target, rate * delta)
	_car_yaw -= input.x * vehicle.turn * delta * clampf(_car_speed / 6.0, -1.0, 1.0)
	var fwd := Vector3(-sin(_car_yaw), 0, -cos(_car_yaw))
	velocity.x = fwd.x * _car_speed
	velocity.z = fwd.z * _car_speed
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y = maxf(velocity.y - gravity * delta, -48.0)
	move_and_slide()
	if is_on_wall():
		_car_speed *= 0.5
	_target_yaw = _car_yaw
	if avatar != null and avatar.emote != "sit":
		avatar.play_emote("sit")
	if Game.consume_jump():
		leave_seat()
	if global_position.y < kill_height:
		leave_seat()
		Game.kill_player()
	_send_net(delta)


func _process(delta: float) -> void:
	if avatar == null:
		return
	var t := get_global_transform_interpolated()
	avatar.global_position = t.origin + (Vector3(0, 0.6, 0) if vehicle != null else Vector3.ZERO)
	if vehicle != null:
		avatar.rotation.y = _car_yaw
	avatar.rotation.y = lerp_angle(avatar.rotation.y, _target_yaw, 1.0 - exp(-turn_speed * delta))
	var hs := Vector2(velocity.x, velocity.z).length()
	avatar.animate(delta, hs / max_speed, is_on_floor() or _dead, velocity.y)


const STEP_HEIGHT := 0.65


## Climbs small ledges (stairs, single blocks) without jumping.
func _try_step_up(dir: Vector3) -> void:
	var xf := global_transform
	var up := Vector3(0, STEP_HEIGHT, 0)
	if test_move(xf, up):
		return
	var raised := xf.translated(up)
	if test_move(raised, dir * 0.3):
		return
	global_position += up + dir * 0.18
	move_and_collide(Vector3(0, -STEP_HEIGHT, 0))
	velocity.y = 0.0


## Old name kept for scripts/tests: puts the gear in the backpack.
func give_gear(kind: String) -> void:
	Game.give_tool(kind)
	var i := Game.backpack.find(kind)
	if i >= 0 and Game.held_tool != i:
		Game.equip_tool(i)
	_update_tool_effects(0.0)


# ---------------------------------------------------------------- tools ---

func _on_backpack() -> void:
	if avatar != null:
		avatar.set_tool(Game.held_tool_id())
	_update_tool_effects(0.0)


func _update_tool_effects(delta: float) -> void:
	var held := Game.held_tool_id()
	gear_speed = 1.6 if held == "speedcoil" else 1.0
	gear_gravity = 0.45 if held == "gravitycoil" else 1.0
	if health < max_health and not _dead:
		_regen_wait -= delta
		if _regen_wait <= 0.0:
			health = minf(health + 4.0 * delta, max_health)
			Game.health_changed.emit(health, max_health)


## USE button: swing the sword.
func use_tool() -> void:
	if _dead or Game.held_tool_id() != "sword" or _swing_cool > 0.0:
		return
	_swing_cool = 0.45
	_swing_flag = not _swing_flag
	if avatar != null:
		avatar.swing()
	Sfx.play("jump", -6.0, 1.6)
	var fwd := Vector3(-sin(_target_yaw), 0, -cos(_target_yaw))
	swung.emit(global_position + Vector3(0, 1, 0), fwd)


## Takes damage (sword hits, script traps). 0 health = respawn.
func damage(amount: float, _from: String = "") -> void:
	if _dead or amount <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	_regen_wait = 5.0
	Game.health_changed.emit(health, max_health)
	Sfx.play("hit", -4.0)
	if health <= 0.0:
		Game.kill_player()


## Plays an emote (wave, dance...). Moving cancels it.
func play_emote(id: String) -> void:
	if avatar == null or not (id in Game.EMOTES):
		return
	avatar.play_emote(id)
	if id != "":
		Game.award_badge("dancer")


func emote_index() -> int:
	if avatar == null:
		return 0
	return maxi(Game.EMOTES.find(avatar.emote), 0)


func get_speed_ratio() -> float:
	return Vector2(velocity.x, velocity.z).length() / max_speed


## Strong push (spinners, bumpers). Briefly reduces player control.
func knockback(v: Vector3) -> void:
	if _dead:
		return
	velocity = v
	_control_lock = 0.35
	_jumping = false


## Temporary speed boost (speed pads).
func boost(seconds: float) -> void:
	_boost_t = maxf(_boost_t, seconds)


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
	if seat_node != null:
		leave_seat()
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
	gear_speed = 1.0
	gear_gravity = 1.0
	health = max_health
	Game.health_changed.emit(health, max_health)
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
