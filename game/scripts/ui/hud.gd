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
	btn_row.offset_left = -460
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

	Game.coins_changed.connect(_on_coins_changed)
	Game.checkpoint_reached.connect(_on_checkpoint)
	Game.player_died.connect(_on_player_died)
	Game.player_respawned.connect(_on_player_respawned)
	Game.course_started.connect(_on_course_started)
	Game.course_completed.connect(_on_course_completed)
	Network.chat_received.connect(_on_chat_received)
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
	_stats_label.text = "%d FPS%s" % [Engine.get_frames_per_second(), online]


func _unhandled_input(event: InputEvent) -> void:
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
	if text.strip_edges() != "":
		Network.send_chat(text)
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


func _on_chat_received(_id: int, sender: String, text: String) -> void:
	add_chat_line("%s: %s" % [sender, text])
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


func _on_win_resized() -> void:
	_win_panel.pivot_offset = _win_panel.size * 0.5


func _on_win_home() -> void:
	_hide_win()
	home_pressed.emit()


func _hide_win() -> void:
	_win_panel.visible = false
