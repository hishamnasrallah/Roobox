class_name CameraRig
extends Node3D
## Third-person orbit camera: drag to rotate, wheel/pinch to zoom,
## sphere-cast against the world so it never clips through walls.
## Runs at render rate using the player's interpolated transform.

@export var min_distance: float = 3.5
@export var max_distance: float = 18.0
@export var height_offset: float = 1.8
@export var base_fov: float = 70.0

var target: Player = null
var yaw: float = 0.0
var pitch: float = -0.32
var distance: float = 10.0

var camera: Camera3D
var _focus: Vector3 = Vector3.ZERO
var _dist_smooth: float = 10.0
var _hit_frac: float = 1.0
var _probe := SphereShape3D.new()


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_probe.radius = 0.3
	camera = Camera3D.new()
	camera.fov = base_fov
	camera.near = 0.1
	camera.far = 1500.0
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(camera)
	camera.make_current()
	Game.player_respawned.connect(snap)


func snap() -> void:
	if target == null:
		return
	_focus = target.global_position + Vector3(0, height_offset, 0)
	_hit_frac = 1.0


func _process(delta: float) -> void:
	if target == null:
		return

	var look := Game.consume_look()
	yaw = wrapf(yaw - look.x, -PI, PI)
	pitch = clampf(pitch - look.y, -1.3, 0.55)
	distance = clampf(distance + Game.consume_zoom() * 1.2, min_distance, max_distance)
	_dist_smooth = lerpf(_dist_smooth, distance, 1.0 - exp(-10.0 * delta))

	# Follow: tight horizontally, a little softer vertically (nicer jumps).
	var tp := target.get_global_transform_interpolated().origin + Vector3(0, height_offset, 0)
	_focus.x = tp.x
	_focus.z = tp.z
	_focus.y = lerpf(_focus.y, tp.y, 1.0 - exp(-12.0 * delta))

	var orbit := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var back := orbit * Vector3(0.0, 0.0, 1.0)
	var desired_offset := back * _dist_smooth

	# Wall avoidance: snap in fast, ease back out.
	var frac := 1.0
	var space := get_world_3d().direct_space_state
	if space != null:
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = _probe
		q.transform = Transform3D(Basis.IDENTITY, _focus)
		q.motion = desired_offset
		q.collision_mask = 1
		var res := space.cast_motion(q)
		if res.size() > 0:
			frac = res[0]
	if frac < _hit_frac:
		_hit_frac = frac
	else:
		_hit_frac = lerpf(_hit_frac, frac, 1.0 - exp(-4.0 * delta))

	camera.global_transform = Transform3D(orbit, _focus + desired_offset * _hit_frac)

	# Subtle speed FOV kick.
	var target_fov := base_fov + 7.0 * clampf(target.get_speed_ratio(), 0.0, 1.0)
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-4.0 * delta))
