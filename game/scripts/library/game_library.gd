class_name GameLibrary
extends RefCounted
## The built-in game library: 18 game types x 16 themes = 288 original games.
## Every game type has TWO different map layouts (e.g. Obby: a straight run
## or a spiral climb around a pillar) and the themes also change the
## difficulty, so games of the same type play differently - not only look
## different. Every game is generated deterministically as a Level (the same
## format as Studio creations), so each one can be played solo, hosted on
## Wi-Fi, or remixed in Studio.

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
	{"id": "hangout", "title": "Hangout", "desc": "A place to chill with friends: disco floor, park, houses and lights."},
	{"id": "tycoon", "title": "Tycoon", "desc": "Earn cash every second and step on the green pads to build your empire."},
	{"id": "floorfall", "title": "Floor Fall", "desc": "Tiles drop after you step on them - stay on the floors as long as you can!"},
	{"id": "dropper", "title": "Dropper", "desc": "Jump in and fall: dodge the lava obstacles and splash into the pool."},
	{"id": "sweeper", "title": "Spinner Survival", "desc": "Jump over the spinning bar. Every hit resets your time!"},
	{"id": "buttons", "title": "Button Hunt", "desc": "Hidden buttons everywhere - find them all to unlock the prize."},
]

## Two map layouts per game type (picked by the theme).
const LAYOUTS: Dictionary = {
	"obby": ["Straight Run", "Spiral Climb"], "tower": ["Spiral Tower", "Tower of Floors"],
	"parkour": ["Obstacle Run", "Rooftops"], "maze": ["Walled Maze", "Sky Maze"],
	"lava": ["Lava Spiral", "Lava Pillars"], "coins": ["Open Field", "Village"],
	"islands": ["Island Chain", "Island Ring"], "race": ["Track", "Downhill"],
	"bounce": ["Bounce Tower", "Trampoline Field"], "vanish": ["Vanishing Path", "Vanishing Grid"],
	"doors": ["Door Corridor", "Room Grid"], "swim": ["Pools", "Lake"], "hangout": ["Disco", "Park"],
	"tycoon": ["Factory", "Farm"], "floorfall": ["Square Floors", "Round Floors"],
	"dropper": ["Shaft", "Sky Drop"], "sweeper": ["Round Arena", "Square Arena"],
	"buttons": ["Mansion", "Park"],
}
const DIFFICULTY: Array[String] = ["Easy", "Normal", "Hard"]

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
	"hangout": Color(1.0, 0.5, 0.75), "tycoon": Color(0.35, 0.85, 0.45), "floorfall": Color(0.95, 0.75, 0.3),
	"dropper": Color(0.45, 0.6, 1.0), "sweeper": Color(1.0, 0.35, 0.3), "buttons": Color(0.95, 0.45, 0.85),
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
	var ti := THEMES.find(th)
	var variant := ti % 2
	var layouts: Array = LAYOUTS.get(g["id"], ["", ""])
	return {
		"id": game_id, "genre": g["id"], "theme": th["id"],
		"title": I18n.game_title(th["title"], g["title"]),
		"genre_title": g["title"], "theme_title": th["title"],
		"desc": g["desc"], "color": GENRE_COLORS.get(g["id"], Color.WHITE),
		"variant": variant, "layout": layouts[variant], "difficulty": DIFFICULTY[(ti / 2) % 3],
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
## 0 = layout A, 1 = layout B.
var variant: int = 0
## 0 easy, 1 normal, 2 hard.
var hard: int = 0


## Builds the level for a game id (deterministic).
static func generate(game_id: String) -> Dictionary:
	var e := entry(game_id)
	if e.is_empty():
		return Level.new_level()
	var gen := GameLibrary.new()
	gen.theme = _find(THEMES, e["theme"])
	gen.rng.seed = hash(game_id)
	gen.variant = int(e["variant"])
	gen.hard = DIFFICULTY.find(str(e["difficulty"]))
	gen.call("_gen_" + str(e["genre"]) + ("_b" if gen.variant == 1 else ""))
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
	var walls := _maze(n)
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


## Perfect maze (recursive backtracker). walls[i] = [N, E, S, W] booleans.
func _maze(n: int) -> Array:
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
	return walls


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
	script_text = LAVA_SCRIPT % int(p.y)


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
	# Karts at the start: drive the track or run it on foot.
	_part("kart", Vector3(-5, 1, 4), Vector3(3, 2, 4), 4)
	_part("kart", Vector3(5, 1, 4), Vector3(3, 2, 4), 8)
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
	script_text = VANISH_SCRIPT


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
	_part("sword", Vector3(-4, 1, 12), Vector3(1, 2, 1), 0)
	_part("sword", Vector3(4, 1, 12), Vector3(1, 2, 1), 0)
	_part("balloon", Vector3(0, 1, 14), Vector3(1, 2, 1), 10)
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


# ============================================================== scripts ===

const LAVA_SCRIPT := """-- The floor is lava! It rises, then a new round starts.
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
"""

const VANISH_SCRIPT := """-- Each platform vanishes 0.8s after you touch it and comes back later.
on_touch("fade", function(player, part)
  after(0.8, function()
    part:set_visible(false)
    part:set_solid(false)
  end)
  after(4, function()
    part:set_visible(true)
    part:set_solid(true)
  end)
end)
"""

const DOORS_SCRIPT := """-- Step on each green button to open the red door ahead.
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
"""

const TYCOON_SCRIPT := """-- Tycoon: cash comes in every second. Step on a green pad to buy.
local cash = 0
local income = 1
local bought = {}
local prices = {10, 25, 45, 80, 130, 200, 320, 500}
local names = {%s}
on_start(function()
  for i = 1, 8 do
    local it = world.find("item" .. i)
    if it then
      it:set_visible(false)
      it:set_solid(false)
    end
  end
  ui.status("Tycoon - step on the green pads to build!")
end)
every(1, function()
  cash = cash + income
  score.set(cash)
end)
local function buy(i, player)
  if bought[i] then return end
  if cash < prices[i] then
    player:message("You need $" .. prices[i] .. " for the " .. names[i])
    return
  end
  cash = cash - prices[i]
  bought[i] = true
  income = income + i * 2
  local it = world.find("item" .. i)
  it:set_visible(true)
  it:set_solid(true)
  world.find("buy" .. i):set_visible(false)
  ui.message("Built the " .. names[i] .. "! Income: $" .. income .. "/s", 2)
  score.set(cash)
  if i == 8 then ui.status("You finished the tycoon!") end
end
"""

const FLOORFALL_SCRIPT := """-- Tiles drop half a second after you step on them.
-- Every 45 seconds all the floors come back.
local left = 45
on_start(function() ui.status("Floor Fall - don't drop into the lava!") end)
on_touch("tile", function(player, part)
  after(0.5, function()
    part:set_visible(false)
    part:set_solid(false)
  end)
end)
every(1, function()
  left = left - 1
  ui.status("Floors come back in " .. left .. "s")
  if left <= 0 then
    left = 45
    local t = world.find("tile")
    t:set_visible(true)
    t:set_solid(true)
    ui.message("New round - the floors are back!", 2.5)
  end
end)
"""

const SWEEPER_SCRIPT := """-- Survive as long as you can: the spinning bar resets your time.
local t = 0
local best = 0
on_start(function() ui.status("Jump over the spinning bar!") end)
every(1, function()
  t = t + 1
  if t > best then best = t end
  score.set(t)
  ui.status("Best: " .. best .. "s")
end)
on_touch("bar", function(player)
  t = 0
  score.set(0)
  player:message("Ouch! Your time is back to 0")
end)
"""

const BUTTONS_SCRIPT := """-- Find every hidden button to unlock the golden prize.
local found = 0
local total = %d
local got = {}
on_start(function()
  ui.status("Find all " .. total .. " buttons!")
  local pz = world.find("prize")
  pz:set_visible(false)
  pz:set_solid(false)
end)
on_touch("btn", function(player, part)
  if got[part.name] then return end
  got[part.name] = true
  part:destroy()
  found = found + 1
  score.set(found)
  if found >= total then
    ui.message("You found every button! The prize is open!", 3)
    local pz = world.find("prize")
    pz:set_visible(true)
    pz:set_solid(true)
  else
    ui.message("Button " .. found .. " / " .. total, 1.5)
  end
end)
"""


# ========================================================== layout B ===

func _gen_obby_b() -> void:
	# Spiral climb around a giant pillar.
	_ground(46)
	_spawn(0, 0, 17)
	_part("cyl", Vector3(0, 21, 0), Vector3(8, 42, 8), int(theme["colors"][1]), str(theme["path"][0]))
	var r := 12.0
	var a := PI * 0.5
	var y := 0.0
	var step := deg_to_rad(20.0 + hard * 2.0)
	for i in 38:
		a -= step
		y += 1.0
		var x := roundf(cos(a) * r)
		var z := roundf(sin(a) * r)
		if i % 12 == 11:
			_plat(x, y, z, Vector3(4, 1, 4))
			_checkpoint(x, y, z)
			continue
		match i % 5:
			0, 2:
				_plat(x, y, z, Vector3(3, 1, 3))
			1:
				_part("block", Vector3(x, y - 0.5, z), Vector3(3, 1, 3), _col(), _path_mat(), {"m": "spin"})
			3:
				_plat(x, y, z, Vector3(3, 1, 3))
				_coin(x, y + 1.5, z)
			_:
				_plat(x, y, z, Vector3(2, 1, 2) if hard > 0 else Vector3(3, 1, 3))
	_plat(roundf(cos(a) * 8.0), y + 1, roundf(sin(a) * 8.0), Vector3(3, 1, 3))
	_plat(0, y + 2, 0, Vector3(9, 1, 9))
	_finish(0, y + 2, 0)
	_decor(22, 10)


func _gen_tower_b() -> void:
	# A tower of floors: every floor has a hazard and a different way up.
	var floors := 6
	var h := 8.0
	var wall_mat := str(theme["path"][0])
	var wc := int(theme["colors"][1])
	var see := {"a": 0.55}
	_ground(52)
	_spawn(0, 0, 16)
	for k in floors:
		var y0 := k * h
		var wy := y0 + h * 0.5
		_part("block", Vector3(-8.5, wy, 0), Vector3(1, h, 18), wc, wall_mat, see)
		_part("block", Vector3(8.5, wy, 0), Vector3(1, h, 18), wc, wall_mat, see)
		_part("block", Vector3(0, wy, -8.5), Vector3(16, h, 1), wc, wall_mat, see)
		if k == 0:
			_part("block", Vector3(-5.25, wy, 8.5), Vector3(5.5, h, 1), wc, wall_mat, see)
			_part("block", Vector3(5.25, wy, 8.5), Vector3(5.5, h, 1), wc, wall_mat, see)
			_part("block", Vector3(0, y0 + 6, 8.5), Vector3(5, 4, 1), wc, wall_mat, see)
		else:
			_part("block", Vector3(0, wy, 8.5), Vector3(16, h, 1), wc, wall_mat, see)
		# Ceiling (= next floor) with a 4x4 hole in the X corner.
		var sx := 1.0 if k % 2 == 0 else -1.0
		var top := y0 + h
		var pc := _col()
		var pm := _path_mat()
		_part("block", Vector3(0, top - 0.5, -2 * sx), Vector3(16, 1, 12), pc, pm)
		_part("block", Vector3(-2 * sx, top - 0.5, 6 * sx), Vector3(12, 1, 4), pc, pm)
		var hx := 6.0 * sx
		# Hazard between where you arrive and the way up.
		if k > 0:
			_checkpoint(-6 * sx, y0, -2 * sx)
			match (k - 1) % 3:
				0:
					_part("spikes", Vector3(-1.5 * sx, y0 + 0.5, -2.5 * sx), Vector3(1, 1, 11), 1)
					_part("spikes", Vector3(1.5 * sx, y0 + 0.5, 2.5 * sx), Vector3(1, 1, 11), 1)
				1:
					_part("kill", Vector3(0, y0 + 0.25, 0), Vector3(5, 0.5, 16), 4)
					_plat(0, y0 + 1, 0, Vector3(2, 1, 2))
				_:
					_part("kill", Vector3(0, y0 + 0.25, 0), Vector3(5, 0.5, 16), 4)
					_part("block", Vector3(0, y0 + 0.5, -4), Vector3(3, 1, 3), _col(), _path_mat(), {"m": "slide_z"})
		_coin(-3 * sx, y0 + 1.5, 3 * sx)
		# The way up through the hole.
		match k % 4:
			0:
				_part("ladder", Vector3(hx, y0 + (h + 1) * 0.5, 7.5 * sx), Vector3(2, h + 1, 1), 3)
			1:
				_part("truss", Vector3(hx, y0 + (h + 1) * 0.5, hx), Vector3(2, h + 1, 2), 1)
			2:
				var steps := [[2.0, 6.0, 1.5], [2.0, 2.0, 3.0], [6.0, 1.5, 4.5], [5.0, 5.0, 6.0], [7.0, 7.0, 7.5]]
				for st: Array in steps:
					_plat(float(st[0]) * sx, y0 + float(st[2]), float(st[1]) * sx, Vector3(2, 1, 2))
			_:
				_part("block", Vector3(hx, y0 + 0.5, hx), Vector3(3, 1, 3), _col(), _path_mat(), {"m": "lift"})
	var roof := floors * h
	_finish(0, roof, 0)
	_decor(22, 10)


func _gen_parkour_b() -> void:
	# Rooftop run: jump from building to building.
	var x := 0.0
	var z := 0.0
	var h := 6.0
	var bd := 8.0
	_spawn(0, 0, 10)
	_building(0, 0, 8, 8, h)
	_part("ladder", Vector3(0, (h + 1) * 0.5, 4.5), Vector3(2, h + 1, 1), 3)
	for i in 16:
		var nw := float(rng.randi_range(5, 9))
		var nd := float(rng.randi_range(5, 9))
		var nh := clampf(h + float(rng.randi_range(-2, 2)), 4.0, 26.0)
		var gap := rng.randf_range(2.0, 2.6 + hard * 0.3)
		var bridge := i % 5 == 3
		var nx := roundf(clampf(x + rng.randf_range(-4, 4), -10, 10))
		if bridge:
			gap = 7.0
			nh = h
			nx = x
		var nz := roundf(z - bd * 0.5 - gap - nd * 0.5)
		_building(nx, nz, nw, nd, nh)
		if bridge:
			var z0 := z - bd * 0.5
			var z1 := nz + nd * 0.5
			_plat(x, h, (z0 + z1) * 0.5, Vector3(1, 0.5, z0 - z1 + 2), 3, "planks")
		elif nh - h > 1.0:
			_plat(x, h + 1.5, z - bd * 0.5 + 1.2, Vector3(2, 1.5, 2), 3, "planks")
		if i % 5 == 4:
			_checkpoint(nx, nh, nz)
		else:
			_coin(nx, nh + 1.5, nz)
		if nw >= 7 and rng.randf() < 0.6:
			_part("block", Vector3(nx + nw * 0.5 - 1.2, nh + 0.5, nz - nd * 0.5 + 1.2), Vector3(1.4, 1, 1.4), 1, "metal")
		x = nx
		z = nz
		h = nh
		bd = nd
	_finish(x, h, z)
	_part("block", Vector3(0, -0.5, (20.0 + z - 12.0) * 0.5), Vector3(48, 1, 20.0 - z + 12.0), int(theme["colors"][0]), str(theme["ground"]))


func _building(x: float, z: float, w: float, d: float, h: float) -> void:
	_part("block", Vector3(x, h * 0.5, z), Vector3(w, h, d), _col(), _path_mat())
	if h >= 6.0:
		_part("block", Vector3(x, h * 0.5 + 0.3, z + d * 0.5 + 0.06), Vector3(w - 2, h - 3, 0.12), 8, "glass")


func _gen_maze_b() -> void:
	# Sky maze: the paths float over lava, there are no walls.
	var n := 9
	var cell := 4.0
	var half := n * cell * 0.5
	var y := 6.0
	var walls := _maze(n)
	_part("kill", Vector3(0, 0.25, 0), Vector3(n * cell + 20, 0.5, n * cell + 20), 4)
	var sx := -half + cell * 0.5
	_spawn(sx, y - 1, -half - 2.5)
	var tm := str(theme["path"][0])
	for cy in n:
		for cx in n:
			var w: Array = walls[cy * n + cx]
			var px := -half + (cx + 0.5) * cell
			var pz := -half + (cy + 0.5) * cell
			var c := int(theme["colors"][(cx + cy) % 2])
			_plat(px, y, pz, Vector3(2, 1, 2), c, tm)
			if not w[1]:
				_plat(px + cell * 0.5, y, pz, Vector3(2, 1, 2), c, tm)
			if not w[2]:
				_plat(px, y, pz + cell * 0.5, Vector3(2, 1, 2), c, tm)
			var open := 0
			for k in 4:
				if not w[k]:
					open += 1
			if open == 1 and not (cx == 0 and cy == 0):
				_coin(px, y + 1.5, pz)
	_finish(half - cell * 0.5, y - 1, half + 2.5)


func _gen_lava_b() -> void:
	# A staircase of pillars - climb before the lava gets you.
	var n := 7
	var pitch := 4.0
	var off := -(n - 1) * pitch * 0.5
	_ground(n * pitch + 20)
	_spawn(off - 5, 0, off)
	for z in n:
		for x in n:
			var top := 1.0 + x + z
			_plat(off + x * pitch, top, off + z * pitch, Vector3(3, top, 3))
			if (x + z) % 4 == 2 and x != z:
				_coin(off + x * pitch, top + 1.5, off + z * pitch)
	var peak := 1.0 + 2 * (n - 1)
	_plat(-off, peak + 1, -off, Vector3(3, 1, 3), 6, "gold")
	_decor(n * pitch * 0.5 + 8, 12)
	_part("kill", Vector3(0, -2, 0), Vector3(n * pitch + 18, 1, n * pitch + 18), 4, "", {"n": "lava"})
	script_text = LAVA_SCRIPT % int(peak)


func _gen_coins_b() -> void:
	# A little village: coins in houses, on roofs and in gardens.
	_ground(80)
	_spawn(0, 0, 4)
	_part("cyl", Vector3(0, 0.6, -4), Vector3(8, 1.2, 8), 0, "stone")
	_part("water", Vector3(0, 1.5, -4), Vector3(6, 0.6, 6), 8)
	_coin(0, 3, -4)
	for i in 2:
		var horizontal := i == 0
		var sz := Vector3(76, 0.1, 3) if horizontal else Vector3(3, 0.1, 76)
		_part("block", Vector3(0, 0.05, 7 if horizontal else 0), sz, 1, "cobble")
	for gx in range(-2, 3):
		for gz in range(-2, 3):
			if gx == 0 and gz == 0:
				continue
			var c := Vector3(gx * 14.0, 0, gz * 14.0)
			match rng.randi() % 4:
				0, 1:
					var hh := 4.0
					_house(c, 8, 8, hh)
					_coin(c.x, 1.2, c.z)
					_coin(c.x, hh + 2.5, c.z)
				2:
					_plat(c.x, 8, c.z, Vector3(3, 8, 3), _col(), _path_mat())
					_part("ladder", Vector3(c.x, 4.5, c.z + 2), Vector3(2, 9, 1), 3)
					_coin(c.x, 9.5, c.z)
				_:
					_part("tree", c + Vector3(-2, 3, -2), Vector3(3, 6, 3), 7)
					_part("tree", c + Vector3(2, 3, 2), Vector3(3, 6, 3), 7)
					_part("block", c + Vector3(0, 0.5, 4), Vector3(8, 1, 0.3), 3, "planks")
					_coin(c.x + 2, 1.2, c.z - 2)
	script_text = """on_start(function()
  ui.status("Find the coins hidden in the village!")
end)
"""


## Small house with a door on +Z, a flat roof and a ladder on -X.
func _house(c: Vector3, w: float, d: float, h: float) -> void:
	var m := _path_mat()
	var col := _col()
	_part("block", c + Vector3(0, h * 0.5, -d * 0.5 + 0.5), Vector3(w, h, 1), col, m)
	_part("block", c + Vector3(-w * 0.5 + 0.5, h * 0.5, 0), Vector3(1, h, d - 2), col, m)
	_part("block", c + Vector3(w * 0.5 - 0.5, h * 0.5, 0), Vector3(1, h, d - 2), col, m)
	var fw := (w - 2.0) * 0.5
	_part("block", c + Vector3(-1 - fw * 0.5, h * 0.5, d * 0.5 - 0.5), Vector3(fw, h, 1), col, m)
	_part("block", c + Vector3(1 + fw * 0.5, h * 0.5, d * 0.5 - 0.5), Vector3(fw, h, 1), col, m)
	_part("block", c + Vector3(0, h * 0.5 + 1.5, d * 0.5 - 0.5), Vector3(2, h - 3, 1), col, m)
	_part("block", c + Vector3(0, h + 0.5, 0), Vector3(w + 1, 1, d + 1), 4, "planks")
	_part("ladder", c + Vector3(-w * 0.5 - 0.5, (h + 1.5) * 0.5, 0), Vector3(2, h + 1.5, 1), 3, "", {"r": 1})


func _gen_islands_b() -> void:
	# A ring of islands around a big one, then a cloud staircase to a crown island.
	var y := 8.0
	_island(Vector3.ZERO, y, 14)
	_spawn(0, y, 3)
	var count := 11
	var r := 24.0
	for k in 3:
		var t := 9.5 + k * 3.8
		_plat(t, y, 0, Vector3(2, 1, 2), 11, "wool")
	var prev := Vector3(r, 0, 0)
	for i in count:
		var a := TAU * i / count
		var c := Vector3(roundf(cos(a) * r), 0, roundf(sin(a) * r))
		if i > 0:
			var mid := (prev + c) * 0.5
			_plat(roundf(mid.x), y + 0.5, roundf(mid.z), Vector3(2, 1, 2), 11, "wool")
			y += 1.0
		_island(c, y, float(rng.randi_range(6, 8)))
		if i % 4 == 3:
			_checkpoint(c.x, y, c.z)
		else:
			_coin(c.x, y + 1.5, c.z)
		prev = c
	var dir := -prev.normalized()
	for k in 4:
		var p := prev + dir * (5.0 + k * 3.5)
		y += 1.0
		_plat(roundf(p.x), y, roundf(p.z), Vector3(2, 1, 2), 11, "wool")
	var crown := prev + dir * 24.0
	y += 1.0
	_island(Vector3(roundf(crown.x), 0, roundf(crown.z)), y, 8)
	_finish(roundf(crown.x), y, roundf(crown.z))


func _gen_race_b() -> void:
	# Downhill: start on a tower, race down ramps and platforms to the ground.
	var y := 40.0
	_plat(0, y, 0, Vector3(8, y, 8), int(theme["colors"][1]), str(theme["path"][0]))
	_spawn(0, y, 1)
	_ground(26)
	var z := -4.0
	for i in 20:
		if i % 4 == 3:
			# Jump down to a lower platform.
			z -= 3.0
			y -= 2.0
		else:
			_part("ramp", Vector3(0, y - 1.0, z - 4.0), Vector3(8, 2, 6), _col(), _path_mat(), {"r": 1})
			z -= 8.0
			y -= 2.0
		_plat(0, y, z - 3.0, Vector3(6, 1, 6))
		if i % 3 == 1:
			_part("speed", Vector3(0, y + 0.5, z - 3.0), Vector3(3, 1, 3), 6)
		elif i % 5 == 4:
			_checkpoint(0, y, z - 3.0)
		elif i % 6 == 5 and hard > 0:
			_part("kill", Vector3(0, y + 0.4, z - 3.0), Vector3(5, 0.5, 0.5), 4, "", {"m": "spin"})
		else:
			_coin(0, y + 1.5, z - 3.0)
		z -= 6.0
	_plat(0, y, z - 4.0, Vector3(10, 1, 10), int(theme["colors"][0]), str(theme["ground"]))
	_finish(0, y, z - 4.0)


func _gen_bounce_b() -> void:
	# A field of trampolines with floating coin platforms and a bounce tower.
	_ground(64)
	_spawn(0, 0, 26)
	for i in 16:
		var x := roundf(rng.randf_range(-24, 24))
		var z := roundf(rng.randf_range(-16, 20))
		if Vector2(x, z - 26).length() < 6:
			continue
		_part("jumppad", Vector3(x, 0.5, z), Vector3(3, 1, 3), 8 + i % 3)
		var top := 5.0 + float(rng.randi_range(0, 2))
		_plat(x + 3, top, z, Vector3(3, 1, 3))
		_coin(x + 3, top + 1.5, z)
	var y := 0.0
	var z2 := -24.0
	for i in 5:
		_plat(0, y, z2, Vector3(5, 1, 5))
		_part("jumppad", Vector3(0, y + 0.5, z2), Vector3(3, 1, 3), 9)
		y += 6.0
		z2 -= 6.0
	_plat(0, y, z2, Vector3(8, 1, 8))
	_finish(0, y, z2)
	_decor(34, 12)


func _gen_vanish_b() -> void:
	# A grid of vanishing tiles over lava. Any way across works - if you're fast.
	var n := 9
	var pitch := 3.5
	var y := 4.0
	var off := -(n - 1) * pitch * 0.5
	_part("kill", Vector3(0, 0.25, 0), Vector3(n * pitch + 14, 0.5, n * pitch + 22), 4)
	_plat(0, y, off - 5.5, Vector3(8, 1, 6), int(theme["colors"][0]), str(theme["ground"]))
	_spawn(0, y, off - 5.5)
	for z in n:
		for x in n:
			if rng.randf() < 0.12 + hard * 0.05 and z > 0 and z < n - 1:
				continue
			var p := _part("block", Vector3(off + x * pitch, y - 0.5, off + z * pitch), Vector3(3, 1, 3), _col(), _path_mat())
			p["n"] = "fade"
			if rng.randf() < 0.08:
				_coin(off + x * pitch, y + 1.5, off + z * pitch)
	_plat(0, y, -off + 5.5, Vector3(8, 1, 6), int(theme["colors"][0]), str(theme["ground"]))
	_finish(0, y, -off + 5.5)
	script_text = VANISH_SCRIPT


func _gen_doors_b() -> void:
	# 3x3 rooms: open the doors one by one, snaking through the grid.
	var order: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1),
		Vector2i(1, 1), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]
	var R := 12.0
	var wall_mat := str(theme["path"][0])
	var wc := int(theme["colors"][1])
	_part("block", Vector3(0, -0.5, 0), Vector3(3 * R + 8, 1, 3 * R + 8), int(theme["colors"][0]), str(theme["ground"]))
	for li in 4:
		var line := -18.0 + R * li
		for k in 3:
			var mid := (k - 1) * R
			# Vertical line (x = line) between rooms (li-1, k) and (li, k).
			_grid_wall(Vector3(line, 2, mid), true, order.find(Vector2i(li - 1, k)), order.find(Vector2i(li, k)), wc, wall_mat)
			# Horizontal line (z = line) between rooms (k, li-1) and (k, li).
			_grid_wall(Vector3(mid, 2, line), false, order.find(Vector2i(k, li - 1)), order.find(Vector2i(k, li)), wc, wall_mat)
	var lines: Array[String] = []
	for i in order.size():
		var c := Vector3((order[i].x - 1) * R, 0, (order[i].y - 1) * R)
		if i == 0:
			_spawn(c.x, 0, c.z)
			continue
		_coin(c.x + 2, 1.5, c.z + 2)
		if i < order.size() - 1:
			var corner := Vector3(3.5 if rng.randf() < 0.5 else -3.5, 0.5, 3.5 if rng.randf() < 0.5 else -3.5)
			_part("block", c + corner, Vector3(2, 1, 2), 7, "", {"n": "button%d" % (i + 1)})
	# The first door is opened by a button in the spawn room.
	var c0 := Vector3((order[0].x - 1) * R, 0, (order[0].y - 1) * R)
	_part("block", c0 + Vector3(-3.5, 0.5, -3.5), Vector3(2, 1, 2), 7, "", {"n": "button1"})
	for i in order.size() - 1:
		lines.append("on_touch(\"button%d\", function(p) open(%d) end)" % [i + 1, i + 1])
	var last := order[order.size() - 1]
	_finish((last.x - 1) * R, 0, (last.y - 1) * R)
	script_text = DOORS_SCRIPT + "\n".join(lines) + "\n"


## One 12-long wall on the room grid, with a named door if a and b are
## consecutive rooms (door number = the later room).
func _grid_wall(at: Vector3, along_z: bool, a: int, b: int, wc: int, wall_mat: String) -> void:
	var size := Vector3(1, 4, 12) if along_z else Vector3(12, 4, 1)
	if a < 0 or b < 0 or absi(a - b) != 1:
		_part("block", at, size, wc, wall_mat)
		return
	var side := Vector3(0, 0, 4) if along_z else Vector3(4, 0, 0)
	var piece := Vector3(1, 4, 4) if along_z else Vector3(4, 4, 1)
	_part("block", at - side, piece, wc, wall_mat)
	_part("block", at + side, piece, wc, wall_mat)
	_part("block", at, piece, 4, "", {"n": "door%d" % maxi(a, b)})


func _gen_swim_b() -> void:
	# A big lake: swim between islands, grab the coins on the lake floor.
	var size := 64.0
	var depth := 6.0
	_part("block", Vector3(0, -depth - 0.5, 0), Vector3(size, 1, size), 3, "sand")
	for side in [-1.0, 1.0]:
		_part("block", Vector3(side * (size * 0.5 + 0.5), -depth * 0.5, 0), Vector3(1, depth, size + 2), 1, "stone")
		_part("block", Vector3(0, -depth * 0.5, side * (size * 0.5 + 0.5)), Vector3(size, depth, 1), 1, "stone")
	_part("water", Vector3(0, -depth * 0.5 + 0.25, 0), Vector3(size, depth - 0.5, size), 8)
	_part("block", Vector3(0, -0.5, size * 0.5 + 8), Vector3(size + 2, 1, 16), int(theme["colors"][0]), str(theme["ground"]))
	_spawn(0, 0, size * 0.5 + 6)
	var z := size * 0.5 - 6.0
	for i in 7:
		var x := roundf(rng.randf_range(-18, 18))
		var w := float(rng.randi_range(5, 8))
		_plat(x, 1, z, Vector3(w, depth + 1, w), int(theme["colors"][0]), str(theme["ground"]))
		_part("ladder", Vector3(x, (1 - depth) * 0.5, z + w * 0.5 + 0.5), Vector3(2, depth + 1, 1), 3)
		if i % 3 == 2:
			_checkpoint(x, 1, z)
		elif str(theme["decor"]) != "none":
			_part("tree", Vector3(x + w * 0.3, 4, z - w * 0.3), Vector3(3, 6, 3), 7)
		_coin(x + rng.randf_range(-4, 4), -depth + 1.0, z + 4)
		z -= 8.0
	_plat(0, 1, -size * 0.5 + 3, Vector3(8, depth + 1, 6), int(theme["colors"][0]), str(theme["ground"]))
	_part("ladder", Vector3(0, (1 - depth) * 0.5, -size * 0.5 + 6.5), Vector3(2, depth + 1, 1), 3)
	_finish(0, 1, -size * 0.5 + 3)


func _gen_hangout_b() -> void:
	# A park plaza: fountain, benches, lamp posts and a stage with lights.
	_ground(72)
	_spawn(0, 0, 22)
	_part("block", Vector3(0, 0.05, 0), Vector3(30, 0.1, 30), 0, "cobble")
	_part("cyl", Vector3(0, 0.6, 0), Vector3(10, 1.2, 10), 0, "stone")
	_part("water", Vector3(0, 1.5, 0), Vector3(8, 0.6, 8), 8)
	_part("cyl", Vector3(0, 2.5, 0), Vector3(1.4, 4, 1.4), 0, "stone")
	_part("sparkles", Vector3(0, 5.5, 0), Vector3(3, 2, 3), 8)
	for i in 8:
		var a := TAU * i / 8.0 + PI / 8.0
		var c := Vector3(roundf(cos(a) * 11), 0, roundf(sin(a) * 11))
		if i % 2 == 0:
			_part("block", c + Vector3(0, 0.8, 0), Vector3(3, 0.3, 1), 3, "planks", {"ry": rad_to_deg(-a) + 90.0})
			_part("block", c + Vector3(0, 0.35, 0), Vector3(2.4, 0.7, 0.6), 1, "metal", {"ry": rad_to_deg(-a) + 90.0})
		else:
			_part("cyl", c + Vector3(0, 2, 0), Vector3(0.3, 4, 0.3), 1, "metal")
			_part("light", c + Vector3(0, 4.3, 0), Vector3.ONE, 6)
	# Stage with color-changing lights.
	_part("block", Vector3(0, 0.5, -20), Vector3(14, 1, 7), 1, "planks")
	for i in 5:
		_part("block", Vector3(-6 + i * 3, 1.1, -23), Vector3(2, 0.2, 0.6), 4 + i, "neon", {"n": "stage"})
		_part("light", Vector3(-6 + i * 3, 4, -22), Vector3.ONE, 4 + i)
	_part("sign", Vector3(0, 3, -23.4), Vector3(8, 2, 0.4), 3, "", {"txt": "Welcome to the park!", "r": 2})
	_part("fire", Vector3(14, 0.5, 14), Vector3(1.5, 1.5, 1.5), 5)
	for i in 4:
		_part("seat", Vector3(10 + i * 2.5, 0.5, 17), Vector3(2, 1, 2), 3, "", {"r": 2})
	_part("kart", Vector3(-20, 1, 20), Vector3(3, 2, 4), 4)
	_part("block", Vector3(14, 0.25, 14), Vector3(2, 0.5, 2), 3, "log")
	_decor(30, 16)
	script_text = """-- The stage lights change color.
local colors = {4, 5, 6, 7, 8, 9, 10}
local i = 1
on_start(function() ui.status("Park hangout - invite friends with HOST!") end)
every(0.6, function()
  world.find("stage"):set_color(colors[i])
  i = i % #colors + 1
end)
"""


# ========================================================== new types ===

func _tycoon_pads(z: float, labels: Array) -> void:
	var prices := [10, 25, 45, 80, 130, 200, 320, 500]
	for i in 8:
		var x := -14.0 + i * 4.0
		_part("block", Vector3(x, 0.15, z), Vector3(3, 0.3, 3), 7, "neon", {"n": "buy%d" % (i + 1)})
		_part("sign", Vector3(x, 1.4, z - 2.2), Vector3(3.6, 1.6, 0.3), 3, "",
			{"txt": "%s\n$%d" % [labels[i], prices[i]], "r": 2})
	var quoted: Array[String] = []
	for l in labels:
		quoted.append("\"%s\"" % l)
	script_text = TYCOON_SCRIPT % ", ".join(quoted)
	for i in 8:
		script_text += "on_touch(\"buy%d\", function(player) buy(%d, player) end)\n" % [i + 1, i + 1]


func _gen_tycoon() -> void:
	# Factory tycoon.
	_ground(72)
	_spawn(0, 0, 24)
	_part("block", Vector3(0, 0.05, -4), Vector3(36, 0.1, 30), 1, "metal")
	_tycoon_pads(14, ["Dropper", "Walls", "Upgrader", "Floor 2", "Ramp", "Roof", "Tower", "Statue"])
	var it := {"n": "item1"}
	_part("block", Vector3(-12, 5, -12), Vector3(3, 3, 3), 1, "metal", it)
	_part("block", Vector3(-12, 2, -12), Vector3(1, 3, 1), 1, "metal", it)
	_part("block", Vector3(-12, 0.4, -4), Vector3(2, 0.6, 14), 1, "metal", it)
	_part("block", Vector3(-12, 3.6, -12), Vector3(1.4, 0.4, 1.4), 6, "neon", it)
	it = {"n": "item2"}
	_part("block", Vector3(0, 2.5, -19.5), Vector3(36, 5, 1), _col(), "brick", it)
	_part("block", Vector3(-17.5, 2.5, -8), Vector3(1, 5, 22), _col(), "brick", it)
	_part("block", Vector3(17.5, 2.5, -8), Vector3(1, 5, 22), _col(), "brick", it)
	it = {"n": "item3"}
	_part("block", Vector3(-13.5, 2, -4), Vector3(1, 4, 1), 9, "neon", it)
	_part("block", Vector3(-10.5, 2, -4), Vector3(1, 4, 1), 9, "neon", it)
	_part("block", Vector3(-12, 4.5, -4), Vector3(4, 1, 1), 9, "neon", it)
	it = {"n": "item4"}
	_part("block", Vector3(4, 6.5, -13), Vector3(26, 1, 12), _col(), "planks", it)
	it = {"n": "item5"}
	_part("ramp", Vector3(13, 3.5, -2), Vector3(10, 7, 4), _col(), "planks", {"n": "item5", "r": 3})
	it = {"n": "item6"}
	_part("block", Vector3(0, 12.5, -8), Vector3(37, 1, 24), _col(), "metal", it)
	it = {"n": "item7"}
	_part("cyl", Vector3(-24, 8, -14), Vector3(5, 16, 5), _col(), "stone", it)
	_part("cone", Vector3(-24, 18, -14), Vector3(6, 4, 6), 4, "", it)
	it = {"n": "item8"}
	_part("block", Vector3(24, 1, 6), Vector3(4, 2, 4), 0, "stone", it)
	_part("block", Vector3(24, 4, 6), Vector3(2, 4, 1.4), 6, "gold", it)
	_part("block", Vector3(24, 6.8, 6), Vector3(1.8, 1.6, 1.6), 6, "gold", it)
	_decor(34, 12)


func _gen_tycoon_b() -> void:
	# Farm tycoon.
	_ground(72)
	_spawn(0, 0, 24)
	_part("block", Vector3(0, 0.05, -4), Vector3(36, 0.1, 30), 3, "dirt")
	_tycoon_pads(14, ["Fence", "Crops", "Barn", "Barn Roof", "Silo", "Tractor", "Windmill", "Gold Cow"])
	var it := {"n": "item1"}
	_part("block", Vector3(0, 0.6, -19), Vector3(36, 1.2, 0.3), 3, "planks", it)
	_part("block", Vector3(-18, 0.6, -6), Vector3(0.3, 1.2, 26), 3, "planks", it)
	_part("block", Vector3(18, 0.6, -6), Vector3(0.3, 1.2, 26), 3, "planks", it)
	it = {"n": "item2"}
	for row in 4:
		_part("block", Vector3(-12, 0.4, -14 + row * 3), Vector3(8, 0.8, 1.2), 2 if row % 2 == 0 else 6, "leaves", it)
	it = {"n": "item3"}
	_part("block", Vector3(8, 2.5, -15), Vector3(10, 5, 1), 4, "planks", it)
	_part("block", Vector3(3.5, 2.5, -10), Vector3(1, 5, 9), 4, "planks", it)
	_part("block", Vector3(12.5, 2.5, -10), Vector3(1, 5, 9), 4, "planks", it)
	it = {"n": "item4"}
	_part("ramp", Vector3(5.5, 6, -10), Vector3(5, 2, 10), 0, "planks", {"n": "item4", "r": 2})
	_part("ramp", Vector3(10.5, 6, -10), Vector3(5, 2, 10), 0, "planks", it)
	it = {"n": "item5"}
	_part("cyl", Vector3(-4, 5, -14), Vector3(4, 10, 4), 0, "metal", it)
	_part("cone", Vector3(-4, 11, -14), Vector3(4.4, 2, 4.4), 4, "", it)
	it = {"n": "item6"}
	_part("block", Vector3(-2, 1.2, 2), Vector3(3, 1.4, 4), 4, "", it)
	_part("block", Vector3(-2, 2.4, 1), Vector3(2, 1.2, 2), 11, "glass", it)
	_part("block", Vector3(-3.6, 0.6, 3.2), Vector3(0.6, 1.2, 1.2), 1, "", it)
	_part("block", Vector3(-0.4, 0.6, 3.2), Vector3(0.6, 1.2, 1.2), 1, "", it)
	it = {"n": "item7"}
	_part("block", Vector3(24, 6, -10), Vector3(2, 12, 2), 0, "stone", it)
	_part("block", Vector3(24, 11, -8.8), Vector3(10, 1, 0.4), 11, "wool", {"n": "item7", "m": "spin"})
	it = {"n": "item8"}
	_part("block", Vector3(24, 1.5, 8), Vector3(4, 2, 2), 6, "gold", it)
	_part("block", Vector3(26.4, 2.4, 8), Vector3(1.4, 1.4, 1.4), 6, "gold", it)
	for k in 4:
		_part("block", Vector3(22.6 + (k % 2) * 2.8, 0.25, 7.3 + (k / 2) * 1.4), Vector3(0.5, 0.5, 0.5), 6, "gold", it)
	_decor(34, 12)


func _gen_floorfall() -> void:
	# Three floors of tiles over lava.
	var n := 8
	var pitch := 3.0
	var off := -(n - 1) * pitch * 0.5
	var cs: Array = theme["colors"]
	for layer in 3:
		var y := 24.0 - layer * 9.0
		for z in n:
			for x in n:
				_part("block", Vector3(off + x * pitch, y - 0.5, off + z * pitch), Vector3(3, 1, 3),
					int(cs[layer % cs.size()]), _path_mat(), {"n": "tile"})
	_part("kill", Vector3(0, 4, 0), Vector3(n * pitch + 30, 1, n * pitch + 30), 4)
	_plat(off - 6.5, 24, 0, Vector3(6, 1, 6), int(cs[0]), str(theme["ground"]))
	_spawn(off - 6.5, 24, 0)
	script_text = FLOORFALL_SCRIPT


func _gen_floorfall_b() -> void:
	# Round floors: rings of round tiles.
	var cs: Array = theme["colors"]
	for layer in 3:
		var y := 24.0 - layer * 9.0
		_part("cyl", Vector3(0, y - 0.5, 0), Vector3(3, 1, 3), int(cs[layer % cs.size()]), _path_mat(), {"n": "tile"})
		for ring in range(1, 5):
			var r := ring * 3.0
			var count := int(TAU * r / 3.1)
			for i in count:
				var a := TAU * i / count + layer * 0.3
				_part("cyl", Vector3(roundf(cos(a) * r * 10) / 10, y - 0.5, roundf(sin(a) * r * 10) / 10), Vector3(3, 1, 3),
					int(cs[(layer + ring) % cs.size()]), _path_mat(), {"n": "tile"})
	_part("kill", Vector3(0, 4, 0), Vector3(60, 1, 60), 4)
	_plat(0, 24, -19, Vector3(6, 1, 6), int(cs[0]), str(theme["ground"]))
	_spawn(0, 24, -19)
	script_text = FLOORFALL_SCRIPT


func _gen_dropper() -> void:
	# Fall down a glass shaft, dodge the lava, land in the pool.
	var top := 110.0
	var hw := 6.0
	var glass := {"a": 0.6}
	_ground(40)
	for side in [-1.0, 1.0]:
		_part("block", Vector3(side * (hw + 0.5), top * 0.5, 0), Vector3(1, top, hw * 2 + 2), 8, "glass", glass)
	_part("block", Vector3(0, top * 0.5, -(hw + 0.5)), Vector3(hw * 2, top, 1), 8, "glass", glass)
	_part("block", Vector3(0, (top - 4) * 0.5, hw + 0.5), Vector3(hw * 2, top - 4, 1), 8, "glass", glass)
	_part("water", Vector3(0, 3, 0), Vector3(hw * 2, 6, hw * 2), 8)
	_part("finish", Vector3(0, 0.5, 0), Vector3(4, 1, 4), 6)
	_plat(0, top, hw + 5, Vector3(8, 1, 8), int(theme["colors"][0]), str(theme["path"][0]))
	_spawn(0, top, hw + 6)
	for k in 12:
		var y := top - 10.0 - k * 8.0
		match k % 4:
			0:
				var s := 1.0 if rng.randf() < 0.5 else -1.0
				_part("kill", Vector3(s * hw * 0.5, y, 0), Vector3(hw, 1, hw * 2), 4)
				_coin(-s * hw * 0.5, y + 2, 0)
			1:
				for b in 3:
					_part("kill", Vector3(0, y, -hw + 2 + b * 4), Vector3(hw * 2, 1, 1.5), 4)
			2:
				_part("kill", Vector3(0, y, 0), Vector3(hw * 2 - 1, 1, 1.2), 4, "", {"m": "spin"})
				_coin(hw - 2, y + 3, hw - 2)
			_:
				var hx := roundf(rng.randf_range(-2, 2))
				var hz := roundf(rng.randf_range(-2, 2))
				_part("kill", Vector3((hx - 2 - hw) * 0.5, y, 0), Vector3(hx - 2 + hw, 1, hw * 2), 4)
				_part("kill", Vector3((hx + 2 + hw) * 0.5, y, 0), Vector3(hw - hx - 2, 1, hw * 2), 4)
				_part("kill", Vector3(hx, y, (hz - 2 - hw) * 0.5), Vector3(4, 1, hz - 2 + hw), 4)
				_part("kill", Vector3(hx, y, (hz + 2 + hw) * 0.5), Vector3(4, 1, hw - hz - 2), 4)
				_coin(hx, y - 1, hz)


func _gen_dropper_b() -> void:
	# Sky drop: fall through floating rings and land in the lake.
	var top := 100.0
	_plat(0, top, 0, Vector3(8, 1, 8), int(theme["colors"][0]), str(theme["path"][0]))
	_spawn(0, top, 2)
	_ground(70)
	_part("block", Vector3(0, 0.05, -14), Vector3(22, 0.1, 22), 3, "sand")
	_part("water", Vector3(0, 2, -14), Vector3(20, 4, 20), 8)
	_part("finish", Vector3(0, 0.5, -14), Vector3(4, 1, 4), 6)
	var c := Vector3(0, 0, -6)
	for k in 10:
		var y := top - 10.0 - k * 9.0
		c = Vector3(roundf(clampf(c.x + rng.randf_range(-3, 3), -5, 5)), 0, roundf(lerpf(-6, -14, k / 9.0)))
		var col := _col()
		_part("block", Vector3(c.x - 3, y, c.z), Vector3(1, 1, 7), col, "neon")
		_part("block", Vector3(c.x + 3, y, c.z), Vector3(1, 1, 7), col, "neon")
		_part("block", Vector3(c.x, y, c.z - 3), Vector3(5, 1, 1), col, "neon")
		_part("block", Vector3(c.x, y, c.z + 3), Vector3(5, 1, 1), col, "neon")
		_coin(c.x, y, c.z)
		if k % 3 == 1:
			_part("kill", Vector3(c.x + (6 if k % 2 == 0 else -6), y - 4, c.z), Vector3(5, 1, 5), 4, "", {"m": "slide_x"})
	_decor(30, 12)


func _gen_sweeper() -> void:
	# Round arena over lava with a spinning bar.
	var cs: Array = theme["colors"]
	_part("kill", Vector3(0, 0.25, 0), Vector3(70, 0.5, 70), 4)
	_part("cyl", Vector3(0, 1.5, 0), Vector3(30, 3, 30), int(cs[0]), str(theme["ground"]))
	_plat(0, 3, 22, Vector3(6, 1, 6), int(cs[1]), _path_mat())
	_spawn(0, 3, 22)
	_plat(0, 3, 17, Vector3(2, 1, 4), int(cs[1]), _path_mat())
	_part("kill", Vector3(0, 3.45, 0), Vector3(28, 0.8, 0.8), 4, "", {"m": "spin", "n": "bar"})
	if hard == 2:
		_part("kill", Vector3(0, 3.45, 0), Vector3(0.8, 0.8, 28), 4, "", {"m": "spin", "n": "bar"})
	_part("cyl", Vector3(0, 4.5, 0), Vector3(1.6, 3, 1.6), int(cs[2 % cs.size()]), "metal")
	for i in 6:
		var a := TAU * i / 6.0
		_coin(roundf(cos(a) * 9), 4.5, roundf(sin(a) * 9))
	script_text = SWEEPER_SCRIPT


func _gen_sweeper_b() -> void:
	# Square arena: two spinning bars and sliding lava blocks.
	var cs: Array = theme["colors"]
	_part("kill", Vector3(0, 0.25, 0), Vector3(70, 0.5, 70), 4)
	_plat(0, 3, 0, Vector3(32, 3, 32), int(cs[0]), str(theme["ground"]))
	_plat(0, 3, 21, Vector3(6, 1, 6), int(cs[1]), _path_mat())
	_spawn(0, 3, 21)
	_plat(0, 3, 17, Vector3(2, 1, 2), int(cs[1]), _path_mat())
	_part("kill", Vector3(-8, 3.45, -8), Vector3(14, 0.8, 0.8), 4, "", {"m": "spin", "n": "bar"})
	_part("kill", Vector3(8, 3.45, 8), Vector3(14, 0.8, 0.8), 4, "", {"m": "spin", "n": "bar"})
	_part("kill", Vector3(-12, 3.5, 0), Vector3(2, 1, 2), 4, "", {"m": "slide_x", "n": "bar"})
	if hard > 0:
		_part("kill", Vector3(0, 3.5, -12), Vector3(2, 1, 2), 4, "", {"m": "slide_z", "n": "bar"})
	for i in 4:
		_coin(-10 + i * 7, 4.5, 3)
	script_text = SWEEPER_SCRIPT


func _button(at: Vector3) -> void:
	_part("cyl", at + Vector3(0, 0.2, 0), Vector3(1, 0.4, 1), 4, "neon", {"n": "btn"})


func _gen_buttons() -> void:
	# A mansion with a garden. Buttons are hidden all over.
	_ground(76)
	_spawn(0, 0, 28)
	_house(Vector3(0, 0, 0), 20, 14, 6)
	_house(Vector3(0, 7, -2), 10, 8, 4)
	_house(Vector3(-22, 0, 10), 6, 6, 4)
	_part("cyl", Vector3(16, 0.6, 14), Vector3(8, 1.2, 8), 0, "stone")
	_part("water", Vector3(16, 1.5, 14), Vector3(6, 0.6, 6), 8)
	_plat(22, 8, -18, Vector3(3, 8, 3), _col(), _path_mat())
	_part("ladder", Vector3(22, 4.5, -16), Vector3(2, 9, 1), 3)
	for i in 6:
		_part("tree", Vector3(-26 + i * 9, 3, -24), Vector3(3, 6, 3), 7)
	_part("block", Vector3(-14, 1, -12), Vector3(3, 2, 3), 1, "stone")
	var spots: Array[Vector3] = [Vector3(-8, 0, -5), Vector3(8, 0, 5), Vector3(0, 7, 4), Vector3(0, 7, -4.5),
		Vector3(-22, 0, 10), Vector3(16, 1.8, 14), Vector3(22, 8, -18), Vector3(-26, 0, -26),
		Vector3(-14, 2, -12), Vector3(-22, 5, 10), Vector3(30, 0, 30), Vector3(0, 12, -2)]
	var count := 10 if hard == 0 else 12
	for i in count:
		_button(spots[i])
	_part("flashlight", Vector3(4, 1, 26), Vector3(1, 2, 1), 6)
	_part("block", Vector3(0, 2, 22), Vector3(4, 4, 4), 6, "gold", {"n": "prize"})
	_coin(0, 5, 22)
	script_text = BUTTONS_SCRIPT % count


func _gen_buttons_b() -> void:
	# A park with hills, a pond, a bridge and a cave. Find the buttons.
	_ground(80)
	_spawn(0, 0, 30)
	for k in 4:
		var s := 16.0 - k * 4.0
		_part("block", Vector3(-18, k + 0.5, -14), Vector3(s, 1, s), int(theme["colors"][0]), str(theme["ground"]))
	_part("block", Vector3(16, -0.45, -6), Vector3(14, 0.1, 18), 3, "sand")
	_part("water", Vector3(16, 0.5, -6), Vector3(12, 1, 16), 8)
	_plat(16, 1.5, -6, Vector3(12, 0.5, 2), 3, "planks")
	_part("block", Vector3(-4, 3, 14), Vector3(10, 1, 4), 1, "stone")
	_part("block", Vector3(-8.5, 1.25, 14), Vector3(1, 2.5, 4), 1, "stone")
	_part("block", Vector3(0.5, 1.25, 14), Vector3(1, 2.5, 4), 1, "stone")
	for i in 10:
		var a := TAU * i / 10.0
		_part("tree", Vector3(roundf(cos(a) * 32), 3, roundf(sin(a) * 32)), Vector3(3, 6, 3), 7)
	var spots: Array[Vector3] = [Vector3(-18, 4, -14), Vector3(-24, 1, -8), Vector3(16, 1.5, -6), Vector3(20, 0, 6),
		Vector3(-4, 0, 14), Vector3(-4, 3.5, 14), Vector3(32, 0, 0), Vector3(-32, 0, 0), Vector3(0, 0, -32),
		Vector3(10, 0, -20), Vector3(-12, 0, 24), Vector3(26, 0, 22)]
	var count := 10 if hard == 0 else 12
	for i in count:
		_button(spots[i])
	_part("block", Vector3(0, 2, 0), Vector3(4, 4, 4), 6, "gold", {"n": "prize"})
	_coin(0, 5, 0)
	script_text = BUTTONS_SCRIPT % count
