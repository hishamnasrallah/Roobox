extends Experience
## Plays a user-made level (from Studio, local creations or COMMUNITY).
## The level data comes from Game.pending_level.

var level: Dictionary = {}


func setup() -> void:
	level = Level.sanitize(Game.pending_level)
	Level.build_play(self, level)
	spawn_point = Level.spawn_point(level)
	var lowest := spawn_point.y
	for p: Dictionary in level["parts"]:
		lowest = minf(lowest, Level.pos(p).y - Level.size(p).y)
	kill_height = lowest - 25.0
	var sky_label := Label3D.new()
	sky_label.text = str(level["name"])
	sky_label.font_size = 160
	sky_label.outline_size = 32
	sky_label.modulate = Color(1.0, 0.85, 0.3)
	sky_label.outline_modulate = Color(0.06, 0.07, 0.15)
	sky_label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sky_label.position = spawn_point + Vector3(0, 7, -8)
	add_child(sky_label)


func on_player_ready(_p: Player) -> void:
	Game.checkpoint_position = spawn_point
	for p: Dictionary in level["parts"]:
		if p["t"] == "finish":
			# Start the timer right away so reaching FINISH counts.
			Game.start_course(str(level["name"]))
			break
	if Game.testing:
		set_status("TEST MODE - press MENU to go back to the editor", Color(1.0, 0.85, 0.3))
