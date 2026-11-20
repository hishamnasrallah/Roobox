class_name Hud
extends CanvasLayer
## In-game HUD: coins, timer, FPS, toasts, respawn fade, win screen.

var touch: TouchControls
var _coin_label: Label
var _time_label: Label
var _fps_label: Label
var _toast: Label
var _hint: Label
var _fade: ColorRect
var _win_panel: PanelContainer
var _win_stats: Label


class CoinIcon:
	extends Control

	func _ready() -> void:
		custom_minimum_size = Vector2(40, 40)

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 18.0, Color(0.85, 0.55, 0.05))
		draw_circle(c, 14.0, Color(1.0, 0.82, 0.15))
		draw_rect(Rect2(c + Vector2(-3, -9), Vector2(6, 18)), Color(1.0, 0.95, 0.6))


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	touch = TouchControls.new()
	root.add_child(touch)

	# --- Coins (top-left) ---
	var coin_box := HBoxContainer.new()
	coin_box.position = Vector2(28, 22)
	coin_box.add_theme_constant_override("separation", 10)
	coin_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(coin_box)
	coin_box.add_child(CoinIcon.new())
	_coin_label = _label(36)
	coin_box.add_child(_coin_label)

	# --- Timer (top-center) ---
	_time_label = _label(36)
	_time_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.offset_left = -150
	_time_label.offset_right = 150
	_time_label.offset_top = 22
	root.add_child(_time_label)

	# --- FPS (top-right) ---
	_fps_label = _label(20)
	_fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps_label.offset_left = -160
	_fps_label.offset_right = -24
	_fps_label.offset_top = 24
	_fps_label.modulate = Color(1, 1, 1, 0.7)
	root.add_child(_fps_label)

	# --- Toast (center) ---
	_toast = _label(64)
	_toast.set_anchors_preset(Control.PRESET_CENTER)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.offset_left = -400
	_toast.offset_right = 400
	_toast.offset_top = -180
	_toast.offset_bottom = -100
	_toast.pivot_offset = Vector2(400, 40)
	_toast.modulate.a = 0.0
	root.add_child(_toast)

	# --- Controls hint (desktop) ---
	_hint = _label(22)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.offset_left = -500
	_hint.offset_right = 500
	_hint.offset_top = -60
	_hint.offset_bottom = -24
	_hint.text = "WASD / Arrows: move   ·   Space: jump   ·   Drag mouse: camera   ·   Wheel: zoom"
	_hint.visible = not touch.visible
	root.add_child(_hint)
	if _hint.visible:
		var tw := create_tween()
		tw.tween_interval(7.0)
		tw.tween_property(_hint, "modulate:a", 0.0, 1.0)

	# --- Fade overlay ---
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(1, 1, 1, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)

	_build_win_panel(root)

	Game.coins_changed.connect(_on_coins_changed)
	Game.checkpoint_reached.connect(_on_checkpoint)
	Game.player_died.connect(_on_player_died)
	Game.player_respawned.connect(_on_player_respawned)
	Game.level_completed.connect(_on_level_completed)
	_on_coins_changed(Game.coins)
	show_toast("GO!", Color(0.5, 1.0, 0.55))


func _process(_delta: float) -> void:
	_time_label.text = _format_time(Game.run_time)
	_fps_label.text = "%d FPS" % Engine.get_frames_per_second()


func _label(font_size: int) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font_size = font_size
	ls.font_color = Color(1, 1, 1)
	ls.outline_size = maxi(4, font_size / 5)
	ls.outline_color = Color(0.07, 0.08, 0.16)
	ls.shadow_size = 2
	ls.shadow_color = Color(0, 0, 0, 0.35)
	ls.shadow_offset = Vector2(0, 3)
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _format_time(t: float) -> String:
	var m := int(t) / 60
	var s := fmod(t, 60.0)
	return "%02d:%04.1f" % [m, s]


func show_toast(text: String, color: Color = Color(1, 1, 1)) -> void:
	_toast.text = text
	_toast.label_settings.font_color = color
	_toast.scale = Vector2(0.6, 0.6)
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_toast, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.9)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


func _on_coins_changed(total: int) -> void:
	_coin_label.text = "%d / %d" % [total, Game.total_coins]
	_coin_label.pivot_offset = _coin_label.size * 0.5
	var tw := create_tween()
	tw.tween_property(_coin_label, "scale", Vector2(1.25, 1.25), 0.07)
	tw.tween_property(_coin_label, "scale", Vector2.ONE, 0.15)


func refresh_coins() -> void:
	_coin_label.text = "%d / %d" % [Game.coins, Game.total_coins]


func _on_checkpoint(_index: int) -> void:
	show_toast("CHECKPOINT!", Color(0.45, 1.0, 0.6))


func _on_player_died() -> void:
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(_fade, "color:a", 0.85, 0.3)


func _on_player_respawned() -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.35)


func _on_level_completed(time_sec: float, coins: int) -> void:
	touch.release_all()
	touch.visible = false
	show_toast("YOU WIN!", Color(1.0, 0.85, 0.2))
	_win_stats.text = "Time  %s\nCoins  %d / %d" % [_format_time(time_sec), coins, Game.total_coins]
	_win_panel.visible = true
	_win_panel.modulate.a = 0.0
	_win_panel.scale = Vector2(0.8, 0.8)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_win_panel, "modulate:a", 1.0, 0.4).set_delay(0.8)
	tw.tween_property(_win_panel, "scale", Vector2.ONE, 0.45).set_delay(0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_win_panel(root: Control) -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	_win_panel = PanelContainer.new()
	_win_panel.visible = false
	_win_panel.custom_minimum_size = Vector2(460, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.2, 0.88)
	sb.set_corner_radius_all(28)
	sb.set_content_margin_all(32)
	sb.border_color = Color(1, 1, 1, 0.15)
	sb.set_border_width_all(3)
	_win_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_win_panel)
	_win_panel.resized.connect(func() -> void: _win_panel.pivot_offset = _win_panel.size * 0.5)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	_win_panel.add_child(vb)

	var title := _label(58)
	title.text = "COURSE CLEAR!"
	title.label_settings.font_color = Color(1.0, 0.85, 0.2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	_win_stats = _label(34)
	_win_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_win_stats)

	var btn := Button.new()
	btn.text = "PLAY AGAIN"
	btn.custom_minimum_size = Vector2(0, 84)
	btn.add_theme_font_size_override("font_size", 34)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_stylebox_override("normal", _button_style(Color(0.2, 0.75, 0.35)))
	btn.add_theme_stylebox_override("hover", _button_style(Color(0.25, 0.85, 0.42)))
	btn.add_theme_stylebox_override("pressed", _button_style(Color(0.15, 0.6, 0.28)))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.pressed.connect(Game.restart)
	vb.add_child(btn)


func _button_style(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(20)
	sb.set_content_margin_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 4)
	return sb
