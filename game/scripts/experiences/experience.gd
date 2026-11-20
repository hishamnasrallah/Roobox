class_name Experience
extends Node3D
## Base class for every playable game ("experience") on the platform.
## Subclasses build their world in `setup()` and react to round events
## coming from their GameMode (which runs only on the authority:
## solo / host / dedicated server).

## (text, color) for the HUD banner. Empty text hides it.
signal status_changed(text: String, color: Color)

var id: String = ""
var spawn_point: Vector3 = Vector3(0, 1, 0)
var kill_height: float = -7.0
## The local player (null on dedicated servers / before spawn).
var player: Player = null
var hud: Hud = null


## Build the world. Called once, right after the node enters the tree.
func setup() -> void:
	pass


## The local player has spawned.
func on_player_ready(_p: Player) -> void:
	pass


## A round/state event from the authority's GameMode.
func apply_event(_ev: Dictionary) -> void:
	pass


## Current mode snapshot (sent to late joiners). Only used by modes.
func set_status(text: String, color: Color = Color(1, 1, 1)) -> void:
	status_changed.emit(text, color)


## Utility: submit a score to the online board and remember the local best.
## higher_is_better = true for survival/rounds/stages.
func report_score(board: String, value: int, higher_is_better: bool = true) -> bool:
	var prev: int = int(Game.best_scores.get(board, 0))
	var better := prev == 0 or (value > prev if higher_is_better else value < prev)
	if better and value > 0:
		Game.best_scores[board] = value
		Game.save_profile()
	if Backend.online and value > 0:
		Backend.submit(board, value)
	return better
