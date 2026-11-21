class_name GameTile
extends Button
## A game card with a real 3D thumbnail (rendered on demand when the card
## scrolls into view, then cached). Until the picture is ready it shows
## drawn art in the game type's color.

signal chosen(id: String)

var game_id: String = ""
var title: String = ""
var subtitle: String = ""
var color: Color = Color(0.4, 0.5, 0.8)
## Thumbnail cache key and level source (Callable() -> Dictionary).
var thumb_key: String = ""
var level_provider: Callable = Callable()
var tile_size: Vector2 = Vector2(232, 182)

var _thumb: TextureRect
var _requested: bool = false
var _scrolls: Array[ScrollContainer] = []


func _ready() -> void:
	custom_minimum_size = tile_size
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	var sb := UiStyle.box(Color(0.1, 0.12, 0.22), 16, 0)
	sb.border_color = color.darkened(0.1)
	sb.set_border_width_all(3)
	add_theme_stylebox_override("normal", sb)
	var hov := sb.duplicate() as StyleBoxFlat
	hov.border_color = color.lightened(0.3)
	add_theme_stylebox_override("hover", hov)
	var pr := sb.duplicate() as StyleBoxFlat
	pr.bg_color = Color(0.06, 0.07, 0.14)
	add_theme_stylebox_override("pressed", pr)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 6
	vb.offset_right = -6
	vb.offset_top = 6
	vb.offset_bottom = -6
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vb)
	var art := Art.new()
	art.color = color
	art.custom_minimum_size = Vector2(0, (tile_size.x - 12) * 9.0 / 16.0)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(art)
	_thumb = TextureRect.new()
	_thumb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(_thumb)
	var t := UiStyle.label(16)
	t.text = title
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.clip_text = true
	vb.add_child(t)
	if subtitle != "":
		var st := UiStyle.label(12, color.lightened(0.45))
		st.text = subtitle
		st.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		st.clip_text = true
		vb.add_child(st)
	pressed.connect(_on_pressed)
	var p := get_parent()
	while p != null:
		if p is ScrollContainer:
			_scrolls.append(p as ScrollContainer)
		p = p.get_parent()
	if thumb_key == "" or not level_provider.is_valid():
		set_process(false)


func _on_pressed() -> void:
	chosen.emit(game_id)


func _process(_delta: float) -> void:
	if _requested:
		set_process(false)
		return
	if not is_visible_in_tree():
		return
	var r := get_global_rect()
	if not r.intersects(get_viewport_rect()):
		return
	for sc in _scrolls:
		if is_instance_valid(sc) and not r.intersects(sc.get_global_rect()):
			return
	_requested = true
	Thumbs.request(thumb_key, level_provider, _on_thumb)


func _on_thumb(tex: Texture2D) -> void:
	if is_instance_valid(_thumb):
		_thumb.texture = tex


## Placeholder picture: sky, ground and a few blocks in the card color.
class Art:
	extends Control
	var color: Color = Color.WHITE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var bands := 8
		for i in bands:
			var c := Color(0.25, 0.45, 0.85).lerp(Color(0.65, 0.82, 1.0), float(i) / bands)
			draw_rect(Rect2(0, h * 0.62 * i / bands, w, h * 0.62 / bands + 1), c)
		draw_rect(Rect2(0, h * 0.62, w, h * 0.38), color.darkened(0.35))
		for i in 5:
			var bw := w * 0.11
			var bh := h * (0.12 + 0.07 * i)
			draw_rect(Rect2(w * 0.12 + i * w * 0.16, h * 0.62 - bh, bw, bh), color.lightened(0.1 * i))
			draw_rect(Rect2(w * 0.12 + i * w * 0.16, h * 0.62 - bh, bw, 4), color.lightened(0.5))
