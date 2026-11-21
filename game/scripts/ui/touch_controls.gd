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
const TAP_TIME := 0.3
const TAP_MOVE := 18.0

## A quick touch on the right side (camera area) that didn't drag.
signal tapped(screen_pos: Vector2)
## Two-finger drag (Studio camera pan), in pixels.
signal panned(delta: Vector2)

## Studio hides the jump button.
var show_jump: bool = true
## Studio has no joystick: one finger orbits/taps anywhere, two fingers
## pinch to zoom and drag to pan.
var joystick_enabled: bool = true
## Optional "grab" hooks (Studio transform handles):
## grab_begin(pos) -> bool claims the touch; then grab_move(pos), grab_end().
var grab_begin: Callable = Callable()
var grab_move: Callable = Callable()
var grab_end: Callable = Callable()
var _grab_index: int = -1
## UI panels where touches must not start joystick/camera input.
var blockers: Array[Control] = []
var _look_start: Vector2 = Vector2.ZERO
var _look_start_t: float = 0.0
var _look_moved: float = 0.0

var _joy_index: int = -1
var _joy_center: Vector2 = Vector2.ZERO
var _joy_knob: Vector2 = Vector2.ZERO
var _jump_index: int = -1
var _look_index: int = -1
var _pinch_index: int = -1
var _touch_pos: Dictionary = {}


func _ready() -> void:
	# NOTE: must also reset offsets; plain set_anchors_preset() inside the tree
	# keeps the old (zero) size, which made the controls dead on device.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	resized.connect(queue_redraw)


func _screen() -> Vector2:
	if size.x > 1.0 and size.y > 1.0:
		return size
	return get_viewport_rect().size


func _jump_center() -> Vector2:
	var s := _screen()
	return Vector2(s.x - 175.0, s.y - 175.0)


func _joy_home() -> Vector2:
	return Vector2(200.0, _screen().y - 190.0)


func release_all() -> void:
	if _grab_index != -1 and grab_end.is_valid():
		grab_end.call()
	_grab_index = -1
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


## Top strip is reserved for HUD buttons (chat, home).
const TOP_RESERVED := 120.0


func _on_touch(t: InputEventScreenTouch) -> void:
	if t.pressed:
		if t.position.y < TOP_RESERVED:
			return
		for c in blockers:
			if is_instance_valid(c) and c.is_visible_in_tree() and c.get_global_rect().has_point(t.position):
				return
		_touch_pos[t.index] = t.position
		if _grab_index == -1 and _look_index == -1 and grab_begin.is_valid() and bool(grab_begin.call(t.position)):
			_grab_index = t.index
			return
		if show_jump and _jump_index == -1 and t.position.distance_to(_jump_center()) < JUMP_RADIUS * 1.3:
			_jump_index = t.index
			Game.touch_jump_held = true
			Game.press_jump()
		elif joystick_enabled and _joy_index == -1 and t.position.x < _screen().x * 0.45:
			_joy_index = t.index
			_joy_center = t.position
			_joy_knob = t.position
		elif _look_index == -1:
			_look_index = t.index
			_look_start = t.position
			_look_start_t = Time.get_ticks_msec() / 1000.0
			_look_moved = 0.0
		elif _pinch_index == -1:
			_pinch_index = t.index
	else:
		_touch_pos.erase(t.index)
		if t.index == _grab_index:
			_grab_index = -1
			if grab_end.is_valid():
				grab_end.call()
		elif t.index == _joy_index:
			_joy_index = -1
			Game.touch_move = Vector2.ZERO
		elif t.index == _jump_index:
			_jump_index = -1
			Game.touch_jump_held = false
		elif t.index == _look_index:
			var quick := Time.get_ticks_msec() / 1000.0 - _look_start_t < TAP_TIME
			if quick and _look_moved < TAP_MOVE and _pinch_index == -1:
				tapped.emit(t.position)
			_look_index = _pinch_index
			_pinch_index = -1
		elif t.index == _pinch_index:
			_pinch_index = -1
	queue_redraw()


func _on_drag(d: InputEventScreenDrag) -> void:
	var prev: Vector2 = _touch_pos.get(d.index, d.position)
	_touch_pos[d.index] = d.position
	if d.index == _grab_index:
		if grab_move.is_valid():
			grab_move.call(d.position)
		return

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
			panned.emit((d.position - prev) * 0.5)
		elif d.index == _look_index:
			_look_moved += (d.position - prev).length()
			Game.add_look_touch(d.position - prev)


func _draw() -> void:
	var white := Color(1, 1, 1)
	if not joystick_enabled:
		return

	# Joystick.
	var active := _joy_index != -1
	var base := _joy_center if active else _joy_home()
	var knob := _joy_knob if active else base
	draw_circle(base, JOY_RADIUS, Color(1, 1, 1, 0.10 if not active else 0.16))
	draw_arc(base, JOY_RADIUS, 0.0, TAU, 64, Color(1, 1, 1, 0.35), 4.0, true)
	draw_circle(knob, KNOB_RADIUS, Color(1, 1, 1, 0.38 if not active else 0.6))

	if not show_jump:
		return
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
