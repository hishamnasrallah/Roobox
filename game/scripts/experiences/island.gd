extends Experience
## Roobox Island: the big hub world (obby, sky tower, playground, village).

var world: World


func setup() -> void:
	world = World.new()
	world.name = "World"
	add_child(world)
	spawn_point = world.spawn_point
	kill_height = -7.0
