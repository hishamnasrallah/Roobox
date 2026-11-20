class_name TouchControls
extends Control
## Multi-touch mobile controls:
##  - left side: floating virtual joystick
##  - jump button bottom-right
##  - right side: drag to rotate camera, two-finger pinch to zoom

const JOY_RADIUS := 110.0
const KNOB_RADIUS := 46.0
const JUMP_RADIUS := 80.0
const DEADZONE := 0.12

var _joy_index: int = -1
var _joy_center: Vector2 = Vector2.ZERO
var _joy_knob: Vector2 = Vector2.ZERO
var _jump_index: int = -1
var _look_index: int = -1
var _pinch_index: int = -1
var _touch_pos: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	resized.connect(queue_redraw)


func _jump_center() -> Vector2:
	return Vector2(size.x - 175.0, size.y - 175.0)


func _joy_home() -> Vector2:
	return Vector2(200.0, size.y - 190.0)


func release_all() -> void:
	_joy_index = -1
	_jump_index = -1
	_look_index = -1
	_pinch_index = -1
	_touch_pos.clear()
	Game.touch_move = Vector2.ZERO
	Game.touch_jump_held = false
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		_on_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_on_drag(event as InputEventScreenDrag)


func _on_touch(t: InputEventScreenTouch) -> void:
	if t.pressed:
		_touch_pos[t.index] = t.position
		if _jump_index == -1 and t.position.distance_to(_jump_center()) < JUMP_RADIUS * 1.3:
			_jump_index = t.index
			Game.touch_jump_held = true
			Game.press_jump()
		elif _joy_index == -1 and t.position.x < size.x * 0.45:
			_joy_index = t.index
			_joy_center = t.position
			_joy_knob = t.position
		elif _look_index == -1:
			_look_index = t.index
		elif _pinch_index == -1:
			_pinch_index = t.index
	else:
		_touch_pos.erase(t.index)
		if t.index == _joy_index:
			_joy_index = -1
			Game.touch_move = Vector2.ZERO
		elif t.index == _jump_index:
			_jump_index = -1
			Game.touch_jump_held = false
		elif t.index == _look_index:
			_look_index = _pinch_index
			_pinch_index = -1
		elif t.index == _pinch_index:
			_pinch_index = -1
	queue_redraw()


func _on_drag(d: InputEventScreenDrag) -> void:
	var prev: Vector2 = _touch_pos.get(d.index, d.position)
	_touch_pos[d.index] = d.position

	if d.index == _joy_index:
		var off := d.position - _joy_center
		if off.length() > JOY_RADIUS:
			# Base follows the finger so the stick never "runs out".
			_joy_center += off.normalized() * (off.length() - JOY_RADIUS)
			off = d.position - _joy_center
		_joy_knob = d.position
		var v := off / JOY_RADIUS
		var mag := v.length()
		if mag < DEADZONE:
			v = Vector2.ZERO
		else:
			v = v.normalized() * inverse_lerp(DEADZONE, 1.0, minf(mag, 1.0))
		Game.touch_move = Vector2(v.x, -v.y)
		queue_redraw()
	elif d.index == _look_index or d.index == _pinch_index:
		if _look_index != -1 and _pinch_index != -1:
			var other_index := _pinch_index if d.index == _look_index else _look_index
			var other: Vector2 = _touch_pos.get(other_index, d.position)
			var before := prev.distance_to(other)
			var after := d.position.distance_to(other)
			Game.add_zoom(-(after - before) * 0.03)
		elif d.index == _look_index:
			Game.add_look_touch(d.position - prev)


func _draw() -> void:
	var white := Color(1, 1, 1)

	# Joystick.
	var active := _joy_index != -1
	var base := _joy_center if active else _joy_home()
	var knob := _joy_knob if active else base
	draw_circle(base, JOY_RADIUS, Color(1, 1, 1, 0.10 if not active else 0.16))
	draw_arc(base, JOY_RADIUS, 0.0, TAU, 64, Color(1, 1, 1, 0.35), 4.0, true)
	draw_circle(knob, KNOB_RADIUS, Color(1, 1, 1, 0.38 if not active else 0.6))

	# Jump button with an up arrow.
	var jc := _jump_center()
	var pressed := _jump_index != -1
	draw_circle(jc, JUMP_RADIUS * (0.92 if pressed else 1.0), Color(1, 1, 1, 0.32 if pressed else 0.16))
	draw_arc(jc, JUMP_RADIUS, 0.0, TAU, 64, Color(1, 1, 1, 0.45), 4.0, true)
	var arrow := PackedVector2Array([
		jc + Vector2(0, -34), jc + Vector2(30, 0), jc + Vector2(11, 0),
		jc + Vector2(11, 30), jc + Vector2(-11, 30), jc + Vector2(-11, 0),
		jc + Vector2(-30, 0),
	])
	draw_colored_polygon(arrow, Color(white, 0.85))
