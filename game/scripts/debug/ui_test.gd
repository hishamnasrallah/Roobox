extends Node
## CI test for menu touch scrolling and navigation:
##   godot --headless --path game -- --uitest
## Drags the game list with a (touch-emulated) mouse, checks it follows the
## finger without jumps and without opening a game, then taps a game and
## checks BACK returns to the same place.

var _fails: Array[String] = []


func _ready() -> void:
	_run()


func _check(ok: bool, what: String, detail: Variant = "") -> void:
	print("UITEST %s %s %s" % ["ok  " if ok else "FAIL", what, str(detail) if not ok else ""])
	if not ok:
		_fails.append(what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _button(pos: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = pos
	ev.global_position = pos
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	get_viewport().push_input(ev, true)


func _move(pos: Vector2, rel: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.relative = rel
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(ev, true)


func _visible_tile(menu: MainMenu, sc: ScrollContainer) -> GameTile:
	var area := sc.get_global_rect()
	for n in menu.find_children("*", "GameTile", true, false):
		var t := n as GameTile
		if t.is_visible_in_tree() and area.encloses(t.get_global_rect()):
			return t
	return null


func _run() -> void:
	var menu := MainMenu.new()
	add_child(menu)
	await _frames(12)
	var sc: ScrollContainer = menu.get("_scroll")
	var vb := sc.get_v_scroll_bar()
	_check(vb.max_value - vb.page > 600, "the PLAY page can scroll", vb.max_value - vb.page)
	var area := sc.get_global_rect()
	var start := area.position + Vector2(area.size.x * 0.5, area.size.y * 0.75)
	# Drag up 300 px in small steps (like a finger).
	_button(start, true)
	await _frames(1)
	var p := start
	for i in 30:
		p += Vector2(0, -10)
		_move(p, Vector2(0, -10))
		await _frames(1)
	await _frames(2)
	var y := sc.scroll_vertical
	# Finger rests a moment before lifting (no fling).
	await get_tree().create_timer(0.2).timeout
	_button(p, false)
	await _frames(4)
	_check(y >= 270 and y <= 330, "the list follows the finger (no jumps)", y)
	_check(not bool(menu.get("_in_detail")), "dragging over a game does not open it")
	# Slow release: the list stops where it is.
	_check(absi(sc.scroll_vertical - y) < 40, "no big jump after letting go", [y, sc.scroll_vertical])
	# Tap a game: it opens; BACK returns to the same place.
	var before := sc.scroll_vertical
	var tile := _visible_tile(menu, sc)
	_check(tile != null, "a game card is on screen")
	if tile != null:
		var c := tile.get_global_rect().get_center()
		_button(c, true)
		await _frames(1)
		_button(c, false)
		await _frames(4)
		_check(bool(menu.get("_in_detail")), "tapping a game opens its page")
		await menu.back_to_list()
		await _frames(3)
		_check(absi(sc.scroll_vertical - before) < 8, "BACK returns to the same place in the list", [before, sc.scroll_vertical])
	# Fling: a quick swipe keeps the list gliding after the finger lifts.
	sc.scroll_vertical = 0
	await _frames(2)
	var f0 := area.position + Vector2(area.size.x * 0.5, area.size.y * 0.8)
	_button(f0, true)
	var fp := f0
	for i in 8:
		fp += Vector2(0, -25)
		_move(fp, Vector2(0, -25))
		await get_tree().create_timer(0.01).timeout
	var at_release := sc.scroll_vertical
	_button(fp, false)
	await get_tree().create_timer(0.5).timeout
	_check(sc.scroll_vertical > at_release + 150, "a quick swipe keeps gliding", [at_release, sc.scroll_vertical])
	_check(not bool(menu.get("_in_detail")), "a fling does not open a game")
	await get_tree().create_timer(2.5).timeout
	_check(not TouchScroll.busy(), "gliding stops by itself")
	# Android back from the PLAY page scrolls to the top first.
	_check(menu.go_back() and sc.scroll_vertical == 0, "back button goes to the top first")
	if _fails.is_empty():
		print("UITEST PASS")
	else:
		print("UITEST FAIL: " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)
