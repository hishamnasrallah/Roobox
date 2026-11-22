class_name Hud
extends CanvasLayer
## In-game HUD: coins, course timer, chat, home button, player count,
## toasts, respawn fade and the course-complete panel.

signal home_pressed
signal menu_pressed

const CHAT_LINES := 7
const CHAT_TTL := 14.0

var touch: TouchControls
var _coin_label: Label
var _timer_label: Label
var _info_label: Label
var _mode_label: Label
var _stats_label: Label
var _toast: Label
var _hint: Label
var _fade: ColorRect
var _chat_log: VBoxContainer
var _chat_edit: LineEdit
var _win_panel: PanelContainer
var _win_stats: Label
var _players_panel: PanelContainer
var _players_list: VBoxContainer
var _players_btn: Button
var _chat_history: Array = []


class CoinIcon:
	extends Control

	func _ready() -> void:
		custom_minimum_size = Vector2(40, 40)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 18.0, Color(0.85, 0.55, 0.05))
		draw_circle(c, 14.0, Color(1.0, 0.82, 0.15))
		draw_rect(Rect2(c + Vector2(-3, -9), Vector2(6, 18)), Color(1.0, 0.95, 0.6))


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	touch = TouchControls.new()
	root.add_child(touch)

	# --- Coins (top-left) ---
	var coin_box := HBoxContainer.new()
	coin_box.position = Vector2(28, 20)
	coin_box.add_theme_constant_override("separation", 10)
	coin_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(coin_box)
	coin_box.add_child(CoinIcon.new())
	_coin_label = UiStyle.label(34)
	coin_box.add_child(_coin_label)

	# --- Chat log (under coins) ---
	_chat_log = VBoxContainer.new()
	_chat_log.position = Vector2(28, 76)
	_chat_log.custom_minimum_size = Vector2(560, 0)
	_chat_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chat_log.add_theme_constant_override("separation", 2)
	root.add_child(_chat_log)

	# --- Course timer + info (top-center) ---
	_timer_label = UiStyle.label(38, Color(1.0, 0.9, 0.4))
	_timer_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.offset_left = -260
	_timer_label.offset_right = 260
	_timer_label.offset_top = 18
	_timer_label.visible = false
	root.add_child(_timer_label)

	_mode_label = UiStyle.label(34)
	_mode_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_label.offset_left = -520
	_mode_label.offset_right = 520
	_mode_label.offset_top = 96
	_mode_label.visible = false
	root.add_child(_mode_label)

	_info_label = UiStyle.label(20, Color(0.75, 0.9, 1.0))
	_info_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.offset_left = -360
	_info_label.offset_right = 360
	_info_label.offset_top = 70
	root.add_child(_info_label)

	# --- Buttons (top-right) ---
	var btn_row := HBoxContainer.new()
	btn_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	btn_row.offset_left = -740
	btn_row.offset_right = -24
	btn_row.offset_top = 16
	btn_row.offset_bottom = 80
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 10)
	root.add_child(btn_row)
	var chat_btn := UiStyle.button("CHAT", Color(0.25, 0.5, 0.95), 24, 60)
	chat_btn.custom_minimum_size.x = 120
	chat_btn.pressed.connect(open_chat)
	btn_row.add_child(chat_btn)
	_players_btn = UiStyle.button("PLAYERS", Color(0.45, 0.35, 0.65), 22, 60)
	_players_btn.custom_minimum_size.x = 130
	_players_btn.pressed.connect(toggle_players)
	btn_row.add_child(_players_btn)
	var emote_btn := UiStyle.button("EMOTE", Color(0.85, 0.4, 0.6), 22, 60)
	emote_btn.custom_minimum_size.x = 120
	emote_btn.pressed.connect(toggle_emotes)
	btn_row.add_child(emote_btn)
	var home_btn := UiStyle.button("HOME", Color(0.95, 0.5, 0.2), 24, 60)
	home_btn.custom_minimum_size.x = 120
	home_btn.pressed.connect(func() -> void: home_pressed.emit())
	btn_row.add_child(home_btn)
	var menu_btn := UiStyle.button("MENU", Color(0.45, 0.45, 0.55), 24, 60)
	menu_btn.custom_minimum_size.x = 120
	menu_btn.pressed.connect(func() -> void: menu_pressed.emit())
	btn_row.add_child(menu_btn)

	_stats_label = UiStyle.label(18)
	_stats_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stats_label.offset_left = -330
	_stats_label.offset_right = -26
	_stats_label.offset_top = 84
	_stats_label.modulate = Color(1, 1, 1, 0.75)
	root.add_child(_stats_label)

	# --- Chat input ---
	_chat_edit = UiStyle.line_edit("Say something...", 26)
	_chat_edit.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_chat_edit.offset_left = -320
	_chat_edit.offset_right = 320
	_chat_edit.offset_top = 100
	_chat_edit.offset_bottom = 162
	_chat_edit.max_length = Network.MAX_CHAT
	_chat_edit.visible = false
	_chat_edit.text_submitted.connect(_on_chat_submitted)
	_chat_edit.focus_exited.connect(close_chat)
	root.add_child(_chat_edit)

	# --- Toast (center) ---
	_toast = UiStyle.label(64)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.offset_left = -500
	_toast.offset_right = 500
	_toast.offset_top = -190
	_toast.offset_bottom = -110
	_toast.pivot_offset = Vector2(500, 40)
	_toast.modulate.a = 0.0
	root.add_child(_toast)

	# --- Controls hint (desktop) ---
	_hint = UiStyle.label(22)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.offset_left = -520
	_hint.offset_right = 520
	_hint.offset_top = -60
	_hint.offset_bottom = -24
	_hint.text = "WASD: move   ·   Space: jump   ·   Drag mouse: camera   ·   Wheel: zoom   ·   Enter: chat"
	_hint.visible = not touch.visible
	root.add_child(_hint)
	if _hint.visible:
		var tw := create_tween()
		tw.tween_interval(8.0)
		tw.tween_property(_hint, "modulate:a", 0.0, 1.0)

	# --- Fade overlay ---
	_fade = ColorRect.new()
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(1, 1, 1, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)

	_build_win_panel(root)
	_build_players_panel(root)
	_build_emote_panel(root)
	_build_leaderboard(root)
	_build_tools(root)
	_build_gui(root)
	if not Game.tutorial_done and DisplayServer.get_name() != "headless":
		_build_tutorial(root)

	Game.coins_changed.connect(_on_coins_changed)
	Game.checkpoint_reached.connect(_on_checkpoint)
	Game.player_died.connect(_on_player_died)
	Game.player_respawned.connect(_on_player_respawned)
	Game.course_started.connect(_on_course_started)
	Game.course_completed.connect(_on_course_completed)
	Network.chat_received.connect(_on_chat_received)
	Game.badge_awarded.connect(_on_badge)
	Game.notice.connect(_on_notice)
	Network.player_joined.connect(_on_player_joined)
	Network.player_left.connect(_on_player_left)
	refresh_coins()


func _process(_delta: float) -> void:
	_timer_label.visible = Game.current_course != ""
	if _timer_label.visible:
		_timer_label.text = "%s  %s" % [Game.current_course, _format_time(Game.course_time)]
	var online := ""
	if Network.is_online():
		online = "   ·   %d online" % (Network.players.size() + (0 if Network.mode == "host" else 1))
	_stats_label.visible = Game.show_fps or online != ""
	_stats_label.text = ("%d FPS" % Engine.get_frames_per_second() if Game.show_fps else "") + online


func _unhandled_input(event: InputEvent) -> void:
	var tk := event as InputEventKey
	if tk != null and tk.pressed and not tk.echo and not Game.input_blocked and _tool_key(tk):
		get_viewport().set_input_as_handled()
		return
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo:
		if k.keycode == KEY_ENTER and not _chat_edit.visible:
			open_chat()
			get_viewport().set_input_as_handled()


func _format_time(t: float) -> String:
	var m := int(t) / 60
	var s := fmod(t, 60.0)
	return "%02d:%04.1f" % [m, s]


## Banner for round-based experiences (empty text hides it).
func set_mode_status(text: String, color: Color = Color(1, 1, 1)) -> void:
	_mode_label.visible = text != ""
	_mode_label.text = text
	_mode_label.label_settings.font_color = color


func set_info(text: String) -> void:
	_info_label.text = text


func show_toast(text: String, color: Color = Color(1, 1, 1)) -> void:
	_toast.text = text
	_toast.label_settings.font_color = color
	_toast.scale = Vector2(0.6, 0.6)
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_toast, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.0)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


func refresh_coins() -> void:
	_coin_label.text = "%d / %d" % [Game.coins, Game.total_coins]


# ------------------------------------------------------------------ chat ---

func open_chat() -> void:
	if Game.chat_muted_until > int(Time.get_unix_time_from_system()):
		show_toast("You are muted by a moderator", Color(1, 0.6, 0.5))
		return
	if not Game.chat_allowed():
		show_toast("Chat is off (SETTINGS)", Color(1, 0.8, 0.5))
		return
	_chat_edit.visible = true
	_chat_edit.text = ""
	_chat_edit.grab_focus()
	Game.input_blocked = true
	touch.release_all()


func close_chat() -> void:
	_chat_edit.visible = false
	_chat_edit.release_focus()
	Game.input_blocked = false


func _on_chat_submitted(text: String) -> void:
	var t := text.strip_edges()
	if t.begins_with("/e ") or t.begins_with("/emote "):
		# Chat emote command, like "/e dance".
		var id := t.get_slice(" ", 1).to_lower()
		if id in Game.EMOTES and id != "":
			Game.emote_requested.emit(id)
		else:
			add_chat_line("Emotes: " + ", ".join(Game.EMOTES.slice(1)), Color(0.7, 0.85, 1.0))
	elif t != "" and Game.chat_allowed():
		Network.send_chat(t)
	close_chat()


func add_chat_line(text: String, color: Color = Color(1, 1, 1)) -> void:
	var l := UiStyle.label(22, color)
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(560, 0)
	_chat_log.add_child(l)
	while _chat_log.get_child_count() > CHAT_LINES:
		var old := _chat_log.get_child(0)
		_chat_log.remove_child(old)
		old.queue_free()
	var tw := l.create_tween()
	tw.tween_interval(CHAT_TTL)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(l.queue_free)


func _on_chat_received(id: int, sender: String, text: String) -> void:
	if Game.is_blocked(str((Network.players.get(id, {}) as Dictionary).get("uid", "")), sender):
		return
	_chat_history.append("%s: %s" % [sender, text])
	if _chat_history.size() > 40:
		_chat_history.pop_front()
	if not Game.chat_allowed() or sender in Game.muted:
		return
	add_chat_line("%s: %s" % [sender, ChatFilter.clean(text)])
	Sfx.play("pop", -4.0)


func _on_player_joined(_id: int, info: Dictionary) -> void:
	add_chat_line("%s joined the game" % info.get("name", "Someone"), Color(0.55, 1.0, 0.6))
	Sfx.play("join", -2.0)


func _on_player_left(id: int) -> void:
	add_chat_line("Player %d left" % id, Color(1.0, 0.7, 0.5))


# ---------------------------------------------------------------- events ---

func _on_coins_changed(_total: int) -> void:
	refresh_coins()
	_coin_label.pivot_offset = _coin_label.size * 0.5
	var tw := create_tween()
	tw.tween_property(_coin_label, "scale", Vector2(1.25, 1.25), 0.07)
	tw.tween_property(_coin_label, "scale", Vector2.ONE, 0.15)


func _on_checkpoint() -> void:
	show_toast("CHECKPOINT!", Color(0.45, 1.0, 0.6))


func _on_course_started(course_name: String) -> void:
	show_toast(course_name.to_upper() + " - GO!", Color(1.0, 0.85, 0.3))


func _on_player_died() -> void:
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(_fade, "color:a", 0.85, 0.3)


func _on_player_respawned() -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.35)


func _on_course_completed(course_name: String, time_sec: float) -> void:
	show_toast("YOU WIN!", Color(1.0, 0.85, 0.2))
	var best: float = Game.best_times.get(course_name, time_sec)
	_win_stats.text = "%s\nTime  %s\nBest  %s" % [course_name, _format_time(time_sec), _format_time(best)]
	_win_panel.visible = true
	if Backend.online:
		_show_world_rank(course_name)
	_win_panel.modulate.a = 0.0
	_win_panel.scale = Vector2(0.8, 0.8)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_win_panel, "modulate:a", 1.0, 0.4).set_delay(0.8)
	tw.tween_property(_win_panel, "scale", Vector2.ONE, 0.45).set_delay(0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _show_world_rank(course_name: String) -> void:
	await get_tree().create_timer(1.2).timeout
	var rows: Array = await Backend.top_times(course_name, 100)
	for r: Dictionary in rows:
		if r["mine"]:
			add_chat_line("World rank on %s: #%d" % [course_name, r["rank"]], Color(1.0, 0.85, 0.3))
			return


func _build_win_panel(root: Control) -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	_win_panel = PanelContainer.new()
	_win_panel.visible = false
	_win_panel.custom_minimum_size = Vector2(500, 0)
	_win_panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	center.add_child(_win_panel)
	_win_panel.resized.connect(_on_win_resized)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	_win_panel.add_child(vb)

	var title := UiStyle.label(56, Color(1.0, 0.85, 0.2))
	title.text = "COURSE CLEAR!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	_win_stats = UiStyle.label(32)
	_win_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_win_stats)

	var home := UiStyle.button("BACK TO SPAWN", Color(0.2, 0.72, 0.35), 30, 76)
	home.pressed.connect(_on_win_home)
	vb.add_child(home)
	var cont := UiStyle.button("KEEP EXPLORING", Color(0.3, 0.4, 0.6), 26, 64)
	cont.pressed.connect(_hide_win)
	vb.add_child(cont)


# ------------------------------------------------------------ tutorial ---

const TIPS: Array[String] = [
	"Move with the joystick on the left side of the screen.",
	"Tap the arrow button to jump. Hold it to jump higher.",
	"Drag on the right side to look around. Pinch to zoom.",
	"Press HOME to go back to the start. Have fun!",
]
var _tip_index: int = 0
var _tip_panel: PanelContainer
var _tip_label: Label


func _build_tutorial(root: Control) -> void:
	_tip_panel = PanelContainer.new()
	_tip_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_tip_panel.offset_left = -330
	_tip_panel.offset_right = 330
	_tip_panel.offset_top = -40
	_tip_panel.offset_bottom = 120
	_tip_panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	root.add_child(_tip_panel)
	touch.blockers.append(_tip_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	_tip_panel.add_child(vb)
	_tip_label = UiStyle.label(26)
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_tip_label)
	var next := UiStyle.button("NEXT", Color(0.2, 0.72, 0.35), 22, 56)
	next.pressed.connect(_next_tip)
	vb.add_child(next)
	_tip_label.text = TIPS[0]


func _next_tip() -> void:
	_tip_index += 1
	if _tip_index >= TIPS.size():
		_tip_panel.queue_free()
		Game.tutorial_done = true
		Game.save_profile()
		return
	_tip_label.text = TIPS[_tip_index]


# ------------------------------------------------------------- players ---

func _build_players_panel(root: Control) -> void:
	_players_panel = PanelContainer.new()
	_players_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_players_panel.offset_left = -860
	_players_panel.offset_right = -24
	_players_panel.offset_top = 120
	_players_panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	_players_panel.visible = false
	root.add_child(_players_panel)
	_players_list = VBoxContainer.new()
	_players_list.add_theme_constant_override("separation", 8)
	_players_panel.add_child(_players_list)
	touch.blockers.append(_players_panel)


func toggle_players() -> void:
	_players_panel.visible = not _players_panel.visible
	if _players_panel.visible:
		_refresh_players()


func _refresh_players() -> void:
	for ch in _players_list.get_children():
		ch.queue_free()
	var title := UiStyle.label(28, Color(1.0, 0.85, 0.3))
	title.text = "PLAYERS"
	_players_list.add_child(title)
	if Network.players.is_empty():
		var l := UiStyle.label(20, Color(1, 1, 1, 0.7))
		l.text = "You are playing alone. HOST or JOIN to play with friends."
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 480
		_players_list.add_child(l)
		return
	for id: int in Network.players:
		var info: Dictionary = Network.players[id]
		var pname := str(info.get("name", "Player"))
		if id == Network.my_id():
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_players_list.add_child(row)
		var l2 := UiStyle.label(22)
		l2.text = pname
		l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l2)
		var muted := pname in Game.muted
		var mb := UiStyle.button("UNMUTE" if muted else "MUTE", Color(0.4, 0.4, 0.5), 16, 46)
		mb.pressed.connect(func() -> void: _toggle_mute(pname))
		row.add_child(mb)
		var rb := UiStyle.button("REPORT", Color(0.7, 0.3, 0.3), 16, 46)
		rb.pressed.connect(func() -> void: _report(pname))
		row.add_child(rb)
		var uid := str(info.get("uid", ""))
		var bb := UiStyle.button("UNBLOCK" if Game.is_blocked(uid, pname) else "BLOCK", Color(0.35, 0.3, 0.35), 16, 46)
		bb.pressed.connect(_toggle_block.bind(uid, pname))
		row.add_child(bb)
		if Network.mode == "host":
			var kb := UiStyle.button("KICK", Color(0.8, 0.4, 0.2), 16, 46)
			kb.pressed.connect(_kick.bind(id, pname))
			row.add_child(kb)


func _toggle_block(uid: String, pname: String) -> void:
	if Game.is_blocked(uid, pname):
		Game.unblock_player(pname)
	else:
		Game.block_player(uid, pname)
		Backend.block_user(uid)
		show_toast(tr("%s is blocked") % pname, Color(1, 0.85, 0.5))
	_refresh_players()


func _kick(id: int, pname: String) -> void:
	Network.kick(id, "The host removed you from the game.")
	add_chat_line(tr("You removed %s") % pname, Color(1.0, 0.7, 0.5))
	get_tree().create_timer(0.6).timeout.connect(_refresh_players)


func _toggle_mute(pname: String) -> void:
	if pname in Game.muted:
		Game.muted.erase(pname)
	else:
		Game.muted.append(pname)
	_refresh_players()


func _report(pname: String) -> void:
	if not Game.muted.has(pname):
		Game.muted.append(pname)
	var ok: bool = await Backend.report_player(pname, "player report", _chat_history)
	show_toast("Report sent - thank you" if ok else "Player muted", Color(1, 0.85, 0.5))
	_refresh_players()


func _on_win_resized() -> void:
	_win_panel.pivot_offset = _win_panel.size * 0.5


func _on_win_home() -> void:
	_hide_win()
	home_pressed.emit()


func _hide_win() -> void:
	_win_panel.visible = false


# -------------------------------------------------------------- emotes ---

var _emote_panel: PanelContainer


func _build_emote_panel(root: Control) -> void:
	_emote_panel = PanelContainer.new()
	_emote_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_emote_panel.offset_left = -470
	_emote_panel.offset_right = -24
	_emote_panel.offset_top = 92
	_emote_panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	_emote_panel.visible = false
	root.add_child(_emote_panel)
	touch.blockers.append(_emote_panel)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_emote_panel.add_child(grid)
	for id in Game.EMOTES:
		if id == "":
			continue
		var b := UiStyle.button(str(id).to_upper(), Color(0.55, 0.3, 0.6), 18, 58)
		b.custom_minimum_size.x = 96
		b.pressed.connect(_emote_pressed.bind(str(id)))
		grid.add_child(b)
	var rb := UiStyle.button("RESET", Color(0.7, 0.3, 0.3), 18, 58)
	rb.custom_minimum_size.x = 96
	rb.pressed.connect(_reset_pressed)
	grid.add_child(rb)


func _reset_pressed() -> void:
	_emote_panel.visible = false
	Game.kill_player()


func toggle_emotes() -> void:
	_emote_panel.visible = not _emote_panel.visible


func _emote_pressed(id: String) -> void:
	_emote_panel.visible = false
	Game.emote_requested.emit(id)


# -------------------------------------------------------------- badges ---

func _on_notice(text: String) -> void:
	show_toast(tr(text), Color(0.6, 0.95, 1.0))


func _on_badge(badge_name: String, desc: String) -> void:
	show_toast(tr("BADGE: %s") % tr(badge_name), Color(1.0, 0.85, 0.3))
	add_chat_line(tr("You earned the badge \"%s\" - %s") % [tr(badge_name), tr(desc)], Color(1.0, 0.85, 0.3))
	Sfx.play("win", -6.0)


# ---------------------------------------------------------- leaderboard ---
## Player list with stats set by game scripts (player:set_stat("Kills", 3)).

var _board: PanelContainer
var _board_grid: GridContainer
var _board_stats: Dictionary = {}


func _build_leaderboard(root: Control) -> void:
	_board = PanelContainer.new()
	_board.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_board.offset_left = -330
	_board.offset_right = -24
	_board.offset_top = 112
	var sb := UiStyle.box(Color(0.05, 0.06, 0.12, 0.6), 12, 10)
	_board.add_theme_stylebox_override("panel", sb)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.visible = false
	root.add_child(_board)
	_board_grid = GridContainer.new()
	_board_grid.add_theme_constant_override("h_separation", 14)
	_board_grid.add_theme_constant_override("v_separation", 2)
	_board_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_child(_board_grid)


## stats: {peer_id: {stat_name: value}}
func set_leaderstats(stats: Dictionary) -> void:
	_board_stats = stats
	for ch in _board_grid.get_children():
		_board_grid.remove_child(ch)
		ch.queue_free()
	var names: Array[String] = []
	for pid in stats:
		for k in (stats[pid] as Dictionary):
			if not names.has(str(k)) and names.size() < 3:
				names.append(str(k))
	_board.visible = not names.is_empty()
	if names.is_empty():
		return
	_board_grid.columns = names.size() + 1
	_board_cell(tr("Player"), Color(1.0, 0.85, 0.3))
	for n in names:
		_board_cell(n, Color(1.0, 0.85, 0.3))
	var rows: Array = stats.keys()
	var first := names[0]
	rows.sort_custom(_by_first_stat.bind(first))
	for pid in rows:
		var row: Dictionary = stats[pid]
		var me := int(pid) == Network.my_id()
		_board_cell(_player_name(int(pid)), Color(0.6, 1.0, 0.6) if me else Color(1, 1, 1))
		for n in names:
			var v: Variant = row.get(n, 0)
			_board_cell(RooScript.to_str(v), Color(1, 1, 1))


func _by_first_stat(a: Variant, b: Variant, key: String) -> bool:
	var va := float((_board_stats.get(a, {}) as Dictionary).get(key, 0)) if _is_num((_board_stats.get(a, {}) as Dictionary).get(key, 0)) else 0.0
	var vb := float((_board_stats.get(b, {}) as Dictionary).get(key, 0)) if _is_num((_board_stats.get(b, {}) as Dictionary).get(key, 0)) else 0.0
	return va > vb


func _is_num(v: Variant) -> bool:
	return v is int or v is float


func _board_cell(text: String, col: Color) -> void:
	var l := UiStyle.label(18, col)
	l.text = text
	l.custom_minimum_size.x = 60
	_board_grid.add_child(l)


func _player_name(pid: int) -> String:
	if pid == Network.my_id():
		return Game.player_name
	var info: Dictionary = Network.players.get(pid, {})
	return str(info.get("name", "Player %d" % pid))


# ----------------------------------------------------- backpack / health ---

var _hotbar: HBoxContainer
var _use_btn: Button
var _health_bg: ColorRect
var _health_fg: ColorRect


func _build_tools(root: Control) -> void:
	_hotbar = HBoxContainer.new()
	_hotbar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hotbar.offset_left = -330
	_hotbar.offset_right = 330
	_hotbar.offset_top = -92
	_hotbar.offset_bottom = -20
	_hotbar.alignment = BoxContainer.ALIGNMENT_CENTER
	_hotbar.add_theme_constant_override("separation", 8)
	root.add_child(_hotbar)
	touch.blockers.append(_hotbar)
	_use_btn = UiStyle.button("USE", Color(0.85, 0.35, 0.3), 26, 96)
	_use_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_use_btn.offset_left = -330
	_use_btn.offset_right = -230
	_use_btn.offset_top = -200
	_use_btn.offset_bottom = -104
	_use_btn.visible = false
	_use_btn.pressed.connect(_on_use)
	root.add_child(_use_btn)
	touch.blockers.append(_use_btn)
	_health_bg = ColorRect.new()
	_health_bg.color = Color(0, 0, 0, 0.45)
	_health_bg.position = Vector2(30, 66)
	_health_bg.size = Vector2(220, 14)
	_health_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_health_bg)
	_health_fg = ColorRect.new()
	_health_fg.color = Color(0.3, 0.9, 0.4)
	_health_fg.size = Vector2(220, 14)
	_health_fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_bg.add_child(_health_fg)
	_health_bg.visible = false
	Game.backpack_changed.connect(_refresh_hotbar)
	Game.health_changed.connect(_on_health)
	_refresh_hotbar()


func _refresh_hotbar() -> void:
	for ch in _hotbar.get_children():
		ch.queue_free()
	for i in Game.backpack.size():
		var id := str(Game.backpack[i])
		var held := i == Game.held_tool
		var b := UiStyle.button("%d  %s" % [i + 1, tr(Tools.label(id))], Tools.color(id).darkened(0.45), 15, 64)
		b.custom_minimum_size.x = 120
		var sb := UiStyle.box(Tools.color(id).darkened(0.2 if held else 0.55), 14, 6)
		sb.border_color = Color(1.0, 0.85, 0.25) if held else Color(0, 0, 0, 0.4)
		sb.set_border_width_all(4 if held else 2)
		b.add_theme_stylebox_override("normal", sb)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(Game.equip_tool.bind(i))
		_hotbar.add_child(b)
	_use_btn.visible = Tools.usable(Game.held_tool_id())


func _on_use() -> void:
	Game.tool_used.emit()


func _on_health(h: float, mx: float) -> void:
	_health_bg.visible = h < mx
	var k := clampf(h / maxf(mx, 1.0), 0.0, 1.0)
	_health_fg.size.x = 220.0 * k
	_health_fg.color = Color(0.9, 0.25, 0.2).lerp(Color(0.3, 0.9, 0.4), k)


## Desktop: 1-6 hold a tool, E / left Ctrl uses it.
func _tool_key(key: InputEventKey) -> bool:
	if key.keycode >= KEY_1 and key.keycode <= KEY_6:
		Game.equip_tool(key.keycode - KEY_1)
		return true
	if key.keycode == KEY_E:
		Game.tool_used.emit()
		return true
	return false


# ------------------------------------------------------- script GUI ---
## Labels and buttons made by game scripts (ui.label / ui.button).

signal gui_pressed(id: String)

var _gui_box: VBoxContainer
var _gui_items: Dictionary = {}


func _build_gui(root: Control) -> void:
	_gui_box = VBoxContainer.new()
	_gui_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	_gui_box.offset_left = 24
	_gui_box.offset_right = 344
	_gui_box.offset_top = -60
	_gui_box.offset_bottom = 200
	_gui_box.add_theme_constant_override("separation", 8)
	_gui_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_gui_box)
	touch.blockers.append(_gui_box)


func set_gui(id: String, kind: String, text: String) -> void:
	if id == "":
		return
	var old: Control = _gui_items.get(id)
	if text == "":
		if old != null:
			old.queue_free()
			_gui_items.erase(id)
		return
	if old != null and ((kind == "button") != (old is Button)):
		old.queue_free()
		old = null
	if old == null:
		if kind == "button":
			var b := UiStyle.button(text, Color(0.3, 0.45, 0.85), 20, 56)
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(_gui_press.bind(id))
			old = b
		else:
			var panel := PanelContainer.new()
			panel.add_theme_stylebox_override("panel", UiStyle.box(Color(0.05, 0.06, 0.12, 0.65), 12, 10))
			panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var l := UiStyle.label(20)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			panel.add_child(l)
			old = panel
		_gui_box.add_child(old)
		_gui_items[id] = old
	if old is Button:
		(old as Button).text = text
	else:
		((old as PanelContainer).get_child(0) as Label).text = text


func _gui_press(id: String) -> void:
	gui_pressed.emit(id)
