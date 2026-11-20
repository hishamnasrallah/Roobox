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
var _account_label: Label
var _online_btn: Button
var _overlay: Control
var _ov_title: Label
var _ov_content: VBoxContainer


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

	_account_label = UiStyle.label(20, Color(0.75, 0.9, 1.0))
	_account_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_account_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_account_label)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	vb.add_child(top_row)
	for spec in [["FRIENDS", _open_friends], ["RECORDS", _open_records], ["SETTINGS", _open_settings]]:
		var b := UiStyle.button(spec[0], Color(0.3, 0.36, 0.55), 20, 52)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(spec[1])
		top_row.add_child(b)

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

	_online_btn = UiStyle.button("PLAY ONLINE", Color(0.6, 0.35, 0.95))
	_online_btn.pressed.connect(func() -> void: _request("online"))
	vb.add_child(_online_btn)
	_buttons.append(_online_btn)

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

	_build_overlay(root)
	Backend.status_changed.connect(_refresh_account)
	_refresh_account()


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
	if Backend.online:
		Backend.update_name()
		Backend.push_progress()
	play_requested.emit(mode, Game.server_address)


func set_busy(busy: bool) -> void:
	for b in _buttons:
		b.disabled = busy


func show_status(text: String, is_error: bool = false) -> void:
	_status.text = text
	_status.label_settings.font_color = Color(1.0, 0.45, 0.45) if is_error else Color(1, 1, 1, 0.9)


# ------------------------------------------------------------ account ---

func _refresh_account() -> void:
	if _account_label == null:
		return
	_account_label.text = "%s\nCoins collected: %d" % [Backend.status_text(), Game.lifetime_coins]
	_online_btn.visible = Backend.online or Game.backend_url != ""
	_online_btn.disabled = not Backend.online


# ------------------------------------------------------------ overlay ---

func _build_overlay(root: Control) -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	root.add_child(_overlay)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(700, 560)
	panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	_ov_title = UiStyle.label(40, Color(1.0, 0.85, 0.3))
	_ov_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_ov_title)
	var close := UiStyle.button("CLOSE", Color(0.75, 0.3, 0.3), 20, 52)
	close.custom_minimum_size.x = 130
	close.pressed.connect(_close_overlay)
	head.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	_ov_content = VBoxContainer.new()
	_ov_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ov_content.add_theme_constant_override("separation", 10)
	scroll.add_child(_ov_content)


func _open_overlay(title: String) -> VBoxContainer:
	_ov_title.text = title
	for c in _ov_content.get_children():
		c.queue_free()
	_overlay.visible = true
	return _ov_content


func _close_overlay() -> void:
	_overlay.visible = false
	_refresh_account()


func _text(parent: Control, text: String, size: int = 24, color: Color = Color(1, 1, 1)) -> Label:
	var l := UiStyle.label(size, color)
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


# ----------------------------------------------------------- settings ---

func _open_settings() -> void:
	var c := _open_overlay("SETTINGS")
	_text(c, "Account server (Nakama) - enables accounts, friends, cloud save and world records. Leave empty to play as a guest.", 20, Color(1, 1, 1, 0.8))
	var url := UiStyle.line_edit("http://YOUR-SERVER-IP:7350", 24)
	url.text = Game.backend_url
	c.add_child(url)
	_text(c, "Server key", 20)
	var key := UiStyle.line_edit("defaultkey", 24)
	key.text = Game.backend_key
	c.add_child(key)
	var status := _text(c, Backend.status_text(), 20, Color(0.75, 0.9, 1.0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	c.add_child(row)
	var save := UiStyle.button("SAVE & CONNECT", Color(0.2, 0.72, 0.35), 22, 60)
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(save)
	var out := UiStyle.button("USE AS GUEST", Color(0.45, 0.45, 0.5), 22, 60)
	out.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(out)
	save.pressed.connect(func() -> void: _save_settings(url.text, key.text, status))
	out.pressed.connect(func() -> void: _save_settings("", key.text, status))


func _save_settings(url_text: String, key_text: String, status: Label) -> void:
	var u := url_text.strip_edges()
	if u != "" and not u.begins_with("http"):
		u = "http://" + u
	if u != "" and u.count(":") < 2:
		u += ":7350"
	Game.backend_url = u
	Game.backend_key = key_text.strip_edges() if key_text.strip_edges() != "" else "defaultkey"
	Game.save_profile()
	if u == "":
		Backend.disconnect_backend()
		status.text = Backend.status_text()
		return
	status.text = "Connecting..."
	await Backend.connect_backend()
	if is_instance_valid(status):
		status.text = Backend.status_text()
	_refresh_account()


# ------------------------------------------------------------ friends ---

func _open_friends() -> void:
	var c := _open_overlay("FRIENDS")
	if not Backend.online:
		_text(c, "Friends need an account server. Open SETTINGS and connect first.", 24)
		return
	_text(c, "Your username: @%s  (share it so friends can add you)" % Backend.username(), 22, Color(0.75, 0.9, 1.0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	c.add_child(row)
	var input := UiStyle.line_edit("friend's username", 24)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(input)
	var add := UiStyle.button("ADD", Color(0.25, 0.5, 0.95), 22, 62)
	add.custom_minimum_size.x = 120
	row.add_child(add)
	var info := _text(c, "", 20, Color(1, 1, 1, 0.8))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	c.add_child(list)
	add.pressed.connect(func() -> void: _add_friend(input, info, list))
	_reload_friends(list)


func _add_friend(input: LineEdit, info: Label, list: VBoxContainer) -> void:
	var uname := input.text.strip_edges().trim_prefix("@")
	if uname == "":
		return
	info.text = "Sending request..."
	var r: Dictionary = await Backend.add_friend(uname)
	if not is_instance_valid(info):
		return
	info.text = "Request sent to @%s" % uname if r.get("ok", false) else "Could not add: %s" % r.get("error", "?")
	input.text = ""
	_reload_friends(list)


func _reload_friends(list: VBoxContainer) -> void:
	var friends: Array = await Backend.friends()
	if not is_instance_valid(list):
		return
	for ch in list.get_children():
		ch.queue_free()
	if friends.is_empty():
		_text(list, "No friends yet - add someone by username!", 22, Color(1, 1, 1, 0.7))
		return
	for f: Dictionary in friends:
		var state: int = f["state"]
		if state == 3:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		list.add_child(row)
		var tag := ""
		match state:
			0:
				tag = "online" if f["online"] else "offline"
			1:
				tag = "request sent"
			2:
				tag = "wants to be friends"
		var l := _text(row, "%s  (@%s)  -  %s" % [f["name"], f["username"], tag], 22,
			Color(0.6, 1.0, 0.65) if state == 0 and f["online"] else Color(1, 1, 1))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: String = f["id"]
		if state == 2:
			var acc := UiStyle.button("ACCEPT", Color(0.2, 0.72, 0.35), 18, 48)
			acc.pressed.connect(func() -> void: _friend_action(id, true, list))
			row.add_child(acc)
		var rem := UiStyle.button("REMOVE", Color(0.6, 0.3, 0.3), 18, 48)
		rem.pressed.connect(func() -> void: _friend_action(id, false, list))
		row.add_child(rem)


func _friend_action(id: String, accept: bool, list: VBoxContainer) -> void:
	if accept:
		await Backend.accept_friend(id)
	else:
		await Backend.remove_friend(id)
	_reload_friends(list)


# ------------------------------------------------------------ records ---

func _open_records() -> void:
	var c := _open_overlay("RECORDS")
	for course in ["Obby Land", "Sky Tower"]:
		_text(c, course.to_upper(), 30, Color(1.0, 0.85, 0.3))
		var best: float = Game.best_times.get(course, 0.0)
		_text(c, "Your best: %s" % (_fmt(best) if best > 0.0 else "not finished yet"), 22)
		var box := VBoxContainer.new()
		c.add_child(box)
		if Backend.online:
			_text(box, "Loading world records...", 20, Color(1, 1, 1, 0.6))
			_load_records(course, box)
		else:
			_text(box, "Connect an account server to see world records.", 20, Color(1, 1, 1, 0.6))


func _load_records(course: String, box: VBoxContainer) -> void:
	var rows: Array = await Backend.top_times(course, 10)
	if not is_instance_valid(box):
		return
	for ch in box.get_children():
		ch.queue_free()
	if rows.is_empty():
		_text(box, "No records yet - be the first!", 20, Color(1, 1, 1, 0.6))
	for r: Dictionary in rows:
		_text(box, "#%d   %s   %s" % [r["rank"], r["name"], _fmt(r["time"])], 22,
			Color(0.6, 1.0, 0.65) if r["mine"] else Color(1, 1, 1))


func _fmt(t: float) -> String:
	return "%02d:%04.1f" % [int(t) / 60, fmod(t, 60.0)]
