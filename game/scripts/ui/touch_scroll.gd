class_name TouchScroll
extends Node
## Phone-style drag scrolling for every registered ScrollContainer.
##
## Godot only scrolls a ScrollContainer when the finger lands on empty space;
## a drag that starts on a button (which is almost everywhere in our lists)
## did nothing. One shared manager watches the (touch-emulated) mouse:
##  - a press inside registered scroll areas starts tracking,
##  - once the finger moves past THRESHOLD along an axis that one of those
##    areas can scroll, that area follows the finger (deepest area first, so
##    a horizontal row inside a vertical page works both ways),
##  - the button under the finger is cancelled (no accidental press),
##  - on release the list keeps gliding and slows down (kinetic scrolling).
## Sliders and text editors keep their own drag behaviour.

const THRESHOLD := 12.0
const FRICTION := 0.04   # velocity left after one second of gliding

static var _manager: TouchScroll = null
static var _scrolls: Array = []

var _pressed: bool = false
var _active: ScrollContainer = null
var _axis_h: bool = false
var _cands: Array = []
var _start: Vector2 = Vector2.ZERO
var _last: Vector2 = Vector2.ZERO
var _last_ms: int = 0
var _vel: Vector2 = Vector2.ZERO
var _acc: Vector2 = Vector2.ZERO
var _coast: ScrollContainer = null


## Registers a ScrollContainer (safe to call many times).
static func attach(sc: ScrollContainer) -> ScrollContainer:
	if not _scrolls.has(sc):
		_scrolls.append(sc)
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
	sc.follow_focus = false
	return attach(sc)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
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
	_last_ms = Time.get_ticks_msec()


func _on_motion(mm: InputEventMouseMotion) -> void:
	var pos := mm.position
	var d := pos - _last
	var now := Time.get_ticks_msec()
	var dt := maxf((now - _last_ms) / 1000.0, 0.001)
	_last = pos
	_last_ms = now
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
	_vel = _vel.lerp(-d / dt, 0.35)


func _on_release(mb: InputEventMouseButton) -> void:
	if not _pressed:
		return
	_pressed = false
	if _active == null:
		return
	get_viewport().set_input_as_handled()
	var rel := mb.duplicate() as InputEventMouseButton
	rel.position = Vector2(-10000, -10000)
	rel.global_position = rel.position
	_push.call_deferred(rel)
	if Time.get_ticks_msec() - _last_ms < 90:
		_coast = _active
	else:
		_vel = Vector2.ZERO
	_active = null


func _process(delta: float) -> void:
	if _coast == null:
		return
	if not is_instance_valid(_coast) or not _coast.is_visible_in_tree():
		_coast = null
		return
	_vel *= pow(FRICTION, delta)
	if _vel.length() < 25.0:
		_coast = null
		return
	_scroll_by(_coast, _vel * delta)


## Moves the button under the finger "away" so it does not fire on release.
func _cancel_buttons() -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = Vector2(-10000, -10000)
	mv.global_position = mv.position
	mv.button_mask = MOUSE_BUTTON_MASK_LEFT
	_push.call_deferred(mv)


func _push(ev: InputEvent) -> void:
	var vp := get_viewport()
	if vp != null:
		vp.push_input(ev)


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
