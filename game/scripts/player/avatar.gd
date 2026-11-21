class_name Avatar
extends Node3D
## Blocky avatar built from primitives + fully procedural animation.
## Blends idle / walk / run / jump / fall smoothly, with squash & stretch,
## body lean and turn banking. Purely visual (no physics).

@export var skin_color: Color = Color(1.0, 0.8, 0.62)
@export var shirt_color: Color = Color(1.0, 0.55, 0.2)
@export var pants_color: Color = Color(0.2, 0.27, 0.55)
@export var shoe_color: Color = Color(0.95, 0.95, 0.97)

const HIP_HEIGHT := 0.85

## Equipped shop item ids (see AvatarItems).
var items: Array = []

var _body: Node3D        # lean + squash root (at feet)
var _hips: Node3D        # bobbing
var _torso: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D

var _phase: float = 0.0
var _time: float = 0.0
var _move_w: float = 0.0     # 0 idle .. 1 full speed
var _air_w: float = 0.0      # 0 grounded .. 1 airborne
var _squash: float = 0.0     # >0 squashed, <0 stretched
var _squash_vel: float = 0.0
var _bank: float = 0.0
var _last_yaw: float = 0.0


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_build()


## Set colors from a profile dictionary (call before adding to the tree).
func apply_profile(info: Dictionary) -> void:
	if info.get("shirt") is Color:
		shirt_color = info["shirt"]
	if info.get("pants") is Color:
		pants_color = info["pants"]
	if info.get("skin") is Color:
		skin_color = info["skin"]
	if info.get("items") is Array:
		items = (info["items"] as Array).duplicate()


func _build() -> void:
	var skin := _mat(skin_color)
	var shirt := _mat(shirt_color)
	var pants := _mat(pants_color)
	var shoes := _mat(shoe_color)
	var dark := _mat(Color(0.1, 0.1, 0.14))

	_body = Node3D.new()
	add_child(_body)

	_hips = Node3D.new()
	_hips.position.y = HIP_HEIGHT
	_body.add_child(_hips)

	# Legs (pivot at hip joint).
	_leg_l = _limb(_hips, Vector3(-0.21, 0.0, 0.0), Vector3(0.41, 0.86, 0.42), pants)
	_leg_r = _limb(_hips, Vector3(0.21, 0.0, 0.0), Vector3(0.41, 0.86, 0.42), pants)
	_box(_leg_l, Vector3(0, -0.78, -0.04), Vector3(0.4, 0.16, 0.48), shoes)
	_box(_leg_r, Vector3(0, -0.78, -0.04), Vector3(0.4, 0.16, 0.48), shoes)

	# Torso.
	_torso = Node3D.new()
	_hips.add_child(_torso)
	_box(_torso, Vector3(0, 0.4, 0), Vector3(0.84, 0.8, 0.44), shirt)
	# Hoodie pocket for a bit of detail.
	_box(_torso, Vector3(0, 0.18, -0.225), Vector3(0.5, 0.18, 0.02), _mat(shirt_color.darkened(0.15)))

	# Arms (pivot at shoulder).
	_arm_l = _limb(_torso, Vector3(-0.62, 0.72, 0.0), Vector3(0.39, 0.8, 0.42), shirt)
	_arm_r = _limb(_torso, Vector3(0.62, 0.72, 0.0), Vector3(0.39, 0.8, 0.42), shirt)
	_box(_arm_l, Vector3(0, -0.72, 0), Vector3(0.34, 0.16, 0.38), skin)
	_box(_arm_r, Vector3(0, -0.72, 0), Vector3(0.34, 0.16, 0.38), skin)

	# Head with a simple friendly face (front is -Z).
	_head = Node3D.new()
	_head.position = Vector3(0, 0.8, 0)
	_torso.add_child(_head)
	_box(_head, Vector3(0, 0.3, 0), Vector3(0.58, 0.56, 0.56), skin)
	_box(_head, Vector3(-0.13, 0.36, -0.285), Vector3(0.09, 0.14, 0.02), dark)
	_box(_head, Vector3(0.13, 0.36, -0.285), Vector3(0.09, 0.14, 0.02), dark)
	_box(_head, Vector3(0, 0.2, -0.285), Vector3(0.2, 0.05, 0.02), dark)
	# Hair cap.
	_box(_head, Vector3(0, 0.6, 0.03), Vector3(0.62, 0.1, 0.6), _mat(Color(0.25, 0.16, 0.1)))

	for id in items:
		AvatarItems.build(str(id), _head, _torso)


func _limb(parent: Node3D, pivot: Vector3, size: Vector3, mat: Material) -> Node3D:
	var joint := Node3D.new()
	joint.position = pivot
	parent.add_child(joint)
	_box(joint, Vector3(0, -size.y * 0.5 + 0.05, 0), size, mat)
	return joint


func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	# Glossy toy-plastic look.
	m.roughness = 0.32
	m.metallic_specular = 0.65
	m.rim_enabled = true
	m.rim = 0.22
	m.rim_tint = 0.5
	return m


# ------------------------------------------------------------- reactions ---

func on_jump() -> void:
	_squash = -0.22
	_squash_vel = 0.0


func on_land(impact_speed: float) -> void:
	_squash = clampf(impact_speed / 40.0, 0.06, 0.35)
	_squash_vel = 0.0


# ------------------------------------------------------------- animation ---

## Called every rendered frame by the player.
## speed_ratio: horizontal speed / max speed. vertical_speed: velocity.y.
func animate(delta: float, speed_ratio: float, on_floor: bool, vertical_speed: float) -> void:
	_time += delta
	var k_fast := 1.0 - exp(-12.0 * delta)
	var k_slow := 1.0 - exp(-6.0 * delta)

	_move_w = lerpf(_move_w, clampf(speed_ratio, 0.0, 1.0) if on_floor else 0.0, k_fast)
	_air_w = lerpf(_air_w, 0.0 if on_floor else 1.0, k_fast)

	# Gait cycle: faster steps when running.
	if _move_w > 0.02:
		_phase += delta * lerpf(5.0, 11.5, _move_w)
	else:
		_phase = lerpf(_phase, roundf(_phase / PI) * PI, k_slow)

	var s := sin(_phase)
	var stride := lerpf(0.55, 1.05, _move_w) * _move_w

	# --- Ground locomotion ---
	var leg_swing := s * stride
	var arm_swing := -s * stride * 0.85
	var bob := absf(cos(_phase)) * 0.09 * _move_w
	var breathe := sin(_time * 2.2) * 0.012 * (1.0 - _move_w)

	# --- Air pose (jump: arms up & out, falling: flail) ---
	var rising := clampf(vertical_speed / 8.0, -1.0, 1.0)
	var flail := sin(_time * 16.0) * 0.25 * clampf(-rising, 0.0, 1.0)
	var air_arm_z := lerpf(2.2, 1.4, clampf(-rising, 0.0, 1.0)) + flail
	var air_leg_l := 0.55
	var air_leg_r := -0.25

	_leg_l.rotation.x = lerpf(leg_swing, air_leg_l, _air_w)
	_leg_r.rotation.x = lerpf(-leg_swing, air_leg_r, _air_w)
	_arm_l.rotation.x = lerpf(arm_swing, 0.2, _air_w)
	_arm_r.rotation.x = lerpf(-arm_swing, 0.2, _air_w)
	_arm_l.rotation.z = lerpf(-0.06 - breathe * 2.0, -air_arm_z, _air_w)
	_arm_r.rotation.z = lerpf(0.06 + breathe * 2.0, air_arm_z, _air_w)

	_hips.position.y = HIP_HEIGHT + bob + breathe
	_torso.rotation.y = s * 0.12 * _move_w
	_torso.rotation.x = -0.1 * _move_w
	_head.rotation.y = -s * 0.1 * _move_w
	_head.rotation.x = 0.06 * _move_w + sin(_time * 1.3) * 0.02 * (1.0 - _move_w)

	# --- Banking into turns ---
	var yaw_vel := wrapf(rotation.y - _last_yaw, -PI, PI) / maxf(delta, 0.0001)
	_last_yaw = rotation.y
	_bank = lerpf(_bank, clampf(yaw_vel * 0.035, -0.22, 0.22) * _move_w, k_slow)
	_body.rotation.z = _bank
	_body.rotation.x = -0.08 * _move_w

	# --- Squash & stretch spring ---
	var accel := -_squash * 220.0 - _squash_vel * 16.0
	_squash_vel += accel * delta
	_squash += _squash_vel * delta
	var sq := clampf(_squash, -0.3, 0.4)
	_body.scale = Vector3(1.0 + sq * 0.5, 1.0 - sq, 1.0 + sq * 0.5)
