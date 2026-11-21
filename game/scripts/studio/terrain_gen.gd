class_name TerrainGen
extends RefCounted
## Studio terrain generator: blocky landscapes made of normal parts
## (a top layer + a body column per cell), grouped as "terrain" and locked
## so building on top of them doesn't select them by accident.

const KINDS: Array[String] = ["hills", "island", "mountains", "desert", "snow", "canyon"]
const LABELS: Dictionary = {
	"hills": "HILLS", "island": "ISLAND", "mountains": "MOUNTAINS",
	"desert": "DESERT", "snow": "SNOW", "canyon": "CANYON",
}


## Returns the parts for a terrain centered at `center` (y = base level).
## size = cells per side, cell = cell width in studs.
static func generate(kind: String, center: Vector3, seed_value: int, size: int = 16, cell: float = 4.0) -> Array:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.06
	noise.fractal_octaves = 3
	var top_mat := "grass"
	var top_col := 7
	var body_mat := "dirt"
	var amp := 6.0
	var water := -100.0
	match kind:
		"island":
			water = 2.0
			amp = 8.0
		"mountains":
			amp = 16.0
			body_mat = "stone"
		"desert":
			top_mat = "sand"
			top_col = 6
			body_mat = "sand"
			amp = 4.0
		"snow":
			top_mat = "snow"
			top_col = 11
			body_mat = "stone"
			amp = 10.0
		"canyon":
			top_mat = "sand"
			top_col = 5
			body_mat = "basalt"
			amp = 12.0
	var out: Array = []
	var half := size * cell * 0.5
	for gz in size:
		for gx in size:
			var x := center.x - half + (gx + 0.5) * cell
			var z := center.z - half + (gz + 0.5) * cell
			var n := (noise.get_noise_2d(gx, gz) + 1.0) * 0.5
			var h := n * amp
			match kind:
				"island":
					var d := Vector2(gx - size * 0.5 + 0.5, gz - size * 0.5 + 0.5).length() / (size * 0.5)
					h = maxf(0.0, (1.0 - d * d) * amp + (n - 0.5) * 4.0)
				"mountains":
					h = pow(n, 1.8) * amp
				"canyon":
					var rv := absf(gx - size * 0.5 + sin(gz * 0.5) * 2.0)
					h = amp if rv > 2.5 else 1.0
					h += (n - 0.5) * 2.0
			h = maxf(1.0, roundf(h))
			var tm := top_mat
			var tc := top_col
			if kind == "island" and h <= water + 1.0:
				tm = "sand"
				tc = 6
			elif kind == "mountains" and h > amp * 0.7:
				tm = "snow"
				tc = 11
			elif kind == "mountains" and h > amp * 0.4:
				tm = "stone"
				tc = 1
			var base := center.y
			if h > 1.0:
				out.append({"t": "block", "p": Level._arr(Vector3(x, base + (h - 1.0) * 0.5, z)),
					"s": [cell, h - 1.0, cell], "r": 0, "c": 3, "mat": body_mat, "g": "terrain", "k": 1})
			out.append({"t": "block", "p": Level._arr(Vector3(x, base + h - 0.5, z)),
				"s": [cell, 1, cell], "r": 0, "c": tc, "mat": tm, "g": "terrain", "k": 1})
	if water > -50.0:
		out.append({"t": "water", "p": Level._arr(Vector3(center.x, center.y + water * 0.5, center.z)),
			"s": [size * cell + 16, water, size * cell + 16], "r": 0, "c": 8, "g": "terrain", "k": 1})
	return out
