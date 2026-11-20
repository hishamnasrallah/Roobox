class_name MainMenu
extends CanvasLayer
## Title screen: name, avatar colors, Solo / Host (Wi-Fi) / Join.

signal play_requested(mode: String, address: String)
signal profile_changed

var _name_edit: LineEdit
var _addr_edit: LineEdit
var _status: Label
var _swatch_rows: Dictionary = {}
var _buttons: Array[Button] = []


func _ready() -> void:
	layer = 20
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	shade.custom_minimum_size = Vector2(700, 0)
	shade.offset_right = 700
	shade.color = Color(0.03, 0.04, 0.1, 0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	margin.offset_right = 660
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	root.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	var title := UiStyle.label(84, Color(1.0, 0.85, 0.25))
	title.text = "ROOBOX"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	_name_edit = UiStyle.line_edit("Your name")
	_name_edit.max_length = Network.MAX_NAME
	_name_edit.text = Game.player_name
	_name_edit.text_changed.connect(_on_name_changed)
	vb.add_child(_name_edit)

	_add_swatches(vb, "Shirt", "shirt", Game.SHIRT_COLORS)
	_add_swatches(vb, "Pants", "pants", Game.PANTS_COLORS)
	_add_swatches(vb, "Skin", "skin", Game.SKIN_COLORS)

	var solo := UiStyle.button("PLAY SOLO", Color(0.2, 0.72, 0.35))
	solo.pressed.connect(func() -> void: _request("offline"))
	vb.add_child(solo)
	_buttons.append(solo)

	var host := UiStyle.button("HOST GAME (Wi-Fi)", Color(0.25, 0.5, 0.95))
	host.pressed.connect(func() -> void: _request("host"))
	vb.add_child(host)
	_buttons.append(host)

	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 10)
	vb.add_child(join_row)
	_addr_edit = UiStyle.line_edit("Server IP  e.g. 192.168.1.5")
	_addr_edit.text = Game.server_address
	_addr_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(_addr_edit)
	var join := UiStyle.button("JOIN", Color(1.0, 0.55, 0.2))
	join.custom_minimum_size = Vector2(150, 72)
	join.pressed.connect(func() -> void: _request("client"))
	join_row.add_child(join)
	_buttons.append(join)

	_status = UiStyle.label(22, Color(1, 1, 1, 0.85))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = "Tip: to play with friends, one phone presses HOST, others type its IP and press JOIN (same Wi-Fi)."
	vb.add_child(_status)


func _on_name_changed(t: String) -> void:
	Game.player_name = t.strip_edges()
	profile_changed.emit()


func _add_swatches(parent: Control, title: String, key: String, colors: Array[Color]) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var l := UiStyle.label(24)
	l.text = title
	l.custom_minimum_size = Vector2(90, 0)
	row.add_child(l)
	var btns: Array[Button] = []
	for i in colors.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(50, 50)
		b.focus_mode = Control.FOCUS_NONE
		var idx := i
		b.pressed.connect(func() -> void: _pick(key, idx))
		row.add_child(b)
		btns.append(b)
	_swatch_rows[key] = {"buttons": btns, "colors": colors}
	_refresh_swatches(key)


func _current(key: String) -> int:
	match key:
		"shirt":
			return Game.shirt_index
		"pants":
			return Game.pants_index
		_:
			return Game.skin_index


func _pick(key: String, idx: int) -> void:
	match key:
		"shirt":
			Game.shirt_index = idx
		"pants":
			Game.pants_index = idx
		_:
			Game.skin_index = idx
	Sfx.play("click")
	_refresh_swatches(key)
	profile_changed.emit()


func _refresh_swatches(key: String) -> void:
	var row: Dictionary = _swatch_rows[key]
	var btns: Array[Button] = row["buttons"]
	var colors: Array[Color] = row["colors"]
	var sel := _current(key)
	for i in btns.size():
		var sb := UiStyle.box(colors[i], 12, 0)
		if i == sel:
			sb.border_color = Color(1, 1, 1)
			sb.set_border_width_all(5)
		else:
			sb.border_color = Color(0, 0, 0, 0.3)
			sb.set_border_width_all(2)
		for state in ["normal", "hover", "pressed"]:
			btns[i].add_theme_stylebox_override(state, sb)


func _request(mode: String) -> void:
	Game.player_name = _name_edit.text.strip_edges()
	if Game.player_name == "":
		Game.player_name = "Player%d" % (randi() % 9000 + 1000)
		_name_edit.text = Game.player_name
	Game.server_address = _addr_edit.text.strip_edges()
	if mode == "client" and Game.server_address == "":
		show_status("Type the server IP first.", true)
		return
	Game.save_profile()
	play_requested.emit(mode, Game.server_address)


func set_busy(busy: bool) -> void:
	for b in _buttons:
		b.disabled = busy


func show_status(text: String, is_error: bool = false) -> void:
	_status.text = text
	_status.label_settings.font_color = Color(1.0, 0.45, 0.45) if is_error else Color(1, 1, 1, 0.9)
