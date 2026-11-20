class_name UiStyle
extends RefCounted
## Shared look for menus and HUD widgets.

const DARK := Color(0.07, 0.08, 0.16)


static func label(font_size: int, color: Color = Color(1, 1, 1)) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font_size = font_size
	ls.font_color = color
	ls.outline_size = maxi(4, font_size / 5)
	ls.outline_color = DARK
	ls.shadow_size = 2
	ls.shadow_color = Color(0, 0, 0, 0.35)
	ls.shadow_offset = Vector2(0, 3)
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func box(c: Color, radius: int = 18, margin: float = 12.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


static func panel_style() -> StyleBoxFlat:
	var sb := box(Color(0.08, 0.1, 0.2, 0.86), 26, 26)
	sb.border_color = Color(1, 1, 1, 0.14)
	sb.set_border_width_all(3)
	return sb


static func button(text: String, color: Color, font_size: int = 30, height: float = 72.0) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, height)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_outline_color", DARK)
	btn.add_theme_constant_override("outline_size", 6)
	var normal := box(color, 18, 10)
	normal.shadow_color = Color(0, 0, 0, 0.3)
	normal.shadow_size = 5
	normal.shadow_offset = Vector2(0, 4)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", box(color.lightened(0.12), 18, 10))
	btn.add_theme_stylebox_override("pressed", box(color.darkened(0.15), 18, 10))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.pressed.connect(func() -> void: Sfx.play("click"))
	return btn


static func line_edit(placeholder: String, font_size: int = 28) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = placeholder
	le.custom_minimum_size = Vector2(0, 62)
	le.add_theme_font_size_override("font_size", font_size)
	le.add_theme_stylebox_override("normal", box(Color(1, 1, 1, 0.12), 14, 12))
	le.add_theme_stylebox_override("focus", box(Color(1, 1, 1, 0.2), 14, 12))
	le.add_theme_color_override("font_color", Color(1, 1, 1))
	le.add_theme_color_override("font_placeholder_color", Color(1, 1, 1, 0.45))
	return le
