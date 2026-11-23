class_name UiIcon
extends Control
## Simple vector icons drawn in code (no image files), designed on a 24x24
## grid and scaled to the control size.
## kinds: home, create, avatar, friends, trophy, gear, chat, people, smile,
##        menu, coin, search, back, heart, play, close

var kind: String = "home"
var color: Color = Color(1, 1, 1)


static func make(icon_kind: String, icon_color: Color = Color(1, 1, 1), px: float = 28.0) -> UiIcon:
	var i := UiIcon.new()
	i.kind = icon_kind
	i.color = icon_color
	i.custom_minimum_size = Vector2(px, px)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


func _ready() -> void:
	resized.connect(queue_redraw)


func _p(x: float, y: float) -> Vector2:
	var s := minf(size.x, size.y) / 24.0
	var off := (size - Vector2(24, 24) * s) * 0.5
	return off + Vector2(x, y) * s


func _s() -> float:
	return minf(size.x, size.y) / 24.0


func _poly(pts: Array, c: Color) -> void:
	var arr := PackedVector2Array()
	for p in pts:
		arr.append(_p(p[0], p[1]))
	draw_colored_polygon(arr, c)


func _line(a: Array, b: Array, w: float, c: Color) -> void:
	draw_line(_p(a[0], a[1]), _p(b[0], b[1]), c, w * _s(), true)


func _circle(x: float, y: float, r: float, c: Color) -> void:
	draw_circle(_p(x, y), r * _s(), c)


func _ring(x: float, y: float, r: float, w: float, c: Color) -> void:
	draw_arc(_p(x, y), r * _s(), 0.0, TAU, 32, c, w * _s(), true)


func _draw() -> void:
	var c := color
	match kind:
		"home", "play":
			_poly([[12, 3], [22, 11], [19, 11], [19, 21], [5, 21], [5, 11], [2, 11]], c)
			_poly([[10, 14], [14, 14], [14, 21], [10, 21]], Color(0, 0, 0, 0.35))
		"create":
			_poly([[15, 4], [20, 9], [9, 20], [4, 20], [4, 15]], c)
			_poly([[16.5, 2.5], [21.5, 7.5], [20, 9], [15, 4]], c.darkened(0.3))
		"avatar":
			_circle(12, 8, 4.5, c)
			_poly([[3, 22], [5, 15], [9, 13], [15, 13], [19, 15], [21, 22]], c)
		"friends", "people":
			_circle(8.5, 8, 3.5, c)
			_poly([[1, 21], [3, 15], [6, 13.5], [11, 13.5], [14, 15], [16, 21]], c)
			_circle(16.5, 7, 3.2, c.darkened(0.2))
			_poly([[13, 13], [19, 13], [22, 15], [23, 20], [17, 20], [16, 15.5]], c.darkened(0.2))
		"trophy":
			_poly([[6, 3], [18, 3], [17, 10], [12, 14], [7, 10]], c)
			_ring(5, 7, 3, 1.6, c)
			_ring(19, 7, 3, 1.6, c)
			_poly([[10.5, 13], [13.5, 13], [13.5, 18], [10.5, 18]], c)
			_poly([[7, 18], [17, 18], [17, 21], [7, 21]], c)
		"gear":
			for i in 8:
				var a := TAU * i / 8.0
				var d := Vector2(cos(a), sin(a))
				var n := Vector2(-d.y, d.x)
				var cc := Vector2(12, 12)
				var pts := [cc + d * 6 + n * 2, cc + d * 10.5 + n * 1.6, cc + d * 10.5 - n * 1.6, cc + d * 6 - n * 2]
				var arr := PackedVector2Array()
				for q in pts:
					arr.append(_p((q as Vector2).x, (q as Vector2).y))
				draw_colored_polygon(arr, c)
			_circle(12, 12, 7, c)
			_circle(12, 12, 3, Color(0, 0, 0, 0.45))
		"chat":
			draw_rect(Rect2(_p(2, 4), Vector2(20, 13) * _s()), c)
			_poly([[6, 16], [11, 16], [6, 21]], c)
			for x in [7.0, 12.0, 17.0]:
				_circle(x, 10.5, 1.5, Color(0, 0, 0, 0.45))
		"smile":
			_circle(12, 12, 10, c)
			_circle(8.5, 9.5, 1.5, Color(0, 0, 0, 0.6))
			_circle(15.5, 9.5, 1.5, Color(0, 0, 0, 0.6))
			draw_arc(_p(12, 12), 5.5 * _s(), 0.35, PI - 0.35, 16, Color(0, 0, 0, 0.6), 1.8 * _s(), true)
		"menu":
			for y in [6.0, 12.0, 18.0]:
				_line([4, y], [20, y], 2.6, c)
		"coin":
			_circle(12, 12, 10, Color(1.0, 0.78, 0.2))
			_circle(12, 12, 7, Color(1.0, 0.88, 0.35))
			_poly([[11, 7], [13, 7], [13, 17], [11, 17]], Color(0.85, 0.6, 0.1))
		"search":
			_ring(10, 10, 6, 2.4, c)
			_line([14.5, 14.5], [21, 21], 3.0, c)
		"back":
			_line([15, 4], [7, 12], 3.0, c)
			_line([7, 12], [15, 20], 3.0, c)
		"heart":
			_circle(8, 9, 5, c)
			_circle(16, 9, 5, c)
			_poly([[3.3, 11], [20.7, 11], [12, 21]], c)
		"close":
			_line([5, 5], [19, 19], 3.0, c)
			_line([19, 5], [5, 19], 3.0, c)
		_:
			_circle(12, 12, 8, c)
