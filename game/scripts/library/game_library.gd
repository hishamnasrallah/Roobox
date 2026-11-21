class_name GameLibrary
extends RefCounted
## The built-in game library: 13 game types x 16 themes = 208 original games.
## Every game is generated deterministically as a Level (the same format as
## Studio creations), so each one can be played solo, hosted on Wi-Fi, or
## remixed in Studio.

const GENRES: Array[Dictionary] = [
	{"id": "obby", "title": "Obby", "desc": "Jump across platforms, dodge lava and spikes, reach the finish."},
	{"id": "tower", "title": "Tower", "desc": "Climb a giant spiral tower to the very top."},
	{"id": "parkour", "title": "Parkour", "desc": "Run, climb ladders, ride conveyors and leap gaps."},
	{"id": "maze", "title": "Maze", "desc": "Find your way through the maze and grab the coins."},
	{"id": "lava", "title": "Floor is Lava", "desc": "The lava keeps rising - climb as high as you can!"},
	{"id": "coins", "title": "Coin Hunt", "desc": "Explore and collect every coin hidden in the map."},
	{"id": "islands", "title": "Sky Islands", "desc": "Hop between floating islands high in the sky."},
	{"id": "race", "title": "Race", "desc": "Speed pads, ramps and boosts - beat your best time."},
	{"id": "bounce", "title": "Trampoline Park", "desc": "Bounce higher and higher on jump pads."},
	{"id": "vanish", "title": "Vanishing Path", "desc": "Platforms disappear after you touch them - keep moving!"},
	{"id": "doors", "title": "Button Doors", "desc": "Press the buttons to open the doors, room after room."},
	{"id": "swim", "title": "Water Course", "desc": "Swim through pools, climb ladders and reach the end."},
	{"id": "hangout", "title": "Hangout", "desc": "A place to chill with friends: disco floor, houses and lights."},
]

## colors = indices into Level.COLORS
const THEMES: Array[Dictionary] = [
	{"id": "meadow", "title": "Meadow", "env": "day", "ground": "grass", "path": ["planks", "stone", "plastic"], "colors": [7, 8, 6, 4], "decor": "trees"},
	{"id": "desert", "title": "Desert", "env": "day", "ground": "sand", "path": ["sand", "brick", "planks"], "colors": [5, 6, 3, 4], "decor": "cactus"},
	{"id": "frozen", "title": "Frozen", "env": "day", "ground": "snow", "path": ["ice", "snow", "stone"], "colors": [8, 11, 0, 9], "decor": "snowmen"},
	{"id": "candy", "title": "Candy", "env": "day", "ground": "wool", "path": ["plastic", "wool"], "colors": [10, 6, 9, 4], "decor": "lollipops"},
	{"id": "galaxy", "title": "Galaxy", "env": "space", "ground": "metal", "path": ["neon", "metal", "glass"], "colors": [9, 8, 10, 7], "decor": "crystals"},
	{"id": "jungle", "title": "Jungle", "env": "day", "ground": "grass", "path": ["log", "leaves", "planks"], "colors": [7, 2, 5, 3], "decor": "trees"},
	{"id": "ocean", "title": "Ocean", "env": "day", "ground": "sand", "path": ["planks", "plastic", "wool"], "colors": [8, 11, 6, 9], "decor": "palms"},
	{"id": "volcano", "title": "Volcano", "env": "sunset", "ground": "basalt", "path": ["basalt", "stone", "brick"], "colors": [4, 5, 1, 6], "decor": "rocks"},
	{"id": "castle", "title": "Castle", "env": "day", "ground": "cobble", "path": ["cobble", "stone", "brick"], "colors": [0, 1, 9, 4], "decor": "towers"},
	{"id": "city", "title": "City", "env": "day", "ground": "stone", "path": ["metal", "glass", "brick"], "colors": [1, 0, 8, 6], "decor": "buildings"},
	{"id": "neon", "title": "Neon", "env": "night", "ground": "basalt", "path": ["neon", "glass"], "colors": [9, 10, 8, 7], "decor": "lights"},
	{"id": "autumn", "title": "Autumn", "env": "sunset", "ground": "grass", "path": ["planks", "log", "dirt"], "colors": [5, 4, 6, 3], "decor": "trees"},
	{"id": "clouds", "title": "Cloud", "env": "day", "ground": "wool", "path": ["wool", "glass", "plastic"], "colors": [11, 8, 10, 0], "decor": "none"},
	{"id": "crystal", "title": "Crystal", "env": "night", "ground": "stone", "path": ["glass", "ice", "neon"], "colors": [9, 8, 10, 11], "decor": "crystals"},
	{"id": "farm", "title": "Farm", "env": "day", "ground": "grass", "path": ["planks", "dirt", "log"], "colors": [6, 4, 7, 3], "decor": "fences"},
	{"id": "ancient", "title": "Ancient", "env": "sunset", "ground": "sand", "path": ["cobble", "stone", "gold"], "colors": [6, 0, 3, 5], "decor": "pillars"},
]

## Sound-based card color per genre.
const GENRE_COLORS: Dictionary = {
	"obby": Color(0.95, 0.4, 0.35), "tower": Color(0.6, 0.45, 1.0), "parkour": Color(0.3, 0.75, 0.95),
	"maze": Color(0.35, 0.75, 0.4), "lava": Color(1.0, 0.45, 0.15), "coins": Color(1.0, 0.8, 0.25),
	"islands": Color(0.45, 0.8, 0.5), "race": Color(0.95, 0.3, 0.55), "bounce": Color(0.3, 0.85, 0.9),
	"vanish": Color(0.7, 0.55, 0.95), "doors": Color(0.85, 0.6, 0.3), "swim": Color(0.25, 0.55, 1.0),
	"hangout": Color(1.0, 0.5, 0.75),
}


## All games: [{id, title, genre, theme, desc, color}]
static func all() -> Array:
	var out: Array = []
	for g in GENRES:
		for th in THEMES:
			out.append(entry("g:%s:%s" % [g["id"], th["id"]]))
	return out


static func count() -> int:
	return GENRES.size() * THEMES.size()


static func entry(game_id: String) -> Dictionary:
	var parts := game_id.split(":")
	if parts.size() != 3:
		return {}
	var g := _find(GENRES, parts[1])
	var th := _find(THEMES, parts[2])
	if g.is_empty() or th.is_empty():
		return {}
	return {
		"id": game_id, "genre": g["id"], "theme": th["id"],
		"title": I18n.game_title(th["title"], g["title"]),
		"desc": g["desc"], "color": GENRE_COLORS.get(g["id"], Color.WHITE),
	}


static func _find(list: Array, id: String) -> Dictionary:
	for it in list:
		if it["id"] == id:
			return it
	return {}


# ============================================================ generation ===

var parts: Array = []
var rng := RandomNumberGenerator.new()
var theme: Dictionary = {}
var script_text: String = ""


## Builds the level for a game id (deterministic).
static func generate(game_id: String) -> Dictionary:
	var e := entry(game_id)
	if e.is_empty():
		return Level.new_level()
	var gen := GameLibrary.new()
	gen.theme = _find(THEMES, e["theme"])
	gen.rng.seed = hash(game_id)
	gen.call("_gen_" + str(e["genre"]))
	var lvl := {"v": Level.VERSION, "name": e["title"], "parts": gen.parts}
	if str(gen.theme["env"]) != "day":
		lvl["env"] = gen.theme["env"]
	if gen.script_text != "":
		lvl["script"] = gen.script_text
	return Level.sanitize(lvl)


# ------------------------------------------------------------- helpers ---

func _part(t: String, center: Vector3, size: Vector3, c: int, mat: String = "", extra: Dictionary = {}) -> Dictionary:
	var p := {"t": t, "p": [center.x, center.y, center.z], "s": [size.x, size.y, size.z], "r": 0, "c": c}
	if mat != "" and mat != "plastic":
		p["mat"] = mat
	p.merge(extra, true)
	parts.append(p)
	return p


## Solid block whose top face is at `top`.
func _plat(x: float, top: float, z: float, size: Vector3, c: int = -1, mat: String = "") -> Dictionary:
	return _part("block", Vector3(x, top - size.y * 0.5, z), size, c if c >= 0 else _col(), mat if mat != "" else _path_mat())


func _col() -> int:
	var cs: Array = theme["colors"]
	return int(cs[rng.randi() % cs.size()])


func _path_mat() -> String:
	var ms: Array = theme["path"]
	return str(ms[rng.randi() % ms.size()])


func _ground(size: float, top: float = 0.0) -> void:
	_part("block", Vector3(0, top - 0.5, 0), Vector3(size, 1, size), int(theme["colors"][0]), str(theme["ground"]))


func _spawn(x: float, top: float, z: float) -> void:
	_part("spawn", Vector3(x, top + 0.5, z), Vector3(4, 1, 4), 8)


func _finish(x: float, top: float, z: float) -> void:
	_part("finish", Vector3(x, top + 0.5, z), Vector3(4, 1, 4), 6)


func _checkpoint(x: float, top: float, z: float) -> void:
	_part("checkpoint", Vector3(x, top + 0.5, z), Vector3(4, 1, 4), 7)


func _coin(x: float, y: float, z: float) -> void:
	_part("coin", Vector3(x, y, z), Vector3.ONE, 6)


func _decor(radius: float, count: int, base_top: float = 0.0) -> void:
	var style: String = theme["decor"]
	for i in count:
		var a := TAU * i / count + rng.randf_range(-0.2, 0.2)
		var r := radius + rng.randf_range(-2.0, 4.0)
		var x := roundf(cos(a) * r)
		var z := roundf(sin(a) * r)
		var y := base_top
		match style:
			"trees":
				_part("tree", Vector3(x, y + 3, z), Vector3(3, 6, 3), 7)
			"cactus":
				_part("block", Vector3(x, y + 2, z), Vector3(1, 4, 1), 7, "leaves")
				_part("block", Vector3(x + 1, y + 2.5, z), Vector3(1, 1, 1), 7, "leaves")
			"snowmen":
				_part("ball", Vector3(x, y + 1, z), Vector3(2, 2, 2), 11, "snow")
				_part("ball", Vector3(x, y + 2.5, z), Vector3(1.4, 1.4, 1.4), 11, "snow")
			"lollipops":
				_part("cyl", Vector3(x, y + 1.5, z), Vector3(0.4, 3, 0.4), 11)
				_part("ball", Vector3(x, y + 3.5, z), Vector3(2, 2, 2), _col())
			"crystals":
				_part("cone", Vector3(x, y + 1.5, z), Vector3(1.5, 3, 1.5), _col(), "neon")
			"palms":
				_part("block", Vector3(x, y + 2.5, z), Vector3(0.6, 5, 0.6), 3, "log")
				_part("block", Vector3(x, y + 5.2, z), Vector3(4, 0.4, 4), 7, "leaves")
			"rocks":
				_part("block", Vector3(x, y + 1, z), Vector3(2, 2, 2), 1, "basalt")
			"towers":
				_part("cyl", Vector3(x, y + 3, z), Vector3(3, 6, 3), 0, "cobble")
				_part("cone", Vector3(x, y + 7, z), Vector3(3.6, 2, 3.6), 4)
			"buildings":
				var h := float(rng.randi_range(6, 16))
				_part("block", Vector3(x, y + h * 0.5, z), Vector3(4, h, 4), 1, "glass" if i % 2 == 0 else "metal")
			"lights":
				_part("light", Vector3(x, y + 3, z), Vector3.ONE, _col())
				_part("cyl", Vector3(x, y + 1.25, z), Vector3(0.3, 2.5, 0.3), 1, "metal")
			"fences":
				_part("block", Vector3(x, y + 0.5, z), Vector3(3, 1, 0.3), 3, "planks")
			"pillars":
				_part("cyl", Vector3(x, y + 2.5, z), Vector3(1.4, 5, 1.4), 0, "stone")


# -------------------------------------------------------------- genres ---

func _gen_obby() -> void:
	_plat(0, 0, 0, Vector3(10, 1, 10), int(theme["colors"][0]), str(theme["ground"]))
	_spawn(0, 0, 2)
	var x := 0.0
	var y := 0.0
	var z := -6.0
	for i in 34:
		var kind := rng.randi() % 6
		if i % 9 == 8:
			z -= 6
			_plat(x, y, z, Vector3(6, 1, 6))
			_checkpoint(x, y, z)
			z -= 3
			continue
		match kind:
			0, 1:
				var s := 3.0 if i < 12 else 2.0
				z -= s * 0.5 + rng.randf_range(1.6, 2.6)
				x = clampf(x + rng.randf_range(-3, 3), -8, 8)
				y += rng.randf_range(-0.5, 1.0)
				_plat(roundf(x), roundf(y), roundf(z), Vector3(s, 1, s))
				z -= s * 0.5
			2:
				z -= 4.5
				_plat(roundf(x), roundf(y), roundf(z), Vector3(1, 1, 6))
				z -= 3
			3:
				z -= 5
				_plat(roundf(x), roundf(y), roundf(z), Vector3(4, 1, 8))
				_part("spikes" if i % 2 == 0 else "kill", Vector3(roundf(x), roundf(y) + 0.5, roundf(z)), Vector3(4, 1, 1), 4)
				z -= 4
			4:
				z -= 6
				_part("block", Vector3(roundf(x) - 4, roundf(y) - 0.5, roundf(z)), Vector3(4, 1, 4), _col(), _path_mat(), {"m": "slide_x"})
				z -= 4
			5:
				z -= 3
				_plat(roundf(x), roundf(y), roundf(z), Vector3(3, 1, 3))
				_part("jumppad", Vector3(roundf(x), roundf(y) + 0.5, roundf(z)), Vector3(3, 1, 3), 8)
				y += 5
				z -= 6
				_plat(roundf(x), roundf(y), roundf(z), Vector3(4, 1, 4))
				z -= 2
		if i % 3 == 0:
			_coin(roundf(x), roundf(y) + 1.5, roundf(z))
	z -= 5
	_plat(roundf(x), roundf(y), z, Vector3(8, 1, 8))
	_finish(roundf(x), roundf(y), z)


func _gen_tower() -> void:
	_ground(40)
	_spawn(0, 0, 14)
	_part("cyl", Vector3(0, 30, 0), Vector3(6, 60, 6), int(theme["colors"][1]), str(theme["path"][0]))
	var r := 7.0
	for i in 44:
		var a := deg_to_rad(22.0 * i)
		var top := 1.3 * (i + 1)
		var s := 3.0 if i < 20 else 2.4
		_plat(roundf(cos(a) * r), top, roundf(sin(a) * r), Vector3(s, 1, s))
		if i % 11 == 10:
			_checkpoint(roundf(cos(a) * r), top, roundf(sin(a) * r))
		elif i % 4 == 1:
			_coin(roundf(cos(a) * r), top + 1.5, roundf(sin(a) * r))
	_plat(0, 61, 0, Vector3(9, 1, 9))
	_finish(0, 61, 0)
	_decor(20, 10)


func _gen_parkour() -> void:
	_plat(0, 0, 0, Vector3(10, 1, 10), int(theme["colors"][0]), str(theme["ground"]))
	_spawn(0, 0, 2)
	var y := 0.0
	var z := -5.0
	for i in 24:
		match i % 6:
			0:
				z -= 4
				_part("conveyor", Vector3(0, y - 0.5, z - 3), Vector3(2, 1, 6), 1)
				z -= 6
			1:
				z -= 2
				_part("block", Vector3(0, y + 3, z - 0.5), Vector3(4, 6, 1), _col(), _path_mat())
				_part("ladder", Vector3(0, y + 3, z + 0.5), Vector3(2, 6, 1), 3)
				y += 6
				_plat(0, y, z - 2.5, Vector3(4, 1, 4))
				z -= 4.5
			2:
				z -= 3.5
				_plat(-3, y, z, Vector3(2, 1, 2))
				z -= 3.5
				_plat(3, y, z, Vector3(2, 1, 2))
				z -= 3.5
				_plat(0, y, z, Vector3(2, 1, 2))
				z -= 1
			3:
				z -= 3
				_part("ramp", Vector3(0, y + 1, z - 2), Vector3(4, 2, 4), _col(), _path_mat())
				y += 2
				z -= 4
				_plat(0, y, z - 1, Vector3(4, 1, 2))
				z -= 2
			4:
				z -= 4
				_part("speed", Vector3(0, y - 0.5, z), Vector3(3, 1, 3), 6)
				z -= 2
				_plat(0, y, z - 4, Vector3(2, 1, 8))
				z -= 8
			5:
				z -= 4
				_plat(0, y, z, Vector3(6, 1, 6))
				_checkpoint(0, y, z)
				_coin(2, y + 1.5, z)
				z -= 3
	z -= 5
	_plat(0, y, z, Vector3(8, 1, 8))
	_finish(0, y, z)


func _gen_maze() -> void:
	var n := 10
	var cell := 4.0
	var half := n * cell * 0.5
	_ground(n * cell + 8)
	_spawn(-half + cell * 0.5, 0, -half + cell * 0.5)
	var visited: Array[bool] = []
	visited.resize(n * n)
	visited.fill(false)
	var walls: Array = []
	for i in n * n:
		walls.append([true, true, true, true])
	var stack: Array[Vector2i] = [Vector2i(0, 0)]
	visited[0] = true
	var dirs := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	while not stack.is_empty():
		var c: Vector2i = stack.back()
		var opts: Array[int] = []
		for d in 4:
			var nb: Vector2i = c + dirs[d]
			if nb.x >= 0 and nb.y >= 0 and nb.x < n and nb.y < n and not visited[nb.y * n + nb.x]:
				opts.append(d)
		if opts.is_empty():
			stack.pop_back()
			continue
		var d2: int = opts[rng.randi() % opts.size()]
		var nx: Vector2i = c + dirs[d2]
		var wa: Array = walls[c.y * n + c.x]
		wa[d2] = false
		var wb: Array = walls[nx.y * n + nx.x]
		wb[(d2 + 2) % 4] = false
		visited[nx.y * n + nx.x] = true
		stack.append(nx)
	var wall_mat := str(theme["path"][0])
	var wc := int(theme["colors"][1])
	for y in n:
		for x in n:
			var w: Array = walls[y * n + x]
			var cx := -half + (x + 0.5) * cell
			var cz := -half + (y + 0.5) * cell
			if w[0]:
				_part("block", Vector3(cx, 1.5, cz - cell * 0.5), Vector3(cell + 1, 3, 1), wc, wall_mat)
			if w[3]:
				_part("block", Vector3(cx - cell * 0.5, 1.5, cz), Vector3(1, 3, cell + 1), wc, wall_mat)
			if y == n - 1 and w[2]:
				_part("block", Vector3(cx, 1.5, cz + cell * 0.5), Vector3(cell + 1, 3, 1), wc, wall_mat)
			if x == n - 1 and w[1]:
				_part("block", Vector3(cx + cell * 0.5, 1.5, cz), Vector3(1, 3, cell + 1), wc, wall_mat)
			if rng.randf() < 0.15:
				_coin(cx, 1.2, cz)
	_finish(half - cell * 0.5, 0, half - cell * 0.5)
	_decor(half + 10, 12)


func _gen_lava() -> void:
	_ground(56)
	_plat(0, 1, 0, Vector3(8, 1, 8), 11, "stone")
	_spawn(0, 1, 0)
	var p := Vector3(0, 1, 0)
	var ang := rng.randf() * TAU
	for i in 60:
		ang += rng.randf_range(0.4, 1.0)
		var step := rng.randf_range(3.5, 4.2)
		var nxt := p + Vector3(cos(ang) * step, rng.randf_range(0.8, 1.2), sin(ang) * step)
		if Vector2(nxt.x, nxt.z).length() > 22.0:
			ang += PI * 0.7
			nxt = p + Vector3(cos(ang) * step, nxt.y - p.y, sin(ang) * step)
		p = nxt
		_plat(roundf(p.x), roundf(p.y), roundf(p.z), Vector3(3, 1, 3))
		if i % 7 == 3:
			_coin(roundf(p.x), roundf(p.y) + 1.5, roundf(p.z))
	_plat(roundf(p.x), roundf(p.y) + 1, roundf(p.z), Vector3(6, 1, 6), 6, "gold")
	_part("kill", Vector3(0, -2, 0), Vector3(54, 1, 54), 4, "", {"n": "lava"})
	script_text = """-- The floor is lava! It rises, then a new round starts.
local h = 0
on_start(function() ui.status("The floor is lava - climb!") end)
every(0.25, function()
  h = h + 0.18
  if h > %d then
    h = 0
    world.find("lava"):move_to(0, -2, 0, 0)
    ui.message("New round!", 2)
  else
    world.find("lava"):move_by(0, 0.18, 0, 0.25)
  end
end)
""" % int(p.y)


func _gen_coins() -> void:
	_ground(70)
	_spawn(0, 0, 0)
	for i in 36:
		var x := roundf(rng.randf_range(-30, 30))
		var z := roundf(rng.randf_range(-30, 30))
		if Vector2(x, z).length() < 5:
			continue
		var h := float(rng.randi_range(0, 4)) * 2.0
		if h > 0.0:
			_plat(x, h, z, Vector3(3, 1, 3))
			if h >= 4.0:
				_plat(x + 3, h - 2, z, Vector3(2, 1, 2))
				if h >= 6.0:
					_plat(x + 5, h - 4, z, Vector3(2, 1, 2))
		_coin(x, h + 1.5, z)
	_decor(38, 16)
	script_text = """on_start(function()
  ui.status("Find all the coins!")
  ui.message("Coin Hunt: explore the map!", 3)
end)
"""


func _gen_islands() -> void:
	var pos := Vector3.ZERO
	var y := 10.0
	_island(pos, y, 12)
	_spawn(0, y, 0)
	for i in 12:
		var dir := Vector3(rng.randf_range(-1, 1), 0, -1).normalized()
		var gap := rng.randf_range(4, 7)
		var size := float(rng.randi_range(6, 10))
		pos += dir * (size * 0.5 + gap + 4)
		pos = Vector3(roundf(pos.x), 0, roundf(pos.z))
		y += rng.randf_range(-1.0, 2.0)
		y = roundf(y)
		_island(pos, y, size)
		if i % 4 == 2:
			_part("jumppad", Vector3(pos.x, y + 0.5, pos.z + size * 0.3), Vector3(3, 1, 3), 8)
		if i % 3 == 1:
			_checkpoint(pos.x, y, pos.z)
		else:
			_coin(pos.x + 1, y + 1.5, pos.z)
	_finish(pos.x, y, pos.z)


func _island(c: Vector3, top: float, size: float) -> void:
	_part("block", Vector3(c.x, top - 0.5, c.z), Vector3(size, 1, size), int(theme["colors"][0]), str(theme["ground"]))
	_part("block", Vector3(c.x, top - 2.0, c.z), Vector3(size - 2, 2, size - 2), 3, "dirt")
	_part("block", Vector3(c.x, top - 3.5, c.z), Vector3(size - 5, 1, size - 5), 3, "dirt")
	if size >= 8 and str(theme["decor"]) != "none":
		_part("tree", Vector3(c.x + size * 0.3, top + 3, c.z - size * 0.3), Vector3(3, 6, 3), 7)


func _gen_race() -> void:
	_ground(16)
	_spawn(0, 0, 4)
	var x := 0.0
	var z := 0.0
	var dir := Vector2(0, -1)
	var y := 0.0
	for i in 22:
		var length := float(rng.randi_range(10, 18))
		var mid := Vector2(x, z) + dir * (length * 0.5 + 2)
		var w := 6.0
		var size := Vector3(w, 1, length) if absf(dir.y) > 0.5 else Vector3(length, 1, w)
		_plat(roundf(mid.x), y, roundf(mid.y), size)
		if i % 3 == 1:
			_part("speed", Vector3(roundf(mid.x), y + 0.5, roundf(mid.y)), Vector3(3, 1, 3), 6)
		if i % 5 == 4:
			_checkpoint(roundf(mid.x), y, roundf(mid.y))
		elif i % 2 == 0:
			_coin(roundf(mid.x), y + 1.5, roundf(mid.y))
		var end := Vector2(x, z) + dir * (length + 4)
		x = roundf(end.x)
		z = roundf(end.y)
		_plat(x, y, z, Vector3(w, 1, w))
		var turn := rng.randi() % 3
		if turn == 1:
			dir = Vector2(-dir.y, dir.x)
		elif turn == 2:
			dir = Vector2(dir.y, -dir.x)
		if dir.y > 0.5:
			dir = Vector2(-1 if x > 0 else 1, 0)
	_finish(x, y, z)
	_decor(30, 10)


func _gen_bounce() -> void:
	_ground(40)
	_spawn(0, 0, 12)
	var y := 0.0
	var z := 0.0
	for i in 10:
		_plat(0, y, z, Vector3(5, 1, 5))
		_part("jumppad", Vector3(0, y + 0.5, z), Vector3(3, 1, 3), 8 + i % 3)
		y += 6.0
		z -= 6.0
		_coin(0, y - 2, z + 3)
		if i % 3 == 2:
			_plat(4, y, z + 2, Vector3(4, 1, 4))
			_checkpoint(4, y, z + 2)
	_plat(0, y, z, Vector3(8, 1, 8))
	_finish(0, y, z)
	_decor(18, 10)


func _gen_vanish() -> void:
	_plat(0, 0, 0, Vector3(10, 1, 10), int(theme["colors"][0]), str(theme["ground"]))
	_spawn(0, 0, 2)
	var x := 0.0
	var z := -6.0
	var y := 0.0
	for i in 30:
		z -= rng.randf_range(3.6, 4.4)
		x = clampf(x + rng.randf_range(-2.5, 2.5), -6, 6)
		y += rng.randf_range(-0.3, 0.6)
		if i % 10 == 9:
			_plat(roundf(x), roundf(y), roundf(z), Vector3(6, 1, 6))
			_checkpoint(roundf(x), roundf(y), roundf(z))
			z -= 2
		else:
			var p := _part("block", Vector3(roundf(x), roundf(y) - 0.5, roundf(z)), Vector3(3, 1, 3), _col(), _path_mat())
			p["n"] = "fade"
	z -= 6
	_plat(roundf(x), roundf(y), roundf(z), Vector3(8, 1, 8))
	_finish(roundf(x), roundf(y), roundf(z))
	script_text = """-- Platforms vanish 0.8s after you touch them and come back later.
on_touch("fade", function(player)
  local p = world.find("fade")
  after(0.8, function()
    p:set_visible(false)
    p:set_solid(false)
  end)
  after(3.5, function()
    p:set_visible(true)
    p:set_solid(true)
  end)
end)
"""


func _gen_doors() -> void:
	var rooms := 6
	var wall_mat := str(theme["path"][0])
	var wc := int(theme["colors"][1])
	_part("block", Vector3(0, -0.5, -rooms * 6 + 6), Vector3(14, 1, rooms * 12 + 12), int(theme["colors"][0]), str(theme["ground"]))
	_spawn(0, 0, 6)
	var lines: Array[String] = []
	for i in rooms:
		var z := -i * 12.0
		# Side walls of the room.
		_part("block", Vector3(-6.5, 2, z - 6), Vector3(1, 4, 12), wc, wall_mat)
		_part("block", Vector3(6.5, 2, z - 6), Vector3(1, 4, 12), wc, wall_mat)
		# Wall with a door at the end of the room.
		_part("block", Vector3(-4, 2, z - 12), Vector3(4, 4, 1), wc, wall_mat)
		_part("block", Vector3(4, 2, z - 12), Vector3(4, 4, 1), wc, wall_mat)
		_part("block", Vector3(0, 2, z - 12), Vector3(4, 4, 1), 4, "", {"n": "door%d" % (i + 1)})
		var bx := -4.0 if i % 2 == 0 else 4.0
		_part("block", Vector3(bx, 0.5, z - 6), Vector3(2, 1, 2), 7, "", {"n": "button%d" % (i + 1)})
		_coin(-bx, 1.5, z - 6)
		lines.append("on_touch(\"button%d\", function(p) open(%d) end)" % [i + 1, i + 1])
	_finish(0, 0, -rooms * 12.0 - 4)
	script_text = """-- Step on each green button to open the red door ahead.
local function open(i)
  local d = world.find("door" .. i)
  d:set_solid(false)
  d:set_visible(false)
  ui.message("Door " .. i .. " is open!", 1.5)
  after(8, function()
    d:set_solid(true)
    d:set_visible(true)
  end)
end
""" + "\n".join(lines) + "\n"


func _gen_swim() -> void:
	_plat(0, 0, 0, Vector3(10, 1, 10), int(theme["colors"][0]), str(theme["ground"]))
	_spawn(0, 0, 2)
	var z := -5.0
	for i in 8:
		var depth := 6.0
		var length := 12.0
		var pz := z - length * 0.5
		_part("block", Vector3(0, -depth - 0.5, pz), Vector3(10, 1, length), 3, "sand")
		_part("block", Vector3(-5.5, -depth * 0.5, pz), Vector3(1, depth, length), int(theme["colors"][1]), "stone")
		_part("block", Vector3(5.5, -depth * 0.5, pz), Vector3(1, depth, length), int(theme["colors"][1]), "stone")
		_part("water", Vector3(0, -depth * 0.5 + 0.5, pz), Vector3(10, depth - 1, length), 8)
		_coin(0, -depth + 1.5, pz)
		z -= length
		_plat(0, 0, z - 3, Vector3(10, 1, 6))
		_part("ladder", Vector3(0, -depth * 0.5, z + 0.4), Vector3(2, depth, 1), 3)
		if i % 3 == 2:
			_checkpoint(0, 0, z - 3)
		z -= 6
	_finish(0, 0, z + 3)


func _gen_hangout() -> void:
	_ground(64)
	_spawn(0, 0, 18)
	# Disco floor.
	for x in 6:
		for z in 6:
			_part("block", Vector3(-6 + x * 2 + 1, 0.05, -6 + z * 2 + 1), Vector3(2, 0.1, 2), 4 + (x + z) % 6, "neon", {"n": "disco"})
	for i in 4:
		var a := TAU * i / 4.0
		_part("light", Vector3(cos(a) * 8, 5, sin(a) * 8), Vector3.ONE, _col())
	# Houses around.
	for i in 6:
		var a := TAU * i / 6.0 + 0.5
		var c := Vector3(roundf(cos(a) * 20), 0, roundf(sin(a) * 20))
		var wm := _path_mat()
		_part("block", c + Vector3(0, 2, -3), Vector3(6, 4, 1), _col(), wm)
		_part("block", c + Vector3(-3, 2, 0), Vector3(1, 4, 6), _col(), wm)
		_part("block", c + Vector3(3, 2, 0), Vector3(1, 4, 6), _col(), wm)
		_part("block", c + Vector3(0, 4.5, 0), Vector3(7, 1, 7), _col(), "planks")
		_part("sign", c + Vector3(0, 1.5, 3.6), Vector3(3, 1.5, 0.3), 3, "", {"txt": "House %d" % (i + 1)})
	_decor(28, 14)
	script_text = """-- Disco floor changes color every half second.
local colors = {4, 5, 6, 7, 8, 9, 10}
local i = 1
on_start(function() ui.status("Hangout - invite friends with HOST!") end)
every(0.5, function()
  world.find("disco"):set_color(colors[i])
  i = i % #colors + 1
end)
"""
