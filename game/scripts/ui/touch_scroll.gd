class_name TouchScroll
extends Node
## Phone-style drag scrolling for every registered ScrollContainer.
##
## Godot only scrolls a ScrollContainer when the finger lands on empty space;
## a drag that starts on a button (which is almost everywhere in our lists)
## did nothing. One shared manager watches the (touch-emulated) mouse:
##  - a press inside registered scroll areas starts tracking,
##  - once the finger moves past THRESHOLD along an axis that one of those
##    areas can scroll, that area follows the finger 1:1 (deepest area
##    first, so a sideways row inside a vertical page works both ways),
##  - the button under the finger is cancelled (no accidental press),
##  - on release the list keeps gliding with the finger's speed (measured
##    over the last ~100 ms) and slows down smoothly.
## While a list moves, busy() is true so heavy work (thumbnails) waits.
## Sliders and text editors keep their own drag behaviour.

const THRESHOLD := 10.0
## Velocity kept after one second of gliding (lower = stops sooner).
const FRICTION := 0.08
const MAX_SPEED := 7000.0
const MIN_FLING := 250.0
## Our own fake "pointer moved away" events live far off screen.
const FAR := -10000.0

static var _manager: TouchScroll = null
static var _scrolls: Array = []

var _pressed: bool = false
var _active: ScrollContainer = null
var _axis_h: bool = false
var _cands: Array = []
var _start: Vector2 = Vector2.ZERO
var _last: Vector2 = Vector2.ZERO
var _samples: Array = []   # [[msec, Vector2 position], ...]
var _vel: Vector2 = Vector2.ZERO
var _acc: Vector2 = Vector2.ZERO
var _coast: ScrollContainer = null
var _idle_at: int = 0


## Registers a ScrollContainer (safe to call many times).
static func attach(sc: ScrollContainer) -> ScrollContainer:
	if not _scrolls.has(sc):
		_scrolls.append(sc)
	# Turn off Godot's own touch dragging so the two never fight.
	sc.scroll_deadzone = 100000
	sc.follow_focus = false
	if _manager == null or not is_instance_valid(_manager):
		_manager = TouchScroll.new()
		_manager.name = "TouchScroll"
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			tree.root.add_child.call_deferred(_manager)
	return sc


## Creates a ScrollContainer that already scrolls by dragging.
## horizontal = true -> a sideways row, otherwise a vertical list.
static func make(horizontal: bool) -> ScrollContainer:
	var sc := ScrollContainer.new()
	if horizontal:
		sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	else:
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	return attach(sc)


## True while a finger is down on a list, a list is gliding, or just after.
static func busy() -> bool:
	if _manager == null or not is_instance_valid(_manager):
		return false
	return _manager._pressed or _manager._coast != null or Time.get_ticks_msec() - _manager._idle_at < 250


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	var me := event as InputEventMouse
	if me == null or me.position.x <= FAR * 0.5:
		return  # not a pointer event, or our own cancel/release event
	var mb := event as InputEventMouseButton
	if mb != null:
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_on_press(mb.position)
		else:
			_on_release(mb)
		return
	var mm := event as InputEventMouseMotion
	if mm != null and _pressed:
		_on_motion(mm)


func _on_press(pos: Vector2) -> void:
	_coast = null
	_vel = Vector2.ZERO
	_acc = Vector2.ZERO
	_active = null
	_cands.clear()
	_samples.clear()
	for sc in _scrolls.duplicate():
		if not is_instance_valid(sc):
			_scrolls.erase(sc)
			continue
		var s := sc as ScrollContainer
		if s.is_visible_in_tree() and s.get_global_rect().has_point(pos):
			if _blocked_at(s, pos):
				_cands.clear()
				break
			_cands.append(s)
	_cands.sort_custom(_deeper)
	_pressed = not _cands.is_empty()
	_start = pos
	_last = pos
	_samples.append([Time.get_ticks_msec(), pos])


func _on_motion(mm: InputEventMouseMotion) -> void:
	var pos := mm.position
	var d := pos - _last
	_last = pos
	var now := Time.get_ticks_msec()
	_samples.append([now, pos])
	while _samples.size() > 2 and now - int(_samples[0][0]) > 120:
		_samples.pop_front()
	if _active == null:
		var total := pos - _start
		if total.length() < THRESHOLD:
			return
		var horiz := absf(total.x) > absf(total.y)
		for sc in _cands:
			if is_instance_valid(sc) and _can_scroll(sc as ScrollContainer, horiz):
				_active = sc
				break
		if _active == null:
			_pressed = false
			return
		_axis_h = horiz
		d = total
		_cancel_buttons()
	get_viewport().set_input_as_handled()
	_scroll_by(_active, -d)


func _on_release(mb: InputEventMouseButton) -> void:
	if not _pressed:
		return
	_pressed = false
	_idle_at = Time.get_ticks_msec()
	if _active == null:
		return
	get_viewport().set_input_as_handled()
	var rel := mb.duplicate() as InputEventMouseButton
	rel.position = Vector2(FAR, FAR)
	rel.global_position = rel.position
	_push.call_deferred(rel)
	_vel = _release_velocity(mb.position)
	var speed := absf(_vel.x if _axis_h else _vel.y)
	_coast = _active if speed > MIN_FLING else null
	_active = null


## Finger speed over the last ~100 ms (px/s, in scroll direction).
func _release_velocity(pos: Vector2) -> Vector2:
	var now := Time.get_ticks_msec()
	_samples.append([now, pos])
	var first: Array = _samples[0]
	for s: Array in _samples:
		if now - int(s[0]) <= 100:
			first = s
			break
	var dt := (now - int(first[0])) / 1000.0
	if dt < 0.008:
		return Vector2.ZERO
	var v := -(pos - (first[1] as Vector2)) / dt
	return v.limit_length(MAX_SPEED)


func _process(delta: float) -> void:
	if _coast == null:
		return
	_idle_at = Time.get_ticks_msec()
	if not is_instance_valid(_coast) or not _coast.is_visible_in_tree():
		_coast = null
		return
	_vel *= pow(FRICTION, delta)
	if _vel.length() < 30.0:
		_coast = null
		return
	var before := _coast.scroll_horizontal if _axis_h else _coast.scroll_vertical
	_scroll_by(_coast, _vel * delta)
	var after := _coast.scroll_horizontal if _axis_h else _coast.scroll_vertical
	if before == after and absf((_vel * delta).x if _axis_h else (_vel * delta).y) >= 1.0:
		_coast = null  # hit the end of the list


## Moves the button under the finger "away" so it does not fire on release.
func _cancel_buttons() -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = Vector2(FAR, FAR)
	mv.global_position = mv.position
	mv.button_mask = MOUSE_BUTTON_MASK_LEFT
	_push.call_deferred(mv)


func _push(ev: InputEvent) -> void:
	var vp := get_viewport()
	if vp != null:
		vp.push_input(ev, true)


## Is a drag in progress (tests / other code)?
func dragging() -> bool:
	return _active != null


func _scroll_by(sc: ScrollContainer, d: Vector2) -> void:
	if _axis_h:
		_acc.x += d.x
		var ix := int(_acc.x)
		_acc.x -= ix
		sc.scroll_horizontal += ix
	else:
		_acc.y += d.y
		var iy := int(_acc.y)
		_acc.y -= iy
		sc.scroll_vertical += iy


func _can_scroll(sc: ScrollContainer, horiz: bool) -> bool:
	if horiz:
		if sc.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
			return false
		var hb := sc.get_h_scroll_bar()
		return hb.max_value - hb.page > 1.0
	if sc.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
		return false
	var vb := sc.get_v_scroll_bar()
	return vb.max_value - vb.page > 1.0


## True when the press lands on a control that needs drags itself.
func _blocked_at(node: Node, pos: Vector2) -> bool:
	for ch in node.get_children():
		var c := ch as Control
		if c == null or not c.visible:
			continue
		if not c.get_global_rect().has_point(pos):
			continue
		if c is Slider or c is TextEdit:
			return true
		if _blocked_at(c, pos):
			return true
	return false


func _deeper(a: Variant, b: Variant) -> bool:
	return _depth(a as Node) > _depth(b as Node)


func _depth(n: Node) -> int:
	var d := 0
	var p := n
	while p != null:
		d += 1
		p = p.get_parent()
	return d
