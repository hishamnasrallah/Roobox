class_name RemotePlayer
extends Node3D
## Another player seen over the network. Visual only.
## Snapshots are buffered and rendered ~120 ms in the past with
## interpolation, so movement looks smooth even with jittery networks.

const INTERP_DELAY := 0.12
const MAX_SNAPS := 30
const MAX_EXTRAPOLATE := 0.25

var peer_id: int = 0
var avatar: Avatar
var _label: Label3D
var _snaps: Array = []   # [time, pos, yaw, vel, flags]
var _was_dead: bool = false


func setup(id: int, info: Dictionary) -> void:
	peer_id = id
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	avatar = Avatar.new()
	avatar.apply_profile(info)
	avatar.visible = false
	add_child(avatar)
	_label = Label3D.new()
	_label.text = str(info.get("name", "Player"))
	_label.font_size = 64
	_label.outline_size = 14
	_label.modulate = Color(1, 1, 1)
	_label.outline_modulate = Color(0.05, 0.06, 0.12)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = false
	_label.position.y = 2.75
	_label.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	avatar.add_child(_label)


func push_state(pos: Vector3, yaw: float, vel: Vector3, flags: int) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if _snaps.is_empty():
		avatar.global_position = pos
		avatar.rotation.y = yaw
		avatar.visible = true
	_snaps.append([now, pos, yaw, vel, flags])
	if _snaps.size() > MAX_SNAPS:
		_snaps.pop_front()


func _process(delta: float) -> void:
	if _snaps.is_empty() or avatar == null:
		return
	var render_t := Time.get_ticks_msec() / 1000.0 - INTERP_DELAY
	var pos: Vector3
	var yaw: float
	var vel: Vector3
	var flags: int

	var first: Array = _snaps[0]
	var last: Array = _snaps[_snaps.size() - 1]
	if render_t <= float(first[0]):
		pos = first[1]
		yaw = first[2]
		vel = first[3]
		flags = first[4]
	elif render_t >= float(last[0]):
		var ahead := minf(render_t - float(last[0]), MAX_EXTRAPOLATE)
		var lv: Vector3 = last[3]
		pos = (last[1] as Vector3) + lv * ahead
		yaw = last[2]
		vel = lv
		flags = last[4]
	else:
		var i := _snaps.size() - 2
		while i > 0 and float((_snaps[i] as Array)[0]) > render_t:
			i -= 1
		var a: Array = _snaps[i]
		var b: Array = _snaps[i + 1]
		var span := maxf(float(b[0]) - float(a[0]), 0.0001)
		var k := clampf((render_t - float(a[0])) / span, 0.0, 1.0)
		pos = (a[1] as Vector3).lerp(b[1] as Vector3, k)
		yaw = lerp_angle(float(a[2]), float(b[2]), k)
		vel = (a[3] as Vector3).lerp(b[3] as Vector3, k)
		flags = b[4]
		# Drop snapshots we no longer need.
		while i > 1:
			_snaps.pop_front()
			i -= 1

	var dead := (flags & 2) != 0
	if dead and not _was_dead:
		Fx.burst(get_parent(), pos + Vector3(0, 1, 0), avatar.shirt_color, 18, 6.0, 0.2, 0.8, -12.0)
	_was_dead = dead
	avatar.visible = not dead
	avatar.global_position = pos
	avatar.rotation.y = yaw
	var hs := Vector2(vel.x, vel.z).length()
	avatar.auto_expire = false
	var vi := (flags >> 7) & 1023
	if vi > 0:
		avatar.global_position += Vector3(0, 0.6, 0)
		for k in get_tree().get_nodes_in_group("karts"):
			if (k as Kart).index == vi - 1 and not ((k as Kart).driver is Player):
				(k as Kart).follow(avatar.global_position - Vector3(0, 0.6, 0), avatar.rotation.y)
	var ei := (flags >> 2) & 15
	avatar.play_emote(Game.EMOTES[ei] if ei < Game.EMOTES.size() else "")
	avatar.animate(delta, hs / 8.5, (flags & 1) != 0, vel.y)
