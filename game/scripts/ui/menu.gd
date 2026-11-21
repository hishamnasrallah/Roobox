class_name MainMenu
extends CanvasLayer
## Main menu with tabs: PLAY (Discover games), AVATAR, FRIENDS, RECORDS, SETTINGS.
## The 3D avatar preview stays visible on the right side of the screen.

signal play_requested(exp_id: String, mode: String, address: String)
signal profile_changed
signal studio_requested(slot: String)

var _account_label: Label
var _status: Label
var _content: VBoxContainer
var _tab_buttons: Dictionary = {}
var _busy_buttons: Array[Button] = []
var _swatch_rows: Dictionary = {}
var _tab: String = ""


func _ready() -> void:
	layer = 20
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var shade := ColorRect.new()
	shade.anchor_right = 0.64
	shade.anchor_bottom = 1.0
	shade.color = Color(0.03, 0.04, 0.1, 0.45)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	var margin := MarginContainer.new()
	margin.anchor_right = 0.64
	margin.anchor_bottom = 1.0
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	root.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)

	# Header: logo + account.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	vb.add_child(head)
	var title := UiStyle.label(56, Color(1.0, 0.85, 0.25))
	title.text = "ROOBOX"
	head.add_child(title)
	_account_label = UiStyle.label(18, Color(0.75, 0.9, 1.0))
	_account_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_account_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_account_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_account_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_account_label)

	# Tabs.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	vb.add_child(tabs)
	for t in ["PLAY", "CREATE", "AVATAR", "FRIENDS", "RECORDS", "SETTINGS"]:
		var b := UiStyle.button(t, Color(0.25, 0.3, 0.48), 18, 54)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tab_name: String = t
		b.pressed.connect(func() -> void: open_tab(tab_name))
		tabs.add_child(b)
		_tab_buttons[t] = b

	# Content area.
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	vb.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	scroll.add_child(_content)

	_status = UiStyle.label(20, Color(1, 1, 1, 0.85))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_status)

	Backend.status_changed.connect(_refresh_account)
	_refresh_account()
	open_tab("PLAY")


# ---------------------------------------------------------------- tabs ---

func open_tab(t: String) -> void:
	_tab = t
	for k: String in _tab_buttons:
		var btn: Button = _tab_buttons[k]
		var c := Color(0.95, 0.55, 0.2) if k == t else Color(0.25, 0.3, 0.48)
		btn.add_theme_stylebox_override("normal", UiStyle.box(c, 18, 10))
	for ch in _content.get_children():
		ch.queue_free()
	_busy_buttons.clear()
	_swatch_rows.clear()
	match t:
		"PLAY":
			_build_discover()
		"CREATE":
			_build_create()
		"AVATAR":
			_build_avatar()
		"FRIENDS":
			_build_friends()
		"RECORDS":
			_build_records()
		"SETTINGS":
			_build_settings()


func _refresh_account() -> void:
	if _account_label != null:
		_account_label.text = "%s\nCoins: %d" % [Backend.status_text(), Game.wallet()]


func set_busy(busy: bool) -> void:
	for b in _busy_buttons:
		if is_instance_valid(b):
			b.disabled = busy


func show_status(text: String, is_error: bool = false) -> void:
	_status.text = text
	_status.label_settings.font_color = Color(1.0, 0.45, 0.45) if is_error else Color(1, 1, 1, 0.9)


func _text(parent: Control, text: String, font_size: int = 24, color: Color = Color(1, 1, 1)) -> Label:
	var l := UiStyle.label(font_size, color)
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


func _save_name_if_needed() -> void:
	if Game.player_name.strip_edges() == "":
		Game.player_name = "Player%d" % (randi() % 9000 + 1000)
	Game.save_profile()
	if Backend.online:
		Backend.update_name()
		Backend.push_progress()


# ------------------------------------------------------------ discover ---

class CardArt:
	extends Control
	var kind: String = ""
	var base: Color = Color.WHITE

	func _ready() -> void:
		custom_minimum_size = Vector2(0, 92)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var c := Vector2(w * 0.5, h * 0.5)
		match kind:
			"island":
				draw_circle(c + Vector2(0, 14), 46, Color(0.2, 0.5, 0.85))
				draw_circle(c + Vector2(0, 6), 34, Color(0.4, 0.8, 0.35))
				draw_rect(Rect2(c + Vector2(-3, -34), Vector2(6, 22)), Color(0.45, 0.3, 0.18))
				draw_rect(Rect2(c + Vector2(-14, -48), Vector2(28, 16)), Color(0.3, 0.7, 0.3))
			"lava_rising":
				for i in 4:
					draw_rect(Rect2(Vector2(w * 0.25 + i * 22, h - 30 - i * 16), Vector2(18, 8)), World.PALETTE[i])
				draw_rect(Rect2(Vector2(0, h - 18), Vector2(w, 18)), Color(1.0, 0.4, 0.1))
				draw_rect(Rect2(Vector2(0, h - 22), Vector2(w, 4)), Color(1.0, 0.75, 0.2))
			"color_drop":
				var cs: Array[Color] = [Color(1, 0.3, 0.3), Color(1, 0.6, 0.15), Color(1, 0.9, 0.25),
					Color(0.3, 0.85, 0.4), Color(0.3, 0.55, 1), Color(0.7, 0.4, 1)]
				for y in 3:
					for x in 6:
						draw_rect(Rect2(Vector2(w * 0.5 - 75 + x * 25, 12 + y * 25), Vector2(22, 22)), cs[(x + y * 2) % 6])
			_:
				for i in 5:
					draw_rect(Rect2(Vector2(w * 0.5 - 90 + i * 38, h - 22 - i * 13), Vector2(28, 10)), base.lightened(0.1 * i))
				draw_rect(Rect2(Vector2(w * 0.5 + 12, h - 70), Vector2(30, 8)), Color(1, 0.2, 0.25))


func _build_discover() -> void:
	_text(_content, "Discover", 34, Color(1.0, 0.85, 0.3))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	_content.add_child(grid)
	for e: Dictionary in Catalog.ENTRIES:
		if not e.get("hidden", false):
			grid.add_child(_card(e))
	_text(_content, "Community games", 34, Color(1.0, 0.85, 0.3))
	if not Backend.online:
		_text(_content, "Connect an account server (SETTINGS) to play games made by other players.", 20, Color(1, 1, 1, 0.6))
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_content.add_child(box)
	_text(box, "Loading...", 20, Color(1, 1, 1, 0.6))
	_load_community(box)


func _load_community(box: VBoxContainer) -> void:
	var games: Array = await Backend.list_community(40)
	if not is_instance_valid(box):
		return
	for ch in box.get_children():
		ch.queue_free()
	if games.is_empty():
		_text(box, "No community games yet - make one in CREATE and publish it!", 20, Color(1, 1, 1, 0.6))
		return
	for g: Dictionary in games:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		var l := _text(row, "%s   by %s   (%d parts)" % [g["name"], g["author"], g["parts"]], 22)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var item: Dictionary = g
		var solo := UiStyle.button("PLAY", Color(0.2, 0.72, 0.35), 18, 50)
		solo.custom_minimum_size.x = 110
		solo.pressed.connect(func() -> void: _play_community(item, "offline"))
		row.add_child(solo)
		var host := UiStyle.button("HOST", Color(0.25, 0.5, 0.95), 18, 50)
		host.custom_minimum_size.x = 110
		host.pressed.connect(func() -> void: _play_community(item, "host"))
		row.add_child(host)
		_busy_buttons.append(solo)
		_busy_buttons.append(host)


func _play_community(item: Dictionary, mode: String) -> void:
	set_busy(true)
	show_status("Downloading %s..." % item["name"])
	var lvl: Dictionary = await Backend.load_community(item["owner"], item["key"])
	set_busy(false)
	if lvl.is_empty():
		show_status("Could not download this game.", true)
		return
	Game.pending_level = lvl
	Game.testing = false
	_play("ugc", mode, "")


# -------------------------------------------------------------- create ---

func _build_create() -> void:
	_text(_content, "Roobox Studio", 34, Color(1.0, 0.85, 0.3))
	_text(_content, "Build your own game with blocks, ramps, lava, jump pads, coins and a finish line. Test it, then publish it for everyone.", 20, Color(1, 1, 1, 0.85))
	var new_btn := UiStyle.button("+ NEW GAME", Color(0.2, 0.72, 0.35))
	new_btn.pressed.connect(func() -> void: studio_requested.emit(""))
	_content.add_child(new_btn)
	var saved := Level.list_saved()
	if saved.is_empty():
		_text(_content, "Your games will appear here.", 20, Color(1, 1, 1, 0.6))
		return
	_text(_content, "Your games", 26)
	for g: Dictionary in saved:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_content.add_child(row)
		var l := _text(row, "%s   (%d parts)" % [g["name"], g["parts"]], 22)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var slot: String = g["slot"]
		for spec in [["EDIT", Color(0.95, 0.55, 0.2)], ["PLAY", Color(0.2, 0.72, 0.35)],
				["HOST", Color(0.25, 0.5, 0.95)], ["DELETE", Color(0.6, 0.3, 0.3)]]:
			var b := UiStyle.button(spec[0], spec[1], 16, 48)
			b.custom_minimum_size.x = 96
			var action: String = spec[0]
			b.pressed.connect(func() -> void: _creation_action(slot, action))
			row.add_child(b)


func _creation_action(slot: String, action: String) -> void:
	match action:
		"EDIT":
			studio_requested.emit(slot)
		"PLAY", "HOST":
			Game.pending_level = Level.load_slot(slot)
			Game.testing = false
			_play("ugc", "offline" if action == "PLAY" else "host", "")
		"DELETE":
			Level.delete_slot(slot)
			open_tab("CREATE")


func _card(e: Dictionary) -> Control:
	var col: Color = e["color"]
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 200)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	var sb := UiStyle.box(col.darkened(0.25), 20, 12)
	sb.border_color = col.lightened(0.3)
	sb.set_border_width_all(3)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", UiStyle.box(col.darkened(0.12), 20, 12))
	btn.add_theme_stylebox_override("pressed", UiStyle.box(col.darkened(0.4), 20, 12))
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 12
	vb.offset_right = -12
	vb.offset_top = 8
	vb.offset_bottom = -8
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vb)
	var art := CardArt.new()
	art.kind = e["id"]
	art.base = col
	vb.add_child(art)
	var t := UiStyle.label(30)
	t.text = e["title"]
	vb.add_child(t)
	var tag := UiStyle.label(16, col.lightened(0.5))
	tag.text = "%s  -  up to %d players" % [e["tag"], e["max"]]
	vb.add_child(tag)
	var exp_id: String = e["id"]
	btn.pressed.connect(func() -> void: _show_detail(exp_id))
	return btn


func _show_detail(exp_id: String) -> void:
	Sfx.play("click")
	for ch in _content.get_children():
		ch.queue_free()
	_busy_buttons.clear()
	var e := Catalog.get_entry(exp_id)
	var col: Color = e["color"]
	var back := UiStyle.button("< ALL GAMES", Color(0.3, 0.33, 0.45), 18, 46)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.custom_minimum_size.x = 200
	back.pressed.connect(func() -> void: open_tab("PLAY"))
	_content.add_child(back)
	_text(_content, e["title"], 44, col.lightened(0.35))
	_text(_content, e["desc"], 22, Color(1, 1, 1, 0.9))
	_text(_content, _best_text(exp_id), 20, Color(1.0, 0.85, 0.3))

	var solo := UiStyle.button("PLAY SOLO", Color(0.2, 0.72, 0.35))
	solo.pressed.connect(func() -> void: _play(exp_id, "offline", ""))
	_content.add_child(solo)
	_busy_buttons.append(solo)

	var online := UiStyle.button("PLAY ONLINE", Color(0.6, 0.35, 0.95))
	online.disabled = not Backend.online
	online.pressed.connect(func() -> void: _play(exp_id, "online", ""))
	_content.add_child(online)
	if Backend.online:
		_busy_buttons.append(online)
	else:
		_text(_content, "Online play needs an account server (SETTINGS).", 18, Color(1, 1, 1, 0.6))

	var host := UiStyle.button("HOST ON WI-FI", Color(0.25, 0.5, 0.95))
	host.pressed.connect(func() -> void: _play(exp_id, "host", ""))
	_content.add_child(host)
	_busy_buttons.append(host)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_content.add_child(row)
	var addr := UiStyle.line_edit("Host IP  e.g. 192.168.1.5")
	addr.text = Game.server_address
	addr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(addr)
	var join := UiStyle.button("JOIN", Color(1.0, 0.55, 0.2))
	join.custom_minimum_size = Vector2(150, 72)
	join.pressed.connect(func() -> void: _join(exp_id, addr.text))
	row.add_child(join)
	_busy_buttons.append(join)


func _best_text(exp_id: String) -> String:
	match exp_id:
		"island":
			var parts: Array[String] = []
			for course in ["Obby Land", "Sky Tower"]:
				var t: float = Game.best_times.get(course, 0.0)
				parts.append("%s %s" % [course, _fmt_time(t) if t > 0.0 else "--"])
			return "Your best:  " + "   ".join(parts)
		"lava_rising":
			return "Your best: %ds survived" % int(Game.best_scores.get("lava_rising", 0))
		"color_drop":
			return "Your best: %d rounds" % int(Game.best_scores.get("color_drop", 0))
		"obby_rush":
			return "Your best: stage %d" % int(Game.best_scores.get("obby_rush", 0))
	return ""


func _play(exp_id: String, mode: String, address: String) -> void:
	_save_name_if_needed()
	play_requested.emit(exp_id, mode, address)


func _join(exp_id: String, address: String) -> void:
	Game.server_address = address.strip_edges()
	if Game.server_address == "":
		show_status("Type the host's IP first.", true)
		return
	_play(exp_id, "client", Game.server_address)


# -------------------------------------------------------------- avatar ---

func _build_avatar() -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	_content.add_child(top)
	var wallet := _text(top, "Coins: %d" % Game.wallet(), 30, Color(1.0, 0.85, 0.3))
	wallet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if Game.daily_available():
		var daily := UiStyle.button("DAILY REWARD +%d" % Game.DAILY_REWARD, Color(0.95, 0.6, 0.15), 18, 52)
		daily.pressed.connect(_claim_daily)
		top.add_child(daily)

	_text(_content, "Your name", 22)
	var name_edit := UiStyle.line_edit("Your name")
	name_edit.max_length = Network.MAX_NAME
	name_edit.text = Game.player_name
	name_edit.text_changed.connect(_on_name_changed)
	_content.add_child(name_edit)
	_add_swatches(_content, "Shirt", "shirt", Game.SHIRT_COLORS)
	_add_swatches(_content, "Pants", "pants", Game.PANTS_COLORS)
	_add_swatches(_content, "Skin", "skin", Game.SKIN_COLORS)

	_text(_content, "Avatar shop", 30, Color(1.0, 0.85, 0.3))
	_text(_content, "Collect coins in any game to buy items. Tap an item you own to wear or remove it.", 18, Color(1, 1, 1, 0.7))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_content.add_child(grid)
	for it: Dictionary in AvatarItems.ITEMS:
		grid.add_child(_shop_item(it))


func _shop_item(it: Dictionary) -> Control:
	var id: String = it["id"]
	var owned := Game.owns(id)
	var worn: bool = Game.equipped.get(it["slot"], "") == id
	var col: Color = it["color"]
	var label := "%s\n%s" % [it["name"], "WEARING" if worn else ("OWNED - tap to wear" if owned else "%d coins" % it["price"])]
	var base := Color(0.2, 0.55, 0.3) if worn else (Color(0.25, 0.3, 0.48) if owned else Color(0.18, 0.2, 0.3))
	var b := UiStyle.button(label, base, 17, 86)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := UiStyle.box(base, 16, 8)
	sb.border_color = col
	sb.set_border_width_all(4)
	b.add_theme_stylebox_override("normal", sb)
	b.pressed.connect(func() -> void: _shop_press(id))
	return b


func _shop_press(id: String) -> void:
	if Game.owns(id):
		Game.toggle_equip(id)
	else:
		var err := Game.buy(id)
		if err != "":
			show_status(err, true)
			Sfx.play("hit")
			return
		Sfx.play("win")
		show_status("You bought %s!" % AvatarItems.get_item(id)["name"])
	if Backend.online:
		Backend.push_progress()
	profile_changed.emit()
	_refresh_account()
	open_tab("AVATAR")


func _claim_daily() -> void:
	var got := Game.claim_daily()
	if got > 0:
		Sfx.play("coin")
		show_status("Daily reward: +%d coins!" % got)
		if Backend.online:
			Backend.push_progress()
	_refresh_account()
	open_tab("AVATAR")


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
		b.custom_minimum_size = Vector2(54, 54)
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
	Game.save_profile()
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


# ------------------------------------------------------------ settings ---

func _build_settings() -> void:
	var c := _content
	_text(c, "Account server (Nakama) - enables accounts, friends, cloud save, world records and online play. Leave empty to play as a guest.", 20, Color(1, 1, 1, 0.8))
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


# ------------------------------------------------------------- friends ---

func _build_friends() -> void:
	var c := _content
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


# ------------------------------------------------------------- records ---

func _build_records() -> void:
	for bd: Dictionary in Catalog.BOARDS:
		var board: String = bd["id"]
		var kind: String = bd["kind"]
		_text(_content, str(bd["title"]).to_upper(), 30, Color(1.0, 0.85, 0.3))
		var mine := ""
		if kind == "time":
			var t: float = Game.best_times.get(bd["title"], 0.0)
			mine = _fmt_time(t) if t > 0.0 else "--"
		else:
			var v := int(Game.best_scores.get(board, 0))
			mine = "%d %s" % [v, kind] if v > 0 else "--"
		_text(_content, "Your best: %s" % mine, 22)
		var box := VBoxContainer.new()
		_content.add_child(box)
		if Backend.online:
			_text(box, "Loading world records...", 20, Color(1, 1, 1, 0.6))
			_load_records(board, kind, box)
		else:
			_text(box, "Connect an account server to see world records.", 20, Color(1, 1, 1, 0.6))


func _load_records(board: String, kind: String, box: VBoxContainer) -> void:
	var rows: Array = await Backend.top_scores(board, 10)
	if not is_instance_valid(box):
		return
	for ch in box.get_children():
		ch.queue_free()
	if rows.is_empty():
		_text(box, "No records yet - be the first!", 20, Color(1, 1, 1, 0.6))
	for r: Dictionary in rows:
		var score: int = r["score"]
		var shown := _fmt_time(score / 1000.0) if kind == "time" else "%d %s" % [score, kind]
		_text(box, "#%d   %s   %s" % [r["rank"], r["name"], shown], 22,
			Color(0.6, 1.0, 0.65) if r["mine"] else Color(1, 1, 1))


func _fmt_time(t: float) -> String:
	return "%02d:%04.1f" % [int(t) / 60, fmod(t, 60.0)]
