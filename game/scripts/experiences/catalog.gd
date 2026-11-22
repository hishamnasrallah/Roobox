class_name Catalog
extends RefCounted
## All experiences available on the platform.

const DEFAULT_ID := "island"

const ENTRIES: Array[Dictionary] = [
	{
		"id": "island", "title": "Plazo Island", "tag": "EXPLORE",
		"desc": "A big island with an obby over the ocean, a 60m sky tower, a playground, a maze and a village. Collect coins and set records!",
		"color": Color(0.3, 0.72, 0.4), "max": 32,
		"scene": "res://scripts/experiences/island.gd", "mode": "",
	},
	{
		"id": "lava_rising", "title": "Lava Rising", "tag": "SURVIVAL",
		"desc": "The lava is rising! Climb the floating tower and survive as long as you can. Rounds restart automatically.",
		"color": Color(1.0, 0.42, 0.15), "max": 24,
		"scene": "res://scripts/experiences/lava_rising.gd", "mode": "res://scripts/experiences/lava_mode.gd",
	},
	{
		"id": "color_drop", "title": "Color Drop", "tag": "PARTY",
		"desc": "A color is called - run to a tile of that color before everything else disappears! Each round gets faster.",
		"color": Color(0.6, 0.4, 1.0), "max": 24,
		"scene": "res://scripts/experiences/color_drop.gd", "mode": "res://scripts/experiences/color_mode.gd",
	},
	{
		"id": "obby_rush", "title": "Obby Rush", "tag": "OBBY",
		"desc": "An endless obby that gets harder every stage. How far can you go?",
		"color": Color(0.25, 0.6, 1.0), "max": 32,
		"scene": "res://scripts/experiences/obby_rush.gd", "mode": "",
	},
	{
		"id": "ugc", "title": "Community Game", "tag": "CREATED", "hidden": true,
		"desc": "A game made in Plazo Studio.",
		"color": Color(0.95, 0.5, 0.6), "max": 16,
		"scene": "res://scripts/experiences/ugc.gd", "mode": "",
	},
]

## Leaderboards: id -> {title, kind}. kind: "time" (lower wins) or a unit word.
const BOARDS: Array[Dictionary] = [
	{"id": "obby_land", "title": "Obby Land", "kind": "time"},
	{"id": "sky_tower", "title": "Sky Tower", "kind": "time"},
	{"id": "lava_rising", "title": "Lava Rising", "kind": "seconds survived"},
	{"id": "color_drop", "title": "Color Drop", "kind": "rounds"},
	{"id": "obby_rush", "title": "Obby Rush", "kind": "stages"},
]


static func get_entry(exp_id: String) -> Dictionary:
	for e in ENTRIES:
		if e["id"] == exp_id:
			return e
	return ENTRIES[0]


static func has(exp_id: String) -> bool:
	for e in ENTRIES:
		if e["id"] == exp_id:
			return true
	return false


static func create(exp_id: String) -> Experience:
	var entry := get_entry(exp_id)
	var inst: Experience = (load(entry["scene"]) as GDScript).new()
	inst.id = entry["id"]
	inst.name = "Experience"
	return inst


static func create_mode(exp_id: String) -> GameMode:
	var path: String = get_entry(exp_id)["mode"]
	if path == "":
		return null
	var mode: GameMode = (load(path) as GDScript).new()
	mode.name = "GameMode"
	return mode
